## 可追溯的事件紀錄。每一筆事件都帶有 causes（影響來源），
## 對應 GDD「所有重要決策都應該能追蹤其影響來源」。
## 事件全部是純 Dictionary，可直接序列化進存檔。
class_name SimLog
extends RefCounted

var entries: Array = []
var max_entries: int = 4000


func add(type: String, day: int, actors: Array, data: Dictionary = {}, causes: Array = []) -> Dictionary:
	var e = {"type": type, "day": day, "actors": actors, "data": data, "causes": causes}
	entries.append(e)
	if entries.size() > max_entries:
		entries = entries.slice(entries.size() - max_entries)
	return e


func of_type(type: String) -> Array:
	return entries.filter(func(e): return e["type"] == type)


func for_actor(actor_id: String) -> Array:
	return entries.filter(func(e): return actor_id in e["actors"])


func to_array() -> Array:
	return entries.duplicate(true)


func load_array(arr: Array) -> void:
	entries = arr.duplicate(true)
