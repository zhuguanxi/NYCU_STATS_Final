# =============================================================================
# Variable screening
# -----------------------------------------------------------------------------
# This script documents why the final model variables are reasonable.
# It is a screening/EDA supplement and does not replace the main nested models.
# =============================================================================

INPUT_FILE <- file.path("dataset", "Spotify_Youtube.csv")
TABLE_DIR <- "tables_screening"
FIGURE_DIR <- "figures_screening"
REPORT_FILE <- "Variable_Screening_Report.md"

dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIGURE_DIR, showWarnings = FALSE, recursive = TRUE)

df <- read.csv(INPUT_FILE, fileEncoding = "UTF-8-BOM", check.names = TRUE)

# ---- Helpers ----------------------------------------------------------------
as_binary_factor <- function(x, false_label, true_label) {
  x_chr <- trimws(tolower(as.character(x)))
  out <- ifelse(x_chr %in% c("true", "t", "1", "yes", "y"), 1,
                ifelse(x_chr %in% c("false", "f", "0", "no", "n"), 0, NA))
  factor(out, levels = c(0, 1), labels = c(false_label, true_label))
}

parse_date_to_days <- function(x) {
  parsed <- as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (all(is.na(parsed))) {
    parsed <- as.POSIXct(as.Date(x, format = "%Y-%m-%d"), tz = "UTC")
  }
  days <- as.numeric(difftime(Sys.time(), parsed, units = "days"))
  days[days < 0] <- NA
  days
}

fmt <- function(x, digits = 4) {
  formatC(x, format = "f", digits = digits)
}

fmt_p <- function(x) {
  ifelse(is.na(x), "NA", ifelse(x < 0.001, "< 0.001", sprintf("%.3f", x)))
}

numeric_summary <- function(data) {
  out <- data.frame(
    variable = names(data),
    class = vapply(data, function(x) paste(class(x), collapse = "/"), character(1)),
    missing_count = vapply(data, function(x) sum(is.na(x)), integer(1)),
    missing_rate = vapply(data, function(x) mean(is.na(x)), numeric(1)),
    zero_count = vapply(data, function(x) {
      if (is.numeric(x)) sum(x == 0, na.rm = TRUE) else NA_integer_
    }, integer(1)),
    zero_rate = vapply(data, function(x) {
      if (is.numeric(x)) mean(x == 0, na.rm = TRUE) else NA_real_
    }, numeric(1))
  )
  out[order(-out$missing_rate, out$variable), ]
}

vif_table <- function(formula, data) {
  mm <- model.matrix(formula, data = data)
  mm <- mm[, colnames(mm) != "(Intercept)", drop = FALSE]
  out <- lapply(colnames(mm), function(col) {
    y <- mm[, col]
    x <- mm[, setdiff(colnames(mm), col), drop = FALSE]
    if (ncol(x) == 0 || sd(y) == 0) {
      vif <- NA_real_
    } else {
      r2 <- summary(lm(y ~ x))$r.squared
      vif <- 1 / (1 - r2)
    }
    data.frame(term = col, VIF = vif)
  })
  do.call(rbind, out)
}

screen_numeric <- function(response, predictor, data) {
  d <- data[complete.cases(data[, c(response, predictor)]), c(response, predictor)]
  if (nrow(d) < 10 || sd(d[[predictor]]) == 0) {
    return(data.frame(
      response = response, predictor = predictor, predictor_type = "numeric",
      n = nrow(d), estimate = NA_real_, p_value = NA_real_, r_squared = NA_real_
    ))
  }
  m <- lm(as.formula(paste(response, "~", predictor)), data = d)
  s <- summary(m)
  data.frame(
    response = response,
    predictor = predictor,
    predictor_type = "numeric",
    n = nobs(m),
    estimate = coef(m)[2],
    p_value = s$coefficients[2, 4],
    r_squared = s$r.squared
  )
}

screen_categorical <- function(response, predictor, data) {
  d <- data[complete.cases(data[, c(response, predictor)]), c(response, predictor)]
  d[[predictor]] <- factor(d[[predictor]])
  if (nrow(d) < 10 || nlevels(d[[predictor]]) < 2) {
    return(data.frame(
      response = response, predictor = predictor, predictor_type = "categorical",
      n = nrow(d), estimate = NA_real_, p_value = NA_real_, r_squared = NA_real_
    ))
  }
  m0 <- lm(as.formula(paste(response, "~ 1")), data = d)
  m1 <- lm(as.formula(paste(response, "~", predictor)), data = d)
  a <- anova(m0, m1)
  data.frame(
    response = response,
    predictor = predictor,
    predictor_type = "categorical",
    n = nobs(m1),
    estimate = NA_real_,
    p_value = a$`Pr(>F)`[2],
    r_squared = summary(m1)$r.squared
  )
}

plot_correlation_heatmap <- function(cor_mat, output_file) {
  png(output_file, width = 1100, height = 950)
  op <- par(mar = c(9, 9, 4, 2))
  image(
    1:ncol(cor_mat), 1:nrow(cor_mat), t(cor_mat[nrow(cor_mat):1, ]),
    axes = FALSE, col = colorRampPalette(c("#3B6EA8", "white", "#C74732"))(100),
    zlim = c(-1, 1), xlab = "", ylab = "", main = "Correlation Heatmap"
  )
  axis(1, at = 1:ncol(cor_mat), labels = colnames(cor_mat), las = 2, cex.axis = 0.75)
  axis(2, at = 1:nrow(cor_mat), labels = rev(rownames(cor_mat)), las = 2, cex.axis = 0.75)
  box()
  par(op)
  dev.off()
}

plot_univariate_r2 <- function(screening, output_file) {
  top <- screening[order(-screening$r_squared), ]
  top <- top[!is.na(top$r_squared), ]
  top <- head(top, 16)
  labels <- paste(top$response, top$predictor, sep = ": ")
  png(output_file, width = 1200, height = 800)
  op <- par(mar = c(10, 5, 4, 2))
  barplot(top$r_squared, names.arg = labels, las = 2, col = "#3B6EA8",
          ylab = "Univariate R-squared", main = "Top Univariate Screening Results")
  par(op)
  dev.off()
}

# ---- Variable preparation ---------------------------------------------------
numeric_cols <- c(
  "Danceability", "Energy", "Key", "Loudness", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo", "Duration_ms",
  "Views", "Likes", "Comments", "Stream"
)
for (col in intersect(numeric_cols, names(df))) {
  df[[col]] <- as.numeric(df[[col]])
}

df$ln_Stream <- log(df$Stream + 1)
df$ln_Views <- log(df$Views + 1)
df$ln_Duration <- log(df$Duration_ms + 1)
df$Days_Since_Release <- parse_date_to_days(df$Youtube_published_date)
df$ln_Days <- log(df$Days_Since_Release + 1)
df$official_video <- as_binary_factor(df$official_video, "No_Official_Video", "Official_Video")
df$Licensed <- as_binary_factor(df$Licensed, "Not_Licensed", "Licensed")
df$Album_type <- factor(df$Album_type)

AUDIO_SELECTED <- c(
  "Danceability", "Energy", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo", "ln_Duration"
)
NUMERIC_CANDIDATES <- c(
  "Danceability", "Energy", "Key", "Loudness", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo", "Duration_ms",
  "ln_Duration", "ln_Days"
)
CATEGORICAL_CANDIDATES <- c("official_video", "Licensed", "Album_type")
LEAKAGE_VARIABLES <- c("Likes", "Comments")

# ---- Missing / zero summary -------------------------------------------------
missing_summary <- numeric_summary(df)
write.csv(missing_summary, file.path(TABLE_DIR, "missing_zero_summary.csv"), row.names = FALSE)

leakage_notes <- data.frame(
  variable = LEAKAGE_VARIABLES,
  reason = c(
    "YouTube engagement outcome; using it to explain Views would create data leakage.",
    "YouTube engagement outcome; using it to explain Views would create data leakage."
  )
)
write.csv(leakage_notes, file.path(TABLE_DIR, "excluded_leakage_variables.csv"), row.names = FALSE)

# ---- Correlation screening --------------------------------------------------
cor_data <- df[, NUMERIC_CANDIDATES]
cor_mat <- cor(cor_data, use = "pairwise.complete.obs")
write.csv(cor_mat, file.path(TABLE_DIR, "correlation_matrix_numeric_candidates.csv"))

cor_pairs <- do.call(rbind, lapply(seq_len(ncol(cor_mat) - 1), function(i) {
  do.call(rbind, lapply((i + 1):ncol(cor_mat), function(j) {
    data.frame(
      variable_1 = colnames(cor_mat)[i],
      variable_2 = colnames(cor_mat)[j],
      correlation = cor_mat[i, j],
      abs_correlation = abs(cor_mat[i, j])
    )
  }))
}))
cor_pairs <- cor_pairs[order(-cor_pairs$abs_correlation), ]
write.csv(cor_pairs[cor_pairs$abs_correlation >= 0.7, ],
          file.path(TABLE_DIR, "correlation_pairs_high.csv"), row.names = FALSE)

plot_correlation_heatmap(cor_mat, file.path(FIGURE_DIR, "correlation_heatmap.png"))

# ---- VIF screening ----------------------------------------------------------
vif_vars <- c(AUDIO_SELECTED, "ln_Days", "official_video", "Licensed", "Album_type")
vif_data <- df[complete.cases(df[, vif_vars]), vif_vars]
vifs <- vif_table(
  as.formula(paste("~", paste(vif_vars, collapse = " + "))),
  vif_data
)
vifs <- vifs[order(-vifs$VIF), ]
write.csv(vifs, file.path(TABLE_DIR, "vif_selected_predictors.csv"), row.names = FALSE)

# ---- Univariate screening ---------------------------------------------------
numeric_screen <- do.call(rbind, lapply(c("ln_Stream", "ln_Views"), function(y) {
  do.call(rbind, lapply(NUMERIC_CANDIDATES, function(x) screen_numeric(y, x, df)))
}))
categorical_screen <- do.call(rbind, lapply(c("ln_Stream", "ln_Views"), function(y) {
  do.call(rbind, lapply(CATEGORICAL_CANDIDATES, function(x) screen_categorical(y, x, df)))
}))

screening <- rbind(numeric_screen, categorical_screen)
screening <- screening[order(screening$response, -screening$r_squared), ]
write.csv(screening[screening$response == "ln_Stream", ],
          file.path(TABLE_DIR, "univariate_screening_stream.csv"), row.names = FALSE)
write.csv(screening[screening$response == "ln_Views", ],
          file.path(TABLE_DIR, "univariate_screening_views.csv"), row.names = FALSE)
write.csv(screening, file.path(TABLE_DIR, "univariate_screening_all.csv"), row.names = FALSE)

plot_univariate_r2(screening, file.path(FIGURE_DIR, "univariate_r2_top.png"))

# ---- Markdown report --------------------------------------------------------
top_high_cor <- head(cor_pairs, 5)
top_vif <- head(vifs, 8)
top_stream <- head(screening[screening$response == "ln_Stream", ], 6)
top_views <- head(screening[screening$response == "ln_Views", ], 6)

md <- c(
  "# Variable Screening Report",
  "",
  "本報告補充說明變數篩選流程，目的不是取代主模型，而是支持主模型的變數選擇。",
  "",
  "## 1. Data Leakage 檢查",
  "",
  "`Likes` 與 `Comments` 屬於 YouTube engagement outcomes，若用來解釋 `Views` 會造成 data leakage。因此這兩個變數不放入主迴歸模型。",
  "",
  "## 2. Correlation Screening",
  "",
  "數值型候選變數使用 pairwise correlation 檢查共線性。完整矩陣見 `tables_screening/correlation_matrix_numeric_candidates.csv`。",
  "",
  "| Variable 1 | Variable 2 | Correlation |",
  "| --- | --- | ---: |",
  apply(top_high_cor, 1, function(x) {
    sprintf("| `%s` | `%s` | %s |", x[["variable_1"]], x[["variable_2"]],
            fmt(as.numeric(x[["correlation"]]), 3))
  }),
  "",
  "若絕對相關係數超過 0.7，代表兩個變數可能提供相近資訊。這也是主模型沒有同時強調所有高度相近特徵的原因。",
  "",
  "## 3. VIF Screening",
  "",
  "VIF 用來檢查主模型選定 predictors 的 multicollinearity。完整結果見 `tables_screening/vif_selected_predictors.csv`。",
  "",
  "| Term | VIF |",
  "| --- | ---: |",
  apply(top_vif, 1, function(x) {
    sprintf("| `%s` | %s |", x[["term"]], fmt(as.numeric(x[["VIF"]]), 2))
  }),
  "",
  "VIF 越高代表該變數和其他 predictors 越容易重疊。一般而言，VIF 超過 5 需要注意，超過 10 代表嚴重共線性。",
  "",
  "## 4. Univariate Screening",
  "",
  "Univariate screening 用來初步理解每個變數單獨和 `ln_Stream` / `ln_Views` 的關係。這不是最終推論，最終結論仍以 multivariable nested models 為準。",
  "",
  "### Top predictors for `ln_Stream`",
  "",
  "| Predictor | Type | R-squared | p-value |",
  "| --- | --- | ---: | ---: |",
  apply(top_stream, 1, function(x) {
    sprintf("| `%s` | %s | %s | %s |", x[["predictor"]], x[["predictor_type"]],
            fmt(as.numeric(x[["r_squared"]]), 4), fmt_p(as.numeric(x[["p_value"]])))
  }),
  "",
  "### Top predictors for `ln_Views`",
  "",
  "| Predictor | Type | R-squared | p-value |",
  "| --- | --- | ---: | ---: |",
  apply(top_views, 1, function(x) {
    sprintf("| `%s` | %s | %s | %s |", x[["predictor"]], x[["predictor_type"]],
            fmt(as.numeric(x[["r_squared"]]), 4), fmt_p(as.numeric(x[["p_value"]])))
  }),
  "",
  "## 5. 建議",
  "",
  "主模型仍應採用 block-based nested models，因為它符合 proposal 的分析故事，也比逐步挑變數更容易解釋。",
  "VIF 與 univariate screening 適合放在變數選擇的補充說明，證明模型變數不是任意挑選。",
  "",
  "輸出檔案：",
  "",
  "- `tables_screening/missing_zero_summary.csv`",
  "- `tables_screening/excluded_leakage_variables.csv`",
  "- `tables_screening/correlation_pairs_high.csv`",
  "- `tables_screening/vif_selected_predictors.csv`",
  "- `tables_screening/univariate_screening_stream.csv`",
  "- `tables_screening/univariate_screening_views.csv`",
  "- `figures_screening/correlation_heatmap.png`",
  "- `figures_screening/univariate_r2_top.png`"
)

writeLines(md, REPORT_FILE, useBytes = TRUE)

cat(sprintf("Done. Screening tables saved to %s/ and figures saved to %s/.\n",
            TABLE_DIR, FIGURE_DIR))
cat(sprintf("Summary report written to %s.\n", REPORT_FILE))
