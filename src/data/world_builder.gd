## 從資料模組建立新世界（GDD 2.2 的 A/B/C 三種開局都經由這裡）：
##  A. 模組提供完整俱樂部與選手 → 直接使用
##  B. 模組只提供俱樂部/英雄 → 依種子生成選手與教練
##  C. 自訂俱樂部 → custom_club 參數覆蓋/新增一間俱樂部
class_name WorldBuilder
extends RefCounted


static func build(module: DataModule, world_seed: int, human_club_id: String = "", custom_club: Dictionary = {}) -> WorldState:
	Tuning.reset()
	Tuning.apply_overrides(module.rules)
	var w := WorldState.new()
	w.module_id = module.id
	w.world_seed = world_seed
	w.rng = SimRng.new(world_seed)
	w.year = module.start_year()
	w.names = module.names
	w.event_defs = module.events.duplicate(true)
	for c in module.champions:
		var ch = Champion.from_dict(c)
		w.champions[ch.id] = ch
	w.patch = generate_patch(w, w.rng, "%d.1" % (w.year % 100))
	for l in module.leagues:
		var lg = League.from_dict(l)
		if lg.tier == 0:
			w.international = lg  # 國際賽事：參賽隊伍每季由各一級聯賽成績決定
		else:
			w.leagues[lg.id] = lg
	var club_defs: Array = module.clubs.duplicate(true)
	if not custom_club.is_empty():
		club_defs = club_defs.filter(func(c): return c.get("id") != custom_club.get("replace", ""))
		club_defs.append(custom_club)
	for c in club_defs:
		var cl = Club.from_dict(c)
		w.clubs[cl.id] = cl
		if w.leagues.has(cl.league_id):
			w.leagues[cl.league_id].club_ids.append(cl.id)
	for p in module.players:
		var pl = Player.from_dict(p)
		if pl.id == "":
			pl.id = w.new_id("p")
		w.players[pl.id] = pl
		if pl.club_id != "" and w.clubs.has(pl.club_id):
			w.clubs[pl.club_id].roster.append(pl.id)
		else:
			w.free_agents.append(pl.id)
	for s in module.staff:
		var st = Staff.from_dict(s)
		w.staff[st.id] = st
		if st.club_id != "" and w.clubs.has(st.club_id):
			w.clubs[st.club_id].coach_id = st.id
	_fill_rosters(w)
	_seed_free_agents(w)
	if human_club_id != "" and w.clubs.has(human_club_id):
		w.human_club_id = human_club_id
		w.clubs[human_club_id].is_human = true
	# 員工市場與各隊教練團、初始贊助
	StaffSystem.offseason(w)
	for cl in w.clubs.values():
		StaffSystem.ai_fill(w, cl)
		for kind in Finance.SPONSOR_KINDS:
			var offers = Finance.make_offers(w, cl, kind)
			offers[2]["years"] = w.rng.range_i(1, 3)
			Finance.sign_sponsor(w, cl, offers[2] if kind == "main" else offers[0])
	StaffSystem.replenish(w)
	for cl in w.clubs.values():
		LineupSelector.pick(w, cl)
		cl.training_plan = TrainingEngine.default_plan()
	for p in w.players.values():
		p.reset_season_stats()
	LeagueEngine.start_season(w)
	w.log.add("world_created", w.day, [], {"module": module.id, "seed": world_seed})
	return w


static func _fill_rosters(w: WorldState) -> void:
	for cl in w.clubs.values():
		var quality = clampf(0.35 + (cl.reputation - 35.0) / 50.0 * 0.38, 0.2, 0.85)
		if cl.coach_id == "":
			var coach = PlayerGenerator.generate_coach(w, w.rng, quality)
			coach.club_id = cl.id
			w.staff[coach.id] = coach
			cl.coach_id = coach.id
		for role in Attr.ROLES:
			var has = cl.roster.any(func(pid): return w.players[pid].primary_role == role)
			if not has:
				var q = clampf(quality + w.rng.normal(0.0, 0.12), 0.0, 1.0)
				_add(w, cl, PlayerGenerator.generate(w, w.rng, cl.region, role, q), "starter")
		# 一到兩名替補/新秀
		for i in w.rng.range_i(1, 2):
			var role: String = w.rng.pick(Attr.ROLES)
			_add(w, cl, PlayerGenerator.generate(w, w.rng, cl.region, role, quality * 0.6, true), "prospect")


static func _add(w: WorldState, cl: Club, p: Player, status: String) -> void:
	var c := Contract.new()
	c.club_id = cl.id
	c.start_year = w.year
	c.end_year = w.year + w.rng.range_i(0, 2)
	c.salary = TransferMarket.wage_demand(w, p)
	c.role_promise = status
	p.contract = c
	p.club_id = cl.id
	p.squad_status = status
	w.players[p.id] = p
	cl.roster.append(p.id)


static func _seed_free_agents(w: WorldState) -> void:
	for lg in w.leagues.values():
		for i in 6:
			var role: String = Attr.ROLES[i % 5]
			var p = PlayerGenerator.generate(w, w.rng, lg.region, role, w.rng.range_f(0.1, 0.5))
			w.players[p.id] = p
			w.free_agents.append(p.id)


## 版本生成：每個英雄得到 -2..+2 的版本強度；約三成英雄有明顯變動。
static func generate_patch(w: WorldState, rng: SimRng, version: String) -> PatchState:
	var p := PatchState.new()
	p.version = version
	for cid in w.champions:
		var prev = w.patch.meta(cid) if w.patch else 0.0
		var v = prev * 0.4 + rng.normal(0.0, 0.9)
		p.tiers[cid] = clampf(roundf(v), -2.0, 2.0)
	return p
