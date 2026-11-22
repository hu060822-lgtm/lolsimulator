# 開發路線圖

## Phase 1：Playable Foundation（本 PR 建立骨架）

| 項目 | 狀態 |
|---|---|
| 俱樂部選擇（模組俱樂部 / 自訂俱樂部參數） | ✅ 核心（`WorldBuilder.build`），UI 待做 |
| 5 個位置 | ✅ |
| 選手能力與英雄池 | ✅ |
| 基本選手市場 | ✅ 核心（估值、要價、報價、自由球員、AI 補強） |
| 基本合約 | ✅ 核心（續約、到期、拒絕續約） |
| 基本訓練 | ✅ |
| BP | ✅ AI；玩家逐步 BP 的 API 已就緒，UI 待做 |
| 比賽模擬 | ✅ 事件驅動引擎 + 系列賽 |
| 聯賽排名 | ✅（含同分判定、季後賽） |
| 基本存檔 | ✅（可決定性存讀檔） |
| 驗收：完整賽季 → 轉會期 | ✅ 測試 `test_full_season_reaches_transfer_window` |

**Phase 1 剩餘工作**（建議下一批 PR）：
1. UI：俱樂部選擇、名單、戰術、訓練規劃、轉會中心、比賽中心（文字直播 / 時間軸）、聯賽總覽、收件匣。
2. 玩家 BP 介面（使用 `DraftSession.apply`）。
3. 收件匣中轉會報價的接受/拒絕流程。
4. 存檔槽位管理。

## Phase 2：Management Depth
完整財務與贊助、選手心理深化、關係網絡（Relationship Engine）、完整教練團與員工、
球探（能力區間與誤差）、經紀人、租借、動態 AI 經營加強。

## Phase 3：World Simulation
多地區與國際賽事、次級聯賽與升降級、媒體與輿論、隨機事件敘事、動態賽制。
（多年世代交替、退役、新人、歷史紀錄已在 P1 打底。）

## Phase 4：Advanced Simulation
完整對話系統（以 `CareerAgent.respond` 為基礎）、即時戰術指揮（以 `TeamContext.orders` 為基礎）、
法律事件、組織危機、品牌系統。
