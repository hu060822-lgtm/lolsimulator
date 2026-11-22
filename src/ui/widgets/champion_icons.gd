## 英雄頭像：第一次需要時從 Riot Data Dragon 下載，存在本機 user://champion_icons/。
##
## repo 不附帶任何 Riot 圖檔；下載失敗（離線、被擋）時，UI 改用英雄名縮寫的圓形小棋。
## 環境變數 LOLSIM_ICON_BASE 可指定其他來源（測試用）；LOLSIM_ICONS=off 停用下載。
class_name ChampionIcons
extends Node

signal icon_ready(champ_id: String)

const DEFAULT_BASE := "https://ddragon.leagueoflegends.com"
const CACHE_DIR := "user://champion_icons"
const MAX_PARALLEL := 4

static var _inst: ChampionIcons

var base_url: String = DEFAULT_BASE
var enabled: bool = true
var version: String = ""
var dd_ids: Dictionary = {}        ## 正規化名稱 -> Data Dragon id
var textures: Dictionary = {}      ## champ_id -> Texture2D（已裁成圓形）
var failed: Dictionary = {}
var queue: Array = []              ## [champ_id, name_en]
var active: int = 0
var _index_state: String = "none"  ## none / loading / ready / failed


static func instance() -> ChampionIcons:
	if _inst == null or not is_instance_valid(_inst):
		_inst = ChampionIcons.new()
		_inst.name = "ChampionIcons"
		var env_base = OS.get_environment("LOLSIM_ICON_BASE")
		if env_base != "":
			_inst.base_url = env_base.trim_suffix("/")
		_inst.enabled = OS.get_environment("LOLSIM_ICONS") != "off"
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			tree.root.add_child.call_deferred(_inst)
	return _inst


## 取得頭像；尚未下載時回傳 null 並排入下載佇列（完成後發出 icon_ready）。
static func get_icon(c: Champion) -> Texture2D:
	if c == null:
		return null
	var me = instance()
	if me.textures.has(c.id):
		return me.textures[c.id]
	if me._load_cached(c.id):
		return me.textures[c.id]
	me._request(c)
	return null


static func normalize(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


func _cache_path(champ_id: String) -> String:
	return "%s/%s.png" % [CACHE_DIR, champ_id]


func _load_cached(champ_id: String) -> bool:
	var path = _cache_path(champ_id)
	if not FileAccess.file_exists(path):
		return false
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return false
	textures[champ_id] = _round_texture(img)
	return true


func _request(c: Champion) -> void:
	if not enabled or failed.has(c.id) or _index_state == "failed":
		return
	for q in queue:
		if q[0] == c.id:
			return
	queue.append([c.id, c.name_en if c.name_en != "" else c.id])
	if is_inside_tree():
		_pump()
	else:
		_pump.call_deferred()


func _pump() -> void:
	if not is_inside_tree():
		return
	if _index_state == "none":
		_load_index()
		return
	if _index_state != "ready":
		return
	while active < MAX_PARALLEL and not queue.is_empty():
		var q: Array = queue.pop_front()
		_download_icon(q[0], q[1])


func _http(url: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(func(result, code, _h, body):
		req.queue_free()
		cb.call(result == HTTPRequest.RESULT_SUCCESS and code == 200, body))
	if req.request(url) != OK:
		req.queue_free()
		cb.call(false, PackedByteArray())


func _load_index() -> void:
	_index_state = "loading"
	_http(base_url + "/api/versions.json", func(ok, body):
		var v = JSON.parse_string(body.get_string_from_utf8()) if ok else null
		if not (v is Array) or v.is_empty():
			_index_fail()
			return
		version = str(v[0])
		_http("%s/cdn/%s/data/en_US/champion.json" % [base_url, version], func(ok2, body2):
			var d = JSON.parse_string(body2.get_string_from_utf8()) if ok2 else null
			if not (d is Dictionary) or not d.has("data"):
				_index_fail()
				return
			for k in d["data"]:
				var e: Dictionary = d["data"][k]
				dd_ids[normalize(str(e.get("id", k)))] = str(e.get("id", k))
				dd_ids[normalize(str(e.get("name", k)))] = str(e.get("id", k))
			_index_state = "ready"
			_pump()))


func _index_fail() -> void:
	_index_state = "failed"
	queue.clear()


func _download_icon(champ_id: String, name_en: String) -> void:
	var dd: String = dd_ids.get(normalize(name_en), dd_ids.get(normalize(champ_id), ""))
	if dd == "":
		failed[champ_id] = true
		return
	active += 1
	_http("%s/cdn/%s/img/champion/%s.png" % [base_url, version, dd], func(ok, body):
		active -= 1
		var img := Image.new()
		if not ok or img.load_png_from_buffer(body) != OK:
			failed[champ_id] = true
		else:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
			img.save_png(ProjectSettings.globalize_path(_cache_path(champ_id)))
			textures[champ_id] = _round_texture(img)
			icon_ready.emit(champ_id)
		_pump())


## 裁成圓形並縮成 64px，方便在地圖上當小棋。
static func _round_texture(src: Image) -> ImageTexture:
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var r := 31.5
	for y in 64:
		for x in 64:
			var d = Vector2(x - 31.5, y - 31.5).length()
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r - 1.5:
				var c = img.get_pixel(x, y)
				c.a *= (r - d) / 1.5
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
