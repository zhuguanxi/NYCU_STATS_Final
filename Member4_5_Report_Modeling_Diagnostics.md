# Member 4 & 5：多元迴歸建模、假說檢定與模型診斷任務回報

本文件承接 Member 2（Y 應變數）與 Member 3（X 自變數）的結論，完成專案「**推論、建模與診斷**」主幹：
**Member 4（Core Modeler）** 負責建立多元迴歸、執行 Partial F-test、檢驗交互作用；
**Member 5（Diagnostician & Storyteller）** 負責殘差診斷、離群／影響點分析，並把係數翻譯成商業故事。

所有分析以 **R 4.5.3（base R / stats，無外部套件）** 完成，可直接 `Rscript modeling_diagnostics.R` 重現。

## 一、產出檔案與目錄

| 類別 | 檔案 |
| --- | --- |
| 分析程式碼 | [modeling_diagnostics.R](modeling_diagnostics.R)（純 base R，英文註解，可直接執行） |
| 視覺化圖表 | [figures_model/](figures_model/)：`figM1_interaction_plot.png`、`figM2_diagnostics.png`、`figM3_cooks_distance.png` |
| 係數／檢定摘要（CSV） | `coefs_full_stream.csv`、`coefs_full_views.csv`、`coefs_interaction_stream.csv`、`business_multipliers_stream.csv`、`coef_stability.csv`、`top_influential.csv` |

### 建模資料與變數設定

- **應變數 Y**：採用資料集既有的 `ln_Stream`（Spotify，主線）與 `ln_Views`（YouTube，平行對照）。依 Member 2 決策，建模前**排除 `Stream = 0`（549 筆）與 `Views = 0`（402 筆）**，避免對數左尾突波破壞常態性。
  - ln_Stream 模型 n = **18,307**；ln_Views 模型 n = **18,454**。
- **音學特徵 X**（採 Member 3「方案一・重可解釋性」清單，已剔除與 Energy 高度共線的 Loudness、並對 Duration 取對數）：
  `Danceability, Energy, Speechiness, Acousticness, Instrumentalness, Liveness, Valence, Tempo, ln_Duration`。
- **類別變數（虛擬變數）**：`official_video`、`Licensed`，皆轉為因子並指定 **Baseline（基準組）**：
  - `official_video`：基準 = **No_MV（無官方 MV）**，係數 `official_videoHas_MV` 解讀為「有 MV 相對於無 MV」。
  - `Licensed`：基準 = **Not_Licensed（未授權）**，係數 `LicensedLicensed` 解讀為「已授權相對於未授權」。
  > 講義重點：類別變數放入 `lm()` 會自動產生 k−1 個虛擬變數，被省略的那一組即 Baseline；所有係數都是「相對於 Baseline」的差異。

---

# 👨‍💻 Member 4：核心建模與假說檢定

## 二、多元迴歸模型（Multiple Linear Regression）

我們建立三個**巢狀模型（nested models）**，全部以 `ln_Stream` 為 Y：

| 模型 | 設定 | R² | Adjusted R² |
| --- | --- | ---: | ---: |
| **Reduced（簡單）** | 只含 9 個音學特徵 | 0.0593 | 0.0589 |
| **Full（複雜）** | 音學特徵 + `official_video` + `Licensed` | **0.0677** | **0.0671** |
| **Interaction（交互）** | Full + `Danceability:official_video` | 0.0679 | 0.0672 |

### Full 模型係數表（Y = ln_Stream）

| 變數 | Estimate | Std. Error | t value | p-value | 顯著 |
| --- | ---: | ---: | ---: | ---: | :---: |
| (Intercept) | 12.607 | 0.512 | 24.61 | <2e-16 | *** |
| Danceability | **+0.583** | 0.089 | 6.53 | 6.9e-11 | *** |
| Energy | −0.178 | 0.081 | −2.21 | 0.027 | * |
| Speechiness | **−2.318** | 0.115 | −20.15 | <2e-16 | *** |
| Acousticness | −0.508 | 0.057 | −8.92 | <2e-16 | *** |
| Instrumentalness | **−0.938** | 0.068 | −13.85 | <2e-16 | *** |
| Liveness | −0.365 | 0.073 | −4.97 | 6.9e-07 | *** |
| Valence | −0.374 | 0.059 | −6.35 | 2.2e-10 | *** |
| Tempo | +0.0019 | 0.0004 | 4.55 | 5.4e-06 | *** |
| ln_Duration | **+0.405** | 0.040 | 10.10 | <2e-16 | *** |
| **official_video**（Has_MV vs No_MV） | +0.084 | 0.050 | 1.69 | **0.091** | （不顯著） |
| **Licensed**（Licensed vs Not） | **+0.263** | 0.046 | 5.78 | 7.6e-09 | *** |

> **整體模型 F-statistic = 120.8（df = 11, 18295），p < 2.2e-16** → 模型整體高度顯著。
> **但 Adjusted R² 僅 0.067**——這是本研究最重要、也最該誠實面對的發現：**音學特徵＋影音屬性合計只能解釋 Spotify 串流量約 6.7% 的變異**。換言之，一首歌「會不會在 Spotify 爆」絕大部分由模型外的因素（藝人既有粉絲、playlist 編輯推薦、社群／TikTok 病毒傳播、發行時間長短）決定，光看歌曲「內在屬性」遠遠不夠。

## 三、Partial F-test（部分 F 檢定）：影音屬性的額外解釋力

比較 Reduced vs Full，檢定「加入 `official_video` 與 `Licensed` 是否帶來額外解釋力」：

- **H₀**：β(official_video) = β(Licensed) = 0（影音屬性毫無貢獻）
- **H₁**：至少一個影音係數 ≠ 0

R 指令：`anova(m_reduced, m_full)`

| | Res.Df | RSS | Df | Sum of Sq | **F** | **Pr(>F)** |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Reduced | 18,297 | 47,378 | | | | |
| Full | 18,295 | 46,956 | 2 | 421.5 | **82.10** | **< 2.2e-16** |

**結論**：P-value < 0.05，**拒絕 H₀**。即使 R² 只從 0.059 升到 0.068，加入影音屬性後 **確實顯著降低了預測誤差（RSS 減少 421）**，因此**值得採用 Full 模型**。

> ⚠️ 給上台報告者的提醒：F 顯著 ≠ 影響力大。本例 n 高達 1.8 萬，極小的改善也會「統計顯著」。要同時說「**統計上顯著（F 檢定通過）、但實務上 R² 增幅有限（+0.8%）**」，這才是誠實的解讀。

## 四、交互作用檢驗（Interaction Effect）：Danceability × official_video

商業問題：**「一首歌的『適合跳舞程度』對串流的帶動效果，是否會因為『有官方 MV』而加乘放大？」**

### 圖形判斷

[figM1_interaction_plot.png](figures_model/figM1_interaction_plot.png)：X 軸為 Danceability，Y 軸為預測 ln(Stream)，紅實線＝有 MV、藍虛線＝無 MV（其餘變數固定於均值／Baseline）。
兩條線**斜率略有不同（有 MV 那條較陡）但差距很小、未交叉**，視覺上交互作用相當微弱。

### 報表判斷

交互項 `Danceability:official_videoHas_MV` 係數 = **+0.282，p-value = 0.086**。
另以 Partial F-test 確認交互項是否值得加入：`anova(m_full, m_interaction)` → **F = 2.94，p = 0.086**。

**結論（誠實版）**：p = 0.086 **> 0.05，交互作用「不顯著」**。
方向上正號（+0.282）暗示「有 MV 時 Danceability 的帶動效果確實偏強」，**但在 95% 信賴水準下證據不足**（僅達 0.10 邊緣顯著）。
因此在 Spotify 串流模型中，我們**保留可直接解釋的主效應**：Danceability 對串流為正向（+0.583）且高度顯著，不需與 MV 狀態綁在一起解讀。

> 教學備註：若交互項顯著（p < 0.05），則**不能單獨解釋 Danceability 主效應**，必須說「Danceability 的效果在『有 MV』時為 0.583+0.282、在『無 MV』時為 0.583」。本例因不顯著，故無此限制——但這個檢定流程本身就是報告的得分點。

## 五、平行對照：YouTube 觀看數模型（Y = ln_Views）

同一套 X 套到 `ln_Views`，與 Spotify 並排，凸顯**平台本質差異**（呼應 Member 2 的洞察）：

| 指標 | Spotify（ln_Stream） | YouTube（ln_Views） |
| --- | ---: | ---: |
| Full 模型 Adjusted R² | 0.067 | **0.235** |
| 影音屬性 Partial F | 82.1 | **1436.8** |
| Partial F 的 p-value | <2.2e-16 | <2.2e-16 |

**關鍵故事**：影音屬性（尤其 `official_video`）在 **YouTube 的解釋力（F=1437）是 Spotify（F=82）的 17 倍**，且 YouTube 模型 R² 高達 0.235。這完全符合直覺——**YouTube 是「影音平台」，有沒有官方 MV 直接決定觀看數；Spotify 是「純聆聽平台」，MV 的影響相對微弱**。係數細節見 [coefs_full_views.csv](figures_model/coefs_full_views.csv)。

---

# 🕵️‍♂️ Member 5：模型診斷與故事整合

以下診斷皆針對主線 **ln_Stream Full 模型**。

## 六、殘差分析（Residual Analysis）

四宮格診斷圖：[figM2_diagnostics.png](figures_model/figM2_diagnostics.png)

### 1. Residual vs Fitted（變異數同質性）

殘差大致以水平 0 軸為中心散佈、**未呈現明顯喇叭狀**，顯示對 Y 取對數後**異質性（Heteroscedasticity）已大致獲得控制**——這正是 Member 2 採用對數／Box-Cox 轉換的功勞。唯左下角有一小撮殘差極端為負的點（後述影響點）拉低了局部。

### 2. Normal Q-Q Plot（常態性）

點大致沿 45° 對角線排列，但**左尾明顯下彎（粗尾）**：
- 殘差 **偏態 = −0.55**（輕微左偏）。
- Shapiro-Wilk（隨機抽 5,000 筆）：W = 0.982，p = 1.3e-24。
> **誠實解讀**：p 極小看似「嚴重違反常態」，但在 n≈1.8 萬時 Shapiro 對任何微小偏離都會拒絕，**不可只看 p**。由 W=0.982（非常接近 1）與 Q-Q 圖判斷，殘差**近似常態、僅左尾偏厚**，主因是下方一群「實際串流遠低於模型預測」的極端歌曲（見第七節）。對如此大的樣本，OLS 推論仍穩健（CLT）。

### 3. Scale-Location（變異趨勢）

紅色平滑線大致水平、無系統性上升，再次支持**變異數同質**的假設成立。

## 七、離群值（Outliers）vs 具影響力的點（Influential Observations）

講義區分兩者：**離群值**＝Y 方向預測差距大（殘差大）；**影響力點**＝會「拉扯迴歸線」、改變係數（高 Cook's D / 高槓桿）。

| 偵測標準 | 門檻 | 命中數 | 佔比 |
| --- | --- | ---: | ---: |
| 離群值 \|studentized resid\| > 3 | 3 | 137 | 0.75% |
| 高槓桿 hat > 2p/n | 0.0013 | 1,544 | 8.43% |
| **具影響力 Cook's D > 4/n** | 0.00022 | **904** | **4.94%** |

Cook's 距離圖：[figM3_cooks_distance.png](figures_model/figM3_cooks_distance.png)（紅圈標出前 10 大影響點）。

### 🎯 最具影響力的點是什麼歌？（破案）

把 Cook's D 前 10 大的觀測抓出來看 `Artist / Track`，結果**全部是同一群**：

> **Sir Arthur Conan Doyle —《Sherlock Holmes》德語有聲書章節**（"Teil 9 - Sherlock Holmes und der blinde Bettler…"）

這些根本**不是歌曲，而是有聲書（audiobook）的分章音軌**：
- 它們的 `Speechiness`、`Danceability` 被演算法標得很怪，模型依音學特徵預測它們「應該」有 ln(Stream)≈16（≈千萬級串流），
- 但實際串流僅 ~10,000（ln≈9），**studentized 殘差高達 −4.2**，於是同時成為「離群值」又因群聚而成為「影響點」。

這就是講義說的「**特異歌曲**」——資料集裡混進了非音樂內容，它們系統性地把模型往下拉。

## 八、剔除影響點再跑一次（係數穩定性檢核）

依講義建議，**暫時剔除 904 筆 Cook's D > 4/n 的影響點（4.94%）重新建模**，比較係數：[coef_stability.csv](figures_model/coef_stability.csv)

| 變數 | Full 係數 | 剔除後 | 變動% | Full 顯著 | 剔除後顯著 |
| --- | ---: | ---: | ---: | :---: | :---: |
| Danceability | 0.583 | 0.382 | −34.5% | ✓ | ✓ |
| Energy | −0.178 | −0.246 | −38.1% | ✓ | ✓ |
| **Speechiness** | **−2.318** | **−1.148** | **+50.5%** | ✓ | ✓ |
| Liveness | −0.365 | −0.280 | +23.2% | ✓ | ✓ |
| **official_video** | **+0.084** | **+0.137** | **+63.4%** | **✗（p=0.091）** | **✓ 變顯著！** |
| Licensed | 0.263 | 0.214 | −18.6% | ✓ | ✓ |

**兩個必須在報告中特別提出的發現：**

1. **`official_video` 從「不顯著」翻轉為「顯著」**：原模型中 MV 對 Spotify 串流不顯著（p=0.091），**但剔除那群有聲書影響點後，MV 係數放大 63%、變得顯著**。這證明原本的「不顯著」是被少數特異資料點稀釋掉的——**清掉雜訊後，官方 MV 對串流的正向效果才浮現**。
2. **`Speechiness` 係數收斂一半**（−2.32 → −1.15）：原本「越多口語、串流越低」的斜率被有聲書（極高 Speechiness、極低串流）過度放大，剔除後回到較合理的水準。

> 註：剔除影響點後 Adjusted R² 略降（0.067 → 0.061），屬正常——影響點本身殘差大，留著反而虛增了部分變異。重點不在 R²，而在**係數方向與顯著性的穩定性**。建議報告中以「**主模型用全樣本、並附此穩健性檢核**」的方式呈現。

## 九、商業語言翻譯（exp(β) 還原）

因 Y = ln(Stream)，**exp(β) 即 X 每增加 1 單位對 Stream 的「倍數效果」**。完整表見 [business_multipliers_stream.csv](figures_model/business_multipliers_stream.csv)。

| 變數 | β | exp(β) 倍數 | 對串流的效果 | 商業翻譯 |
| --- | ---: | ---: | ---: | --- |
| **Licensed** | +0.263 | **1.30** | **+30.1%** | 在相同音樂屬性下，**已取得授權的歌曲串流量平均高出約 30%**——版權資源是真實的流量護城河。 |
| **Danceability** | +0.583 | 1.79 | +79%（每+1，全距 0→1） | Danceability 從最低到最高，串流上看近 1.8 倍，**「適合跳舞」是 Spotify 的硬通貨**。 |
| ln_Duration | +0.405 | 1.50 | 長度每翻倍 ≈ +32% | 較長的曲目串流略高（×2 長度約 +32%）。 |
| official_video | +0.084 | 1.09 | +8.8%（不顯著） | 有 MV 對 Spotify 串流僅小幅正向且**未達顯著**——MV 的舞台在 YouTube，不在 Spotify。 |
| **Speechiness** | −2.318 | **0.10** | **−90%** | 口語成分越高串流越低（受有聲書影響，剔除後縮為約 −68%）。 |
| Instrumentalness | −0.938 | 0.39 | −61% | 純樂器曲串流明顯偏低——主流聽眾仍偏好有人聲的歌。 |
| Acousticness | −0.508 | 0.60 | −40% | 原聲成分越高串流越低。 |

---

## 十、結論與給簡報的故事線

1. **模型整體顯著但解釋力有限**：音學＋影音屬性可顯著預測串流（F=120.8, p<2e-16），但 **Adjusted R² 僅 0.067**——歌曲「內在屬性」遠不足以解釋爆紅，行銷／演算法推薦等外部力量才是主角。**這是誠實且有深度的結論，不要假裝 R² 很高。**
2. **影音屬性確有額外解釋力**（Partial F=82.1, p<2e-16），值得採用 Full 模型，但增幅務實看待。
3. **交互作用 Danceability×MV 未顯著**（p=0.086）——方向為正但證據不足，照實報告即可。
4. **平台差異是最大亮點**：影音屬性對 **YouTube（R²=0.235, F=1437）** 的解釋力遠勝 **Spotify（R²=0.067, F=82）**，印證「影音平台 vs 純聆聽平台」的本質不同。
5. **診斷揭露資料裡的「特異歌曲」**：最具影響力的點竟是混入的**德語 Sherlock Holmes 有聲書**；剔除後 **`official_video` 由不顯著翻轉為顯著**、`Speechiness` 斜率收斂——這個「破案」橋段既展示診斷功力，也是最好的故事素材。
6. **商業金句**：「在相同音樂屬性下，**已授權的歌曲串流量平均高出約 30%**；而**官方 MV 的真正戰場在 YouTube（觀看數），不在 Spotify（串流）**。」

---

### 重現方式

```bash
Rscript modeling_diagnostics.R
```
所有圖表與 CSV 將輸出至 `figures_model/`。資料前處理（排除 Y=0、log Duration、因子化）已內建於程式，無需外部套件。
