## 極簡測試基底（不依賴第三方外掛，方便在 CI 以 headless 執行）。
class_name TestCase
extends RefCounted

var failures: Array = []
var current: String = ""

const MODULE_DIR := "res://data/modules/fictional_base"


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s: %s (got %s, expected %s)" % [current, msg, str(a), str(b)])


func make_world(world_seed: int = 42, human: String = "") -> WorldState:
	var m = DataModule.load_from_dir(MODULE_DIR)
	return WorldBuilder.build(m, world_seed, human)
