# 資料模組格式

資料模組讓「真實資料庫 / 虛構資料庫 / 自訂資料庫」可以自由切換，並把授權問題隔離在核心引擎之外。

## 目錄結構

```
data/modules/<module_id>/
  module.json      必要：模組資訊與檔案對照
  champions.json   必要：英雄
  leagues.json     必要：聯賽與賽制
  clubs.json       必要：俱樂部
  names.json       建議：生成選手/教練用的名字庫
  players.json     可選：直接提供選手（未提供的位置由生成器補足）
  staff.json       可選：直接提供教練
  rules.json       可選：覆寫 Tuning 平衡參數
  events.json      可選：隨機事件
```

## module.json

```json
{
  "id": "fictional_base",
  "name": "虛構世界：基礎資料庫",
  "kind": "fictional",          // fictional | real_unofficial | custom
  "version": "0.1.0",
  "start_year": 2027,
  "files": {"champions": "champions.json", "leagues": "leagues.json", "clubs": "clubs.json",
            "names": "names.json", "players": "players.json", "rules": "rules.json", "events": "events.json"}
}
```

## champions.json

```json
{"id": "starweaver", "name": "Starweaver", "roles": ["MID"],
 "curve": {"early": 5, "mid": 7, "late": 8}, "lane": 6, "damage": "AP",
 "tags": {"teamfight": 3, "waveclear": 3, "poke": 1}}
```
標籤清單見 `Champion.TAGS`。每個位置至少需要 4 隻英雄（載入時驗證）。

## leagues.json

```json
{"id": "ecl", "name": "Eastern Crown League", "region": "EAST", "tier": 1, "prize_pool": 800000,
 "format": {"regular": {"type": "double_round_robin", "best_of": 3, "days_between_rounds": 3},
            "playoffs": {"type": "single_elimination", "teams": 4, "best_of": 5}}}
```
賽制完全由資料決定（GDD 10.1：不把某一年度的賽制寫死）。

- `tier`：1 = 一級聯賽，2 = 次級聯賽。同 `region` 的一級最後一名與次級冠軍每季互換。
- `format.wage_cap`：薪資預算上限；`format.revenue_share`：每季聯賽分潤（預設 250000）。
- `format.slots`：國際賽事名額，例如 `{"worlds": 4, "msi": 2}`。
- `tier: 0` 的項目是國際賽事，不屬於任何俱樂部。`format.timing` 為 `"end"`（世界賽，國內賽季結束後）或
  `"midseason"`（季中邀請賽，第一循環後；`break_days` 為國內聯賽休兵天數）：

```json
{"id": "worlds", "name": "World Championship", "region": "INTL", "tier": 0, "prize_pool": 3000000,
 "format": {"qualify_per_league": 4,
            "regular": {"type": "single_round_robin", "best_of": 1, "days_between_rounds": 1},
            "playoffs": {"type": "single_elimination", "teams": 4, "best_of": 5},
            "stakes": {"regular": 1.4, "playoffs": 1.7, "final": 2.0}}}
```
`stakes` 可用在任何賽事，指定各階段比賽的重要性（影響壓力、大賽經驗）。

## clubs.json

```json
{"id": "jade_dragons", "name": "Jade Dragons", "short_name": "JDR", "league_id": "ecl", "region": "EAST",
 "reputation": 76, "cash": 3200000, "wage_budget": 2000000, "fanbase": 700000, "philosophy": "balanced"}
```

## players.json（可選）

任何 `Player.to_dict()` 欄位都可以提供；未提供的欄位使用預設值。
`club_id` 留空 → 自由球員。真實資料模組可在此提供完整選手名單。

## events.json（可選）

```json
{"id": "stream_controversy", "weight": 3, "target": "player",
 "condition": {"trait_below": {"temperament": 60}},
 "text": "{player} 在直播中與觀眾嗆聲", "headline": "{player}（{club}）直播失言引發論戰",
 "options": [
   {"id": "fine", "label": "罰款並要求公開道歉", "effects": {"target": {"morale": -8}, "club": {"opinion": 8}}},
   {"id": "ignore", "label": "不回應", "effects": {"club": {"opinion": -5}}}],
 "ai": "fine"}
```
`target`：`player` 或 `club`。條件：`trait_below`、`trait_above`、`min_reputation`、`min_ability`。
效果欄位見 [rules/10](rules/10-world-competitions-media.md)。只有一個選項的事件會直接生效。

## rules.json（可選）

覆寫 `src/core/tuning.gd` 中的任何參數，例如：

```json
{"mistake_base": 0.03, "regens_per_league_per_year": 20}
```

## 授權注意

英雄使用英雄聯盟實際英雄（173 隻，台服中文名，`name_en` 為英文名；roles / curve / tags 為本模擬的設計值）。
`lol_world` 的聯賽與國際賽事名稱、賽制對標 Riot 的官方賽事（非官方粉絲作品）；俱樂部與選手只使用改寫過的致敬名，不使用真實姓名或戰隊商標。
`fictional_base` 的俱樂部、選手、聯賽為原創。真名名單只存在玩家自己的電腦（`user://`），不放入本倉庫。


## 致敬選手（players.json 的簡化格式）

```json
{"homage": true, "handle": "Fakir", "primary_role": "MID", "club_id": "t_one", "birth": 1996, "quality": 0.93, "signature": ["azir", "ryze"]}
```

只需要名字、位置、出生年與水準（0..1），能力、個性、英雄池由生成器依水準產生；`signature` 的英雄熟練度至少 95。

## 賽區人才水準

`names.json` 的每個賽區可以加上 `"talent": 0.86`，乘上該賽區生成選手的水準（預設 1.0）。

## 真名名單

遊戲不附帶真實選手或戰隊名稱。想用真名，自己建立 `user://name_overlays/<模組 id>.json`
（Windows 為 `%APPDATA%/Godot/app_userdata/ESPORT_ LOL Simulator/name_overlays/lol_world.json`）：

```json
{
 "clubs":   {"t_one": {"name": "（真實戰隊名）", "short_name": "（縮寫）"}},
 "players": {"Fakir": {"handle": "（真實 ID）", "real_name": "（本名）"},
             "Chovi": "（真實 ID）"}
}
```

- `clubs` 以俱樂部 id 對應，`players` 以致敬名對應（可以只給新 ID 字串）。
- 開新遊戲時自動套用，開局畫面會顯示「已套用真名名單」。只影響新遊戲。
