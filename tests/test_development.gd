extends TestCase


func test_prodigy_grows_and_veteran_declines_mechanics_first() -> void:
	var w = make_world()
	var rng := SimRng.new(4)
	var kid = PlayerGenerator.generate(w, rng, "EAST", "MID", 0.5, true)
	kid.birth_year = w.year - 17
	kid.potential = 90.0
	for s in kid.skills:
		kid.ceilings[s] = 90.0
	var vet = PlayerGenerator.generate(w, rng, "EAST", "MID", 0.8)
	vet.birth_year = w.year - 30
	vet.peak_age = 23
	var coach = PlayerGenerator.generate_coach(w, rng, 0.6)
	var kid_before = kid.current_ability()
	var vm = vet.skill("mechanics")
	var vd = vet.skill("decision_making")
	var focus := {}
	for s in Attr.SKILLS:
		focus[s] = 1.5
	for week in 104:
		Development.weekly(w, kid, focus, coach)
		Development.weekly(w, vet, focus, coach)
	print("  prodigy CA %.1f → %.1f; veteran mechanics -%.1f, decision -%.1f" % [kid_before, kid.current_ability(), vm - vet.skill("mechanics"), vd - vet.skill("decision_making")])
	check(kid.current_ability() > kid_before + 8.0, "high-potential youngster grows")
	check(vm - vet.skill("mechanics") > (vd - vet.skill("decision_making")) * 1.5, "mechanics decline faster than decision making")


func test_overtraining_causes_fatigue() -> void:
	var w = make_world()
	var club: Club = w.clubs["paper_tigers"]
	club.training_plan = {"solo_queue": 4, "scrims": 6, "champion_practice": 2}
	for i in 6:
		TrainingEngine.weekly(w, club)
	var p: Player = w.players[club.lineup["MID"]]
	check(p.fatigue > 60.0, "12 heavy slots for 6 weeks exhausts players (fatigue %.1f)" % p.fatigue)
	club.training_plan = {"rest": 6, "scrims": 2}
	for i in 4:
		TrainingEngine.weekly(w, club)
	check(p.fatigue < 30.0, "rest recovers fatigue (%.1f)" % p.fatigue)
