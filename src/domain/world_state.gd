## 世界狀態：整個長期世界的唯一資料容器。存檔 = 序列化這個物件。
## 系統（systems/*）是無狀態的規則，只讀寫 WorldState。
class_name WorldState
extends RefCounted

const PHASE_PRESEASON := "preseason"
const PHASE_REGULAR := "regular"
const PHASE_PLAYOFFS := "playoffs"
const PHASE_INTERNATIONAL := "international"
const PHASE_OFFSEASON := "offseason"

var module_id: String = ""
var world_seed: int = 0
var day: int = 0                  ## 從世界開始起算的天數
var year: int = 2027              ## 目前賽季年份
var phase: String = PHASE_PRESEASON
var phase_day: int = 0            ## 進入當前階段的日期
var human_club_id: String = ""

var champions: Dictionary = {}    ## id -> Champion
var patch: PatchState = PatchState.new()
var leagues: Dictionary = {}      ## id -> League（國內聯賽，含次級聯賽）
var internationals: Dictionary = {}  ## id -> League：國際賽事（tier 0），參賽隊伍每季決定
## 年底的世界賽（format.timing == "end"）
var international: League:
	get:
		return intl("end")
var event_defs: Array = []        ## 隨機事件定義（來自資料模組，隨存檔保存）
var news: Array = []              ## 媒體新聞（見 Media）
var clubs: Dictionary = {}        ## id -> Club
var players: Dictionary = {}      ## id -> Player（含退役）
var staff: Dictionary = {}        ## id -> Staff
var free_agents: Array = []       ## player ids
var names: Dictionary = {}        ## 生成新人用的名字庫（來自資料模組）

var history: Dictionary = {"seasons": [], "transfers": [], "retirements": []}
var relations: Dictionary = {}    ## "id|id" -> -100..100（見 Relationships）
var manager: Dictionary = {}      ## 玩家經理生涯（見 ManagerCareer）
var inbox: Array = []             ## 給玩家俱樂部的訊息（選手要求、轉會報價等）
var log := SimLog.new()
var rng := SimRng.new()
var next_id: int = 1


## 依時機取得國際賽事："midseason"（季中邀請賽）或 "end"（世界賽）。
func intl(timing: String) -> League:
	for l in internationals.values():
		if str(l.format.get("timing", "end")) == timing:
			return l
	return null


func new_id(prefix: String) -> String:
	next_id += 1
	return "%s_%d" % [prefix, next_id]


func active_players() -> Array:
	return players.values().filter(func(p): return not p.retired)


func club_players(club_id: String) -> Array:
	var c: Club = clubs[club_id]
	return c.roster.map(func(pid): return players[pid])


func human_club() -> Club:
	return clubs.get(human_club_id)


func to_dict() -> Dictionary:
	var d = {
		"module_id": module_id, "seed": world_seed, "day": day, "year": year, "phase": phase,
		"phase_day": phase_day, "human_club_id": human_club_id,
		"champions": champions.values().map(func(c): return c.to_dict()),
		"patch": patch.to_dict(),
		"leagues": leagues.values().map(func(l): return l.to_dict()),
		"clubs": clubs.values().map(func(c): return c.to_dict()),
		"players": players.values().map(func(p): return p.to_dict()),
		"staff": staff.values().map(func(s): return s.to_dict()),
		"internationals": internationals.values().map(func(l): return l.to_dict()), "news": news, "event_defs": event_defs,
		"free_agents": free_agents, "names": names, "history": history, "inbox": inbox, "relations": relations, "manager": manager,
		"log": log.to_array(), "rng": rng.get_state(), "next_id": next_id,
	}
	return d


static func from_dict(d: Dictionary) -> WorldState:
	var w := WorldState.new()
	w.module_id = d.get("module_id", "")
	w.world_seed = int(d.get("seed", 0))
	w.day = int(d.get("day", 0))
	w.year = int(d.get("year", 2027))
	w.phase = d.get("phase", PHASE_PRESEASON)
	w.phase_day = int(d.get("phase_day", 0))
	w.human_club_id = d.get("human_club_id", "")
	for c in d.get("champions", []):
		var ch = Champion.from_dict(c)
		w.champions[ch.id] = ch
	w.patch = PatchState.from_dict(d.get("patch", {}))
	for l in d.get("leagues", []):
		var lg = League.from_dict(l)
		w.leagues[lg.id] = lg
	for l in d.get("internationals", []):
		var it = League.from_dict(l)
		w.internationals[it.id] = it
	var legacy: Dictionary = d.get("international", {})
	if not legacy.is_empty() and w.internationals.is_empty():
		var it2 = League.from_dict(legacy)
		w.internationals[it2.id] = it2
	w.news = d.get("news", [])
	w.event_defs = d.get("event_defs", [])
	for c in d.get("clubs", []):
		var cl = Club.from_dict(c)
		w.clubs[cl.id] = cl
	for p in d.get("players", []):
		var pl = Player.from_dict(p)
		w.players[pl.id] = pl
	for s in d.get("staff", []):
		var st = Staff.from_dict(s)
		w.staff[st.id] = st
	w.free_agents = d.get("free_agents", [])
	w.names = d.get("names", {})
	w.history = d.get("history", {"seasons": [], "transfers": [], "retirements": []})
	w.inbox = d.get("inbox", [])
	w.manager = d.get("manager", {})
	w.relations = d.get("relations", {})
	w.log.load_array(d.get("log", []))
	w.rng.set_state(d.get("rng", {}))
	w.next_id = int(d.get("next_id", 1))
	return w
