## 資料模組：真實／虛構／自訂資料庫的統一入口。
## 核心引擎只依賴這個介面，不知道資料來自哪裡，也不含任何寫死的俱樂部或選手。
class_name DataModule
extends RefCounted

var id: String = ""
var meta: Dictionary = {}
var champions: Array = []   ## Array of Dictionary
var leagues: Array = []
var clubs: Array = []
var names: Dictionary = {}
var players: Array = []     ## 可選：模組直接提供的選手
var staff: Array = []
var rules: Dictionary = {}
var errors: Array = []


static func load_from_dir(dir_path: String) -> DataModule:
	var m := DataModule.new()
	var meta_v = _read_json(dir_path.path_join("module.json"))
	if not (meta_v is Dictionary):
		m.errors.append("module.json 缺失或格式錯誤: %s" % dir_path)
		return m
	m.meta = meta_v
	m.id = m.meta.get("id", dir_path.get_file())
	var files: Dictionary = m.meta.get("files", {})
	m.champions = _read_list(dir_path, files.get("champions", ""), m.errors)
	m.leagues = _read_list(dir_path, files.get("leagues", ""), m.errors)
	m.clubs = _read_list(dir_path, files.get("clubs", ""), m.errors)
	m.players = _read_list(dir_path, files.get("players", ""), m.errors, true)
	m.staff = _read_list(dir_path, files.get("staff", ""), m.errors, true)
	var n = _read_json(dir_path.path_join(files.get("names", "names.json")))
	m.names = n if n is Dictionary else {}
	var r = _read_json(dir_path.path_join(files.get("rules", "rules.json")))
	m.rules = r if r is Dictionary else {}
	m.validate()
	return m


func start_year() -> int:
	return int(meta.get("start_year", 2027))


## 基本結構驗證：讓自訂資料庫的錯誤在載入時就被發現，而不是在模擬中途崩潰。
func validate() -> void:
	var champ_ids := {}
	for c in champions:
		if not c.has("id") or not c.has("roles"):
			errors.append("英雄缺少 id/roles: %s" % str(c))
		champ_ids[c.get("id", "")] = true
	for role in Attr.ROLES:
		var count = champions.filter(func(c): return role in c.get("roles", [])).size()
		if count < 4:
			errors.append("位置 %s 的英雄少於 4 名，禁選無法進行" % role)
	var league_ids := {}
	for l in leagues:
		league_ids[l.get("id", "")] = true
	for c in clubs:
		if not league_ids.has(c.get("league_id", "")):
			errors.append("俱樂部 %s 所屬聯賽不存在" % c.get("id", "?"))


static func _read_list(dir_path: String, file_name: String, errors: Array, optional: bool = false) -> Array:
	if file_name == "":
		if not optional:
			errors.append("module.json 未指定必要檔案")
		return []
	var path = dir_path.path_join(file_name)
	if not FileAccess.file_exists(path):
		if not optional:
			errors.append("找不到 %s" % path)
		return []
	var v = _read_json(path)
	if v is Array:
		return v
	errors.append("%s 應為 JSON 陣列" % path)
	return []


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)
