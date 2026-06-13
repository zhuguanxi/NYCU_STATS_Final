# NYCU Statistics Final Project

本專案分析 Spotify / YouTube 音樂資料，目標是理解音訊特徵、曝光時間與平台媒體屬性如何和人氣指標相關。主要人氣指標包含 Spotify `Stream` 與 YouTube `Views`。

## 資料

主資料集：

```text
dataset/Spotify_Youtube.csv
```

資料包含 Spotify audio features、YouTube engagement metrics、媒體屬性，以及 YouTube / Spotify 發布日期。

## 專案分工與主要檔案

| 主題 | 檔案 |
| --- | --- |
| Y 變數分析 | `eda_response_variables.py`, `Member2_Report_Y_Variable.md` |
| X 特徵分析與 PCA | `eda_features_pca.R`, `Member3_Report_X_Features.md` |
| 主模型與診斷 | `modeling_diagnostics.R`, `Member4_5_Report_Modeling_Diagnostics.md` |
| 補充探索模型 | `exploratory_model_extensions.R`, `Exploratory_Model_Extensions.md` |
| 簡報摘要 | `Presentation_Takeaways.md` |

## 主要變數

應變數：

- `ln_Stream = log(Stream + 1)`
- `ln_Views = log(Views + 1)`

音訊特徵：

- `Danceability`
- `Energy`
- `Speechiness`
- `Acousticness`
- `Instrumentalness`
- `Liveness`
- `Valence`
- `Tempo`
- `ln_Duration = log(Duration_ms + 1)`

時間控制變數：

- `ln_Days = log(Days_Since_Release + 1)`

媒體屬性變數：

- `official_video`
- `Licensed`

## 主模型順序

1. M0: Audio only
2. M1: Audio + Time
3. M2: Audio + Time + Media
4. M3: Audio + Time + Media + Interaction

Interaction model 加入：

```text
Danceability x official_video
```

## 如何執行

主模型與診斷：

```bash
Rscript modeling_diagnostics.R
```

補充探索模型：

```bash
Rscript exploratory_model_extensions.R
```

可選 EDA：

```bash
python eda_response_variables.py
Rscript eda_features_pca.R
```

## 輸出

主模型表格：

```text
tables_model/
```

主模型圖：

```text
figures_model/
```

補充探索表格：

```text
tables_exploratory/
```

補充探索圖：

```text
figures_exploratory/
```

舊版模型圖已移至：

```text
figures_model/old/
```

## 主要結論

- 曝光時間 `ln_Days` 對 Spotify `Stream` 與 YouTube `Views` 都有顯著額外解釋力。
- 媒體屬性 `official_video` 與 `Licensed` 對 YouTube `Views` 的解釋力明顯強於 Spotify `Stream`。
- `Danceability x official_video` 的 interaction 在 Spotify `Stream` 不顯著，但在 YouTube `Views` 顯著。
- 補充探索分析顯示，YouTube `Views` 可能存在較明顯的非線性與交互作用結構；Spotify `Stream` 則仍以主線 full model 較適合。

## 研究限制

本研究是觀察性分析，係數應解讀為 association，而不是 causal effect。時間變數主要來自 YouTube 發布日期，對 Spotify stream 而言是 exposure proxy，不一定等於真正的歌曲發行日。
