## 先發陣容選擇（AI 俱樂部，以及玩家未手動設定時的預設）。
class_name LineupSelector
extends RefCounted


static func pick(w: WorldState, club: Club) -> void:
	var used := {}
	var lineup := {}
	var players = club.roster.map(func(pid): return w.players[pid]).filter(func(p): return not p.retired)
	# 依位置挑選：主位置優先，其次副位置，最後任何人（打錯位置有懲罰）
	for role in Attr.ROLES:
		var best: Player = null
		var best_v := -INF
		for p in players:
			if used.has(p.id):
				continue
			var v = p.current_ability(role) - p.fatigue * 0.05
			if v > best_v:
				best_v = v
				best = p
		if best:
			lineup[role] = best.id
			used[best.id] = true
	club.lineup = lineup
	for p in players:
		if used.has(p.id):
			p.squad_status = "starter"
		elif p.squad_status == "starter":
			p.squad_status = "rotation"


static func is_valid(w: WorldState, club: Club) -> bool:
	for role in Attr.ROLES:
		var pid: String = club.lineup.get(role, "")
		if pid == "" or not (pid in club.roster) or w.players[pid].retired:
			return false
	return true
