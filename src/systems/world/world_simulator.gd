## 世界模擬：時間推進的唯一入口。世界不因玩家而停止——
## 所有俱樂部、選手、聯賽在同一套規則下每天推進。
##
## 一年的循環：季前賽（2 週）→ 例行賽 → 季後賽 → 賽季結算 → 休賽季（4 週轉會期）→ 新賽季
## 效能策略（GDD 18）：每週才計算訓練/成長/心理；休賽季 AI 分批行動；
## 非玩家比賽不保留逐事件紀錄（相同規則，僅省略敘事）。
class_name WorldSimulator
extends RefCounted

const OFFSEASON_DAYS := 28


static func advance_day(w: WorldState) -> Array:
	w.day += 1
	var results: Array = []
	match w.phase:
		WorldState.PHASE_PRESEASON:
			if w.day >= w.phase_day + LeagueEngine.PRESEASON_DAYS:
				w.phase = WorldState.PHASE_REGULAR
				w.phase_day = w.day
			results = LeagueEngine.play_day(w)
		WorldState.PHASE_REGULAR, WorldState.PHASE_PLAYOFFS:
			results = LeagueEngine.play_day(w)
			for lg in w.leagues.values():
				if LeagueEngine.regular_done(lg) and lg.playoff_bracket.is_empty():
					LeagueEngine.start_playoffs(w, lg)
					w.phase = WorldState.PHASE_PLAYOFFS
			if w.leagues.values().all(func(l): return l.season_complete):
				end_season(w)
		WorldState.PHASE_OFFSEASON:
			_offseason_day(w, w.day - w.phase_day)
	if w.day % Tuning.i("days_per_week") == 0:
		weekly(w)
	return results


static func advance_days(w: WorldState, n: int) -> void:
	for i in n:
		advance_day(w)


## 推進到指定年份的賽季開始（用於長期模擬測試與「快速推進」）。
static func advance_to_year(w: WorldState, target_year: int, max_days: int = 100000) -> void:
	var guard := 0
	while w.year < target_year and guard < max_days:
		advance_day(w)
		guard += 1


static func weekly(w: WorldState) -> void:
	var in_season = w.phase != WorldState.PHASE_OFFSEASON
	for club in w.clubs.values():
		var coach: Staff = w.staff.get(club.coach_id)
		var focus = TrainingEngine.weekly(w, club)
		for pid in club.roster:
			var p: Player = w.players[pid]
			Development.weekly(w, p, focus.get(pid, {}), coach)
			if in_season:
				CareerAgent.weekly(w, p)
		if not club.is_human:
			ClubAI.weekly(w, club)
		_finance_week(w, club)
	Scouting.weekly(w)
	for pid in w.free_agents:
		var p: Player = w.players[pid]
		Development.weekly(w, p, {}, null)
		p.motivation = clampf(p.motivation - 0.8, 0.0, 100.0)


static func _finance_week(w: WorldState, club: Club) -> void:
	var wages = TransferMarket.wage_bill(w, club) / 52
	var coach: Staff = w.staff.get(club.coach_id)
	if coach:
		wages += coach.salary / 52
	var income = int(club.wage_budget / 52.0 * (0.80 + club.reputation / 300.0))
	club.cash += income - wages


# ---------------------------------------------------------------- 賽季結算

static func end_season(w: WorldState) -> void:
	var season = {"year": w.year, "patch": w.patch.version, "leagues": {}}
	for lg in w.leagues.values():
		var order = LeagueEngine.sorted_standings(lg)
		var awards = _awards(w, lg)
		season["leagues"][lg.id] = {"champion": lg.champion_id, "standings": order, "mvp": awards["mvp"], "all_pro": awards["all_pro"]}
		var champ: Club = w.clubs.get(lg.champion_id)
		if champ:
			champ.titles += 1
			for pid in champ.lineup.values():
				w.players[pid].career["titles"] = int(w.players[pid].career.get("titles", 0)) + 1
				w.players[pid].reputation = minf(w.players[pid].reputation + 6.0, 100.0)  # 冠軍選手身價上漲
		if awards["mvp"] != "":
			w.players[awards["mvp"]].career["mvps"] = int(w.players[awards["mvp"]].career.get("mvps", 0)) + 1
		var n = order.size()
		for i in n:
			var club: Club = w.clubs[order[i]]
			var is_champ = club.id == lg.champion_id
			var prize = lg.prize_pool * (0.35 if is_champ else (0.65 / maxf(n - 1, 1)))
			club.cash += int(prize)
			var expected = (1.0 - club.reputation / 100.0) * n
			club.reputation = clampf(club.reputation + (expected - i) * 0.8 + (4.0 if is_champ else 0.0), 5.0, 99.0)
			# 聲望回歸平均：沒有成績支撐的光環會慢慢褪去
			club.reputation = lerpf(club.reputation, 55.0, 0.08)
			# 下季薪資預算：由聲望與粉絲決定，受聯賽薪資上限約束
			var cap = int(lg.format.get("wage_cap", 99999999))
			var target = 350000.0 + club.reputation * 20000.0 + club.fanbase * 0.2 + maxf(club.cash, 0.0) * 0.08  # 有存款的俱樂部可以加碼
			club.wage_budget = clampi(int(club.wage_budget * 0.6 + target * 0.4), 300000, cap)
			club.history.append({"year": w.year, "league_id": lg.id, "position": i + 1, "champion": is_champ})
			if not club.is_human:
				ClubAI.review_coach(w, club, i + 1, n)
		w.log.add("season_end", w.day, [lg.id], {"champion": lg.champion_id, "mvp": awards["mvp"]}, [])
	for p in w.active_players():
		var g: int = p.season_stats.get("games", 0)
		if g > 0 or p.club_id != "":
			p.history.append({"year": w.year, "club_id": p.club_id, "games": g, "wins": p.season_stats.get("wins", 0), "avg_rating": snappedf(p.avg_season_rating(), 0.01)})
	w.history["seasons"].append(season)
	w.phase = WorldState.PHASE_OFFSEASON
	w.phase_day = w.day


static func _awards(w: WorldState, lg: League) -> Dictionary:
	var max_games := 0
	var pool: Array = []
	for cid in lg.club_ids:
		for pid in w.clubs[cid].roster:
			var p: Player = w.players[pid]
			max_games = maxi(max_games, p.season_stats.get("games", 0))
			pool.append(p)
	var eligible = pool.filter(func(p): return p.season_stats.get("games", 0) >= max_games * 0.5 and max_games > 0)
	eligible.sort_custom(func(a, b): return a.avg_season_rating() > b.avg_season_rating())
	var all_pro := {}
	for p in eligible:
		if not all_pro.has(p.primary_role):
			all_pro[p.primary_role] = p.id
	return {"mvp": eligible[0].id if eligible.size() > 0 else "", "all_pro": all_pro}


# ---------------------------------------------------------------- 休賽季

static func _offseason_day(w: WorldState, d: int) -> void:
	var clubs: Array = w.clubs.values()
	if d == 1:
		_notify_human_expiring(w)
		_retirements(w)
		_new_patch(w)
		_youth_intake(w)
	elif d >= 2 and d <= 6:
		for i in clubs.size():
			if i % 5 == d - 2 and not clubs[i].is_human:
				ClubAI.offseason_step(w, clubs[i], "renew")
	elif d == 7:
		_expire_contracts(w)
	elif d >= 8 and d <= 24:
		for i in clubs.size():
			if i % 2 == d % 2 and not clubs[i].is_human:
				ClubAI.offseason_step(w, clubs[i], "recruit")
	elif d == 25:
		for c in clubs:
			if not c.is_human:
				ClubAI.offseason_step(w, c, "trim")
				ClubAI.offseason_step(w, c, "recruit")
		# 最後一輪挖角可能讓別隊缺人：只補自由選手/新人，不再挖角
		for c in clubs:
			if not c.is_human:
				ClubAI.fill_roster(w, c)
	elif d >= OFFSEASON_DAYS:
		_new_season(w)


static func _retirements(w: WorldState) -> void:
	for p in w.active_players():
		if CareerAgent.retirement_check(w, p, w.rng):
			p.retired = true
			p.retired_year = w.year
			var club_id = p.club_id
			if club_id != "" and w.clubs.has(club_id):
				var c: Club = w.clubs[club_id]
				c.roster.erase(p.id)
				for role in c.lineup.keys():
					if c.lineup[role] == p.id:
						c.lineup.erase(role)
			w.free_agents.erase(p.id)
			p.club_id = ""
			p.contract = null
			w.history["retirements"].append({"year": w.year, "player_id": p.id, "handle": p.handle, "age": p.age(w.year), "titles": p.career.get("titles", 0)})
			w.log.add("retirement", w.day, [p.id, club_id], {"age": p.age(w.year)}, [])


static func _new_patch(w: WorldState) -> void:
	w.patch = WorldBuilder.generate_patch(w, w.rng, "%d.1" % ((w.year + 1) % 100))
	# 新英雄推出：約每兩年一隻（由既有英雄的標籤重組生成，名稱由資料模組的名字庫組合）
	if w.rng.chance(0.5):
		var base: Champion = w.rng.pick(w.champions.values())
		var c = Champion.from_dict(base.to_dict())
		c.id = "gen_%d_%s" % [w.year, base.id]
		c.name = "%s Reborn" % base.name
		for t in c.tags.keys():
			c.tags[t] = clampf(float(c.tags[t]) + w.rng.range_i(-1, 1), 0.0, 3.0)
		c.early = clampf(c.early + w.rng.range_i(-2, 2), 2, 9)
		c.late = clampf(c.late + w.rng.range_i(-2, 2), 2, 9)
		w.champions[c.id] = c
		w.patch.tiers[c.id] = 1.0
		w.log.add("new_champion", w.day, [], {"champion": c.id}, [])
	for p in w.active_players():
		Development.adapt_to_patch(w, p, w.rng)


static func _youth_intake(w: WorldState) -> void:
	for lg in w.leagues.values():
		for i in Tuning.i("regens_per_league_per_year"):
			var role: String = Attr.ROLES[i % 5]
			var q = clampf(w.rng.normal(0.35, 0.2), 0.0, 1.0)
			var p = PlayerGenerator.generate(w, w.rng, lg.region, role, q, true)
			w.players[p.id] = p
			w.free_agents.append(p.id)
			w.log.add("regen", w.day, [p.id], {"region": lg.region, "role": role}, [])


static func _expire_contracts(w: WorldState) -> void:
	for club in w.clubs.values():
		for pid in club.roster.duplicate():
			var p: Player = w.players[pid]
			if p.contract == null or p.contract.end_year <= w.year:
				TransferMarket.release(w, club, p, "合約到期")


static func _new_season(w: WorldState) -> void:
	w.year += 1
	for p in w.active_players():
		p.reset_season_stats()
		p.goals = PlayerGenerator.derive_goals(p, w.year)
		p.fatigue = 10.0
		p.stress = lerpf(p.stress, 25.0, 0.6)
		p.refuses_renewal = false
		p.weeks_unhappy = 0
	# 長期無人簽約的老將與低水準自由選手離開職業圈
	for pid in w.free_agents.duplicate():
		var p: Player = w.players[pid]
		if p.age(w.year) >= 24 and p.current_ability() < 50.0 and w.rng.chance(0.5):
			p.retired = true
			p.retired_year = w.year
			w.free_agents.erase(pid)
	for club in w.clubs.values():
		LineupSelector.pick(w, club)
	LeagueEngine.start_season(w)
	w.log.add("season_start", w.day, [], {"year": w.year}, [])


static func _notify_human_expiring(w: WorldState) -> void:
	var club: Club = w.human_club()
	if club == null:
		return
	var expiring: Array = club.roster.filter(func(pid): return w.players[pid].contract and w.players[pid].contract.end_year <= w.year)
	if expiring.is_empty():
		return
	var names = expiring.map(func(pid): return w.players[pid].handle)
	w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "contracts_expiring", "player_id": "",
		"text": "轉會期開始：%d 名選手合約即將到期（%s）。第 7 天前未續約將成為自由球員。" % [expiring.size(), "、".join(names)],
		"resolved": false, "options": ["acknowledge"]})
