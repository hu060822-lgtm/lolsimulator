## 遊戲工作階段：UI 與模擬核心之間唯一的介面（Facade）。
## UI 不直接修改 WorldState，而是呼叫這裡的指令；這讓模擬可以無頭執行與測試。
class_name GameSession
extends RefCounted

signal day_advanced(day: int)
signal match_played(result: Dictionary)
signal inbox_changed()

var world: WorldState


func new_game(module_dir: String, world_seed: int, club_id: String) -> Array:
	var m = DataModule.load_from_dir(module_dir)
	if not m.errors.is_empty():
		return m.errors
	world = WorldBuilder.build(m, world_seed, club_id)
	return []


func advance_day() -> void:
	var before = world.inbox.size()
	var results = WorldSimulator.advance_day(world)
	for r in results:
		if r["series"]["winner"] == world.human_club_id or r["series"]["loser"] == world.human_club_id:
			match_played.emit(r)
	day_advanced.emit(world.day)
	if world.inbox.size() != before:
		inbox_changed.emit()


func advance_to_next_match() -> void:
	var target = LeagueEngine.next_match_day(world, world.human_club_id)
	if target == -1:
		advance_day()
		return
	while world.day < target:
		advance_day()


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


func offer_contract(player_id: String, salary: int, years: int, role_promise: String) -> Dictionary:
	var p: Player = world.players[player_id]
	if p.club_id == "" or p.club_id == world.human_club_id:
		var r = TransferMarket.offer_contract(world, club(), p, salary, years, role_promise)
		if r["accepted"] and p.club_id == "":
			TransferMarket._move(world, p, null, club(), 0)
		return r
	return {"accepted": false, "reason": "選手屬於其他俱樂部，請提出轉會報價"}


func bid(player_id: String, fee: int, salary: int, years: int, role_promise: String) -> Dictionary:
	return TransferMarket.make_transfer_offer(world, club(), world.players[player_id], fee, salary, years, role_promise)


func save(path: String) -> Error:
	return SaveSystem.save(world, path)


func load_game(path: String) -> bool:
	var w = SaveSystem.load_file(path)
	if w == null:
		return false
	world = w
	return true
