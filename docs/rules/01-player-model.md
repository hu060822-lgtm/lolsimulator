# 規則 01：選手模型、成長與英雄池

> 實作：`src/domain/player.gd`、`src/domain/attr.gd`、`src/systems/player/development.gd`、`src/data/player_generator.gd`

## 1. 能力

所有能力為 1–100 的**真實值**，玩家不會直接看到（第二階段的球探系統會以區間顯示，例如 `Mechanics 88–94`）。

| 類別 | 能力 |
|---|---|
| 個人競技 | mechanics, laning, map_awareness, positioning, teamfighting, decision_making, adaptability, consistency, clutch |
| 戰術 | wave_management, resource_trading, vision, shotcalling, draft_iq |
| 個性（變化緩慢） | ambition, loyalty, professionalism, composure（抗壓）, teamwork, communication, discipline, temperament（情緒穩定） |
| 動態狀態 | morale, confidence, stress, fatigue, motivation |

GDD 中的「開戰判斷、邊線營運、團隊協調、戰術執行」在 P1 由 teamfighting / wave_management / shotcalling / 團隊執行力（`TeamContext.execution()`）涵蓋；P2 可拆分為獨立能力而不需改動引擎結構。

### 目前能力（CA）不決定勝負

`Player.current_ability(role)` 是位置加權平均，**只用於**市場估值、AI 評估、陣容選擇與 UI。
比賽引擎完全不看 CA，而是在每個情境中使用不同的能力組合（見規則 03 §3）。
所以「CA 很高但穩定性很低」或「CA 普通但決策與指揮出色」的選手，在比賽中會有截然不同的表現。

## 2. 潛力與每項能力的上限

- `potential`（PA）是隱藏值。
- 生成時，PA 會展開成**每項能力各自的上限**（`ceilings`），並加入一個「操作型 ↔ 理解型」偏向。
  這讓「17 歲操作已達頂尖、但比賽理解還要好幾年」的選手自然出現。
- 能力永遠不會超過該項上限。

## 3. 成長曲線（每週）

```
若 年齡 ≤ 巔峰年齡（理解型能力 +3 歲）：
  成長 = growth_base × 成長速度 × 訓練重點 × 教練培養(0.7–1.3)
       × 職業態度(0.6–1.2) × 士氣(0.8–1.2) × 年齡係數 × 剩餘空間比例
若 年齡 > 巔峰 + 1：
  衰退 = decline_base × 衰退速度 × (年齡 − 巔峰 − 1)/3
       × (操作型 1.3 / 理解型 0.45) × (1.15 − 職業態度/200)
```

- **操作型**（mechanics, laning, positioning, clutch）較早衰退。
- **理解型**巔峰晚 3 年、衰退慢 → 老將以經驗與決策維持水準（GDD 3.3）。
- **比賽經驗**：每場比賽額外提升決策、地圖意識、指揮（年輕選手最明顯）。
- 疲勞 > 70 時訓練效率減半。

測試：`test_prodigy_grows_and_veteran_declines_mechanics_first`。

## 4. 英雄池

- `champion_pool: {英雄 id: 熟練度 0–100}`，與整體能力完全獨立。
- 熟練度在比賽中是乘數（0.80 + 0.25 × 熟練度）；英雄池外的英雄視為 25。
- 每場比賽使用該英雄 +0.5；英雄練習訓練提升前四名英雄；未使用的英雄緩慢衰退。
- **版本變動**：新版本中強勢（+2）且不在英雄池的同位置英雄，適應力高的選手會開始學習（從 35 + 適應力 × 0.3 起步）。

## 5. 生成器

`PlayerGenerator.generate(w, rng, region, role, quality, young)`：
- 姓名、國籍、遊戲 ID 來自資料模組的 `names.json`（全虛構）。
- quality 0..1 決定能力水準；`young=true` 生成 16–18 歲新秀（CA 低、潛力變異大、比賽理解較弱）。
- 職業目標由個性與年齡推導（見規則 02）。
