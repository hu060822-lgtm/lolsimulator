## 主場景：開局畫面 → 管理介面。
extends Control

const MODULE := "res://data/modules/fictional_base"

var session := GameSession.new()
var current: Control


func _ready() -> void:
	theme = UIKit.make_theme()
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_new_game()


func show_new_game() -> void:
	_swap(NewGameScreen.new().setup(session, self))


func start_game() -> void:
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
