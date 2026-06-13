# Member 3：EDA 與特徵工程（X 自變數）任務回報

本文件針對專案中的**音學特徵（Audio Features，X 變數）**進行單變量、雙變量分析、共線性診斷與主成分分析（PCA），並給出最終放入預測模型的特徵清單。所有分析以 **R 4.5.3（base R）** 完成，可直接執行重現。

## 一、產出檔案與目錄

| 類別 | 檔案 |
| --- | --- |
| 分析程式碼 | [eda_features_pca.R](eda_features_pca.R)（純 base R，含英文註解，可直接 `Rscript` 執行） |
| 視覺化圖表 | [figures_X/](figures_X/) 內共 8 張圖 |
| 數據摘要表（CSV） | `univariate_summary.csv`、`correlation_matrix.csv`、`high_corr_pairs.csv`、`vif.csv`、`pca_variance.csv`、`pca_loadings.csv` |

**分析樣本**：18,856 筆（取音學特徵 complete-case）。
**納入分析的 10 個連續音學特徵**：`Danceability`, `Energy`, `Loudness`, `Speechiness`, `Acousticness`, `Instrumentalness`, `Liveness`, `Valence`, `Tempo`, `Duration_ms`。
> 註：`Key`（音高調性 0–11）屬類別變數，不納入連續型 EDA 與 PCA。

---

## 二、單變量分析（Univariate EDA）

圖表：[figX1_histograms.png](figures_X/figX1_histograms.png)（直方圖＋密度曲線）、[figX2_boxplots.png](figures_X/figX2_boxplots.png)（標準化箱型圖）。

### 1. 分佈形狀與偏態

| 特徵 | 偏態 Skewness | 超峰度 Kurtosis | 分佈形狀 | 離群值數 (%) |
| --- | ---: | ---: | --- | ---: |
| Danceability | −0.51 | 0.08 | 左偏（輕微） | 213 (1.13%) |
| Energy | −0.69 | 0.06 | 左偏 | 281 (1.49%) |
| **Loudness** | **−2.66** | **10.62** | **嚴重左偏、厚尾** | 1,131 (6.00%) |
| **Speechiness** | **3.48** | **17.34** | **嚴重右偏** | 2,405 (12.75%) |
| Acousticness | 0.88 | −0.40 | 右偏（U 型雙峰） | 0 (0.00%) |
| **Instrumentalness** | **3.70** | **12.51** | **嚴重右偏（0 與 ~0.9 雙峰）** | 4,022 (21.33%) |
| **Liveness** | **2.30** | **5.83** | **右偏** | 1,331 (7.06%) |
| Valence | −0.09 | −0.94 | 近似對稱（略平台型） | 0 (0.00%) |
| Tempo | 0.39 | −0.18 | 近似對稱（~95 與 ~120 BPM 雙峰） | 57 (0.30%) |
| **Duration_ms** | **19.65** | **853.62** | **極端右偏** | 692 (3.67%) |

**重點觀察：**
- **近似對稱**：`Valence`、`Tempo`（偏態絕對值 < 0.5），最接近常態，適合直接使用。
- **左偏**：`Danceability`、`Energy` 屬可接受的輕微左偏；但 **`Loudness` 嚴重左偏（−2.66）且厚尾**，因為響度以 dB 計、上限約 0 dB，長尾拖向極小負值。
- **右偏**：`Speechiness`、`Instrumentalness`、`Liveness`、`Duration_ms` 皆明顯右偏，其中 `Instrumentalness` 與 `Speechiness` 呈「多數歌曲接近 0、少數歌曲偏高」的零膨脹型雙峰結構。

### 2. 離群值檢視（Tukey 1.5×IQR）

- **`Duration_ms` 存在不合理極端值**：最大值達 **4,680,000 ms ≈ 78 分鐘**，遠超一般歌曲（中位數約 213 秒），超峰度高達 853。這些是合輯／混音長軌，建模前建議**設定合理上限（如截斷 > 10–15 分鐘者）或改用對數**。
- `Instrumentalness`（21.3%）與 `Speechiness`（12.8%）的「離群值」其實是分佈本質（雙峰／零膨脹），並非錯誤資料，**不應直接刪除**。

### 3. 對數轉換（Log Transformation）

圖表：[figX3_log_transform.png](figures_X/figX3_log_transform.png)（偏態 > 1 之特徵的轉換前後對照）。

對 4 個嚴重右偏特徵（`Speechiness`、`Instrumentalness`、`Liveness`、`Duration_ms`）試做 `log(x + ε)`：
- **`Duration_ms`**：對數轉換後偏態由 19.65 大幅壓回近常態，**強烈建議改用 `log(Duration_ms)`**（與資料集中既有的 `ln_*` 系列一致）。
- `Speechiness`、`Liveness`：對數可改善右尾。
- `Instrumentalness`：因大量精確 0 值，對數效果有限，建議改以**二元化（是否為純樂器曲）**或保留原值交由 PCA／模型處理。

---

## 三、雙變量與多變量分析（Bivariate EDA）

圖表：[figX4_scatterplot_matrix.png](figures_X/figX4_scatterplot_matrix.png)（散佈圖矩陣，n=2000 子樣本）、[figX5_correlation_heatmap.png](figures_X/figX5_correlation_heatmap.png)（Pearson 相關熱力圖）。

### 高相關特徵組合（|r| > 0.5）——共線性警訊

| 特徵 A | 特徵 B | Pearson r | 解讀 |
| --- | --- | ---: | --- |
| **Energy** | **Loudness** | **+0.743** | 能量越高、響度越大（最強共線性，符合假設） |
| Energy | Acousticness | −0.660 | 能量越高、原聲成分越低 |
| Loudness | Acousticness | −0.545 | 響度越大、原聲成分越低 |
| Loudness | Instrumentalness | −0.528 | 響度越大、純樂器程度越低 |

**核心發現**：`Energy`、`Loudness`、`Acousticness`、`Instrumentalness` 形成一個**互相高度相關的「能量／聲學質地」群集**——它們本質上都在描述同一條「強烈響亮 ↔ 安靜原聲」的潛在維度，這是模型的主要共線性來源。其餘特徵（`Speechiness`、`Liveness`、`Tempo`、`Duration_ms`）彼此及與該群集相關性皆低（|r| < 0.5），資訊相對獨立。

---

## 四、共線性診斷（Multi-Collinearity）

### VIF（變異數膨脹因子，手動計算）

對每個特徵 $j$，以其餘特徵迴歸求 $R^2_j$，$\text{VIF}_j = 1/(1-R^2_j)$。

| 特徵 | VIF | 判定 |
| --- | ---: | --- |
| Energy | 3.44 | 中度（2.5–5） |
| Loudness | 3.12 | 中度（2.5–5） |
| Acousticness | 1.91 | ok |
| Danceability | 1.60 | ok |
| Valence | 1.53 | ok |
| Instrumentalness | 1.51 | ok |
| Speechiness | 1.09 | ok |
| Liveness | 1.07 | ok |
| Tempo | 1.07 | ok |
| Duration_ms | 1.03 | ok |

**判讀**：所有 VIF 皆 **< 5**（常用嚴重門檻），最高僅 `Energy`(3.44) 與 `Loudness`(3.12)。亦即**共線性存在但程度為「中度」，尚未達到使 OLS 估計嚴重不穩定的地步**。因此處理共線性有兩種策略，依「可解釋性」與「降維」目的取捨。

---

## 五、解決共線性的兩種策略

### 策略 A：特徵選擇（剔除冗餘變數）

`Energy` 與 `Loudness`（r=0.74）提供高度重複的資訊。建議**二擇一保留**：
- 保留 **`Energy`**（0–1 標準化、語意直觀），剔除 `Loudness`（dB 尺度、嚴重左偏厚尾）。
- 剔除後重算，`Energy` 的 VIF 將從 3.44 降至約 2 以下，群集共線性即可緩解。

> 若希望由演算法自動挑選，可採 LASSO Regression 將冗餘係數壓至 0（本環境未安裝 `glmnet`，留待建模組於有套件時補做）。

### 策略 B：PCA 降維合成「Vibe」綜合指標 ★

圖表：[figX6_scree.png](figures_X/figX6_scree.png)（陡坡圖＋累積變異）、[figX7_loadings_heatmap.png](figures_X/figX7_loadings_heatmap.png)（負荷量熱力圖）、[figX8_biplot.png](figures_X/figX8_biplot.png)（PC1–PC2 雙標圖）。

**重要設定**：因各特徵尺度差異極大（`Tempo`≈121、`Danceability`∈[0,1]、`Duration_ms`≈22 萬），PCA 以**相關矩陣**進行（R 中 `prcomp(..., scale.=TRUE)`），避免大變異特徵主導結果。

#### 1. 變異解釋與主成分個數

| PC | 特徵值 Eigenvalue | 解釋比例 | 累積比例 |
| --- | ---: | ---: | ---: |
| **PC1** | 3.040 | 30.4% | 30.4% |
| **PC2** | 1.298 | 13.0% | 43.4% |
| **PC3** | 1.080 | 10.8% | 54.2% |
| **PC4** | 1.001 | 10.0% | 64.2% |
| PC5 | 0.912 | 9.1% | 73.3% |
| PC6 | 0.848 | 8.5% | 81.8% |

- **Kaiser 準則（特徵值 > 1）**：保留 **PC1–PC4**（累積 64.2%）。
- **80% 變異門檻**：需到 **PC6**（81.8%）。
- 由陡坡圖，肘點落在 PC1 之後並於 PC4–PC5 趨緩。考量音學特徵本身相關性不算極高（故 PCA 壓縮空間有限），**建議保留 PC1–PC4**，在「降維」與「保留資訊」間取得平衡。

#### 2. 主成分負荷量與命名（賦予 "Vibe" 意義）

| 特徵 | PC1 | PC2 | PC3 | PC4 |
| --- | ---: | ---: | ---: | ---: |
| Danceability | −0.318 | **0.548** | −0.152 | 0.101 |
| Energy | **−0.478** | −0.261 | 0.032 | 0.003 |
| Loudness | **−0.488** | −0.168 | −0.073 | 0.035 |
| Speechiness | −0.101 | 0.358 | **0.578** | 0.057 |
| Acousticness | **0.415** | 0.228 | 0.067 | −0.002 |
| Instrumentalness | **0.349** | −0.085 | 0.022 | −0.127 |
| Liveness | −0.077 | −0.221 | **0.732** | 0.312 |
| Valence | −0.328 | **0.320** | −0.105 | −0.076 |
| Tempo | −0.117 | −0.297 | 0.159 | **−0.775** |
| Duration_ms | 0.020 | **−0.419** | −0.243 | **0.515** |

**主成分解讀與命名：**

- **PC1（30.4%）—「強烈氛圍 vs 原聲質地」軸（"High-Energy Vibe"）**
  在 `Energy`(−0.48)、`Loudness`(−0.49)、`Valence`(−0.33)、`Danceability`(−0.32) 為負，在 `Acousticness`(+0.42)、`Instrumentalness`(+0.35) 為正。
  > 即正向 = 安靜、原聲、純樂器；負向 = 響亮、有活力、適合跳舞。把符號反轉後即為直觀的 **「High-Energy Vibe（強烈氛圍指標）」**，完美吻合 Energy↔Loudness↔Acousticness 群集，**是取代該共線性群集的最佳綜合指標**。

- **PC2（13.0%）—「人聲流行律動 vs 長篇樂曲」軸（"Groove & Vocal Vibe"）**
  在 `Danceability`(+0.55)、`Speechiness`(+0.36)、`Valence`(+0.32) 為正，在 `Duration_ms`(−0.42)、`Tempo`(−0.30) 為負。
  > 正向 = 短、可舞、帶人聲、情緒正向的流行曲；負向 = 較長、偏器樂的曲目。

- **PC3（10.8%）—「現場／口語演出」軸（"Live / Spoken Vibe"）**
  由 `Liveness`(+0.73) 與 `Speechiness`(+0.58) 主導。
  > 捕捉現場演唱會錄音與說唱／口語內容。

- **PC4（10.0%）—「節奏 vs 長度」軸（"Tempo–Length Vibe"）**
  由 `Tempo`(−0.78) 與 `Duration_ms`(+0.52) 主導，捕捉快歌偏短、慢歌偏長的對比。

---

## 六、最終特徵清單（Final Feature List）

由於 VIF 顯示共線性僅屬「中度」，提供兩套方案供建模組依模型目標選擇：

### 方案一（推薦・重可解釋性）— 原始變數 + 局部去冗餘
保留語意清楚的原始特徵，僅剔除最冗餘的 `Loudness`：

```
Danceability, Energy, Speechiness, Acousticness,
Instrumentalness, Liveness, Valence, Tempo, log(Duration_ms)
```
- 剔除 `Loudness`（與 `Energy` r=0.74，資訊重複）。
- `Duration_ms` 改用對數以馴化極端右偏與離群值。
- 可選擇性納入 `Key`（轉為類別因子）。
- 此清單所有 VIF 預期 < 2.5，迴歸係數穩定且易於撰寫商業洞察。

### 方案二（重降維）— PCA 綜合指標
以 4 個正交主成分取代 10 個相關特徵，徹底消除共線性：

```
PC1 = High-Energy Vibe
PC2 = Groove & Vocal Vibe
PC3 = Live / Spoken Vibe
PC4 = Tempo–Length Vibe
```
- 優點：主成分彼此正交（相關為 0），完全無共線性，且維度由 10 降為 4。
- 缺點：係數解讀需透過負荷量回推，較不直觀。

> **綜合建議**：迴歸建模主線採**方案一**（兼顧解釋力與穩定性）；另以**方案二**作為穩健性檢核（robustness check），驗證結論不因共線性處理方式而改變。

---

## 七、給建模組的銜接重點

1. **X 端共線性主要來自 `Energy`／`Loudness`／`Acousticness` 群集** → 已透過剔除 `Loudness`（方案一）或 PCA（方案二）處理。
2. **`Duration_ms` 必須轉換或截斷**（最大 78 分鐘的極端值）。
3. 與 Member 2 的 Y 端決策銜接：Y 採 **Box-Cox(Stream)** 與 **Box-Cox(Views)**（排除 0 值）兩條獨立 OLS；本報告之 X 清單可直接套入兩模型並排比較。
