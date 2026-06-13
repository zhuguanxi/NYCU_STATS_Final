# =============================================================================
# Member 4 & 5: Multiple Regression, Hypothesis Testing & Model Diagnostics
# -----------------------------------------------------------------------------
# Member 4 (Core Modeler):
#   1. Multiple linear regression (ln_Stream / ln_Views ~ audio + media)
#   2. Dummy-variable handling (official_video, Licensed) with explicit baseline
#   3. Partial F-test  : anova(reduced, full)  -> extra explanatory power of media
#   4. Interaction     : Danceability * official_video  (+ interaction plot)
#
# Member 5 (Diagnostician & Storyteller):
#   5. Residual analysis  : Residual-vs-Fitted, Normal Q-Q, Scale-Location
#   6. Outliers vs influential points : studentized resid, leverage, Cook's D
#   7. Refit without influential points -> coefficient-stability check
#   8. Adjusted R^2 + back-transformed (exp) business interpretation table
#
# BASE R only (lm/anova/cooks.distance are in stats). Figures -> figures_model/.
# A machine-readable summary is printed to stdout.
# =============================================================================

# ---- Setup ------------------------------------------------------------------
INPUT_FILE <- "Spotify_Youtube_Clean.csv"
OUTPUT_DIR <- "figures_model"
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR)

df <- read.csv(INPUT_FILE, fileEncoding = "UTF-8-BOM", check.names = TRUE)
cat(sprintf("Loaded %d rows, %d columns from %s\n\n", nrow(df), ncol(df), INPUT_FILE))

# ---- Variable preparation ---------------------------------------------------
# Member 3 (Plan A, recommended): drop Loudness (r=0.74 with Energy), log Duration.
# Member 2: exclude Stream/Views == 0 before modelling so the log left-tail spike
#           does not distort the response.
df$ln_Duration <- log(df$Duration_ms)

# Categorical -> factors with an EXPLICIT baseline (the "0 / no" group).
# official_video: 0 = no official MV (baseline), 1 = has official MV
# Licensed      : 0 = not licensed (baseline), 1 = licensed
df$official_video <- factor(df$official_video, levels = c(0, 1),
                            labels = c("No_MV", "Has_MV"))
df$Licensed       <- factor(df$Licensed,       levels = c(0, 1),
                            labels = c("Not_Licensed", "Licensed"))

AUDIO <- c("Danceability", "Energy", "Speechiness", "Acousticness",
           "Instrumentalness", "Liveness", "Valence", "Tempo", "ln_Duration")

# Build the two analysis frames (one per response), each excluding Y == 0.
make_frame <- function(yraw) {
  keep <- is.finite(df[[yraw]]) & df[[yraw]] > 0
  d <- df[keep, c(AUDIO, "official_video", "Licensed",
                  "Stream", "Views", "ln_Stream", "ln_Views")]
  d <- d[complete.cases(d[, c(AUDIO, "official_video", "Licensed")]), ]
  d
}
dS <- make_frame("Stream")   # for ln_Stream model (Spotify)
dV <- make_frame("Views")    # for ln_Views  model (YouTube)
cat(sprintf("Modelling n: ln_Stream = %d (excluded %d zeros) | ln_Views = %d (excluded %d zeros)\n\n",
            nrow(dS), sum(df$Stream == 0, na.rm = TRUE),
            nrow(dV), sum(df$Views  == 0, na.rm = TRUE)))

# Helper: build the three nested formulas for a given response.
audio_rhs <- paste(AUDIO, collapse = " + ")
f_reduced <- function(y) as.formula(paste(y, "~", audio_rhs))
f_full    <- function(y) as.formula(paste(y, "~", audio_rhs, "+ official_video + Licensed"))
f_inter   <- function(y) as.formula(paste(y, "~", audio_rhs,
                                          "+ official_video + Licensed + Danceability:official_video"))

# =============================================================================
# MEMBER 4 -- PART A : MULTIPLE LINEAR REGRESSION (primary = ln_Stream)
# =============================================================================
cat("============================================================\n")
cat(" MEMBER 4 / PART A : MULTIPLE LINEAR REGRESSION  (Y = ln_Stream)\n")
cat("============================================================\n")

m_red_S  <- lm(f_reduced("ln_Stream"), data = dS)   # audio only
m_full_S <- lm(f_full("ln_Stream"),    data = dS)   # audio + media (MV, Licensed)
m_int_S  <- lm(f_inter("ln_Stream"),   data = dS)   # + Danceability x official_video

cat("\n--- FULL model summary (ln_Stream) ---\n")
print(summary(m_full_S))

# Save tidy coefficient tables for the report.
save_coefs <- function(model, file) {
  s <- summary(model)
  ct <- as.data.frame(s$coefficients)
  ct$Term <- rownames(ct); rownames(ct) <- NULL
  ct <- ct[, c("Term", "Estimate", "Std. Error", "t value", "Pr(>|t|)")]
  names(ct) <- c("Term", "Estimate", "Std_Error", "t_value", "p_value")
  write.csv(ct, file.path(OUTPUT_DIR, file), row.names = FALSE)
  ct
}
ct_full_S <- save_coefs(m_full_S, "coefs_full_stream.csv")
ct_int_S  <- save_coefs(m_int_S,  "coefs_interaction_stream.csv")

cat(sprintf("\nR^2 (reduced)=%.4f  Adj-R^2=%.4f\n",
            summary(m_red_S)$r.squared,  summary(m_red_S)$adj.r.squared))
cat(sprintf("R^2 (full)   =%.4f  Adj-R^2=%.4f\n",
            summary(m_full_S)$r.squared, summary(m_full_S)$adj.r.squared))
cat(sprintf("R^2 (interac)=%.4f  Adj-R^2=%.4f\n",
            summary(m_int_S)$r.squared,  summary(m_int_S)$adj.r.squared))

# =============================================================================
# MEMBER 4 -- PART B : PARTIAL F-TEST (nested models)
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 4 / PART B : PARTIAL F-TEST  anova(reduced, full)\n")
cat("============================================================\n")
cat(" H0: beta(official_video) = beta(Licensed) = 0   (media adds nothing)\n")
cat(" H1: at least one media coefficient != 0\n\n")
pf_S <- anova(m_red_S, m_full_S)
print(pf_S)

# also test whether the interaction term adds power on top of the full model
cat("\n--- Does the Danceability x official_video interaction add power? ---\n")
pf_int_S <- anova(m_full_S, m_int_S)
print(pf_int_S)

# =============================================================================
# MEMBER 4 -- PART C : INTERACTION EFFECT + INTERACTION PLOT
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 4 / PART C : INTERACTION  Danceability x official_video\n")
cat("============================================================\n")
int_row <- ct_int_S[grepl("Danceability:official_video", ct_int_S$Term), ]
cat("Interaction coefficient:\n"); print(int_row, row.names = FALSE)

# Figure M1: interaction plot -- predicted ln_Stream vs Danceability, one line per MV group.
# All other predictors held at their mean (numeric) / baseline (Licensed = Not_Licensed).
png(file.path(OUTPUT_DIR, "figM1_interaction_plot.png"), width = 1300, height = 950, res = 130)
op <- par(mar = c(4.5, 4.5, 4, 1))
dance_grid <- seq(min(dS$Danceability), max(dS$Danceability), length.out = 60)
newdat <- function(mv) {
  base <- data.frame(
    Danceability = dance_grid,
    Energy = mean(dS$Energy), Speechiness = mean(dS$Speechiness),
    Acousticness = mean(dS$Acousticness), Instrumentalness = mean(dS$Instrumentalness),
    Liveness = mean(dS$Liveness), Valence = mean(dS$Valence),
    Tempo = mean(dS$Tempo), ln_Duration = mean(dS$ln_Duration),
    official_video = factor(mv, levels = levels(dS$official_video)),
    Licensed = factor("Not_Licensed", levels = levels(dS$Licensed)))
  base
}
p_no <- predict(m_int_S, newdat("No_MV"))
p_yes<- predict(m_int_S, newdat("Has_MV"))
yl <- range(c(p_no, p_yes))
plot(dance_grid, p_yes, type = "l", col = "#D62728", lwd = 3, ylim = yl,
     xlab = "Danceability", ylab = "Predicted ln(Stream)",
     main = "Figure M1: Interaction  Danceability x Official Video")
lines(dance_grid, p_no, col = "#4C72B0", lwd = 3, lty = 2)
legend("topleft", c("Has official MV", "No official MV"),
       col = c("#D62728", "#4C72B0"), lwd = 3, lty = c(1, 2), bty = "n")
par(op); dev.off()
cat("\n[saved] figM1_interaction_plot.png\n")

# =============================================================================
# MEMBER 4 -- PART D : YOUTUBE (Y = ln_Views) -- parallel column for the report
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 4 / PART D : PARALLEL MODEL  (Y = ln_Views, YouTube)\n")
cat("============================================================\n")
m_red_V  <- lm(f_reduced("ln_Views"), data = dV)
m_full_V <- lm(f_full("ln_Views"),    data = dV)
ct_full_V <- save_coefs(m_full_V, "coefs_full_views.csv")
cat(sprintf("R^2 (full, ln_Views)=%.4f  Adj-R^2=%.4f\n",
            summary(m_full_V)$r.squared, summary(m_full_V)$adj.r.squared))
cat("\n--- Partial F-test for ln_Views (media block) ---\n")
print(anova(m_red_V, m_full_V))

# =============================================================================
# MEMBER 5 -- PART E : RESIDUAL DIAGNOSTICS  (on the ln_Stream full model)
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 5 / PART E : RESIDUAL DIAGNOSTICS (ln_Stream full model)\n")
cat("============================================================\n")
fit   <- fitted(m_full_S)
resid <- residuals(m_full_S)
rstud <- rstudent(m_full_S)         # externally studentized residuals
shap_n <- min(5000, length(resid))  # shapiro.test caps at 5000
set.seed(42)
shap <- shapiro.test(sample(resid, shap_n))
cat(sprintf("Shapiro-Wilk on %d sampled residuals: W=%.4f, p=%.3g\n",
            shap_n, shap$statistic, shap$p.value))
cat(sprintf("Residual skewness=%.3f  (0 = symmetric)\n",
            (sum((resid - mean(resid))^3) / length(resid)) / sd(resid)^3))

# Figure M2: the classic 2x2 diagnostic panel (base R plot.lm).
png(file.path(OUTPUT_DIR, "figM2_diagnostics.png"), width = 1500, height = 1300, res = 130)
op <- par(mfrow = c(2, 2), mar = c(4.3, 4.3, 3, 1))
plot(m_full_S, which = 1)   # Residuals vs Fitted (homoscedasticity)
plot(m_full_S, which = 2)   # Normal Q-Q (normality)
plot(m_full_S, which = 3)   # Scale-Location (variance trend)
plot(m_full_S, which = 5)   # Residuals vs Leverage (+ Cook contours)
par(op); dev.off()
cat("[saved] figM2_diagnostics.png\n")

# =============================================================================
# MEMBER 5 -- PART F : OUTLIERS vs INFLUENTIAL OBSERVATIONS
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 5 / PART F : OUTLIERS vs INFLUENTIAL POINTS\n")
cat("============================================================\n")
n   <- nrow(dS)
p   <- length(coef(m_full_S))
cookd <- cooks.distance(m_full_S)
lev   <- hatvalues(m_full_S)
cook_cut <- 4 / n                  # common 4/n screening rule
lev_cut  <- 2 * p / n              # high-leverage rule of thumb
out_cut  <- 3                      # |studentized resid| > 3 => outlier in Y

n_outlier   <- sum(abs(rstud) > out_cut)
n_highlev   <- sum(lev > lev_cut)
n_influential <- sum(cookd > cook_cut)
cat(sprintf("Outliers (|rstudent|>3)        : %d (%.2f%%)\n", n_outlier, 100*n_outlier/n))
cat(sprintf("High leverage (h>2p/n=%.4f)    : %d (%.2f%%)\n", lev_cut, n_highlev, 100*n_highlev/n))
cat(sprintf("Influential (Cook's D>4/n=%.5f): %d (%.2f%%)\n", cook_cut, n_influential, 100*n_influential/n))

# Top-10 most influential tracks (by Cook's D), with their key attributes.
ord <- order(-cookd)[1:10]
top_infl <- data.frame(
  Row          = ord,
  CooksD       = round(cookd[ord], 4),
  Leverage     = round(lev[ord], 4),
  Std_Resid    = round(rstud[ord], 3),
  ln_Stream    = round(dS$ln_Stream[ord], 3),
  Fitted       = round(fit[ord], 3),
  official_video = as.character(dS$official_video[ord]),
  Danceability = round(dS$Danceability[ord], 3))
cat("\n--- Top 10 influential observations (by Cook's distance) ---\n")
print(top_infl, row.names = FALSE)
write.csv(top_infl, file.path(OUTPUT_DIR, "top_influential.csv"), row.names = FALSE)

# Figure M3: Cook's distance stem plot.
png(file.path(OUTPUT_DIR, "figM3_cooks_distance.png"), width = 1500, height = 750, res = 130)
op <- par(mar = c(4.5, 4.5, 3, 1))
plot(cookd, type = "h", col = "#4C72B0",
     xlab = "Observation index", ylab = "Cook's distance",
     main = "Figure M3: Cook's Distance (ln_Stream full model)")
abline(h = cook_cut, col = "#D62728", lty = 2)
text(n * 0.02, cook_cut, sprintf("4/n = %.4g", cook_cut), col = "#D62728",
     pos = 3, cex = 0.8)
points(ord, cookd[ord], col = "#D62728", pch = 1, cex = 1.4)
par(op); dev.off()
cat("[saved] figM3_cooks_distance.png\n")

# =============================================================================
# MEMBER 5 -- PART G : REFIT WITHOUT INFLUENTIAL POINTS (stability check)
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 5 / PART G : COEFFICIENT STABILITY (drop Cook's D > 4/n)\n")
cat("============================================================\n")
keep_idx <- cookd <= cook_cut
m_full_S_clean <- lm(f_full("ln_Stream"), data = dS[keep_idx, ])

comp <- data.frame(
  Term       = names(coef(m_full_S)),
  Full       = round(coef(m_full_S), 4),
  Refit      = round(coef(m_full_S_clean), 4),
  row.names  = NULL)
comp$Pct_Change <- round(100 * (comp$Refit - comp$Full) / abs(comp$Full), 1)
# significance flips
p_full  <- summary(m_full_S)$coefficients[, 4]
p_clean <- summary(m_full_S_clean)$coefficients[, 4]
comp$Sig_Full  <- ifelse(p_full  < 0.05, "*", "")
comp$Sig_Refit <- ifelse(p_clean < 0.05, "*", "")
print(comp, row.names = FALSE)
write.csv(comp, file.path(OUTPUT_DIR, "coef_stability.csv"), row.names = FALSE)
cat(sprintf("\nDropped %d influential rows (%.2f%%). Adj-R^2: full=%.4f -> refit=%.4f\n",
            sum(!keep_idx), 100*sum(!keep_idx)/n,
            summary(m_full_S)$adj.r.squared, summary(m_full_S_clean)$adj.r.squared))

# =============================================================================
# MEMBER 5 -- PART H : BUSINESS TRANSLATION (back-transform exp(beta))
# =============================================================================
cat("\n============================================================\n")
cat(" MEMBER 5 / PART H : BUSINESS INTERPRETATION  (exp(beta) multipliers)\n")
cat("============================================================\n")
cat(" Because Y = ln(Stream), exp(beta) is the MULTIPLICATIVE effect on Stream\n")
cat(" for a one-unit increase in X (holding all else constant).\n\n")
biz <- ct_full_S
biz$Multiplier <- round(exp(biz$Estimate), 4)
biz$Pct_Effect <- round(100 * (exp(biz$Estimate) - 1), 2)
biz <- biz[, c("Term", "Estimate", "p_value", "Multiplier", "Pct_Effect")]
print(biz, row.names = FALSE)
write.csv(biz, file.path(OUTPUT_DIR, "business_multipliers_stream.csv"), row.names = FALSE)

cat("\n============================================================\n")
cat(" DONE. Figures + CSV summaries saved to ", OUTPUT_DIR, "/\n", sep = "")
cat("============================================================\n")
