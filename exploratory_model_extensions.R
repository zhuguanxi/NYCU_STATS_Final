# =============================================================================
# Exploratory model extensions
# -----------------------------------------------------------------------------
# This script is intentionally separate from modeling_diagnostics.R.
# It checks whether reasonable extensions improve model fit without changing the
# proposal-aligned main analysis.
# =============================================================================

INPUT_FILE <- file.path("dataset", "Spotify_Youtube.csv")
TABLE_DIR <- "tables_exploratory"
FIGURE_DIR <- "figures_exploratory"
REPORT_FILE <- "Exploratory_Model_Extensions.md"

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

model_summary <- function(model, response, model_id, description) {
  s <- summary(model)
  data.frame(
    response = response,
    model_id = model_id,
    description = description,
    n = nobs(model),
    r_squared = s$r.squared,
    adj_r_squared = s$adj.r.squared,
    AIC = AIC(model),
    BIC = BIC(model)
  )
}

coef_table <- function(model, response, model_id) {
  out <- as.data.frame(summary(model)$coefficients)
  out$term <- rownames(out)
  rownames(out) <- NULL
  out <- out[, c("term", "Estimate", "Std. Error", "t value", "Pr(>|t|)")]
  out$exp_beta <- exp(out$Estimate)
  out$response <- response
  out$model_id <- model_id
  out[, c("response", "model_id", "term", "Estimate", "Std. Error",
          "t value", "Pr(>|t|)", "exp_beta")]
}

anova_row <- function(reduced, full, response, comparison) {
  a <- anova(reduced, full)
  data.frame(
    response = response,
    comparison = comparison,
    df_added = a$Df[2],
    sumsq_added = a$`Sum of Sq`[2],
    F = a$F[2],
    p_value = a$`Pr(>F)`[2]
  )
}

fmt_p <- function(x) {
  ifelse(is.na(x), "NA", ifelse(x < 0.001, "< 0.001", sprintf("%.3f", x)))
}

fmt_num <- function(x, digits = 4) {
  formatC(x, format = "f", digits = digits)
}

plot_metric <- function(summary_table, metric, output_file, title, y_label) {
  png(output_file, width = 1100, height = 700)
  op <- par(mar = c(8, 5, 4, 2))
  stream_vals <- summary_table[summary_table$response == "ln_Stream", metric]
  views_vals <- summary_table[summary_table$response == "ln_Views", metric]
  vals <- rbind(stream_vals, views_vals)
  colnames(vals) <- summary_table$model_id[summary_table$response == "ln_Stream"]
  barplot(vals, beside = TRUE, col = c("#3B6EA8", "#C74732"),
          las = 2, ylab = y_label, main = title)
  legend("topright", legend = c("ln_Stream", "ln_Views"),
         fill = c("#3B6EA8", "#C74732"), bty = "n")
  par(op)
  dev.off()
}

# ---- Variable preparation ---------------------------------------------------
numeric_cols <- c(
  "Danceability", "Energy", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo",
  "Duration_ms", "Stream", "Views"
)
for (col in numeric_cols) {
  df[[col]] <- as.numeric(df[[col]])
}

df$ln_Stream <- log(df$Stream + 1)
df$ln_Views <- log(df$Views + 1)
df$ln_Duration <- log(df$Duration_ms + 1)
df$ln_Youtube_Days <- log(parse_date_to_days(df$Youtube_published_date) + 1)
df$ln_Spotify_Days <- log(parse_date_to_days(df$Spotify_published_date) + 1)
df$official_video <- as_binary_factor(df$official_video, "No_Official_Video", "Official_Video")
df$Licensed <- as_binary_factor(df$Licensed, "Not_Licensed", "Licensed")
df$Album_type <- factor(df$Album_type)

AUDIO <- c(
  "Danceability", "Energy", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo", "ln_Duration"
)
MEDIA <- c("official_video", "Licensed")
POLY <- c("I(Danceability^2)", "I(Energy^2)", "I(ln_Duration^2)")
INTERACTIONS <- c("Danceability:official_video", "official_video:Licensed",
                  "ln_Time:official_video")

make_frame <- function(response, platform_time_col) {
  vars <- c(response, AUDIO, MEDIA, "Album_type", "ln_Youtube_Days", platform_time_col)
  d <- df[complete.cases(df[, vars]), vars]
  d$ln_Time <- d[[platform_time_col]]
  d
}

dS_platform_time <- make_frame("ln_Stream", "ln_Spotify_Days")
dV_platform_time <- make_frame("ln_Views", "ln_Youtube_Days")

rhs <- function(terms) paste(terms, collapse = " + ")
form <- function(response, terms) as.formula(paste(response, "~", rhs(terms)))

fit_set <- function(response, d_current, d_platform) {
  current_terms <- c(AUDIO, "ln_Youtube_Days", MEDIA)
  platform_terms <- c(AUDIO, "ln_Time", MEDIA)
  album_terms <- c(platform_terms, "Album_type")
  poly_terms <- c(album_terms, POLY)
  interaction_terms <- c(poly_terms, INTERACTIONS)

  list(
    E0_current_full = lm(form(response, current_terms), data = d_current),
    E1_platform_time = lm(form(response, platform_terms), data = d_platform),
    E2_album_type = lm(form(response, album_terms), data = d_platform),
    E3_polynomial = lm(form(response, poly_terms), data = d_platform),
    E4_interactions = lm(form(response, interaction_terms), data = d_platform)
  )
}

# Use the same complete-case sample for all Stream exploratory models, so AIC/BIC
# comparisons are valid even when comparing YouTube-time and Spotify-time models.
models_S <- fit_set("ln_Stream", dS_platform_time, dS_platform_time)
models_V <- fit_set("ln_Views", dV_platform_time, dV_platform_time)

descriptions <- c(
  E0_current_full = "Current full model using YouTube time",
  E1_platform_time = "Use platform-specific time variable",
  E2_album_type = "Add Album_type",
  E3_polynomial = "Add squared terms for Danceability, Energy, ln_Duration",
  E4_interactions = "Add selected interactions"
)

summary_table <- do.call(rbind, c(
  Map(function(model, id) model_summary(model, "ln_Stream", id, descriptions[[id]]),
      models_S, names(models_S)),
  Map(function(model, id) model_summary(model, "ln_Views", id, descriptions[[id]]),
      models_V, names(models_V))
))
rownames(summary_table) <- NULL
write.csv(summary_table, file.path(TABLE_DIR, "model_extension_comparison.csv"), row.names = FALSE)

extension_tests <- rbind(
  anova_row(models_S$E1_platform_time, models_S$E2_album_type, "ln_Stream", "E1 vs E2: add Album_type"),
  anova_row(models_S$E2_album_type, models_S$E3_polynomial, "ln_Stream", "E2 vs E3: add polynomial terms"),
  anova_row(models_S$E3_polynomial, models_S$E4_interactions, "ln_Stream", "E3 vs E4: add selected interactions"),
  anova_row(models_V$E1_platform_time, models_V$E2_album_type, "ln_Views", "E1 vs E2: add Album_type"),
  anova_row(models_V$E2_album_type, models_V$E3_polynomial, "ln_Views", "E2 vs E3: add polynomial terms"),
  anova_row(models_V$E3_polynomial, models_V$E4_interactions, "ln_Views", "E3 vs E4: add selected interactions")
)
write.csv(extension_tests, file.path(TABLE_DIR, "partial_f_extension_tests.csv"), row.names = FALSE)

all_coefs <- rbind(
  coef_table(models_S$E4_interactions, "ln_Stream", "E4_interactions"),
  coef_table(models_V$E4_interactions, "ln_Views", "E4_interactions")
)
write.csv(all_coefs, file.path(TABLE_DIR, "coefs_exploratory_interactions.csv"), row.names = FALSE)

best_by_aic <- do.call(rbind, lapply(split(summary_table, summary_table$response), function(x) {
  x[which.min(x$AIC), ]
}))
best_by_bic <- do.call(rbind, lapply(split(summary_table, summary_table$response), function(x) {
  x[which.min(x$BIC), ]
}))
write.csv(best_by_aic, file.path(TABLE_DIR, "best_models_by_aic.csv"), row.names = FALSE)
write.csv(best_by_bic, file.path(TABLE_DIR, "best_models_by_bic.csv"), row.names = FALSE)

plot_metric(summary_table, "adj_r_squared",
            file.path(FIGURE_DIR, "adj_r_squared_extension_comparison.png"),
            "Exploratory Model Comparison: Adjusted R-squared",
            "Adjusted R-squared")
plot_metric(summary_table, "AIC",
            file.path(FIGURE_DIR, "aic_extension_comparison.png"),
            "Exploratory Model Comparison: AIC",
            "AIC")
plot_metric(summary_table, "BIC",
            file.path(FIGURE_DIR, "bic_extension_comparison.png"),
            "Exploratory Model Comparison: BIC",
            "BIC")

# ---- Markdown summary -------------------------------------------------------
stream_rows <- summary_table[summary_table$response == "ln_Stream", ]
views_rows <- summary_table[summary_table$response == "ln_Views", ]

md <- c(
  "# Exploratory Model Extensions",
  "",
  "本補充分析不取代 proposal 主線模型，而是檢查幾個合理延伸是否改善模型表現。",
  "",
  "## 模型設定",
  "",
  "- `E0_current_full`: 目前主線 full model，時間變數使用 YouTube 發布日期。",
  "- `E1_platform_time`: 平台各自時間，Stream 使用 Spotify 發布日期，Views 使用 YouTube 發布日期。",
  "- `E2_album_type`: 在 E1 上加入 `Album_type`。",
  "- `E3_polynomial`: 在 E2 上加入 `Danceability^2`, `Energy^2`, `ln_Duration^2`。",
  "- `E4_interactions`: 在 E3 上加入 `Danceability:official_video`, `official_video:Licensed`, `ln_Time:official_video`。",
  "",
  "所有模型都在同一個 response-specific complete-case 樣本上比較，因此同一個 response 內的 AIC/BIC 可以直接比較。",
  "",
  "## 主要結果",
  "",
  sprintf("- Stream 最低 AIC 模型：`%s`，Adjusted R-squared = %s，AIC = %s。",
          best_by_aic[best_by_aic$response == "ln_Stream", "model_id"],
          fmt_num(best_by_aic[best_by_aic$response == "ln_Stream", "adj_r_squared"]),
          fmt_num(best_by_aic[best_by_aic$response == "ln_Stream", "AIC"], 1)),
  sprintf("- Views 最低 AIC 模型：`%s`，Adjusted R-squared = %s，AIC = %s。",
          best_by_aic[best_by_aic$response == "ln_Views", "model_id"],
          fmt_num(best_by_aic[best_by_aic$response == "ln_Views", "adj_r_squared"]),
          fmt_num(best_by_aic[best_by_aic$response == "ln_Views", "AIC"], 1)),
  sprintf("- Stream 最低 BIC 模型：`%s`；Views 最低 BIC 模型：`%s`。",
          best_by_bic[best_by_bic$response == "ln_Stream", "model_id"],
          best_by_bic[best_by_bic$response == "ln_Views", "model_id"]),
  "",
  "## 建議解讀",
  "",
  "如果延伸模型只帶來很小的 adjusted R-squared 改善，但 AIC/BIC 沒有同步支持，主報告仍應保留較簡潔、符合 proposal 的主線模型。",
  "若平台各自時間或 `Album_type` 明顯改善模型，則可以在簡報中作為 robustness check 或 future work 提及。",
  "",
  "完整結果見：",
  "",
  "- `tables_exploratory/model_extension_comparison.csv`",
  "- `tables_exploratory/partial_f_extension_tests.csv`",
  "- `tables_exploratory/coefs_exploratory_interactions.csv`",
  "- `figures_exploratory/adj_r_squared_extension_comparison.png`",
  "- `figures_exploratory/aic_extension_comparison.png`",
  "- `figures_exploratory/bic_extension_comparison.png`"
)

writeLines(md, REPORT_FILE, useBytes = TRUE)

cat(sprintf("Done. Exploratory tables saved to %s/ and figures saved to %s/.\n",
            TABLE_DIR, FIGURE_DIR))
cat(sprintf("Summary report written to %s.\n", REPORT_FILE))
