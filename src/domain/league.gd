## 聯賽／賽事定義與當季狀態。賽制來自資料（format），不寫死在程式中。
class_name League
extends RefCounted

var id: String
var name: String
var short_name: String = ""   ## 顯示用縮寫（例：LCK）；空白時用全名
var region: String
var tier: int = 1
var club_ids: Array = []
## 例：{"regular": {"type": "double_round_robin", "best_of": 1},
##      "playoffs": {"type": "single_elimination", "teams": 4, "best_of": 5}}
var format: Dictionary = {}
var prize_pool: int = 500000

## 當季
var fixtures: Array = []    ## [{id, day, stage, round, home, away, best_of, played, result}]
var standings: Dictionary = {}  ## club_id -> {w, l, gw, gl}
var playoff_bracket: Array = []   ## [0] = 季後賽種子；完成後再加上前四名
var bracket: Array = []           ## 季後賽對戰表：[{id, a, b, r, label, final, top4, fixture}]
var champion_id: String = ""
var season_complete: bool = false


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	for k in d:
		if k in l:
			l.set(k, d[k])
	l.tier = int(l.tier)
	l.prize_pool = int(l.prize_pool)
	for fx in l.fixtures:
		fx["day"] = int(fx["day"])
		fx["best_of"] = int(fx["best_of"])
	return l


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "short_name": short_name, "region": region, "tier": tier, "club_ids": club_ids,
		"format": format, "prize_pool": prize_pool, "fixtures": fixtures,
		"standings": standings, "playoff_bracket": playoff_bracket, "bracket": bracket,
		"champion_id": champion_id, "season_complete": season_complete}
