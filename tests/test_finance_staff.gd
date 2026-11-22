extends TestCase
## 第二階段：財務帳本、贊助、教練團。


func _session() -> GameSession:
	var s := GameSession.new()
	var errs = s.new_game(MODULE_DIR, 9, "harbor_lights")
	check(errs.is_empty(), "new game ok")
	s.manual_draft = false
	return s


func test_every_club_has_staff_and_sponsors() -> void:
	var w = make_world(2027)
	for c in w.clubs.values():
		check(StaffSystem.get_staff(w, c, "head_coach") != null, "%s has head coach" % c.id)
		check(c.sponsors.any(func(s): return s["kind"] == "main"), "%s has main sponsor" % c.id)
	check(StaffSystem.free_staff(w, "analyst").size() > 0, "staff market has analysts")


func test_weekly_ledger_records_income_and_wages() -> void:
	var s = _session()
	var c = s.club()
	var cash0 = c.cash
	s.advance_days(14)
	var t = Finance.totals(c.ledger)
	check(int(c.ledger["income"].get("sponsors", 0)) > 0, "sponsor income booked")
	check(int(c.ledger["expense"].get("player_wages", 0)) > 0, "player wages booked")
	check(int(c.ledger["expense"].get("staff_wages", 0)) > 0, "staff wages booked")
	# 帳本淨額應等於資金變化（比賽日的收入也記錄在帳本中）
	check_eq(c.cash - cash0, t["net"], "ledger net equals cash change")


func test_specialist_only_helps_when_better() -> void:
	var w = make_world(2027)
	var c: Club = w.clubs["harbor_lights"]
	var head = StaffSystem.get_staff(w, c, "head_coach")
	if c.staff.has("analyst"):
		StaffSystem.dismiss(w, c, "analyst")
	var base = StaffSystem.rating(w, c, "drafting")
	check_eq(base, head.drafting, "without analyst rating = head coach")
	var weak = PlayerGenerator.generate_staff(w, w.rng, 0.0, "analyst")
	weak.drafting = head.drafting - 20.0
	w.staff[weak.id] = weak
	StaffSystem.hire(w, c, weak, 999999, 1)
	check_eq(StaffSystem.rating(w, c, "drafting"), base, "weaker analyst adds nothing")
	StaffSystem.dismiss(w, c, "analyst")
	var star = PlayerGenerator.generate_staff(w, w.rng, 1.0, "analyst")
	star.drafting = minf(head.drafting + 30.0, 99.0)
	w.staff[star.id] = star
	StaffSystem.hire(w, c, star, 999999, 1)
	check(StaffSystem.rating(w, c, "drafting") > base, "stronger analyst raises drafting")


func test_hire_requires_fair_salary_and_dismiss_costs() -> void:
	var s = _session()
	var pool = s.staff_market("scout")
	check(pool.size() > 0, "scouts available")
	var target: Staff = pool[0]
	var lowball = s.hire_staff(target.id, 1000, 2)
	check(not lowball["ok"], "lowball rejected")
	var ok = s.hire_staff(target.id, s.staff_demand(target.id), 2)
	check(ok["ok"], "fair offer accepted: %s" % ok["note"])
	check_eq(s.staff_of("scout").id, target.id, "scout hired")
	var cash = s.club().cash
	var r = s.dismiss_staff("scout")
	check(r["ok"], "dismissed")
	check(s.club().cash < cash, "severance paid")
	check(not s.dismiss_staff("head_coach")["ok"], "cannot fire head coach mid-season")


func test_sponsor_offers_in_offseason_and_auto_sign() -> void:
	var w = make_world(2027, "harbor_lights")
	var c: Club = w.human_club()
	# 讓所有贊助在今年到期
	for sp in c.sponsors:
		sp["end_year"] = w.year
	var guard := 0
	while w.phase != WorldState.PHASE_OFFSEASON and guard < 400:
		WorldSimulator.advance_day(w)
		guard += 1
	WorldSimulator.advance_day(w)  # 休賽季第 1 天
	check(c.sponsor_offers.size() == 9, "3 offers per sponsor slot (%d)" % c.sponsor_offers.size())
	check(w.inbox.any(func(m): return m["kind"] == "sponsor_offers"), "inbox notified")
	var perf = c.sponsor_offers.filter(func(o): return o["style"] == "performance" and o["kind"] == "main")[0]
	Finance.sign_sponsor(w, c, perf)
	check(c.sponsors.any(func(s): return s["style"] == "performance"), "performance deal signed")
	var y = w.year
	while w.year == y and guard < 800:
		WorldSimulator.advance_day(w)
		guard += 1
	check_eq(c.sponsors.size(), 3, "remaining slots auto-signed at season start")
	check(c.finance_log.size() >= 1, "season ledger archived")


func test_save_load_keeps_finance_and_staff() -> void:
	var s = _session()
	s.advance_days(10)
	var path = "user://test_fin.json"
	check_eq(s.save(path), OK, "saved")
	var s2 := GameSession.new()
	check(s2.load_game(path), "loaded")
	check_eq(s2.club().ledger["income"].get("sponsors", 0), s.club().ledger["income"].get("sponsors", 0), "ledger restored")
	check_eq(s2.club().sponsors.size(), s.club().sponsors.size(), "sponsors restored")
	check_eq(s2.staff_of("head_coach").id, s.staff_of("head_coach").id, "staff restored")
