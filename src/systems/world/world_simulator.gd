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
			LeagueEngine.maybe_start_midseason(w)
			LeagueEngine.advance_internationals(w)
			for lg in w.leagues.values():
				if LeagueEngine.regular_done(lg) and lg.playoff_bracket.is_empty():
					LeagueEngine.start_playoffs(w, lg)
					w.phase = WorldState.PHASE_PLAYOFFS
			if w.leagues.values().all(func(l): return l.season_complete):
				if LeagueEngine.start_international(w):
					w.phase = WorldState.PHASE_INTERNATIONAL
					w.phase_day = w.day
				else:
					end_season(w)
		WorldState.PHASE_INTERNATIONAL:
			results = LeagueEngine.play_day(w)
			LeagueEngine.advance_internationals(w)
			if w.international.season_complete:
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
		if in_season:
			Relationships.weekly(w, club)
			Media.weekly(w, club)
			RandomEvents.weekly(w, club)
		if not club.is_human:
			ClubAI.weekly(w, club)
		_finance_week(w, club)
	Scouting.weekly(w)
	for pid in w.free_agents:
		var p: Player = w.players[pid]
		Development.weekly(w, p, {}, null)
		p.motivation = clampf(p.motivation - 0.8, 0.0, 100.0)


static func _finance_week(w: WorldState, club: Club) -> void:
	Finance.weekly(w, club)
	Organization.weekly(w, club)


# ---------------------------------------------------------------- 賽季結算

static func end_season(w: WorldState) -> void:
	var season = {"year": w.year, "patch": w.patch.version, "leagues": {}}
	var worlds_result = _close_international(w, season)
	var mid_results := {}
	for it in LeagueEngine.midseason_events(w):
		mid_results[it.id] = _close_international(w, season, it)
	var msi_result: Dictionary = mid_results.get("msi", {})
	for lg in w.leagues.values():
		var order = LeagueEngine.sorted_standings(lg)
		var awards = _awards(w, lg)
		season["leagues"][lg.id] = {"champion": lg.champion_id, "standings": order, "mvp": awards["mvp"], "all_pro": awards["all_pro"]}
		var champ: Club = w.clubs.get(lg.champion_id)
		if champ:
			champ.titles += 1
			for pid in champ.lineup.values():
				w.players[pid].career["titles"] = int(w.players[pid].career.get("titles", 0)) + 1
				# 冠軍後的鬆懈：野心越小越容易滿足（連霸越來越難）
				var pl: Player = w.players[pid]
				pl.motivation = clampf(pl.motivation - (4.0 + 12.0 * (1.0 - pl.trait_value("ambition") / 100.0)), 0.0, 100.0)
				w.players[pid].reputation = minf(w.players[pid].reputation + 6.0, 100.0)  # 冠軍選手身價上漲
		if awards["mvp"] != "":
			w.players[awards["mvp"]].career["mvps"] = int(w.players[awards["mvp"]].career.get("mvps", 0)) + 1
		var n = order.size()
		for i in n:
			var club: Club = w.clubs[order[i]]
			var is_champ = club.id == lg.champion_id
			var prize = lg.prize_pool * (0.35 if is_champ else (0.65 / maxf(n - 1, 1)))
			Finance.earn(club, "prize", int(prize))
			Finance.pay_bonuses(w, club, i + 1, is_champ, i < int(lg.format.get("playoffs", {}).get("teams", 4)))
			Finance.update_fanbase(club, i + 1, n, is_champ)
			var expected = (1.0 - club.reputation / 100.0) * n
			club.reputation = rep_change(club.reputation, (expected - i) * 0.8 + (4.0 if is_champ else 0.0))
			# 聲望回歸平均：沒有成績支撐的光環會慢慢褪去
			club.reputation = lerpf(club.reputation, 55.0 if lg.tier <= 1 else 30.0, 0.08)
			# 下季薪資預算：由聲望與粉絲決定，受聯賽薪資上限約束
			var cap = int(lg.format.get("wage_cap", 99999999))
			var target = 350000.0 + club.reputation * 20000.0 + club.fanbase * 0.2 + maxf(club.cash, 0.0) * 0.08  # 有存款的俱樂部可以加碼
			club.wage_budget = clampi(int(club.wage_budget * 0.6 + target * 0.4), 300000, cap)
			club.history.append({"year": w.year, "league_id": lg.id, "tier": lg.tier, "position": i + 1, "champion": is_champ,
				"worlds": worlds_result.get(club.id, ""), "msi": msi_result.get(club.id, ""),
				"intl": _club_intl(mid_results, club.id)})
			if not club.is_human:
				ClubAI.review_coach(w, club, i + 1, n)
			Finance.close_season(w, club)
		w.log.add("season_end", w.day, [lg.id], {"champion": lg.champion_id, "mvp": awards["mvp"]}, [])
	for p in w.active_players():
		var g: int = p.season_stats.get("games", 0)
		if g > 0 or p.club_id != "":
			p.history.append({"year": w.year, "club_id": p.club_id, "games": g, "wins": p.season_stats.get("wins", 0), "avg_rating": snappedf(p.avg_season_rating(), 0.01)})
	_promotion_relegation(w, season)
	w.history["seasons"].append(season)
	Media.on_season_end(w, season)
	w.phase = WorldState.PHASE_OFFSEASON
	w.phase_day = w.day


static func _club_intl(results: Dictionary, club_id: String) -> Dictionary:
	var out := {}
	for k in results:
		if results[k].has(club_id):
			out[k] = results[k][club_id]
	return out


## 聲望變化：越接近頂點，成績帶來的聲望越少（頂級豪門只能「維持」，不會無限累積光環）。
static func rep_change(rep: float, delta: float) -> float:
	if delta > 0.0:
		delta *= clampf((100.0 - rep) / 40.0, 0.15, 1.0)
	return clampf(rep + delta, 5.0, 99.0)


## 國際賽事結算：獎金、聲望、選手生涯紀錄。回傳 club_id -> 成績（champion/final/semis/groups）。
## 世界賽記在 season["international"]，季中邀請賽記在 season["midseason"]。
static func _close_international(w: WorldState, season: Dictionary, it: League = null) -> Dictionary:
	var out := {}
	if it == null:
		it = w.international
	if it == null or it.club_ids.is_empty() or it.champion_id == "":
		return out
	var worlds = str(it.format.get("timing", "end")) == "end"
	var scale = float(it.format.get("scale", 1.0 if worlds else 0.6))  # 季中賽事的份量較輕
	var final_fx = it.fixtures.filter(func(f): return f["stage"] == "final")
	var runner_up := ""
	if not final_fx.is_empty():
		var f: Dictionary = final_fx[0]
		runner_up = f["home"] if f["result"]["winner"] == f["away"] else f["away"]
	var semis: Array = []
	var quarters: Array = []
	for b in it.playoff_bracket:
		if b.size() == 4:
			semis = b
		elif b.size() == 8:
			quarters = b
	var n = it.club_ids.size()
	for cid in it.club_ids:
		var club: Club = w.clubs[cid]
		var res := "groups"
		var share := 0.4 / maxf(n - 4, 1)
		var rep_gain := 0.0
		if cid == it.champion_id:
			res = "champion"
			share = 0.35
			rep_gain = 8.0
		elif cid == runner_up:
			res = "final"
			share = 0.15
			rep_gain = 4.0
		elif semis.has(cid):
			res = "semis"
			share = 0.05
			rep_gain = 2.0
		elif quarters.has(cid):
			res = "quarters"
			share = 0.03
			rep_gain = 1.0
		out[cid] = res
		rep_gain *= scale
		Finance.earn(club, "prize", int(it.prize_pool * share))
		club.reputation = rep_change(club.reputation, rep_gain + scale)
		club.fanbase = int(club.fanbase * (1.0 + rep_gain / 100.0))
		for pid in club.lineup.values():
			var p: Player = w.players[pid]
			var k = "worlds" if worlds else ("msi" if it.id == "msi" else it.id)
			p.career[k] = int(p.career.get(k, 0)) + 1
			if res == "champion":
				p.career[k + "_titles" if not worlds else "world_titles"] = int(p.career.get(k + "_titles" if not worlds else "world_titles", 0)) + 1
				p.reputation = minf(p.reputation + 10.0 * scale, 100.0)
	var champ: Club = w.clubs[it.champion_id]
	if worlds:
		champ.world_titles += 1
	elif it.id == "msi":
		champ.msi_titles += 1
	else:
		champ.intl_titles[it.id] = int(champ.intl_titles.get(it.id, 0)) + 1
	var awards = _awards(w, it)
	season["international" if worlds else ("midseason" if it.id == "msi" else it.id)] = {"id": it.id, "name": it.name, "champion": it.champion_id, "runner_up": runner_up,
		"teams": it.club_ids.duplicate(), "mvp": awards["mvp"]}
	w.log.add("intl_champion", w.day, [champ.id], {"year": w.year, "event": it.id, "runner_up": runner_up}, [])
	return out


## 升降級：同地區的一級聯賽最後一名與次級聯賽冠軍互換。
static func _promotion_relegation(w: WorldState, season: Dictionary) -> void:
	season["movements"] = []
	for top in w.leagues.values():
		if top.tier != 1 or top.format.get("franchise", false):
			continue  # 聯盟制（例：LCK、LPL）不升降級
		for low in w.leagues.values():
			if low.tier != 2 or low.region != top.region or low.champion_id == "":
				continue
			var order = LeagueEngine.sorted_standings(top)
			if order.is_empty():
				continue
			var down: String = order[-1]
			var up: String = low.champion_id
			top.club_ids.erase(down)
			low.club_ids.erase(up)
			top.club_ids.append(up)
			low.club_ids.append(down)
			w.clubs[up].league_id = top.id
			w.clubs[down].league_id = low.id
			season["movements"].append({"up": up, "down": down, "from": low.id, "to": top.id})
			w.log.add("promotion", w.day, [up, top.id], {"from": low.id}, [])
			w.log.add("relegation", w.day, [down, low.id], {"to": low.id}, [])
			for cid in [up, down]:
				var c: Club = w.clubs[cid]
				if c.is_human:
					var promoted = cid == up
					w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "promotion" if promoted else "relegation", "player_id": "",
						"text": ("恭喜！%s 升上 %s，下季薪資上限與收入都會提高。" if promoted else "%s 降級到 %s。薪資上限與收入下降，部分選手可能想離隊。") % [c.name, w.leagues[c.league_id].name],
						"resolved": false, "options": ["acknowledge"]})
			# 降級隊伍的選手失去信心；升級隊伍士氣大振
			for pid in w.clubs[down].roster:
				var p: Player = w.players[pid]
				p.morale = clampf(p.morale - 10.0, 0.0, 100.0)
				p.trust_in_management = clampf(p.trust_in_management - 8.0, 0.0, 100.0)
			for pid in w.clubs[up].roster:
				w.players[pid].morale = clampf(w.players[pid].morale + 8.0, 0.0, 100.0)
			break


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
		Media.offseason_decay(w)
		_retirements(w)
		_new_patch(w)
		_youth_intake(w)
		StaffSystem.offseason(w)
		for c in clubs:
			Finance.offseason_sponsors(w, c)
	elif d >= 2 and d <= 6:
		for i in clubs.size():
			if i % 5 == d - 2 and not clubs[i].is_human:
				ClubAI.offseason_step(w, clubs[i], "renew")
	elif d == 7:
		_expire_contracts(w)
		for c in clubs:
			if not c.is_human:
				StaffSystem.ai_fill(w, c)
		StaffSystem.replenish(w)
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
	for p in w.active_players():
		Development.adapt_to_patch(w, p, w.rng)


static func _youth_intake(w: WorldState) -> void:
	for lg in w.leagues.values():
		# 次級聯賽隊伍較少、新人也較少
		var n = Tuning.i("regens_per_league_per_year")
		if lg.tier >= 2:
			n = int(n * lg.club_ids.size() / 8.0 * 0.6)
		for i in n:
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
	var hc: Club = w.human_club()
	if hc:
		Finance.auto_sign_remaining(w, hc)
		if hc.coach_id == "":
			StaffSystem.ai_fill(w, hc)  # 沒有主教練無法開季：由董事會指派
	Organization.new_season(w)
	for p in w.active_players():
		p.reset_season_stats()
		p.goals = PlayerGenerator.derive_goals(p, w.year)
		p.fatigue = 10.0
		p.stress = lerpf(p.stress, 25.0, 0.6)
		p.refuses_renewal = false
		p.weeks_unhappy = 0
		# 新賽季重燃鬥志：慢慢回到由野心決定的基準（冠軍隊的鬆懈不會一個休賽季就消失）
		p.motivation = lerpf(p.motivation, 50.0 + p.trait_value("ambition") * 0.35, 0.3)
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
