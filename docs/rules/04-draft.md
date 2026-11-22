# 規則 04：BP（Ban / Pick）

> 實作：`src/systems/match/draft_session.gd`、`comp_analyzer.gd`

## 1. 流程

職業賽制：**6 禁（藍紅交替）→ 6 選（B1 R1 R2 B2 B3 R3）→ 4 禁（紅藍交替）→ 4 選（R4 B4 B5 R5）**。

`DraftSession` 可逐步推進：
- 玩家操作的一方：UI 呼叫 `apply(champion_id, role)`。
- AI 一方：`ai_step()`。
- 測試或預先指定：`TeamContext.forced_picks / forced_bans`。

每一步都記錄 `{side, action, champion, role, reason}`，例如「針對 Kite 的拿手英雄」「剋制對手陣容、對線優勢」。

## 2. 英雄資料

引擎只透過以下資料理解英雄（名稱只是顯示用）：

- `roles`：可擔任的位置（支援搖擺位）
- `curve`：前期 / 中期 / 後期強度（1–10）
- `lane`：對線強度
- `damage`：AD / AP / MIX
- `tags`（0–3）：engage, disengage, poke, pick, splitpush, teamfight, peel, frontline, burst, dps, waveclear, mobility, siege
- 版本強度：`PatchState.tiers`（-2..+2），每個賽季重新生成

## 3. 選角評分

對每個「未選位置 × 可用英雄」：

```
分數 = 0.44 × 選手熟練度
     + 0.18 × 版本強度
     + (0.14 + 0.10 × 順位) × 戰術契合（或 flexible 時的陣容完整度）
     + (0.06 + 0.08 × 順位) × 陣容剋制（對已選的敵方英雄）
     + 0.08 × 對線優勢（若對位已選出）
     + 雜訊(標準差 0.12 × (1 − BP 品質))
```

「順位」= 已選英雄數 / 4：**越早的選擇越重視安全（熟練度、版本），越晚越重視針對與契合**——這就是 counter pick。

## 4. 禁用評分

```
威脅 = max(敵方各未選位置：0.6 × 敵方選手熟練度 + 0.3 × 版本強度)
     + 第二輪：剋制我方已選陣容的程度
     + 系列賽調整：上一局對手 MVP 的英雄（累計 +0.35）
     + 雜訊(標準差 0.15 × (1 − BP 品質))   ← 分析師對對手英雄池的認知誤差
```

## 5. 陣容分析

六種原型：engage（開戰）、pick（抓單）、poke（消耗）、protect（保護後排）、split（分推）、teamfight（團戰）。
每個陣容是原型的比例分佈，加上缺陷檢查：

| 缺陷 | 契合度 |
|---|---|
| 前排標籤 < 2 | −0.08 |
| 只有單一傷害類型 | −0.07 |
| 開戰 < 2 且反開 < 2 | −0.07 |
| 沒有清線 | −0.04 |
| 原型集中度（主原型比例 − 0.25）× 0.3 | ± |

剋制循環與在比賽中的作用見規則 03 §4.6。

## 6. 戰術方向

`early_aggression, late_scaling, split_push, teamfight, pick, poke_siege, protect, flexible`。
- 固定方向：BP 偏好契合該方向的英雄，比賽初始姿態跟隨方向。
- `flexible`：BP 追求陣容完整度，BP 結束後由 `CompAnalyzer.best_plan` 依實際陣容決定方向。
