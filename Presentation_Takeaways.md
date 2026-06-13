# Presentation Takeaways

## 一句話總結

歌曲人氣不只取決於音樂本身。控制曝光時間後，平台呈現方式與媒體屬性，尤其是官方影片狀態，對 YouTube views 的關聯特別強。

## 主線結論

1. `ln_Days` 對 `ln_Stream` 與 `ln_Views` 都有顯著額外解釋力。
   - Stream: Partial F = 1561.75, p < 0.001
   - Views: Partial F = 1717.33, p < 0.001

2. 媒體屬性對兩個人氣指標都有額外解釋力，但對 YouTube 更強。
   - Stream media block: Partial F = 145.55, p = 1.85e-63
   - Views media block: Partial F = 1818.98, p < 0.001

3. 官方影片狀態和 YouTube views 的關聯很強。
   - `official_videoOfficial_Video` in Views model: estimate = 2.098
   - `exp(beta) = 8.15`
   - 解讀：控制音訊特徵與曝光時間後，官方影片狀態與顯著較高的預期 YouTube views 有關。

4. Interaction 有平台差異。
   - Stream: `Danceability x official_video` 不顯著，p = 0.277
   - Views: `Danceability x official_video` 顯著，p = 2.85e-06
   - 解讀：Danceability 和官方影片狀態的組合，對 YouTube views 比對 Spotify streams 更重要。

## 補充探索分析

1. Spotify `Stream`
   - 改用 `Spotify_published_date` 作為 exposure time 後，模型表現沒有變好。
   - 最低 AIC/BIC 仍是 current full model。
   - 建議主報告保留 proposal 主線模型。

2. YouTube `Views`
   - 加入 `Album_type`、平方項與 selected interactions 後，模型表現改善。
   - Adjusted R-squared: 0.3209 -> 0.3377
   - 解讀：YouTube views 可能存在較明顯的非線性與交互作用結構。

## 報告時要避免的說法

不要說：

```text
官方影片造成觀看數增加。
```

建議說：

```text
控制音訊特徵與曝光時間後，官方影片狀態與較高的 YouTube views 有關。
```

## 最終限制

- 本研究是 observational regression，不能做 causal conclusion。
- `ln_Days` 使用 YouTube 發布日期建構，對 Spotify stream 而言只是 exposure proxy。
- 模型未控制 artist popularity、playlist placement、marketing budget、fanbase size、genre、country、algorithmic recommendation exposure。
