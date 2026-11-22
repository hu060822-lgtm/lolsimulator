## Competition / League Overview：排名、賽程、季後賽、比賽回顧。
class_name CompetitionScreen
extends UIScreen

var league_opt: OptionButton
var standings: Tree
var fixtures: Tree
var review: VBoxContainer
var ids: Array = []


func build() -> void:
	add_child(UIKit.title("賽事"))
	ids = LeagueEngine.all_competitions(w()).map(func(l): return l.id)
	var c = session.club()
	league_opt = UIKit.option(ids.map(func(i): return _comp(i).name + ("（次級）" if _comp(i).tier >= 2 else "")), ids.find(c.league_id))
	league_opt.item_selected.connect(func(_i): refresh())
	add_child(league_opt)
	var row := UIKit.hbox(12)
	add_child(row)
	standings = UIKit.table(["#", "隊伍", "勝", "敗", "小分", "小分差"], 300)
	row.add_child(standings)
	fixtures = UIKit.table(["日", "階段", "主隊", "客隊", "結果"], 300)
	fixtures.item_selected.connect(_on_fixture)
	row.add_child(fixtures)
	review = UIKit.vbox(6)
	add_child(UIKit.panel(review))


func refresh() -> void:
	var ww = w()
	var lg: League = _comp(ids[league_opt.selected])
	UIKit.clear_table(standings)
	var i := 1
	for cid in LeagueEngine.sorted_standings(lg):
		var s: Dictionary = lg.standings[cid]
		var it := UIKit.add_row(standings, [i, UIKit.club_label(ww.clubs[cid]), int(s["w"]), int(s["l"]), "%d-%d" % [int(s["gw"]), int(s["gl"])], int(s["gw"]) - int(s["gl"])])
		if cid == ww.human_club_id:
			for col in 6:
				it.set_custom_color(col, UIKit.ACCENT)
		i += 1
	UIKit.clear_table(fixtures)
	var stage_names = {"regular": "小組賽" if lg.tier == 0 else "例行賽", "playoffs": "淘汰賽" if lg.tier == 0 else "季後賽", "final": "決賽"}
	for fx in lg.fixtures:
		var res := ""
		if fx["played"]:
			res = "%d-%d" % [int(fx["result"]["score"][fx["home"]]), int(fx["result"]["score"][fx["away"]])]
		var it := UIKit.add_row(fixtures, [int(fx["day"]), stage_names.get(fx["stage"], fx["stage"]), ww.clubs[fx["home"]].short_name, ww.clubs[fx["away"]].short_name, res], fx["id"])
		if fx["home"] == ww.human_club_id or fx["away"] == ww.human_club_id:
			it.set_custom_color(2, UIKit.ACCENT)
			it.set_custom_color(3, UIKit.ACCENT)
	if lg.champion_id != "":
		UIKit.clear(review)
		review.add_child(UIKit.label("🏆 本季冠軍：%s" % ww.clubs[lg.champion_id].name, 18, UIKit.WARN))
	else:
		UIKit.clear(review)
		review.add_child(UIKit.muted("點選有結果的玩家比賽，查看逐局回顧。"))


func _comp(id: String) -> League:
	var ww = w()
	if ww.leagues.has(id):
		return ww.leagues[id]
	return ww.internationals.get(id)


func _on_fixture() -> void:
	var it = fixtures.get_selected()
	if it == null:
		return
	var lg: League = _comp(ids[league_opt.selected])
	for fx in lg.fixtures:
		if fx["id"] == it.get_metadata(0) and fx["played"]:
			UIKit.clear(review)
			if fx["result"].has("games"):
				review.add_child(MatchView.series_summary(session, fx["result"]["games"]))
			else:
				review.add_child(UIKit.muted("非玩家比賽只保存結果。勝者：%s" % w().clubs[fx["result"]["winner"]].short_name))
