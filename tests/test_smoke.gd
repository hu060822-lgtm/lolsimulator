extends TestCase


func test_module_loads_without_errors() -> void:
	var m = DataModule.load_from_dir(MODULE_DIR)
	check(m.errors.is_empty(), "module errors: %s" % str(m.errors))
	check(m.champions.size() >= 40, "champions loaded")


func test_world_builds_full_rosters() -> void:
	var w = make_world()
	for c in w.clubs.values():
		check(LineupSelector.is_valid(w, c), "%s has valid lineup" % c.id)
		check(c.coach_id != "", "%s has coach" % c.id)


func test_single_match_runs() -> void:
	var w = make_world()
	var a = TeamContext.from_club(w, w.clubs["crimson_tide_gaming"])
	var b = TeamContext.from_club(w, w.clubs["harbor_lights"])
	var s = SeriesSim.play(a, b, 1, w.champions, w.patch, SimRng.new(1))
	var g: Dictionary = s["games"][0]
	print("  duration=%d kills=%s gold=%s winner=%s events=%d" % [g["duration"], g["kills"], g["gold"], g["winner_club"], g["events"].size()])
	for e in g["events"]:
		print("   [%02d'] %s  ← %s" % [e["minute"], e["text"], ", ".join(e["causes"])])
	check(g["duration"] >= 20 and g["duration"] <= 60, "plausible duration")
