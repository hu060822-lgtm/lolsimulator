## 版本 Meta 競賽：每次改版都有「版本答案打法」與一批強勢英雄，誰先研究透誰就先吃到優勢。
##
## - 改版：休賽季一次大改版，賽季中每 PATCH_WEEKS 週一次小改版（季後賽與國際賽期間不改版）。
## - 研究進度（Club.meta_research 0..100）：改版時歸零（分析師越強，起步越高）。
##   每週由分析師自然累積，訓練排「版本研究」時段可以大幅加速。
## - 效果：研究進度 × (GENERAL + 打版本答案打法時再加 PLAN_EDGE)，最多約 +6% 戰力。
## - AI：研究到 AI_ADOPT 以上，會有機率改打版本答案打法，所以先研究的優勢只有幾週。
class_name MetaRace
extends RefCounted

const PATCH_WEEKS := 7
const GENERAL := 0.02
const PLAN_EDGE := 0.04
const BASE_GAIN := 3.0        ## 每週自然累積（分析師能力 60 時）
const STUDY_GAIN := 6.0       ## 每個「版本研究」時段
const AI_STUDY_SLOTS := 1.0   ## AI 預設投入的研究時段
const AI_ADOPT := 60.0


static func bonus(research: float, plan: String, meta_plan: String) -> float:
	var r := clampf(research, 0.0, 100.0) / 100.0
	return GENERAL * r + (PLAN_EDGE * r if plan != "" and plan == meta_plan else 0.0)


## 產生新版本（version 例："27.1"）。
static func new_patch(w: WorldState, version: String) -> void:
	var old_plan := w.patch.meta_plan if w.patch else ""
	w.patch = WorldBuilder.generate_patch(w, w.rng, version)
	var choices: Array = StyleMatchup.CYCLE.filter(func(x): return x != old_plan)
	w.patch.meta_plan = choices[w.rng.range_i(0, choices.size() - 1)]
	w.patch.started_day = w.day
	for p in w.active_players():
		Development.adapt_to_patch(w, p, w.rng)
	for c in w.clubs.values():
		c.meta_research = clampf((StaffSystem.rating(w, c, "drafting") - 40.0) * 0.3, 0.0, 15.0)
	var strong: Array = w.patch.strong().slice(0, 4).map(func(cid): return w.champions[cid].name if w.champions.has(cid) else cid)
	var plan_name := plan_label(w.patch.meta_plan)
	Media.post(w, "feature", "版本 %s 上線：版本答案是「%s」，強勢英雄 %s" % [version, plan_name, "、".join(strong)], [], 0.0)
	var me: Club = w.human_club()
	if me:
		w.inbox.append({"id": w.new_id("msg"), "day": w.day, "kind": "patch", "player_id": "",
			"text": "版本 %s 上線！分析師判斷這個版本最強的是「%s」打法，強勢英雄：%s。在訓練排「版本研究」可以比對手更快吃透版本（目前研究進度 %d%%）。" % [version, plan_name, "、".join(strong), int(me.meta_research)],
			"resolved": false, "options": ["acknowledge"]})
	w.log.add("patch", w.day, [], {"version": version, "meta_plan": w.patch.meta_plan}, [])


static func plan_label(plan: String) -> String:
	return {"early_aggression": "前期進攻", "late_scaling": "後期發育", "split_push": "分推", "teamfight": "團戰", "pick": "抓單", "poke_siege": "消耗圍塔", "protect": "保護後排"}.get(plan, plan)


## 下一個小版本號：26.1 -> 26.2。
static func next_version(v: String) -> String:
	var parts := v.split(".")
	if parts.size() < 2:
		return v + ".1"
	return "%s.%d" % [parts[0], int(parts[1]) + 1]


static func weeks_into_patch(w: WorldState) -> int:
	return (w.day - w.patch.started_day) / 7


## 每週：累積研究、AI 跟上版本、必要時推出賽季中改版。
static func weekly(w: WorldState) -> void:
	if w.patch == null:
		return
	if w.phase in [WorldState.PHASE_PRESEASON, WorldState.PHASE_REGULAR] and w.day - w.patch.started_day >= PATCH_WEEKS * 7:
		new_patch(w, next_version(w.patch.version))
		return
	for c: Club in w.clubs.values():
		var analyst := StaffSystem.rating(w, c, "drafting") / 60.0
		var slots := AI_STUDY_SLOTS if not c.is_human else float((c.training_plan if not c.training_plan.is_empty() else TrainingEngine.default_plan()).get("meta_study", 0))
		c.meta_research = clampf(c.meta_research + (BASE_GAIN + STUDY_GAIN * slots) * analyst, 0.0, 100.0)
		if not c.is_human and c.meta_research >= AI_ADOPT and str(c.tactics.get("plan", "")) != w.patch.meta_plan and w.rng.chance(0.35):
			var prev := str(c.tactics.get("plan", "flexible"))
			c.tactics["plan"] = w.patch.meta_plan
			w.log.add("style_change", w.day, [c.id], {"from": prev, "to": w.patch.meta_plan}, ["跟上版本答案"])
