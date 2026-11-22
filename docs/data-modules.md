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
            "names": "names.json", "players": "players.json", "rules": "rules.json"}
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

## clubs.json

```json
{"id": "jade_dragons", "name": "Jade Dragons", "short_name": "JDR", "league_id": "ecl", "region": "EAST",
 "reputation": 76, "cash": 3200000, "wage_budget": 2000000, "fanbase": 700000, "philosophy": "balanced"}
```

## players.json（可選）

任何 `Player.to_dict()` 欄位都可以提供；未提供的欄位使用預設值。
`club_id` 留空 → 自由球員。真實資料模組可在此提供完整選手名單。

## rules.json（可選）

覆寫 `src/core/tuning.gd` 中的任何參數，例如：

```json
{"mistake_base": 0.03, "regens_per_league_per_year": 20}
```

## 授權注意

預設模組的俱樂部、選手、聯賽為虛構，英雄使用英雄聯盟實際英雄（173 隻，台服中文名，`name_en` 為英文名；roles / curve / tags 為本模擬的設計值）。以真實俱樂部、選手、聯賽為基礎的資料需要相關授權；
未取得授權時，應以獨立、明確標示為「非官方」的模組散佈，且不放入本倉庫。
