# ESPORT: LOL Simulator

Football Manager 式的英雄聯盟電競俱樂部經營模擬器（Godot 4.3）。

> **Build a Legacy. Not Just a Team.**

## 現況

**Phase 1（Playable Foundation）已可遊玩**，Phase 2 進行中：

- 可遊玩的 Godot UI：開局選隊/自訂俱樂部、名單、戰術、訓練、轉會中心、賽事、收件匣、歷史、存檔、手動 BP 與比賽文字直播

- 可無頭執行、可測試的模擬核心（與 UI 完全分離）
- 事件驅動比賽引擎：BP、對線、打野路線、物件爭奪與資源交換、分推、抓單、團戰、失誤、戰術調整
- 選手自主行為：職業目標、每週自我評估、要求談話、要求離隊、拒絕續約、退役
- 成長／衰退、英雄池、訓練與疲勞、基本轉會與合約、聯賽與季後賽、AI 俱樂部
- 多年世界模擬：世代交替、新人、新版本、新英雄、歷史紀錄
- 可決定性存讀檔、3 個存檔槽
- 球探誤差：能力以區間顯示，依認識程度縮小
- 財務帳本與贊助合約、教練團（五個職位）與員工市場
- 資料模組與引擎分離（預設模組 `fictional_base`：虛構俱樂部與選手 + 英雄聯盟實際英雄）

## 文件

| 文件 | 內容 |
|---|---|
| [docs/architecture.md](docs/architecture.md) | 系統架構、分層、資料流、如何擴充 |
| [docs/rules/01-player-model.md](docs/rules/01-player-model.md) | 選手能力、潛力、成長曲線、英雄池 |
| [docs/rules/02-player-agency.md](docs/rules/02-player-agency.md) | 選手自主行為與職業目標 |
| [docs/rules/03-match-engine.md](docs/rules/03-match-engine.md) | 事件驅動比賽引擎 |
| [docs/rules/04-draft.md](docs/rules/04-draft.md) | BP 與陣容分析 |
| [docs/rules/05-world-simulation.md](docs/rules/05-world-simulation.md) | 年度循環、AI 俱樂部、世代交替 |
| [docs/rules/06-transfers-contracts.md](docs/rules/06-transfers-contracts.md) | 轉會與合約 |
| [docs/rules/07-training-season-finance.md](docs/rules/07-training-season-finance.md) | 訓練、比賽影響、基本財務 |
| [docs/rules/08-finance-staff.md](docs/rules/08-finance-staff.md) | 財務、贊助、教練團 |
| [docs/data-modules.md](docs/data-modules.md) | 資料模組格式（真實／虛構／自訂資料庫） |
| [docs/roadmap.md](docs/roadmap.md) | 開發路線圖 |

## 執行

```bash
godot --headless --path . --import                       # 第一次：建立 class 快取
godot --headless --path . -s tests/run_tests.gd          # 全部測試
godot --headless --path . -s tools/calibrate.gd -- --games=500        # 比賽引擎統計
godot --headless --path . -s tools/simulate_world.gd -- --years=10    # 多年世界報告
godot --path .                                           # 開始遊戲
godot --path . -s tools/screenshots.gd -- --out=/tmp/shots  # 各畫面截圖
```

## 目錄

```
src/core      可決定性 RNG、事件紀錄、平衡參數
src/domain    純資料：世界、選手、俱樂部、聯賽、英雄、合約
src/data      資料模組載入、世界建立、選手生成
src/systems   規則：match / player / league / transfer / training / world
src/ai        AI 俱樂部經營
src/save      存檔
src/app       GameSession（UI 唯一入口）
src/ui        Godot UI（shell、screens、手動 BP / 比賽畫面）
data/modules  資料模組
tests         headless 測試
tools         校準與長期模擬工具
```

範例資料中的俱樂部、選手、聯賽皆為虛構；英雄使用英雄聯盟的實際英雄名稱（台服中文，資料中附英文名 `name_en`），強度標籤為本模擬自行設定，非官方數據。

本專案為非官方愛好者作品，與 Riot Games 無關，亦未獲其背書。League of Legends 及相關名稱為 Riot Games, Inc. 的商標或註冊商標。依 Riot 的愛好者作品政策，請勿以付費方式散布；若要商業化，需取得授權或改回虛構英雄。
