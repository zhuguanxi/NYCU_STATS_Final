# Variable Screening Report

本報告補充說明變數篩選流程，目的不是取代主模型，而是支持主模型的變數選擇。

## 1. Data Leakage 檢查

`Likes` 與 `Comments` 屬於 YouTube engagement outcomes，若用來解釋 `Views` 會造成 data leakage。因此這兩個變數不放入主迴歸模型。

## 2. Correlation Screening

數值型候選變數使用 pairwise correlation 檢查共線性。完整矩陣見 `tables_screening/correlation_matrix_numeric_candidates.csv`。

| Variable 1 | Variable 2 | Correlation |
| --- | --- | ---: |
| `Energy` | `Loudness` | 0.745 |
| `Duration_ms` | `ln_Duration` | 0.717 |
| `Energy` | `Acousticness` | -0.658 |
| `Loudness` | `Acousticness` | -0.548 |
| `Loudness` | `Instrumentalness` | -0.545 |

若絕對相關係數超過 0.7，代表兩個變數可能提供相近資訊。這也是主模型沒有同時強調所有高度相近特徵的原因。

## 3. VIF Screening

VIF 用來檢查主模型選定 predictors 的 multicollinearity。完整結果見 `tables_screening/vif_selected_predictors.csv`。

| Term | VIF |
| --- | ---: |
| `official_videoOfficial_Video` | 3.03 |
| `LicensedLicensed` | 2.95 |
| `Energy` | 2.20 |
| `Acousticness` | 1.94 |
| `Danceability` | 1.61 |
| `Valence` | 1.54 |
| `ln_Days` | 1.32 |
| `Instrumentalness` | 1.23 |

VIF 越高代表該變數和其他 predictors 越容易重疊。一般而言，VIF 超過 5 需要注意，超過 10 代表嚴重共線性。

## 4. Univariate Screening

Univariate screening 用來初步理解每個變數單獨和 `ln_Stream` / `ln_Views` 的關係。這不是最終推論，最終結論仍以 multivariable nested models 為準。

### Top predictors for `ln_Stream`

| Predictor | Type | R-squared | p-value |
| --- | --- | ---: | ---: |
| `ln_Days` | numeric | 0.0783 | < 0.001 |
| `Loudness` | numeric | 0.0270 | < 0.001 |
| `Album_type` | categorical | 0.0254 | < 0.001 |
| `Instrumentalness` | numeric | 0.0166 | < 0.001 |
| `Speechiness` | numeric | 0.0151 | < 0.001 |
| `Acousticness` | numeric | 0.0138 | < 0.001 |

### Top predictors for `ln_Views`

| Predictor | Type | R-squared | p-value |
| --- | --- | ---: | ---: |
| `official_video` | categorical | 0.1385 | < 0.001 |
| `Licensed` | categorical | 0.1225 | < 0.001 |
| `Loudness` | numeric | 0.0948 | < 0.001 |
| `ln_Days` | numeric | 0.0797 | < 0.001 |
| `Instrumentalness` | numeric | 0.0515 | < 0.001 |
| `Energy` | numeric | 0.0369 | < 0.001 |

## 5. 建議

主模型仍應採用 block-based nested models，因為它符合 proposal 的分析故事，也比逐步挑變數更容易解釋。
VIF 與 univariate screening 適合放在變數選擇的補充說明，證明模型變數不是任意挑選。

輸出檔案：

- `tables_screening/missing_zero_summary.csv`
- `tables_screening/excluded_leakage_variables.csv`
- `tables_screening/correlation_pairs_high.csv`
- `tables_screening/vif_selected_predictors.csv`
- `tables_screening/univariate_screening_stream.csv`
- `tables_screening/univariate_screening_views.csv`
- `figures_screening/correlation_heatmap.png`
- `figures_screening/univariate_r2_top.png`
