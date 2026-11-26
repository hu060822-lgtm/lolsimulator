extends Control

var players: Array = []
var world: WorldState


func _draw() -> void:
	for i in players.size():
		var p: Player = players[i]
		var r := Rect2(Vector2(10 + (i % 8) * 158, 10 + (i / 8) * 166), Vector2(150, 150))
		draw_rect(r, UIKit.PANEL)
		var club: Club = world.clubs.get(p.club_id)
		PlayerPortrait.draw(self, r.grow(-6), PlayerPortrait.traits(p), Badge.club_color(club.id) if club else UIKit.MUTED)
		draw_string(UIKit.cond_font(), r.position + Vector2(6, 162), "%s %s" % [p.handle, p.nationality], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.MUTED)
