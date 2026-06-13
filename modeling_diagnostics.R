# =============================================================================
# Member 4 & 5: Nested Regression Models and Model Diagnostics
# =============================================================================

# ---- Setup ------------------------------------------------------------------
INPUT_FILE <- file.path("dataset", "Spotify_Youtube.csv")
FIGURE_DIR <- "figures_model"
TABLE_DIR <- "tables_model"

dir.create(FIGURE_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)

df <- read.csv(INPUT_FILE, fileEncoding = "UTF-8-BOM", check.names = TRUE)
cat(sprintf("Loaded %d rows and %d columns from %s\n", nrow(df), ncol(df), INPUT_FILE))

# ---- Helpers ----------------------------------------------------------------
first_existing_col <- function(data, candidates) {
  names_lower <- tolower(names(data))
  idx <- which(names_lower %in% tolower(candidates))
  if (length(idx) == 0) {
    return(NA_character_)
  }
  names(data)[idx[1]]
}

as_binary_factor <- function(x, false_label, true_label) {
  x_chr <- trimws(tolower(as.character(x)))
  out <- ifelse(x_chr %in% c("true", "t", "1", "yes", "y"), 1,
                ifelse(x_chr %in% c("false", "f", "0", "no", "n"), 0, NA))
  factor(out, levels = c(0, 1), labels = c(false_label, true_label))
}

coef_table <- function(model) {
  out <- as.data.frame(summary(model)$coefficients)
  out$term <- rownames(out)
  rownames(out) <- NULL
  out <- out[, c("term", "Estimate", "Std. Error", "t value", "Pr(>|t|)")]
  out$exp_beta <- exp(out$Estimate)
  out
}

model_summary <- function(model, model_name, response) {
  s <- summary(model)
  data.frame(
    response = response,
    model = model_name,
    n = nobs(model),
    r_squared = s$r.squared,
    adj_r_squared = s$adj.r.squared,
    AIC = AIC(model),
    BIC = BIC(model)
  )
}

cook_table <- function(model) {
  cooks <- cooks.distance(model)
  lev <- hatvalues(model)
  stud <- rstudent(model)
  out <- data.frame(
    row_id = as.integer(names(cooks)),
    cooks_distance = as.numeric(cooks),
    leverage = as.numeric(lev),
    studentized_residual = as.numeric(stud)
  )
  out[order(-out$cooks_distance), ]
}

prediction_grid <- function(data, model, response_label) {
  dance_grid <- seq(min(data$Danceability, na.rm = TRUE),
                    max(data$Danceability, na.rm = TRUE),
                    length.out = 100)

  ref_license <- levels(data$Licensed)[1]
  pred_data <- data.frame(
    Danceability = rep(dance_grid, 2),
    Energy = mean(data$Energy, na.rm = TRUE),
    Speechiness = mean(data$Speechiness, na.rm = TRUE),
    Acousticness = mean(data$Acousticness, na.rm = TRUE),
    Instrumentalness = mean(data$Instrumentalness, na.rm = TRUE),
    Liveness = mean(data$Liveness, na.rm = TRUE),
    Valence = mean(data$Valence, na.rm = TRUE),
    Tempo = mean(data$Tempo, na.rm = TRUE),
    ln_Duration = mean(data$ln_Duration, na.rm = TRUE),
    ln_Days = mean(data$ln_Days, na.rm = TRUE),
    official_video = factor(rep(levels(data$official_video), each = length(dance_grid)),
                            levels = levels(data$official_video)),
    Licensed = factor(ref_license, levels = levels(data$Licensed))
  )
  pred_data$predicted <- predict(model, newdata = pred_data)
  pred_data$response <- response_label
  pred_data
}

plot_interaction <- function(pred_data, output_file, y_label, title) {
  png(output_file, width = 1100, height = 750)
  op <- par(mar = c(5, 5, 4, 2))
  groups <- levels(pred_data$official_video)
  cols <- c("#3B6EA8", "#C74732")
  ltys <- c(2, 1)
  y_range <- range(pred_data$predicted, na.rm = TRUE)

  first_group <- pred_data[pred_data$official_video == groups[1], ]
  plot(first_group$Danceability, first_group$predicted, type = "l",
       col = cols[1], lwd = 3, lty = ltys[1], ylim = y_range,
       xlab = "Danceability", ylab = y_label, main = title)

  for (i in seq_along(groups)[-1]) {
    g <- pred_data[pred_data$official_video == groups[i], ]
    lines(g$Danceability, g$predicted, col = cols[i], lwd = 3, lty = ltys[i])
  }

  legend("topleft", legend = groups, col = cols[seq_along(groups)],
         lwd = 3, lty = ltys[seq_along(groups)], bty = "n")
  par(op)
  dev.off()
}

# ---- Variable preparation ---------------------------------------------------
required_numeric <- c(
  "Danceability", "Energy", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo",
  "Duration_ms", "Stream", "Views"
)

missing_required <- setdiff(required_numeric, names(df))
if (length(missing_required) > 0) {
  stop(sprintf("Missing required columns: %s", paste(missing_required, collapse = ", ")))
}

for (col in required_numeric) {
  df[[col]] <- as.numeric(df[[col]])
}

# ---- Time control variable --------------------------------------------------
names_lower <- tolower(names(df))
day_candidates <- c(
  "days_since_release", "days_since_youtubepublish",
  "days_since_publish", "days_since_published"
)
day_col_idx <- which(names_lower %in% day_candidates)

if (length(day_col_idx) > 0) {
  day_col <- names(df)[day_col_idx[1]]
  df$Days_Since_Release <- as.numeric(df[[day_col]])
  time_source <- day_col
} else {
  date_candidates <- c(
    "publishat", "publishedat", "publish_date", "published_date",
    "youtube_publishat", "youtube_published_at", "youtube_published_date",
    "spotify_published_date"
  )
  date_col <- first_existing_col(df, date_candidates)

  if (is.na(date_col)) {
    stop("No time variable found. Expected Days_Since_Release or publishAt-like column.")
  }

  publish_time <- as.POSIXct(df[[date_col]], format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  if (all(is.na(publish_time))) {
    publish_date <- as.Date(df[[date_col]], format = "%Y-%m-%d")
    publish_time <- as.POSIXct(publish_date, tz = "UTC")
  }

  reference_time <- Sys.time()
  df$Days_Since_Release <- as.numeric(difftime(reference_time, publish_time, units = "days"))
  time_source <- date_col
}

df$Days_Since_Release[df$Days_Since_Release < 0] <- NA
df$ln_Days <- log(df$Days_Since_Release + 1)

# ---- Response and model variables ------------------------------------------
df$ln_Stream <- log(df$Stream + 1)
df$ln_Views <- log(df$Views + 1)
df$ln_Duration <- log(df$Duration_ms + 1)

df$official_video <- as_binary_factor(df$official_video, "No_Official_Video", "Official_Video")
df$Licensed <- as_binary_factor(df$Licensed, "Not_Licensed", "Licensed")

AUDIO <- c(
  "Danceability", "Energy", "Speechiness", "Acousticness",
  "Instrumentalness", "Liveness", "Valence", "Tempo", "ln_Duration"
)
CONTROL <- c("ln_Days")
MEDIA <- c("official_video", "Licensed")

vars_stream <- c("ln_Stream", AUDIO, CONTROL, MEDIA)
vars_views <- c("ln_Views", AUDIO, CONTROL, MEDIA)

dS <- df[complete.cases(df[, vars_stream]), vars_stream]
dV <- df[complete.cases(df[, vars_views]), vars_views]

cat(sprintf("Time source: %s\n", time_source))
cat(sprintf("Model rows: ln_Stream = %d, ln_Views = %d\n", nrow(dS), nrow(dV)))

# ---- Nested formulas --------------------------------------------------------
audio_rhs <- paste(AUDIO, collapse = " + ")
time_rhs <- paste(c(AUDIO, CONTROL), collapse = " + ")
full_rhs <- paste(c(AUDIO, CONTROL, MEDIA), collapse = " + ")

f_audio <- function(y) as.formula(paste(y, "~", audio_rhs))
f_time <- function(y) as.formula(paste(y, "~", time_rhs))
f_full <- function(y) as.formula(paste(y, "~", full_rhs))
f_inter <- function(y) as.formula(paste(y, "~", full_rhs, "+ Danceability:official_video"))

# ---- Fit models -------------------------------------------------------------
m_audio_S <- lm(f_audio("ln_Stream"), data = dS)
m_time_S <- lm(f_time("ln_Stream"), data = dS)
m_full_S <- lm(f_full("ln_Stream"), data = dS)
m_inter_S <- lm(f_inter("ln_Stream"), data = dS)

m_audio_V <- lm(f_audio("ln_Views"), data = dV)
m_time_V <- lm(f_time("ln_Views"), data = dV)
m_full_V <- lm(f_full("ln_Views"), data = dV)
m_inter_V <- lm(f_inter("ln_Views"), data = dV)

# ---- Partial F-tests --------------------------------------------------------
anova_time_S <- anova(m_audio_S, m_time_S)
anova_media_S <- anova(m_time_S, m_full_S)
anova_inter_S <- anova(m_full_S, m_inter_S)

anova_time_V <- anova(m_audio_V, m_time_V)
anova_media_V <- anova(m_time_V, m_full_V)
anova_inter_V <- anova(m_full_V, m_inter_V)

write.csv(anova_time_S, file.path(TABLE_DIR, "anova_stream_time.csv"))
write.csv(anova_media_S, file.path(TABLE_DIR, "anova_stream_media.csv"))
write.csv(anova_inter_S, file.path(TABLE_DIR, "anova_stream_interaction.csv"))

write.csv(anova_time_V, file.path(TABLE_DIR, "anova_views_time.csv"))
write.csv(anova_media_V, file.path(TABLE_DIR, "anova_views_media.csv"))
write.csv(anova_inter_V, file.path(TABLE_DIR, "anova_views_interaction.csv"))

# ---- Coefficient and model summary tables ----------------------------------
write.csv(coef_table(m_full_S), file.path(TABLE_DIR, "coefs_full_stream.csv"), row.names = FALSE)
write.csv(coef_table(m_inter_S), file.path(TABLE_DIR, "coefs_interaction_stream.csv"), row.names = FALSE)
write.csv(coef_table(m_full_V), file.path(TABLE_DIR, "coefs_full_views.csv"), row.names = FALSE)
write.csv(coef_table(m_inter_V), file.path(TABLE_DIR, "coefs_interaction_views.csv"), row.names = FALSE)

summary_table <- rbind(
  model_summary(m_audio_S, "M0 Audio only", "ln_Stream"),
  model_summary(m_time_S, "M1 Audio + Time", "ln_Stream"),
  model_summary(m_full_S, "M2 Audio + Time + Media", "ln_Stream"),
  model_summary(m_inter_S, "M3 Interaction", "ln_Stream"),
  model_summary(m_audio_V, "M0 Audio only", "ln_Views"),
  model_summary(m_time_V, "M1 Audio + Time", "ln_Views"),
  model_summary(m_full_V, "M2 Audio + Time + Media", "ln_Views"),
  model_summary(m_inter_V, "M3 Interaction", "ln_Views")
)
write.csv(summary_table, file.path(TABLE_DIR, "model_summary_comparison.csv"), row.names = FALSE)

# ---- Diagnostics ------------------------------------------------------------
png(file.path(FIGURE_DIR, "diagnostics_full_stream.png"), width = 1200, height = 900)
par(mfrow = c(2, 2))
plot(m_full_S)
dev.off()

png(file.path(FIGURE_DIR, "diagnostics_full_views.png"), width = 1200, height = 900)
par(mfrow = c(2, 2))
plot(m_full_V)
dev.off()

cook_S <- cook_table(m_full_S)
cook_V <- cook_table(m_full_V)

write.csv(head(cook_S, 20), file.path(TABLE_DIR, "top20_cooks_stream.csv"), row.names = FALSE)
write.csv(head(cook_V, 20), file.path(TABLE_DIR, "top20_cooks_views.csv"), row.names = FALSE)

png(file.path(FIGURE_DIR, "cooks_distance_stream.png"), width = 1000, height = 700)
plot(cooks.distance(m_full_S), type = "h", main = "Cook's Distance: Stream Full Model",
     xlab = "Observation index", ylab = "Cook's distance")
abline(h = 4 / nobs(m_full_S), lty = 2, col = "#C74732")
dev.off()

png(file.path(FIGURE_DIR, "cooks_distance_views.png"), width = 1000, height = 700)
plot(cooks.distance(m_full_V), type = "h", main = "Cook's Distance: Views Full Model",
     xlab = "Observation index", ylab = "Cook's distance")
abline(h = 4 / nobs(m_full_V), lty = 2, col = "#C74732")
dev.off()

# ---- Interaction plots ------------------------------------------------------
pred_stream <- prediction_grid(dS, m_inter_S, "ln_Stream")
pred_views <- prediction_grid(dV, m_inter_V, "ln_Views")

plot_interaction(
  pred_stream,
  file.path(FIGURE_DIR, "interaction_stream_danceability_official_video.png"),
  "Predicted ln(Stream)",
  "Danceability by Official Video Status: Stream"
)

plot_interaction(
  pred_views,
  file.path(FIGURE_DIR, "interaction_views_danceability_official_video.png"),
  "Predicted ln(Views)",
  "Danceability by Official Video Status: Views"
)

cat(sprintf("Done. Tables saved to %s/ and figures saved to %s/.\n", TABLE_DIR, FIGURE_DIR))
