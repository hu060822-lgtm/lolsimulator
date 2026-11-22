## 遊戲工作階段：UI 與模擬核心之間唯一的介面（Facade）。
## UI 不直接修改 WorldState，而是呼叫這裡的指令；這讓模擬可以無頭執行與測試。
class_name GameSession
extends RefCounted

signal day_advanced(day: int)
signal match_played(result: Dictionary)
signal match_ready(fixture: Dictionary)
signal inbox_changed()

const SAVE_DIR := "user://saves"

var world: WorldState
## 玩家是否手動 BP（關閉時由教練團代為 BP）
var manual_draft: bool = true
## 玩家俱樂部的比賽（手動 BP 進行中）
var pending: Dictionary = {}   ## {league, fixture, series: SeriesState}
var last_result: Dictionary = {}


func new_game(module_dir: String, world_seed: int, club_id: String, custom_club: Dictionary = {}) -> Array:
	var m = DataModule.load_from_dir(module_dir)
	if not m.errors.is_empty():
		return m.errors
	if not custom_club.is_empty():
		club_id = custom_club["id"]
	world = WorldBuilder.build(m, world_seed, club_id, custom_club)
	pending = {}
	return []


static func list_clubs(module_dir: String) -> Array:
	var m = DataModule.load_from_dir(module_dir)
	return m.clubs


static func list_leagues(module_dir: String) -> Array:
	var m = DataModule.load_from_dir(module_dir)
	return m.leagues


# ---------------------------------------------------------------- 時間推進

## 推進一天。若明天有玩家的比賽且開啟手動 BP，會停下並發出 match_ready（回傳 false）。
func advance_day() -> bool:
	if not pending.is_empty():
		return false
	if manual_draft and _human_match_tomorrow():
		return false
	var before = world.inbox.size()
	var results = WorldSimulator.advance_day(world)
	for r in results:
		if r["series"]["winner"] == world.human_club_id or r["series"]["loser"] == world.human_club_id:
			last_result = r
			match_played.emit(r)
	day_advanced.emit(world.day)
	if world.inbox.size() != before:
		inbox_changed.emit()
	return true


func advance_days(n: int) -> int:
	var done := 0
	for i in n:
		if not advance_day():
			break
		done += 1
	return done


func advance_to_next_match() -> void:
	var target = LeagueEngine.next_match_day(world, world.human_club_id)
	var guard := 0
	while guard < 400:
		guard += 1
		if target != -1 and world.day >= target:
			return
		if not advance_day():
			return
		if target == -1:
			return


func _human_match_tomorrow() -> bool:
	if world.human_club_id == "":
		return false
	var found = LeagueEngine.find_fixture(world, world.human_club_id, world.day + 1)
	if found.is_empty():
		return false
	match_ready.emit(found["fixture"])
	return true


func has_match_ready() -> bool:
	return manual_draft and world.human_club_id != "" and not LeagueEngine.find_fixture(world, world.human_club_id, world.day + 1).is_empty()


# ---------------------------------------------------------------- 玩家比賽（手動 BP）

func begin_match() -> SeriesState:
	if not pending.is_empty():
		return pending["series"]
	var found = LeagueEngine.find_fixture(world, world.human_club_id, world.day + 1)
	if found.is_empty():
		return null
	var s = LeagueEngine.prepare_series(world, found["fixture"])
	pending = {"league": found["league"], "fixture": found["fixture"], "series": s}
	return s


func human_side(s: SeriesState) -> String:
	return s.side_of(world.human_club_id)


## 一局：玩家完成（或部分完成）BP 後呼叫；未完成的步驟由 AI 補完。
func play_game(ds: DraftSession) -> Dictionary:
	var s: SeriesState = pending["series"]
	return s.play_game(ds)


func finish_match() -> Dictionary:
	var s: SeriesState = pending["series"]
	while not s.is_done():
		var ds = s.new_draft()
		ds.run_all()
		s.play_game(ds)
	var r = LeagueEngine.complete_fixture(world, pending["league"], pending["fixture"], s.result())
	pending = {}
	last_result = r
	match_played.emit(r)
	return r


## 不手動 BP，直接由教練團處理整場系列賽。
func auto_play_match() -> Dictionary:
	begin_match()
	return finish_match()


# ---------------------------------------------------------------- 俱樂部管理

func club() -> Club:
	return world.human_club()


func set_lineup(role: String, player_id: String) -> bool:
	var c = club()
	if not (player_id in c.roster):
		return false
	for r in c.lineup.keys():
		if c.lineup[r] == player_id:
			c.lineup.erase(r)
	c.lineup[role] = player_id
	for pid in c.roster:
		var p: Player = world.players[pid]
		p.squad_status = "starter" if c.lineup.values().has(pid) else ("prospect" if p.squad_status == "prospect" else "rotation")
	return true


func set_tactics(plan: String, aggression: float) -> void:
	club().tactics = {"plan": plan, "aggression": clampf(aggression, 0.0, 1.0)}


func set_training(plan: Dictionary) -> bool:
	if not TrainingEngine.validate(plan):
		return false
	club().training_plan = plan
	return true


func respond_to_player(player_id: String, response: String) -> Dictionary:
	return CareerAgent.respond(world, world.players[player_id], response)


func respond_to_message(msg_id: String, option: String) -> Dictionary:
	var msg = find_message(msg_id)
	if msg.is_empty():
		return {"note": "訊息不存在"}
	match option:
		"accept_offer":
			return TransferMarket.respond_to_offer(world, msg, true)
		"reject_offer":
			return TransferMarket.respond_to_offer(world, msg, false)
		"acknowledge":
			msg["resolved"] = true
			return {"note": "已讀"}
	var r = respond_to_player(msg["player_id"], option)
	msg["resolved"] = true
	return r


func find_message(msg_id: String) -> Dictionary:
	for m in world.inbox:
		if m.get("id") == msg_id:
			return m
	return {}


func open_messages() -> Array:
	return world.inbox.filter(func(m): return not m.get("resolved", false))


func offer_contract(player_id: String, salary: int, years: int, role_promise: String) -> Dictionary:
	var p: Player = world.players[player_id]
	if p.club_id == "" or p.club_id == world.human_club_id:
		if p.club_id == "" and not transfer_window_open():
			return {"accepted": false, "reason": "轉會窗口未開放（休賽季才能簽自由球員）"}
		var r = TransferMarket.offer_contract(world, club(), p, salary, years, role_promise)
		if r["accepted"] and p.club_id == "":
			TransferMarket._move(world, p, null, club(), 0)
		return r
	return {"accepted": false, "reason": "選手屬於其他俱樂部，請提出轉會報價"}


func bid(player_id: String, fee: int, salary: int, years: int, role_promise: String) -> Dictionary:
	if not transfer_window_open():
		return {"accepted": false, "reason": "轉會窗口未開放（休賽季才能轉會）"}
	return TransferMarket.make_transfer_offer(world, club(), world.players[player_id], fee, salary, years, role_promise)


func release_player(player_id: String) -> void:
	TransferMarket.release(world, club(), world.players[player_id], "玩家解約")


func transfer_window_open() -> bool:
	return world.phase == WorldState.PHASE_OFFSEASON or world.phase == WorldState.PHASE_PRESEASON


## 轉會中心搜尋。
func search_players(role: String = "", free_only: bool = false, max_age: int = 99) -> Array:
	var out: Array = []
	for p in world.active_players():
		if p.club_id == world.human_club_id:
			continue
		if free_only and p.club_id != "":
			continue
		if role != "" and p.primary_role != role:
			continue
		if p.age(world.year) > max_age:
			continue
		out.append(p)
	out.sort_custom(func(a, b): return a.current_ability() > b.current_ability())
	return out


# ---------------------------------------------------------------- 存檔

# ---------------------------------------------------------------- 球探

const SCOUT_COST := 15000


## 派球探觀察選手：費用固定，效果取決於球探能力。
func scout_player(player_id: String) -> Dictionary:
	var c = club()
	if c.cash < SCOUT_COST:
		return {"ok": false, "note": "資金不足"}
	Finance.spend(c, "scouting", SCOUT_COST)
	var amount = 0.15 + StaffSystem.rating(world, c, "scouting") / 100.0 * 0.2
	Scouting.observe(world, player_id, amount)
	return {"ok": true, "note": "球探報告已更新（費用 %s，認識程度 +%d%%）" % ["$%d" % SCOUT_COST, int(amount * 100)]}


# ---------------------------------------------------------------- 教練團

func staff_of(role: String) -> Staff:
	return StaffSystem.get_staff(world, club(), role)


func staff_market(role: String) -> Array:
	return StaffSystem.free_staff(world, role)


func staff_demand(staff_id: String) -> int:
	var s: Staff = world.staff.get(staff_id)
	if s == null:
		return 0
	return int(StaffSystem.wage_demand(s) * (1.0 + maxf(s.reputation - club().reputation - 10.0, 0.0) * 0.03)) + 1


func hire_staff(staff_id: String, salary: int, years: int) -> Dictionary:
	var s: Staff = world.staff.get(staff_id)
	if s == null:
		return {"ok": false, "note": "找不到此員工"}
	var r = StaffSystem.hire(world, club(), s, salary, years)
	inbox_changed.emit()
	return r


func dismiss_staff(role: String) -> Dictionary:
	if role == "head_coach" and world.phase != WorldState.PHASE_OFFSEASON:
		return {"ok": false, "note": "賽季中不能解雇主教練（只能在休賽季調整）"}
	var s = staff_of(role)
	if s == null:
		return {"ok": false, "note": "此職位目前無人"}
	var comp = StaffSystem.dismiss(world, club(), role)
	return {"ok": true, "note": "已與 %s 解約，補償 $%d" % [s.name, comp]}


# ---------------------------------------------------------------- 財務

func sponsor_offers() -> Array:
	return club().sponsor_offers


func sign_sponsor(index: int) -> Dictionary:
	var offers = club().sponsor_offers
	if index < 0 or index >= offers.size():
		return {"ok": false, "note": "報價不存在"}
	var o = offers[index]
	Finance.sign_sponsor(world, club(), o)
	return {"ok": true, "note": "與 %s 簽下%s（%s）" % [o["name"], Finance.SPONSOR_KINDS[o["kind"]], Finance.style_name(o["style"])]}


func finance_summary() -> Dictionary:
	var c = club()
	return {"ledger": c.ledger, "totals": Finance.totals(c.ledger), "history": c.finance_log,
		"projected_income": Finance.projected_income(world, c), "player_wages": TransferMarket.wage_bill(world, c),
		"staff_wages": StaffSystem.wage_bill(world, c), "wage_budget": c.wage_budget, "sponsors": c.sponsors}


func save(path: String) -> Error:
	return SaveSystem.save(world, path)


func load_game(path: String) -> bool:
	var w = SaveSystem.load_file(path)
	if w == null:
		return false
	world = w
	pending = {}
	return true


static func slot_path(slot: int) -> String:
	return "%s/slot%d.json" % [SAVE_DIR, slot]


func save_slot(slot: int) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var err = save(slot_path(slot))
	if err == OK:
		var meta = {"club": club().name if club() else "", "year": world.year, "day": world.day, "phase": world.phase,
			"saved_at": Time.get_datetime_string_from_system()}
		var f = FileAccess.open(slot_path(slot) + ".meta", FileAccess.WRITE)
		f.store_string(JSON.stringify(meta))
		f.close()
	return err


func load_slot(slot: int) -> bool:
	return load_game(slot_path(slot))


static func slot_info(slot: int) -> Dictionary:
	var p = slot_path(slot) + ".meta"
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}
