## 選手能力與位置的常數定義（單一真相來源）。
class_name Attr
extends RefCounted

const ROLES := ["TOP", "JUNGLE", "MID", "ADC", "SUPPORT"]

## 個人競技能力 + 戰術能力（1–100）。英雄池另外存在 Player.champion_pool。
const SKILLS := [
	"mechanics", "laning", "map_awareness", "positioning", "teamfighting",
	"decision_making", "adaptability", "consistency", "clutch",
	"wave_management", "resource_trading", "vision", "shotcalling", "draft_iq",
]

## 心理與職業特質（1–100）。特質變化緩慢，屬於「個性」。
const PERSONALITY := [
	"ambition", "loyalty", "professionalism", "composure", "teamwork",
	"communication", "discipline", "temperament",
]

## 「操作型」能力較早到達巔峰、較早衰退；「理解型」能力巔峰較晚、衰退較慢。
const MECHANICAL := ["mechanics", "laning", "positioning", "clutch"]
const COGNITIVE := ["map_awareness", "decision_making", "wave_management", "resource_trading", "vision", "shotcalling", "draft_iq", "teamfighting", "adaptability", "consistency"]

## 各位置計算「目前能力（CA）」的權重——僅用於估值、AI 評估與 UI 顯示，
## 比賽引擎不使用 CA，而是逐項使用個別能力。
const ROLE_WEIGHTS := {
	"TOP": {"mechanics": 1.0, "laning": 1.3, "teamfighting": 1.0, "wave_management": 1.1, "positioning": 0.8, "decision_making": 0.9, "map_awareness": 0.7, "consistency": 0.8},
	"JUNGLE": {"map_awareness": 1.4, "decision_making": 1.3, "resource_trading": 1.2, "mechanics": 0.9, "vision": 0.9, "shotcalling": 0.9, "teamfighting": 0.8, "consistency": 0.8},
	"MID": {"mechanics": 1.3, "laning": 1.2, "map_awareness": 1.0, "teamfighting": 1.0, "decision_making": 1.0, "wave_management": 1.0, "consistency": 0.8},
	"ADC": {"mechanics": 1.3, "positioning": 1.4, "laning": 1.1, "teamfighting": 1.1, "wave_management": 0.8, "consistency": 0.9},
	"SUPPORT": {"vision": 1.4, "map_awareness": 1.2, "shotcalling": 1.2, "decision_making": 1.1, "positioning": 0.9, "teamfighting": 1.0, "laning": 0.7},
}
