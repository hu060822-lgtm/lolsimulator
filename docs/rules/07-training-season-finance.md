# 規則 07：訓練、比賽影響、基本財務

> 實作：`src/systems/training/training_engine.gd`、`src/systems/player/match_effects.gd`、`world_simulator._finance_week`

## 1. 每週訓練

每週 12 個時段，分配到 10 種訓練：

| 訓練 | 成長重點 | 負荷 |
|---|---|---|
| Solo Queue | mechanics, laning | 1.0 |
| Champion Practice | 前四名英雄熟練度 +0.35/時段 | 0.9 |
| Scrims | teamfighting, shotcalling, positioning；默契 +0.25/時段 | 1.2 |
| Tactical Review | decision_making, wave_management, resource_trading | 0.6 |
| VOD Review | map_awareness, vision, adaptability | 0.5 |
| Draft Practice | draft_iq；BP 熟悉度 +0.5/時段 ×(教練 BP/60) | 0.4 |
| Team Building | 士氣 +1、默契 +0.6/時段 | 0.3 |
| Mental Coaching | consistency, clutch；壓力 −2.5/時段 | 0.2 |
| Physical | 恢復 | 0.4 |
| Rest | 疲勞恢復 −4/時段、壓力 −0.8 | 0 |

```
疲勞 += 總負荷 × 1.1 − 休息 × 4 − 5
疲勞 > 70 → 訓練效率 50%、壓力 +3、士氣 −2
訓練重點倍率 = 0.5 + 0.35 × 該項時段數
```

默契與 BP 熟悉度每週自然衰退（−0.6 / −0.4），必須靠訓練維持。

## 2. 比賽對選手的影響

| 狀態 | 變化 |
|---|---|
| 自信 | (個人評分 − 6) × 1.5 |
| 士氣 | 勝 +2.5 / 敗 −2.5，× 比賽重要性 |
| 壓力 | 勝 +1 / 敗 +3，× 重要性 × (1.3 − 抗壓性/100) |
| 疲勞 | 每局 +2 |
| 知名度 | (評分 − 6.5) × 0.3 × 重要性 |
| 經驗 | 決策 / 地圖意識 / 指揮 +0.06 × 年輕係數 |
| 英雄熟練度 | 該英雄 +0.5 |

## 3. 基本財務（P1）

```
每週收入 = 薪資預算/52 × (0.85 + 聲望/250)
每週支出 = 選手年薪總和/52 + 教練年薪/52
賽季獎金：冠軍 35% 獎金池，其餘隊伍平分 65%
```

P2 會擴充為完整財務：贊助商（含條件）、周邊、直播、票務、設施、青訓、財務危機與破產。
