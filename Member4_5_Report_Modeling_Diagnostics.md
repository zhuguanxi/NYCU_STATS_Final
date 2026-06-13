# Member 4 & 5 報告：迴歸建模、假說檢定與模型診斷

本報告整理 Spotify `Stream` 與 YouTube `Views` 的迴歸建模流程。分析使用原始資料集 `dataset/Spotify_Youtube.csv`，建立曝光時間控制變數後，分別針對兩個人氣指標建立巢狀迴歸模型。

本次模型使用 `Youtube_published_date` 建立曝光時間變數。最後進入模型的樣本數如下：

| 應變數 | 建模樣本數 |
| --- | ---: |
| `ln_Stream` | 19,092 |
| `ln_Views` | 19,631 |

## 1. 資料與模型設定

`Stream` 與 `Views` 都是累積型人氣指標。歌曲或影片上架越久，自然有越多時間累積播放量或觀看數。為了降低曝光時間造成的偏誤，本研究加入以下控制變數：

```text
ln_Days = log(Days_Since_Release + 1)
```

`Days_Since_Release` 由 YouTube 發布日期推算而來。由於資料集沒有提供真正的歌曲發行日，因此這個變數應解讀為「曝光時間的代理變數」，而不是精確的音樂發行時間。

應變數採用對數轉換：

```text
ln_Stream = log(Stream + 1)
ln_Views  = log(Views + 1)
```

模型使用的解釋變數包含：

- 音訊特徵：`Danceability`, `Energy`, `Speechiness`, `Acousticness`, `Instrumentalness`, `Liveness`, `Valence`, `Tempo`, `ln_Duration`
- 時間控制變數：`ln_Days`
- 媒體屬性變數：`official_video`, `Licensed`

## 2. 模型順序與配適結果

本研究對 `ln_Stream` 與 `ln_Views` 使用相同的巢狀模型順序。

```text
M0 Audio only:
ln(Y) = beta0 + audio features + error

M1 Audio + Time:
ln(Y) = beta0 + audio features + beta_time ln_Days + error

M2 Full model:
ln(Y) = beta0 + audio features + beta_time ln_Days
        + official_video + Licensed + error

M3 Interaction model:
ln(Y) = beta0 + audio features + beta_time ln_Days
        + official_video + Licensed
        + Danceability x official_video + error
```

其中 `Y` 代表 `Stream` 或 `Views`。

### 模型比較

| 應變數 | 模型 | R-squared | Adjusted R-squared | AIC | BIC |
| --- | --- | ---: | ---: | ---: | ---: |
| `ln_Stream` | M0 Audio only | 0.0534 | 0.0529 | 72214.1 | 72300.5 |
| `ln_Stream` | M1 Audio + Time | 0.1250 | 0.1245 | 70714.1 | 70808.4 |
| `ln_Stream` | M2 Audio + Time + Media | 0.1381 | 0.1376 | 70429.0 | 70539.0 |
| `ln_Stream` | M3 Interaction | 0.1382 | 0.1376 | 70429.8 | 70547.7 |
| `ln_Views` | M0 Audio only | 0.1250 | 0.1246 | 93180.2 | 93267.0 |
| `ln_Views` | M1 Audio + Time | 0.1954 | 0.1950 | 91535.0 | 91629.7 |
| `ln_Views` | M2 Audio + Time + Media | 0.3213 | 0.3209 | 88199.5 | 88309.9 |
| `ln_Views` | M3 Interaction | 0.3220 | 0.3216 | 88179.6 | 88297.9 |

加入時間控制變數後，兩個應變數的模型解釋力都明顯提升。媒體屬性變數對 YouTube `Views` 特別重要，Adjusted R-squared 從 0.1950 提升到 0.3209。Interaction 對 Spotify `Stream` 幾乎沒有改善，但對 YouTube `Views` 有小幅且統計上可偵測的改善。

## 3. Partial F-test

本研究使用 Partial F-test 檢查每一組新加入的變數是否提供額外解釋力。

### Test 1：時間控制變數

```text
H0: 控制 audio features 後，ln_Days 沒有額外解釋力。
H1: 控制 audio features 後，ln_Days 具有額外解釋力。
```

| 應變數 | 模型比較 | F | p-value | 結論 |
| --- | --- | ---: | ---: | --- |
| `ln_Stream` | M0 vs M1 | 1561.75 | < 0.001 | 拒絕 H0 |
| `ln_Views` | M0 vs M1 | 1717.33 | < 0.001 | 拒絕 H0 |

`ln_Days` 對 Spotify streams 與 YouTube views 都有強烈的額外解釋力。這表示在分析累積型人氣指標時，曝光時間是必要的控制變數。

### Test 2：媒體屬性變數

```text
H0: 控制 audio features 與曝光時間後，official_video 與 Licensed 沒有額外解釋力。
H1: official_video 或 Licensed 至少有一個具有額外解釋力。
```

| 應變數 | 模型比較 | F | p-value | 結論 |
| --- | --- | ---: | ---: | --- |
| `ln_Stream` | M1 vs M2 | 145.55 | 1.85e-63 | 拒絕 H0 |
| `ln_Views` | M1 vs M2 | 1818.98 | < 0.001 | 拒絕 H0 |

媒體屬性變數對兩個應變數都有額外解釋力，但對 YouTube `Views` 的影響明顯更強。這符合平台邏輯：官方影片與授權狀態更直接影響 YouTube 上的能見度與可信度，而不是 Spotify 上的聆聽行為。

### Test 3：交互作用

```text
H0: Danceability x official_video = 0
H1: Danceability x official_video != 0
```

| 應變數 | 模型比較 | F | p-value | 結論 |
| --- | --- | ---: | ---: | --- |
| `ln_Stream` | M2 vs M3 | 1.18 | 0.277 | 不拒絕 H0 |
| `ln_Views` | M2 vs M3 | 21.93 | 2.85e-06 | 拒絕 H0 |

`Danceability` 與 `official_video` 的交互作用在 Spotify `Stream` 中不顯著；但在 YouTube `Views` 中顯著。這代表 Danceability 與觀看數之間的關聯，會因為影片是否為官方影片而有所不同。

## 4. 迴歸係數解讀

因為應變數使用對數轉換，`exp(beta)` 可以解讀為在其他變數固定下，預期人氣的倍數差異。

### Full Model：Spotify `ln_Stream`

| 變數 | Estimate | p-value | exp(beta) | 解讀 |
| --- | ---: | ---: | ---: | --- |
| `ln_Days` | 0.917 | < 0.001 | 2.50 | 曝光時間越長，預期 streams 越高。 |
| `official_videoOfficial_Video` | 0.430 | 1.33e-19 | 1.54 | 官方影片狀態與約 1.54 倍的預期 streams 有關。 |
| `LicensedLicensed` | 0.052 | 0.216 | 1.05 | 在 Stream 模型中，Licensed 不顯著。 |
| `Danceability` | 1.190 | 7.82e-45 | 3.29 | Danceability 越高，預期 streams 越高。 |
| `Speechiness` | -1.440 | 9.47e-39 | 0.237 | Speechiness 越高，預期 streams 越低。 |
| `Instrumentalness` | -0.917 | 1.49e-46 | 0.400 | Instrumentalness 越高，預期 streams 越低。 |

對 Spotify 而言，曝光時間與官方影片狀態都和較高的預期 streams 有關。不過整體模型解釋力仍有限，Full model 的 Adjusted R-squared 為 0.1376。

### Full Model：YouTube `ln_Views`

| 變數 | Estimate | p-value | exp(beta) | 解讀 |
| --- | ---: | ---: | ---: | --- |
| `ln_Days` | 1.694 | < 0.001 | 5.44 | 曝光時間越長，預期 views 越高。 |
| `official_videoOfficial_Video` | 2.098 | 3.37e-193 | 8.15 | 官方影片狀態與大幅較高的預期 views 有關。 |
| `LicensedLicensed` | 0.409 | 4.15e-11 | 1.51 | Licensed videos 與約 1.51 倍的預期 views 有關。 |
| `Danceability` | 3.302 | 1.13e-152 | 27.17 | Danceability 越高，預期 views 越高。 |
| `ln_Duration` | 0.776 | 1.21e-44 | 2.17 | 影片或歌曲長度越長，預期 views 越高。 |
| `Instrumentalness` | -2.056 | 1.19e-105 | 0.128 | Instrumentalness 越高，預期 views 越低。 |

對 YouTube 而言，媒體屬性變數的效果更強。尤其 `official_video` 的係數很大，表示在控制音訊特徵與曝光時間後，官方影片狀態仍與顯著較高的 YouTube views 有關。

### Interaction Model

| 應變數 | Interaction estimate | p-value | exp(beta) | 解讀 |
| --- | ---: | ---: | ---: | --- |
| `ln_Stream` | 0.174 | 0.277 | 1.19 | 交互作用不顯著。 |
| `ln_Views` | 1.100 | 2.85e-06 | 3.00 | 官方影片狀態下，Danceability 與 views 的正向關聯更強。 |

這個結果支持平台差異的故事：Danceability 與官方影片狀態的組合，對 YouTube views 比對 Spotify streams 更重要。

## 5. 模型診斷

Full model 的診斷圖輸出如下：

```text
figures_model/diagnostics_full_stream.png
figures_model/diagnostics_full_views.png
figures_model/cooks_distance_stream.png
figures_model/cooks_distance_views.png
```

診斷圖包含：

- Residuals vs Fitted：檢查非線性與變異數是否不固定
- Normal Q-Q：檢查殘差是否接近常態
- Scale-Location：檢查殘差變異是否隨 fitted values 改變
- Residuals vs Leverage：檢查高槓桿點與 Cook's distance

Cook's distance 表格輸出如下：

```text
tables_model/top20_cooks_stream.csv
tables_model/top20_cooks_views.csv
```

Stream 模型中，前幾個 Cook's distance 約落在 0.0066 到 0.0078，studentized residual 約為 -4.4 到 -4.8。這些觀測值可能對係數估計有較大影響，應該被檢查，但不應在沒有資料品質或研究概念理由的情況下自動刪除。

## 6. Interaction Plot

Interaction plot 以 Danceability 為 x 軸，預測的 log popularity 為 y 軸，並用不同線條表示是否為官方影片。其他數值型變數固定在樣本平均值，類別變數固定在 reference level。

輸出圖檔：

```text
figures_model/interaction_stream_danceability_official_video.png
figures_model/interaction_views_danceability_official_video.png
```

Spotify 的 interaction plot 要謹慎解讀，因為 formal test 不顯著。YouTube 的 interaction plot 較具有實質意義，因為 interaction test 顯著。

## 7. 最終解讀

控制曝光時間後，人氣並不能只由音訊特徵解釋。`ln_Days` 對兩個應變數都有強烈解釋力，表示分析累積人氣時必須考慮歌曲或影片上架多久。

媒體屬性變數對兩個應變數都有額外解釋力，但對 YouTube 的改善更明顯。Spotify `Stream` 的 Full model Adjusted R-squared 為 0.1376；YouTube `Views` 的 Full model Adjusted R-squared 為 0.3209。這表示平台呈現方式與內容可取得性，對 YouTube 人氣尤其重要。

最重要的實務結論是：在控制音訊特徵與曝光時間後，官方影片狀態與顯著較高的 YouTube views 有關。對 Spotify streams 而言，官方影片狀態在 Full model 中也顯著，但媒體屬性的核心重要性不如 YouTube 明顯。

## 8. 變數篩選補充

本研究另建立 `variable_screening.R` 作為變數篩選補充，目的不是取代主模型，而是說明主模型變數選擇的合理性。

篩選重點如下：

- `Likes` 與 `Comments` 屬於 YouTube engagement outcomes，若用來解釋 `Views` 會造成 data leakage，因此不放入主迴歸模型。
- Correlation screening 顯示 `Energy` 與 `Loudness` 的相關係數為 0.745，屬於較高相關；因此主模型保留較常用且較好解釋的 `Energy`，不把 `Loudness` 放入主線模型。
- `Duration_ms` 與 `ln_Duration` 的相關係數為 0.717，因此主模型使用對數轉換後的 `ln_Duration`。
- VIF screening 顯示主模型選定 predictors 的 VIF 皆低於 5，最高約為 3.03，沒有嚴重 multicollinearity。
- Univariate screening 顯示 `ln_Days` 是 `ln_Stream` 的重要單變量 predictors 之一，而 `official_video` 與 `Licensed` 是 `ln_Views` 的重要單變量 predictors。

因此，主模型採用 audio features、time control、media attributes 的 block-based nested model 是合理的。完整結果見：

```text
Variable_Screening_Report.md
tables_screening/
figures_screening/
```

## 9. 補充探索分析

為了檢查是否存在更好的變數組合，本研究另建立 `exploratory_model_extensions.R` 作為補充分析。此分析不取代 proposal 主線模型，而是比較幾個合理延伸：

- 平台各自時間：Stream 使用 `Spotify_published_date`，Views 使用 `Youtube_published_date`
- 加入 `Album_type`
- 加入 `Danceability`, `Energy`, `ln_Duration` 的平方項
- 加入少量 interaction：`Danceability:official_video`, `official_video:Licensed`, `ln_Time:official_video`

探索結果顯示，對 Spotify `Stream` 而言，最低 AIC/BIC 的模型仍是使用 YouTube 發布時間的 current full model。改用 Spotify 發布日期後，模型表現反而下降，可能代表 Spotify 發布日期在此資料集中不一定是較好的 stream exposure proxy，或是完整樣本條件改變後造成資訊損失。

對 YouTube `Views` 而言，加入 `Album_type`、平方項與 selected interactions 後，Adjusted R-squared 從 0.3209 提升到 0.3377，AIC/BIC 也下降。這表示 YouTube views 可能存在較明顯的非線性與交互作用結構。不過，為了維持主報告的可解釋性與 proposal 一致性，這些結果較適合作為 robustness check 或 future work。

完整補充結果見：

```text
Exploratory_Model_Extensions.md
tables_exploratory/
figures_exploratory/
```

## 10. 研究限制

本研究是觀察性研究，因此係數應解讀為 association，而不是 causal effect。本研究不能證明官方影片或授權狀態會直接造成更高人氣。

時間變數來自 YouTube 發布日期，可能不等於歌曲在 Spotify 或其他平台上的真實發行日期。因此 `ln_Days` 是曝光時間的代理變數。

模型沒有控制 artist popularity、playlist placement、marketing budget、fanbase size、genre、country 或 algorithmic recommendation exposure。這些遺漏變數仍可能影響人氣。

Cook's distance 可以標示具影響力的觀測值，但本報告不自動刪除這些資料。是否移除需要有明確的資料品質或研究概念理由。

## 11. 可重現性

執行主分析：

```bash
Rscript modeling_diagnostics.R
```

執行變數篩選補充：

```bash
Rscript variable_screening.R
```

程式讀取：

```text
dataset/Spotify_Youtube.csv
```

並將模型表格輸出至 `tables_model/`，模型圖輸出至 `figures_model/`。

執行補充探索分析：

```bash
Rscript exploratory_model_extensions.R
```
