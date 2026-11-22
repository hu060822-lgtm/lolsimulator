extends TestCase
## 真實電競（致敬版）資料庫：五大賽區、次級聯賽、First Stand／MSI／世界賽瑞士輪、真名名單覆蓋。

const LOL_DIR := "res://data/modules/lol_world"


func _world(seed: int, club: String = "t_one") -> WorldState:
	var m = DataModule.load_from_dir(LOL_DIR)
	check(m.errors.is_empty(), "module loads: %s" % str(m.errors))
	return WorldBuilder.build(m, seed, club)


func test_structure_mirrors_real_esports() -> void:
	var w = _world(11)
	var tier1 = w.leagues.values().filter(func(l): return l.tier == 1).map(func(l): return l.short_name)
	tier1.sort()
	check_eq(tier1, ["LCK", "LCP", "LEC", "LPL", "LTA"], "five major regions")
	check(w.leagues.has("lck_cl") and w.leagues.has("ldl"), "LCK CL and LDL exist")
	for id in ["first_stand", "msi", "worlds"]:
		check(w.internationals.has(id), "%s defined" % id)
	check_eq(LeagueEngine.qualifiers(w, w.internationals["worlds"]).size(), 16, "16 Worlds slots")
	check_eq(LeagueEngine.qualifiers(w, w.internationals["msi"]).size(), 10, "10 MSI slots")
	check_eq(LeagueEngine.qualifiers(w, w.internationals["first_stand"]).size(), 5, "5 First Stand slots")
	var fakir: Player = null
	for p in w.players.values():
		if p.handle == "Fakir":
			fakir = p
	check(fakir != null and fakir.club_id == "t_one" and fakir.primary_role == "MID", "homage star placed on his club")
	check(fakir.current_ability() > 70.0, "homage star is strong (%.1f)" % fakir.current_ability())
	for c in w.clubs.values():
		check(c.roster.size() >= 5, "%s has a full roster" % c.short_name)


func test_full_season_with_first_stand_msi_and_swiss_worlds() -> void:
	var w = _world(12)
	var fs: League = w.internationals["first_stand"]
	var msi: League = w.internationals["msi"]
	var fs_day := -1
	var msi_day := -1
	var guard := 0
	while w.phase != WorldState.PHASE_INTERNATIONAL and guard < 400:
		WorldSimulator.advance_day(w)
		guard += 1
		if fs_day == -1 and not fs.club_ids.is_empty():
			fs_day = w.day
		if msi_day == -1 and not msi.club_ids.is_empty():
			msi_day = w.day
	check(fs_day > 0 and msi_day > fs_day, "First Stand (day %d) before MSI (day %d)" % [fs_day, msi_day])
	check(fs.season_complete and msi.season_complete, "both mid-season events finished before Worlds")
	var worlds: League = w.international
	check_eq(worlds.club_ids.size(), 16, "16 teams at Worlds")
	while w.phase == WorldState.PHASE_INTERNATIONAL and guard < 600:
		WorldSimulator.advance_day(w)
		guard += 1
	check(w.phase == WorldState.PHASE_OFFSEASON, "season ended")
	# 瑞士輪：每隊都以 3 勝或 3 敗結束，正好 8 隊晉級淘汰賽
	var qualified := 0
	for cid in worlds.club_ids:
		var st: Dictionary = worlds.standings[cid]
		check(int(st["w"]) == 3 or int(st["l"]) == 3, "%s finished Swiss at 3 wins or 3 losses" % cid)
		if int(st["w"]) == 3:
			qualified += 1
	check_eq(qualified, 8, "8 teams out of the Swiss stage")
	check_eq(worlds.playoff_bracket[0].size(), 8, "quarterfinal bracket")
	var s: Dictionary = w.history["seasons"][-1]
	check(s.has("first_stand") and s.has("midseason") and s.has("international"), "all three events recorded")
	check_eq(int(w.clubs[fs.champion_id].intl_titles.get("first_stand", 0)), 1, "First Stand title credited")


func test_real_name_overlay_renames_without_shipping_names() -> void:
	DirAccess.make_dir_recursive_absolute(DataModule.OVERLAY_DIR)
	var path = DataModule.OVERLAY_DIR.path_join("lol_world.json")
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"clubs": {"t_one": {"name": "Overlay Club", "short_name": "OVR"}}, "players": {"Fakir": "OverlayMid"}}))
	f.close()
	var m = DataModule.load_from_dir(LOL_DIR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(m.overlay_applied, "overlay applied")
	var club: Dictionary = m.clubs.filter(func(c): return c["id"] == "t_one")[0]
	check_eq(club["short_name"], "OVR", "club renamed")
	check(m.players.any(func(p): return p["handle"] == "OverlayMid"), "player renamed")
	var again = DataModule.load_from_dir(LOL_DIR)
	check(not again.overlay_applied, "no overlay once the file is removed")


func test_import_limit_blocks_extra_foreign_signings() -> void:
	var w = _world(13)
	var club: Club = w.clubs["t_one"]
	check_eq(TransferMarket.import_limit(w, club), 1, "LCK allows one import")
	var foreign: Player = null
	for pid in w.free_agents:
		if w.players[pid].home_region != club.region:
			foreign = w.players[pid]
			break
	check(foreign != null, "a foreign free agent exists")
	# 名單已有 1 名外援 → 再簽外援會被擋
	var filler: Player = null
	for p in w.players.values():
		if p.home_region != club.region and p.club_id == "":
			if p != foreign:
				filler = p
				break
	if TransferMarket.import_count(w, club) == 0:
		club.roster.append(filler.id)
	check(TransferMarket.import_blocked(w, club, foreign), "second import blocked")
	var r = TransferMarket.make_transfer_offer(w, club, foreign, 0, 999999, 2, "starter")
	check(not r["accepted"] and r["reason"] == "外援名額已滿", "offer rejected for import limit")
	var fb = DataModule.load_from_dir("res://data/modules/fictional_base")
	var fw = WorldBuilder.build(fb, 13, "")
	var any_club: Club = fw.clubs.values()[0]
	check_eq(TransferMarket.import_limit(fw, any_club), -1, "fictional base has no import limit")
