## 模擬平衡參數。所有「魔法數字」集中於此，資料模組可用 rules.json 覆寫，
## 讓版本平衡與規則調整不需要改程式碼。
class_name Tuning
extends RefCounted

const DEFAULTS := {
	# --- 時間 ---
	"days_per_week": 7,
	"weeks_per_year": 52,
	# --- 比賽：對線 ---
	"lane_gold_per_min": 380.0,
	"lane_edge_gold": 55.0,
	"lane_kill_base": 0.012,
	"lane_kill_edge": 0.035,
	# --- 比賽：打野 ---
	"gank_base_success": 0.34,
	"gank_skill_weight": 0.45,
	"gank_vision_weight": 0.20,
	# --- 比賽：團戰 ---
	"fight_decisiveness": 1.5,
	"mistake_base": 0.022,
	"disengage_base": 0.35,
	"comp_counter_weight": 0.16,
	"comp_fit_weight": 0.10,
	"execution_spread": 0.14,
	"gold_power_exponent": 0.38,
	"scaling_weight": 0.07,
	# --- 比賽：每日狀態 ---
	"form_sd": 0.09,
	# --- 選手成長 ---
	"growth_base_per_week": 0.20,
	"decline_base_per_week": 0.10,
	"mastery_decay_per_week": 0.08,
	# --- 選手自主 ---
	"happiness_ema": 0.18,
	"talk_threshold": -0.25,
	"transfer_request_threshold": -0.45,
	"transfer_request_weeks": 4,
	# --- 世界 ---
	"regens_per_league_per_year": 14,
	"max_roster": 8,
	"min_roster": 6,
}

static var _overrides: Dictionary = {}


static func get_value(key: String) -> Variant:
	if _overrides.has(key):
		return _overrides[key]
	return DEFAULTS.get(key)


static func f(key: String) -> float:
	return float(get_value(key))


static func i(key: String) -> int:
	return int(get_value(key))


static func apply_overrides(d: Dictionary) -> void:
	for k in d:
		_overrides[k] = d[k]


static func reset() -> void:
	_overrides.clear()
