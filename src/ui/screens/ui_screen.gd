## 畫面基底：每個畫面只透過 GameSession 讀寫資料。
class_name UIScreen
extends VBoxContainer

var session: GameSession
var shell: Node


func setup(s: GameSession, sh: Node) -> UIScreen:
	session = s
	shell = sh
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	build()
	return self


func build() -> void:
	pass


func refresh() -> void:
	pass


func w() -> WorldState:
	return session.world


func toast(text: String) -> void:
	if shell and shell.has_method("toast"):
		shell.toast(text)
