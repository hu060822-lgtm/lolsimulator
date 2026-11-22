## 存檔：完整序列化 WorldState（含 RNG 狀態），因此讀檔後的世界與不中斷的世界完全一致。
class_name SaveSystem
extends RefCounted

const FORMAT_VERSION := 1


static func to_json(w: WorldState) -> String:
	return JSON.stringify({"format": FORMAT_VERSION, "world": w.to_dict()}, "", false, true)


static func from_json(text: String) -> WorldState:
	var d = JSON.parse_string(text)
	if not (d is Dictionary) or not d.has("world"):
		return null
	return WorldState.from_dict(d["world"])


static func save(w: WorldState, path: String) -> Error:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(w))
	f.close()
	return OK


static func load_file(path: String) -> WorldState:
	if not FileAccess.file_exists(path):
		return null
	return from_json(FileAccess.get_file_as_string(path))
