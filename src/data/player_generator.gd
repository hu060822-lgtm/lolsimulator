## 選手／教練生成器：用於「AI 隨機生成世界」、每年新人（regen）與補足陣容。
## 所有參數皆由種子 RNG 決定，可重現。
class_name PlayerGenerator
extends RefCounted


## quality: 0..1，大致決定目前能力水準；young=true 時生成低 CA、高變異潛力的新人。
## 賽區人才水準（names.json 的 regions.<賽區>.talent，預設 1.0）會乘上 quality，形成 LCK／LPL 較強的生態。
static func generate(w: WorldState, rng: SimRng, region: String, role: String, quality: float, young: bool = false, apply_talent: bool = true) -> Player:
	var p := Player.new()
	p.id = w.new_id("p")
	var pools: Dictionary = w.names.get("regions", {}).get(region, {})
	if apply_talent:
		quality *= float(pools.get("talent", 1.0))
	p.nationality = str(rng.pick(pools.get("nationalities", ["Unknown"])))
	p.home_region = region
	p.real_name = "%s %s" % [rng.pick(pools.get("given", ["Alex"])), rng.pick(pools.get("family", ["Doe"]))]
	p.handle = _make_handle(w, rng)
	p.primary_role = role
	if rng.chance(0.25):
		var others = Attr.ROLES.filter(func(r): return r != role)
		p.secondary_roles = [rng.pick(others)]
	var age = rng.range_i(16, 18) if young else rng.range_i(17, 29)
	p.birth_year = w.year - age
	p.peak_age = rng.range_i(21, 25)
	p.development_rate = clampf(rng.normal(1.0, 0.22), 0.5, 1.6)
	p.decline_rate = clampf(rng.normal(1.0, 0.25), 0.5, 1.7)

	# 潛力：年輕選手潛力變異較大
	var base = 35.0 + quality * 50.0
	if young:
		# 賽區人才水準也影響新秀的潛力：LCK／LPL 青訓產出的天花板較高
		var talent_shift = (float(pools.get("talent", 1.0)) - 1.0) * 40.0 if apply_talent else 0.0
		p.potential = clampf(rng.normal(62.0 + quality * 18.0, 13.0) + talent_shift, 40.0, 98.0)
	else:
		p.potential = clampf(base + absf(rng.normal(0.0, 7.0)) + maxf(0.0, (p.peak_age - age)) * 2.0, 40.0, 98.0)

	# 能力：圍繞 base 隨機分佈，並給每項能力獨立的上限（使「操作 90、決策 70」這種選手自然出現）
	var mech_bias = rng.normal(0.0, 8.0)  # 正 = 偏操作型，負 = 偏理解型
	for s in Attr.SKILLS:
		var bias = mech_bias if s in Attr.MECHANICAL else -mech_bias * 0.6
		var ceil_v = clampf(p.potential + bias + rng.normal(0.0, 6.0), 25.0, 99.0)
		p.ceilings[s] = ceil_v
		var start = base if not young else 30.0 + quality * 25.0
		var age_gap = clampf(float(p.peak_age - age) / 8.0, 0.0, 1.0)
		var v = lerpf(start + bias, ceil_v, 0.35 * (1.0 - age_gap)) + rng.normal(0.0, 5.0)
		if young and s in Attr.COGNITIVE:
			v -= 6.0  # 新人比賽理解較弱
		p.skills[s] = clampf(v, 15.0, ceil_v)
	for t in Attr.PERSONALITY:
		p.personality[t] = clampf(rng.normal(55.0, 18.0), 5.0, 99.0)

	_assign_champion_pool(w, rng, p, young)
	p.goals = derive_goals(p, w.year)
	p.reputation = clampf(p.current_ability() - 35.0 + rng.normal(0, 6), 1.0, 90.0)
	p.reset_season_stats()
	return p


static func _assign_champion_pool(w: WorldState, rng: SimRng, p: Player, young: bool) -> void:
	var role_champs = w.champions.values().filter(func(c): return p.primary_role in c.roles)
	rng.shuffle(role_champs)
	# 英雄池深度：職業選手通常有 8–15 隻可上場的英雄，適應力高者更深
	var depth = rng.range_i(6, 9) + int(p.skill("adaptability") / 22.0)
	for i in mini(depth, role_champs.size()):
		var comfort = 85.0 - i * rng.range_f(2.5, 5.5)
		if young:
			comfort -= 12.0
		p.champion_pool[role_champs[i].id] = clampf(comfort + rng.normal(0, 5), 20.0, 99.0)
	# 本位置其他英雄：職業選手都摸過，只是不熟（避免被 ban 掉拿手英雄後完全無法上場）
	for i in range(mini(depth, role_champs.size()), role_champs.size()):
		p.champion_pool[role_champs[i].id] = rng.range_f(25.0, 42.0) - (8.0 if young else 0.0)
	for r in p.secondary_roles:
		var sec = w.champions.values().filter(func(c): return r in c.roles)
		rng.shuffle(sec)
		for i in mini(2, sec.size()):
			if not p.champion_pool.has(sec[i].id):
				p.champion_pool[sec[i].id] = rng.range_f(40, 65)


## 職業目標由個性與年齡推導；目標決定選手如何評價合約與現況（見 docs/rules/02-player-agency.md）。
static func derive_goals(p: Player, year: int) -> Array:
	var g: Array = []
	var a = p.age(year)
	if p.trait_value("ambition") > 65:
		g.append("WIN_TITLES")
	if a <= 21:
		g.append("PLAYING_TIME")
		g.append("DEVELOP")
	if p.trait_value("loyalty") > 70 and a >= 25:
		g.append("RETIRE_AT_CLUB")
	if p.trait_value("loyalty") < 35 or (p.trait_value("ambition") > 50 and p.trait_value("professionalism") < 40):
		g.append("MONEY")
	if p.trait_value("ambition") > 75 and p.trait_value("loyalty") < 50:
		g.append("GO_ABROAD")
	if g.is_empty():
		g.append("STABILITY")
	return g


static func _make_handle(w: WorldState, rng: SimRng) -> String:
	var parts: Array = w.names.get("handle_parts", ["Player"])
	var h := str(rng.pick(parts))
	if rng.chance(0.4):
		h += str(rng.pick(parts)).to_lower()
	if rng.chance(0.15):
		h += str(rng.range_i(1, 99))
	# 避免同名：已存在的 ID 加上數字
	var taken := {}
	for p in w.players.values():
		taken[p.handle] = true
	var base := h
	var n := 2
	while taken.has(h):
		h = "%s%d" % [base, n]
		n += 1
	return h


static func generate_coach(w: WorldState, rng: SimRng, quality: float) -> Staff:
	return generate_staff(w, rng, quality, "head_coach")


## 生成員工：職位相關能力較高，其他能力偏低。
static func generate_staff(w: WorldState, rng: SimRng, quality: float, role: String) -> Staff:
	var s := Staff.new()
	s.role = role
	s.id = w.new_id("s")
	s.name = "%s %s" % [rng.pick(w.names.get("coach_given", ["Coach"])), rng.pick(w.names.get("coach_family", ["Smith"]))]
	s.birth_year = w.year - rng.range_i(27, 48)
	var base = 35.0 + quality * 45.0
	s.tactical = clampf(rng.normal(base, 9), 10, 99)
	s.drafting = clampf(rng.normal(base, 9), 10, 99)
	s.development = clampf(rng.normal(base, 9), 10, 99)
	s.man_management = clampf(rng.normal(base, 9), 10, 99)
	s.adaptability = clampf(rng.normal(base, 9), 10, 99)
	s.scouting = clampf(rng.normal(base - 5.0, 9), 10, 99)
	s.fitness = clampf(rng.normal(base - 5.0, 9), 10, 99)
	var focus = {"assistant_coach": ["tactical", "development"], "analyst": ["drafting", "adaptability"],
		"performance_coach": ["fitness", "man_management"], "scout": ["scouting"]}.get(role, [])
	for k in focus:
		s.set(k, clampf(float(s.get(k)) + 8.0, 10, 99))
	s.style = str(rng.pick(Staff.STYLES))
	var pay_scale = 1.0 if role == "head_coach" else 0.35
	s.salary = int((40000 + quality * 160000) * pay_scale)
	s.reputation = base
	s.contract_end = w.year + rng.range_i(1, 3)
	return s
