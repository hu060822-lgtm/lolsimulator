## 媒體與輿論：新聞頭條（w.news）與每支俱樂部的外界評價（club.opinion，-100..100）。
##
## 外界評價 = 成績相對於期待（由聲望推算的預期名次）+ 連勝連敗。
## 評價差 → 選手壓力上升、士氣下滑；評價好 → 自信上升、周邊收入增加（見 Finance.merch_per_year）。
class_name Media
extends RefCounted

const MAX_NEWS := 300


static func post(w: WorldState, kind: String, text: String, ids: Array = [], tone: float = 0.0) -> void:
	w.news.append({"id": w.new_id("news"), "day": w.day, "year": w.year, "kind": kind, "text": text, "ids": ids, "tone": tone})
	if w.news.size() > MAX_NEWS:
		w.news = w.news.slice(w.news.size() - MAX_NEWS)


static func club_news(w: WorldState, club_id: String, n: int = 20) -> Array:
	var out: Array = []
	for i in range(w.news.size() - 1, -1, -1):
		if w.news[i]["ids"].has(club_id):
			out.append(w.news[i])
			if out.size() >= n:
				break
	return out


static func latest(w: WorldState, n: int = 30) -> Array:
	var out: Array = w.news.slice(maxi(w.news.size() - n, 0))
	out.reverse()
	return out


static func _sn(w: WorldState, cid: String) -> String:
	return w.clubs[cid].short_name if w.clubs.has(cid) else cid


# ---------------------------------------------------------------- 比賽新聞

static func on_match(w: WorldState, lg: League, fx: Dictionary, series: Dictionary) -> void:
	var win_id: String = series["winner"]
	var lose_id: String = series["loser"]
	var winner: Club = w.clubs[win_id]
	var loser: Club = w.clubs[lose_id]
	var score = "%d-%d" % [int(series["score"][win_id]), int(series["score"][lose_id])]
	var ids = [win_id, lose_id, lg.id]
	var human = winner.is_human or loser.is_human
	var upset = loser.reputation - winner.reputation >= 15.0
	if fx["stage"] == "final":
		post(w, "final", "%s %s 擊敗 %s，奪下 %s 冠軍！" % [winner.name, score, loser.name, lg.name], ids, 1.0)
	elif upset and (fx["stage"] != "regular" or lg.tier == 0 or human or w.rng.chance(0.35)):
		post(w, "upset", "爆冷！%s %s 擊敗 %s（%s）" % [winner.short_name, score, loser.short_name, lg.name], ids, 0.6)
	elif human:
		post(w, "match", "%s %s %s（%s）" % [winner.short_name, score, loser.short_name, lg.name], ids, 0.0)
	if winner.streak in [5, 8, 12]:
		post(w, "streak", "%s 豪取 %d 連勝，氣勢正旺" % [winner.name, winner.streak], [win_id], 0.7)
	if loser.streak in [-4, -6, -9]:
		post(w, "slump", "%s 陷入 %d 連敗，外界質疑聲浪升高" % [loser.name, -loser.streak], [lose_id], -0.7)


static func on_worlds_start(w: WorldState) -> void:
	var it: League = w.international
	var names = it.club_ids.map(func(c): return _sn(w, c))
	post(w, "worlds", "%d %s 開打！參賽隊伍：%s" % [w.year, it.name, "、".join(names)], it.club_ids.duplicate(), 0.5)
	var hc: Club = w.human_club()
	if hc and it.club_ids.has(hc.id):
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "worlds", "player_id": "",
			"text": "%s 取得 %s 參賽資格！國際賽事的壓力更大，大賽經驗豐富的選手更能穩定發揮。" % [hc.name, it.name],
			"resolved": false, "options": ["acknowledge"]})


static func on_season_end(w: WorldState, season: Dictionary) -> void:
	var intl: Dictionary = season.get("international", {})
	if not intl.is_empty():
		post(w, "worlds", "🏆 %s 成為 %d %s 冠軍" % [w.clubs[intl["champion"]].name, int(season["year"]), intl["name"]], [intl["champion"]], 1.0)
	for mv in season.get("movements", []):
		post(w, "promotion", "%s 升上 %s；%s 降級" % [w.clubs[mv["up"]].name, w.leagues[mv["to"]].name, w.clubs[mv["down"]].name],
			[mv["up"], mv["down"]], 0.0)


static func on_transfer(w: WorldState, p: Player, from: Club, to: Club, fee: int) -> void:
	if fee < 400000 and p.reputation < 70.0 and not to.is_human and not (from and from.is_human):
		return
	var src = ("從 %s " % from.short_name) if from else ""
	var how = ("以 %s 轉會費" % _money(fee)) if fee > 0 else "以自由身"
	post(w, "transfer", "轉會：%s %s%s加盟 %s" % [p.handle, src, how, to.name], [to.id] + ([from.id] if from else []), 0.2)


static func _money(v: int) -> String:
	if v >= 1000000:
		return "$%.1fM" % (v / 1000000.0)
	return "$%dk" % int(v / 1000)


# ---------------------------------------------------------------- 外界評價

## 依聲望推算的預期名次（1 = 冠軍熱門）。
static func expected_position(w: WorldState, club: Club) -> float:
	var lg: League = w.leagues.get(club.league_id)
	var n = lg.club_ids.size() if lg else 8
	var peers: Array = lg.club_ids.map(func(c): return w.clubs[c].reputation) if lg else []
	var better := 0
	for r in peers:
		if r > club.reputation:
			better += 1
	return better + 1.0 if not peers.is_empty() else n / 2.0


static func weekly(w: WorldState, club: Club) -> void:
	var lg: League = w.leagues.get(club.league_id)
	if lg == null or not lg.standings.has(club.id):
		return
	var st: Dictionary = lg.standings[club.id]
	var games = int(st["w"]) + int(st["l"])
	if games < 2:
		return
	var n = lg.club_ids.size()
	var pos = LeagueEngine.sorted_standings(lg).find(club.id) + 1
	var perf = (expected_position(w, club) - pos) / float(n) * 130.0 + club.streak * 6.0
	var before = club.opinion
	club.opinion = clampf(lerpf(club.opinion, clampf(perf, -100.0, 100.0), 0.25), -100.0, 100.0)
	if before >= -45.0 and club.opinion < -45.0:
		post(w, "opinion", "球迷不滿：%s 表現遠低於預期，教練團承受壓力" % club.name, [club.id], -0.8)
	elif before <= 45.0 and club.opinion > 45.0:
		post(w, "opinion", "%s 成為本季最大驚喜" % club.name, [club.id], 0.8)
	# 輿論壓力：心理素質差的選手受影響最大
	for pid in club.roster:
		var p: Player = w.players[pid]
		var composure = p.trait_value("composure")
		if club.opinion < -20.0:
			var k = (-club.opinion - 20.0) / 80.0
			p.stress = clampf(p.stress + k * 2.0 * (1.25 - composure / 100.0), 0.0, 100.0)
			p.morale = clampf(p.morale - k * 0.8, 0.0, 100.0)
		elif club.opinion > 30.0:
			p.confidence = clampf(p.confidence + (club.opinion - 30.0) / 70.0 * 0.8, 0.0, 100.0)


## 休賽季：評價逐漸淡化（新賽季重新開始）。
static func offseason_decay(w: WorldState) -> void:
	for c in w.clubs.values():
		c.opinion *= 0.4


static func label(v: float) -> String:
	if v >= 45:
		return "極度看好"
	if v >= 15:
		return "看好"
	if v > -15:
		return "中立"
	if v > -45:
		return "質疑"
	return "猛烈批評"
