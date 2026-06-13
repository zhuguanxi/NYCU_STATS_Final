# Exploratory Model Extensions

本補充分析不取代 proposal 主線模型，而是檢查幾個合理延伸是否改善模型表現。

## 模型設定

- `E0_current_full`: 目前主線 full model，時間變數使用 YouTube 發布日期。
- `E1_platform_time`: 平台各自時間，Stream 使用 Spotify 發布日期，Views 使用 YouTube 發布日期。
- `E2_album_type`: 在 E1 上加入 `Album_type`。
- `E3_polynomial`: 在 E2 上加入 `Danceability^2`, `Energy^2`, `ln_Duration^2`。
- `E4_interactions`: 在 E3 上加入 `Danceability:official_video`, `official_video:Licensed`, `ln_Time:official_video`。

所有模型都在同一個 response-specific complete-case 樣本上比較，因此同一個 response 內的 AIC/BIC 可以直接比較。

## 主要結果

- Stream 最低 AIC 模型：`E0_current_full`，Adjusted R-squared = 0.1465，AIC = 65612.1。
- Views 最低 AIC 模型：`E4_interactions`，Adjusted R-squared = 0.3377，AIC = 87713.0。
- Stream 最低 BIC 模型：`E0_current_full`；Views 最低 BIC 模型：`E4_interactions`。

## 建議解讀

如果延伸模型只帶來很小的 adjusted R-squared 改善，但 AIC/BIC 沒有同步支持，主報告仍應保留較簡潔、符合 proposal 的主線模型。
若平台各自時間或 `Album_type` 明顯改善模型，則可以在簡報中作為 robustness check 或 future work 提及。

完整結果見：

- `tables_exploratory/model_extension_comparison.csv`
- `tables_exploratory/partial_f_extension_tests.csv`
- `tables_exploratory/coefs_exploratory_interactions.csv`
- `figures_exploratory/adj_r_squared_extension_comparison.png`
- `figures_exploratory/aic_extension_comparison.png`
- `figures_exploratory/bic_extension_comparison.png`
