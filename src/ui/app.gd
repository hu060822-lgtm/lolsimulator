## 主場景：開局畫面 → 管理介面。
extends Control

const MODULE := "res://data/modules/lol_world"

var session := GameSession.new()
var current: Control
var art: TextureRect


func _ready() -> void:
	theme = UIKit.make_theme()
	add_child(UIKit.backdrop())
	# 開局畫面背後淡淡的峽谷地圖
	art = TextureRect.new()
	art.texture = RiftMap.background()
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.55, 0.6, 0.75, 0.16)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	show_new_game()


func show_new_game() -> void:
	art.visible = true
	_swap(NewGameScreen.new().setup(session, self))


func start_game() -> void:
	art.visible = false
	var sh := Shell.new()
	sh.setup(session, self)
	_swap(sh)


func _swap(c: Control) -> void:
	if current:
		remove_child(current)
		current.queue_free()
	current = c
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
