## Training Planner：每週 12 個時段。
class_name TrainingScreen
extends UIScreen

var spins: Dictionary = {}
var total_label: Label
var load_label: Label


func build() -> void:
	add_child(UIKit.title("每週訓練規劃"))
	add_child(UIKit.muted("每週 %d 個時段。負荷過高會累積疲勞（>70 時訓練效率減半、壓力上升）；休息不足會影響比賽狀態。" % TrainingEngine.SLOTS))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(UIKit.panel(grid))
	var plan: Dictionary = session.club().training_plan
	for k in TrainingEngine.TYPES:
		grid.add_child(UIKit.label(UIKit.TRAINING_NAMES.get(k, k)))
		var sp := SpinBox.new()
		sp.min_value = 0
		sp.max_value = TrainingEngine.SLOTS
		sp.value = int(plan.get(k, 0))
		sp.value_changed.connect(func(_v): _update())
		grid.add_child(sp)
		spins[k] = sp
		var skills: Array = TrainingEngine.TYPES[k]["skills"]
		grid.add_child(UIKit.muted("、".join(skills.map(func(s): return UIKit.SKILL_NAMES.get(s, s))) if skills.size() > 0 else {"champion_practice": "英雄熟練度", "team_building": "默契、士氣", "physical": "恢復", "rest": "疲勞、壓力恢復"}.get(k, "")))
	total_label = UIKit.label("")
	load_label = UIKit.label("", 14, UIKit.MUTED)
	add_child(total_label)
	add_child(load_label)
	var row := UIKit.hbox()
	row.add_child(UIKit.primary("儲存訓練計畫", _save))
	row.add_child(UIKit.button("恢復預設", _default))
	add_child(row)


func refresh() -> void:
	_update()


func _plan() -> Dictionary:
	var p := {}
	for k in spins:
		p[k] = int(spins[k].value)
	return p


func _update() -> void:
	var p = _plan()
	var total := 0
	var load := 0.0
	for k in p:
		total += p[k]
		load += TrainingEngine.TYPES[k]["load"] * p[k]
	var rest = int(p.get("rest", 0)) + int(p.get("physical", 0)) * 0.5
	var delta = load * 1.1 - rest * 4.0 - 5.0
	total_label.text = "已使用 %d / %d 時段" % [total, TrainingEngine.SLOTS]
	total_label.add_theme_color_override("font_color", UIKit.BAD if total > TrainingEngine.SLOTS else UIKit.TEXT)
	load_label.text = "預估每週疲勞變化 %+.1f（不含比賽）" % delta


func _save() -> void:
	if session.set_training(_plan()):
		toast("訓練計畫已儲存")
	else:
		toast("時段超過上限")


func _default() -> void:
	var d = TrainingEngine.default_plan()
	for k in spins:
		spins[k].value = int(d.get(k, 0))
	_update()
