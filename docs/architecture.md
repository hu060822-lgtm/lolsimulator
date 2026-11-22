# ESPORT: LOL Simulator — 系統架構

> 版本 0.1（Phase 1：Playable Foundation 的骨架）。本文件描述「程式怎麼切」，
> 各系統的「規則怎麼算」請見 [`docs/rules/`](rules/)。

## 1. 三條不可違反的原則

| 原則 | 在程式中的意義 |
|---|---|
| **模擬與畫面分離** | `src/` 底下除了 `src/ui/` 之外，沒有任何檔案繼承 `Node`。所有模擬類別都是 `RefCounted`，可以用 `godot --headless -s` 直接執行與測試。 |
| **資料與邏輯分離** | 引擎內沒有任何寫死的俱樂部、選手、英雄或賽制。全部來自 `data/modules/<模組>/`，透過 `DataModule` 載入。切換真實／虛構／自訂資料庫 = 換一個資料夾。 |
| **AI 與玩家同一套規則** | `Club.is_human` 只決定「誰做決策」。轉會、合約、陣容、選手反應全部呼叫同一組函式（`TransferMarket`、`CareerAgent`、`LineupSelector`）。 |

另外兩條工程原則：

- **可決定性**：所有隨機性都來自 `SimRng`（有種子）。同一個種子＋同一份存檔＝完全相同的世界。測試 `test_save_load_is_deterministic` 守住這件事。
- **可追溯性**：每一個重要事件都帶有 `causes`（影響來源），從比賽中的一次 Gank 到選手要求離隊都一樣。

## 2. 分層

```
┌──────────────────────────────────────────────────────────────┐
│ UI 層（Godot 場景）              src/ui/                       │
│   只讀取狀態、呼叫 GameSession 指令、監聽 signal                 │
├──────────────────────────────────────────────────────────────┤
│ 應用層（Facade）                 src/app/game_session.gd        │
│   new_game / advance_day / set_lineup / bid / respond / save   │
├──────────────────────────────────────────────────────────────┤
│ 系統層（無狀態規則）              src/systems/*, src/ai/          │
│   World · League · Match(Draft/Engine/Series) · Player         │
│   (Development/Agency/MatchEffects/Lineup) · Training ·        │
│   Transfer · ClubAI                                            │
├──────────────────────────────────────────────────────────────┤
│ 領域層（純資料 + 序列化）         src/domain/                     │
│   WorldState · Player · Club · Staff · League · Champion ·     │
│   Contract · PatchState                                        │
├──────────────────────────────────────────────────────────────┤
│ 核心工具                         src/core/                       │
│   SimRng · SimLog · Tuning · MathX                             │
├──────────────────────────────────────────────────────────────┤
│ 資料模組（外部）                  data/modules/<id>/             │
│   module.json · champions · leagues · clubs · names ·          │
│   players(可選) · staff(可選) · rules(平衡覆寫)                 │
└──────────────────────────────────────────────────────────────┘
```

**相依方向只能往下**。系統之間可以互相呼叫，但都只讀寫 `WorldState`；比賽引擎更進一步只讀取 `TeamContext`（賽前快照），完全不碰 `WorldState`，所以可以單獨拿來做大量校準。

## 3. 模組對照（GDD 第 18 章）

| GDD 模組 | 實作 | 階段 |
|---|---|---|
| World Simulation | `systems/world/world_simulator.gd` | P1 ✅ |
| Player System | `domain/player.gd`、`systems/player/development.gd`、`career_agent.gd`、`match_effects.gd` | P1 ✅（自主行為雛形） |
| Club System | `domain/club.gd`、`ai/club_ai.gd` | P1 ✅ |
| Staff System | `domain/staff.gd`（主教練） | P1 部分 / P2 |
| Transfer Engine | `systems/transfer/transfer_market.gd` | P1 ✅ |
| Training Engine | `systems/training/training_engine.gd` | P1 ✅ |
| Relationship Engine | — | P2（介面預留：`Player.trust_in_management`、`Club.chemistry`） |
| Match Engine | `systems/match/match_engine.gd`、`series_sim.gd` | P1 ✅ |
| Draft Engine | `systems/match/draft_session.gd`、`comp_analyzer.gd` | P1 ✅ |
| League Engine | `systems/league/league_engine.gd` | P1 ✅ |
| Finance Engine | `world_simulator._finance_week`（基本） | P1 基本 / P2 |
| Media Engine | — | P3 |
| Event Engine | `core/sim_log.gd`（事件紀錄與原因） | P1 基礎 / P3 敘事 |
| Database | `data/data_module.gd`、`save/save_system.gd` | P1 ✅ |

## 4. 時間與資料流

```
GameSession.advance_day()
  └─ WorldSimulator.advance_day(w)
       ├─ 依 phase：preseason → regular → playoffs → offseason
       ├─ LeagueEngine.play_day(w)            ← 當天所有比賽
       │    └─ 每場：TeamContext.from_club ×2
       │         → SeriesSim.play（每局：DraftSession → MatchEngine）
       │         → MatchEffects.apply_series（數據、士氣、自信、經驗）
       ├─ 每 7 天 weekly(w)：
       │    TrainingEngine → Development → CareerAgent → ClubAI → 財務
       └─ 休賽季每日排程：退役/新版本/新人 → 續約 → 合約到期 → 補強 → 清理 → 新賽季
```

**效能策略**（GDD 18「模擬效能」）：

- 成長、心理、自主行為每週計算一次，不是每天。
- 非玩家比賽用同一個引擎、同一套規則，只是 `detail=false` 不保存逐事件敘事。
- 休賽季 AI 俱樂部分批行動（每天只有一部分俱樂部做決策）。
- 目前 16 支隊伍、約 200 名選手，12 個賽季的世界模擬可在數十秒內完成（見測試輸出）。

## 5. 存檔

`SaveSystem` 把整個 `WorldState`（包括 RNG 狀態、事件紀錄、歷史）序列化為 JSON。
- 所有領域物件都有 `to_dict()` / `from_dict()`。
- Dictionary 的鍵一律是字串（JSON 相容）。
- 讀檔後繼續模擬與不中斷模擬結果相同（測試保證）。

## 6. 資料模組

詳見 [`data-modules.md`](data-modules.md)。重點：
- 一個模組 = 一個資料夾 + `module.json`。
- 模組只描述「世界的初始狀態」與「平衡參數覆寫」，不含程式。
- 真實資料需要授權，因此本倉庫只附虛構模組 `fictional_base`；真實資料應以獨立、明確標示為非官方的模組發佈。

## 7. 如何擴充一個系統

1. 在 `src/domain/` 加資料欄位（記得 `to_dict`/`from_dict`）。
2. 在 `src/systems/<領域>/` 加規則；只讀寫 `WorldState`，隨機只用傳入的 `SimRng`。
3. 數值常數放進 `Tuning.DEFAULTS`，讓資料模組可以覆寫。
4. 在 `WorldSimulator` 的時間排程中掛上（每日／每週／賽季事件）。
5. 在 `tests/` 寫 headless 測試，至少包含一個「行為」測試（例如「忠誠老將拒絕高薪」），而不只是不會崩潰。
6. UI 只透過 `GameSession` 新增指令。

## 8. 執行

```bash
# 測試（headless）
godot --headless --path . --import          # 第一次需要建立 class 快取
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tests/run_tests.gd -- --filter=agency

# 比賽引擎校準統計
godot --headless --path . -s tools/calibrate.gd -- --games=500

# 多年世界模擬報告
godot --headless --path . -s tools/simulate_world.gd -- --years=10 --seed=7

# 開啟原型 UI
godot --path .
```
