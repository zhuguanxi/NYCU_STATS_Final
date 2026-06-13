# Member 2: Target Variable (Y) Specialist 任務回報

這份文件記錄了針對本專案應變數（Response Variables）`Stream` 和 `Views` 的分析結果與最終決策，請負責建模（Modeling）的組員參考此結論進行後續分析。

## 一、 產出檔案與目錄
* **EDA 程式碼**：`eda_response_variables.py`（已加上完整的英文註解，可直接執行）
* **視覺化圖表**：存放於 `figures_Y/` 資料夾內，共包含 6 張分析圖表與摘要表。

---

## 二、 核心分析與發現

### 1. 原始資料存在嚴重的右偏 (Right-skewed) 問題
從 **Figure 1** (Raw Distribution) 可以觀察到：
* `Stream` 和 `Views` 的分配極度向右傾斜（Skewness 分別高達 4.25 與 9.04）。
* 兩者的平均數（Mean）遠大於中位數（Median），且存在大量極端值（Outliers）。
* **結論**：絕對不能直接使用原始數值跑線性迴歸，否則會嚴重違反常態假設（Normality），導致統計推論失效。

### 2. 轉換方法比較：Log-transform vs. Box-Cox (排除 0 值後比較)
為了修正右偏，我們在排除 $Y=0$ 的樣本後比較了兩種轉換方式（參考 **Figure 4** 的 Q-Q Plot 比較圖與 **Figure 5** 的統計摘要表）：
* **Log 轉換 (Figure 2)**：對數轉換（$ln$）能大幅將 Skewness 壓到 -0.6 ~ -0.8 左右，但從 Q-Q Plot 可以看出兩端（特別是左尾）仍然偏離常態分配。
* **Box-Cox 轉換 (Figure 3)**：能達到最完美的常態分佈，Skewness 幾乎降為 0，且從 **Figure 4** 的 Q-Q Plot 可以明顯看出，Box-Cox 貼合紅線（常態分配）的程度遠優於 Log 轉換。

### 3. Zero-value 的影響
資料中存在部分歌曲無 YouTube 觀看數（`Views=0`，約 402 筆）或無串流數（`Stream=0`，約 549 筆）。如果強行使用 $ln(Y+1)$ 來保留這些零值，會在圖形左尾產生一根明顯的突波（Spike，如 **Figure 6** 所示），這會嚴重破壞分配的常態性。

---

## 三、 最終決策與建模建議

### 決策一：Y 的最終型態決定使用 **Box-Cox 轉換**
由於我們希望殘差盡可能符合常態分配（Normality），從 Q-Q Plot 的表現來看，**Box-Cox 轉換完勝 Log 轉換**。
* **實作建議**：請建模組在跑迴歸模型前，**先將 `Stream = 0` 與 `Views = 0` 的樣本排除**，然後針對剩餘大於 0 的樣本進行 Box-Cox 轉換。
* 算出的最佳 $\lambda$ 值約為 0.10，這代表真實的最佳轉換介於對數轉換 ($\lambda=0$) 與稍微次方轉換之間。

### 決策二：將模型拆分為兩個獨立的 Univariate Regression
在我們最初的 Proposal 中，寫法是把 Y 當成一個 Vector：$Y_i = [Stream_i, Views_i]^T$。但我評估後，**強烈建議拆成兩個獨立的 OLS 模型來跑**：
1. **Model A (Spotify 視角)**：`BoxCox(Stream)` 作為 Y
2. **Model B (YouTube 視角)**：`BoxCox(Views)` 作為 Y

**強烈建議拆分的理由：**
* 統計上，當兩條方程式的自變數（X）完全相同時，跑 Multivariate Regression 算出來的係數，跟分開跑兩次 Univariate Regression 是**一模一樣**的，不需要自找麻煩。
* 拆開來跑，我們可以把兩組迴歸結果「並排」放在同一張表裡。這樣就可以寫出很棒的洞察，例如：「*Official Video 這個變數對 YouTube Views 有極大的正向影響，但對 Spotify Stream 影響不大，這反映了影音平台與純聆聽平台的本質差異。*」
* 殘差檢定與模型診斷分開做會簡單很多。
