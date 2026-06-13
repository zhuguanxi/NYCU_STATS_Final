# =============================================================================
# Member 3: EDA & Feature Engineering for Audio Features (X variables)
# -----------------------------------------------------------------------------
# Tasks:
#   1. Univariate EDA   -> histograms / boxplots, skewness, outliers, log-transform
#   2. Bivariate EDA    -> scatterplot matrix + Pearson correlation heatmap
#   3. Collinearity     -> high-|r| pairs + VIF (variance inflation factor)
#   4. PCA              -> scree plot, cumulative variance, loadings ("Vibe" index)
#   5. Final feature list
#
# Written in BASE R only (no external packages required).
# Figures are saved to figures_X/ ; a machine-readable summary is printed to stdout.
# =============================================================================

# ---- Setup ------------------------------------------------------------------
INPUT_FILE <- "Spotify_Youtube_Clean.csv"
OUTPUT_DIR <- "figures_X"
if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR)

df <- read.csv(INPUT_FILE, fileEncoding = "UTF-8-BOM", check.names = TRUE)
cat(sprintf("Loaded %d rows, %d columns from %s\n\n", nrow(df), ncol(df), INPUT_FILE))

# Continuous audio features (X) we will analyse.
# Key is excluded from continuous analysis (it is a categorical pitch class 0-11).
feat <- c("Danceability", "Energy", "Loudness", "Speechiness",
          "Acousticness", "Instrumentalness", "Liveness", "Valence",
          "Tempo", "Duration_ms")

X <- df[, feat]
# Drop rows with any missing audio feature so every analysis uses the same n.
X <- X[complete.cases(X), ]
cat(sprintf("Complete-case audio-feature matrix: %d rows x %d features\n\n",
            nrow(X), ncol(X)))

# ---- Helper functions (base R has no skewness/kurtosis) ---------------------
skewness <- function(x) {
  x <- x[is.finite(x)]; n <- length(x); m <- mean(x); s <- sd(x)
  (sum((x - m)^3) / n) / s^3
}
kurtosis_excess <- function(x) {              # excess kurtosis (normal = 0)
  x <- x[is.finite(x)]; n <- length(x); m <- mean(x); s <- sd(x)
  (sum((x - m)^4) / n) / s^4 - 3
}
skew_label <- function(sk) {
  if (sk >  0.5) "Right-skewed (positive)"
  else if (sk < -0.5) "Left-skewed (negative)"
  else "Approx. symmetric"
}
n_outliers <- function(x) {                   # Tukey 1.5*IQR rule
  q <- quantile(x, c(.25, .75), na.rm = TRUE); iqr <- q[2] - q[1]
  lo <- q[1] - 1.5 * iqr; hi <- q[2] + 1.5 * iqr
  sum(x < lo | x > hi, na.rm = TRUE)
}

# =============================================================================
# PART 1 : UNIVARIATE EDA
# =============================================================================
cat("============================================================\n")
cat(" PART 1 : UNIVARIATE SUMMARY (skewness / kurtosis / outliers)\n")
cat("============================================================\n")

uni <- data.frame(
  Feature   = feat,
  Mean      = sapply(X, mean),
  Median    = sapply(X, median),
  SD        = sapply(X, sd),
  Min       = sapply(X, min),
  Max       = sapply(X, max),
  Skewness  = sapply(X, skewness),
  Kurtosis  = sapply(X, kurtosis_excess),
  Outliers  = sapply(X, n_outliers),
  row.names = NULL
)
uni$Shape    <- sapply(uni$Skewness, skew_label)
uni$Outlier_pct <- round(100 * uni$Outliers / nrow(X), 2)

print(format(uni, digits = 3, nsmall = 2), row.names = FALSE)
write.csv(uni, file.path(OUTPUT_DIR, "univariate_summary.csv"), row.names = FALSE)

# ---- Figure X1 : Histograms (with density curve) ----------------------------
png(file.path(OUTPUT_DIR, "figX1_histograms.png"), width = 1600, height = 1100, res = 130)
op <- par(mfrow = c(3, 4), mar = c(4, 4, 3, 1))
for (f in feat) {
  x <- X[[f]]
  hist(x, breaks = 40, col = "#4C72B0", border = "white",
       main = f, xlab = f, freq = FALSE)
  lines(density(x), col = "#D62728", lwd = 2)
  abline(v = mean(x),   col = "black",   lty = 2, lwd = 1.5)
  abline(v = median(x), col = "#E67300", lty = 3, lwd = 1.5)
  sk <- skewness(x)
  legend("topright", legend = sprintf("skew=%.2f", sk), bty = "n", cex = 0.9)
}
par(op); dev.off()
cat("\n[saved] figX1_histograms.png\n")

# ---- Figure X2 : Boxplots (standardized so they share one axis) -------------
png(file.path(OUTPUT_DIR, "figX2_boxplots.png"), width = 1500, height = 900, res = 130)
op <- par(mar = c(9, 4, 3, 1))
Xz <- scale(X)                                   # z-scores for comparable scales
boxplot(as.data.frame(Xz), las = 2, col = "#AEC7E8",
        outcol = "#99999955", outpch = 20, outcex = 0.4,
        main = "Figure X2: Standardized Boxplots of Audio Features (z-scores)",
        ylab = "z-score")
abline(h = 0, col = "#D62728", lty = 2)
par(op); dev.off()
cat("[saved] figX2_boxplots.png\n")

# ---- Figure X3 : Log transform of the worst right-skewed features -----------
# Features with strong positive skew benefit from log; +small constant for zeros.
right_skewed <- uni$Feature[uni$Skewness > 1]
cat(sprintf("\nStrongly right-skewed features (skew > 1): %s\n",
            paste(right_skewed, collapse = ", ")))

if (length(right_skewed) > 0) {
  png(file.path(OUTPUT_DIR, "figX3_log_transform.png"),
      width = 1600, height = 350 * length(right_skewed), res = 130)
  op <- par(mfrow = c(length(right_skewed), 2), mar = c(4, 4, 3, 1))
  for (f in right_skewed) {
    x <- X[[f]]
    hist(x, breaks = 40, col = "#E67E22", border = "white",
         main = sprintf("%s (raw, skew=%.2f)", f, skewness(x)), xlab = f, freq = FALSE)
    lines(density(x), col = "#D62728", lwd = 2)
    xl <- log(x + 0.001 * max(x[x > 0]))         # log with small offset for zeros
    hist(xl, breaks = 40, col = "#27AE60", border = "white",
         main = sprintf("log(%s) (skew=%.2f)", f, skewness(xl)),
         xlab = sprintf("log(%s)", f), freq = FALSE)
    lines(density(xl), col = "#D62728", lwd = 2)
  }
  par(op); dev.off()
  cat("[saved] figX3_log_transform.png\n")
}

# =============================================================================
# PART 2 : BIVARIATE / MULTIVARIATE EDA
# =============================================================================
cat("\n============================================================\n")
cat(" PART 2 : PEARSON CORRELATION MATRIX\n")
cat("============================================================\n")

R <- cor(X, method = "pearson")
print(round(R, 2))
write.csv(round(R, 4), file.path(OUTPUT_DIR, "correlation_matrix.csv"))

# ---- Figure X4 : Scatterplot matrix (random subsample to keep it readable) --
set.seed(42)
sub <- X[sample(nrow(X), min(2000, nrow(X))), ]
png(file.path(OUTPUT_DIR, "figX4_scatterplot_matrix.png"),
    width = 1800, height = 1800, res = 120)
pairs(sub, pch = 20, cex = 0.2, col = "#1F77B450",
      main = "Figure X4: Scatterplot Matrix of Audio Features (n=2000 subsample)",
      gap = 0.2)
dev.off()
cat("\n[saved] figX4_scatterplot_matrix.png\n")

# ---- Figure X5 : Correlation heatmap (built with image() + value labels) ----
png(file.path(OUTPUT_DIR, "figX5_correlation_heatmap.png"),
    width = 1300, height = 1200, res = 130)
op <- par(mar = c(9, 9, 4, 2))
p <- ncol(R)
# blue (neg) - white (0) - red (pos) palette
pal <- colorRampPalette(c("#3B4CC0", "white", "#B40426"))(201)
Rt <- R[, p:1]                                   # flip so diagonal runs corner-to-corner
image(1:p, 1:p, Rt, col = pal, zlim = c(-1, 1), axes = FALSE,
      xlab = "", ylab = "", main = "Figure X5: Pearson Correlation Heatmap")
axis(1, at = 1:p, labels = rownames(R),       las = 2, cex.axis = 0.8)
axis(2, at = 1:p, labels = rev(colnames(R)),  las = 2, cex.axis = 0.8)
for (i in 1:p) for (j in 1:p) {
  val <- Rt[i, j]
  text(i, j, sprintf("%.2f", val), cex = 0.7,
       col = if (abs(val) > 0.5) "white" else "black",
       font = if (abs(val) > 0.5 && i != (p - j + 1)) 2 else 1)
}
par(op); dev.off()
cat("[saved] figX5_correlation_heatmap.png\n")

# ---- High-correlation pairs (|r| > 0.5) -------------------------------------
cat("\n--- Feature pairs with |r| > 0.5 (collinearity warning) ---\n")
hi <- which(abs(R) > 0.5 & upper.tri(R), arr.ind = TRUE)
if (nrow(hi) > 0) {
  hi_df <- data.frame(
    Feat_A = rownames(R)[hi[, 1]],
    Feat_B = colnames(R)[hi[, 2]],
    r      = round(R[hi], 3)
  )
  hi_df <- hi_df[order(-abs(hi_df$r)), ]
  print(hi_df, row.names = FALSE)
  write.csv(hi_df, file.path(OUTPUT_DIR, "high_corr_pairs.csv"), row.names = FALSE)
} else {
  cat("None.\n")
}

# =============================================================================
# PART 3 : COLLINEARITY DIAGNOSTIC -- VIF (computed manually)
# =============================================================================
cat("\n============================================================\n")
cat(" PART 3 : VARIANCE INFLATION FACTOR (VIF)\n")
cat("============================================================\n")
cat(" VIF_j = 1 / (1 - R^2_j), where R^2_j is from regressing feature j\n")
cat(" on all other features.  Rule of thumb: VIF > 5 (or 10) = problematic.\n\n")

vif_vals <- sapply(feat, function(f) {
  others <- setdiff(feat, f)
  fml <- as.formula(paste(f, "~", paste(others, collapse = " + ")))
  r2 <- summary(lm(fml, data = X))$r.squared
  1 / (1 - r2)
})
vif_df <- data.frame(Feature = feat, VIF = round(vif_vals, 3),
                     Flag = ifelse(vif_vals > 5, ">5 (high)",
                             ifelse(vif_vals > 2.5, "2.5-5 (moderate)", "ok")),
                     row.names = NULL)
vif_df <- vif_df[order(-vif_df$VIF), ]
print(vif_df, row.names = FALSE)
write.csv(vif_df, file.path(OUTPUT_DIR, "vif.csv"), row.names = FALSE)

# =============================================================================
# PART 4 : PCA  (correlation matrix -> scale = TRUE)
# =============================================================================
cat("\n============================================================\n")
cat(" PART 4 : PRINCIPAL COMPONENT ANALYSIS (scaled / correlation matrix)\n")
cat("============================================================\n")

pca <- prcomp(X, center = TRUE, scale. = TRUE)
ev   <- pca$sdev^2                         # eigenvalues
prop <- ev / sum(ev)
cum  <- cumsum(prop)

pca_summary <- data.frame(
  PC          = paste0("PC", seq_along(ev)),
  Eigenvalue  = round(ev, 3),
  Prop_Var    = round(prop, 4),
  Cum_Var     = round(cum, 4)
)
print(pca_summary, row.names = FALSE)
write.csv(pca_summary, file.path(OUTPUT_DIR, "pca_variance.csv"), row.names = FALSE)

# Kaiser criterion: keep PCs with eigenvalue > 1
k_kaiser <- sum(ev > 1)
k_80     <- which(cum >= 0.80)[1]
cat(sprintf("\nKaiser rule (eigenvalue > 1): keep %d PCs\n", k_kaiser))
cat(sprintf("80%% cumulative variance reached at: PC%d\n", k_80))

# ---- Loadings (eigenvectors) ------------------------------------------------
cat("\n--- Loadings of first 4 PCs (eigenvectors) ---\n")
load_show <- round(pca$rotation[, 1:min(4, ncol(pca$rotation))], 3)
print(load_show)
write.csv(round(pca$rotation, 4), file.path(OUTPUT_DIR, "pca_loadings.csv"))

# ---- Figure X6 : Scree plot + cumulative variance ---------------------------
png(file.path(OUTPUT_DIR, "figX6_scree.png"), width = 1500, height = 650, res = 130)
op <- par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
plot(ev, type = "b", pch = 19, col = "#4C72B0", lwd = 2,
     xlab = "Principal Component", ylab = "Eigenvalue",
     main = "Figure X6a: Scree Plot")
abline(h = 1, col = "#D62728", lty = 2)
text(length(ev) * 0.7, 1.1, "Kaiser cutoff (eig=1)", col = "#D62728", cex = 0.8)

plot(cum, type = "b", pch = 19, col = "#2CA02C", lwd = 2, ylim = c(0, 1),
     xlab = "Number of Components", ylab = "Cumulative Variance Explained",
     main = "Figure X6b: Cumulative Variance")
abline(h = 0.80, col = "#D62728", lty = 2)
text(length(cum) * 0.5, 0.83, "80% threshold", col = "#D62728", cex = 0.8)
par(op); dev.off()
cat("\n[saved] figX6_scree.png\n")

# ---- Figure X7 : Loadings heatmap for retained PCs --------------------------
kk <- max(k_kaiser, 2)
L <- pca$rotation[, 1:kk, drop = FALSE]
png(file.path(OUTPUT_DIR, "figX7_loadings_heatmap.png"),
    width = 350 + 130 * kk, height = 1100, res = 130)
op <- par(mar = c(4, 10, 4, 2))
pal <- colorRampPalette(c("#3B4CC0", "white", "#B40426"))(201)
Lt <- t(L)[, nrow(L):1]
image(1:kk, 1:nrow(L), Lt, col = pal, zlim = c(-max(abs(L)), max(abs(L))),
      axes = FALSE, xlab = "", ylab = "",
      main = "Figure X7: PCA Loadings (retained PCs)")
axis(1, at = 1:kk, labels = colnames(L), las = 1)
axis(2, at = 1:nrow(L), labels = rev(rownames(L)), las = 2, cex.axis = 0.85)
for (i in 1:kk) for (j in 1:nrow(L)) {
  val <- Lt[i, j]
  text(i, j, sprintf("%.2f", val), cex = 0.75,
       col = if (abs(val) > 0.4) "white" else "black")
}
par(op); dev.off()
cat("[saved] figX7_loadings_heatmap.png\n")

# ---- Figure X8 : PCA biplot (PC1 vs PC2), built manually for speed ----------
# base biplot() renders one text label per observation (18k+) and is unusable
# here, so we draw a subsample of scores as points and overlay loading arrows.
png(file.path(OUTPUT_DIR, "figX8_biplot.png"), width = 1300, height = 1200, res = 130)
op <- par(mar = c(4.5, 4.5, 4, 2))
set.seed(42)
ssub <- sample(nrow(pca$x), min(2000, nrow(pca$x)))
sc <- pca$x[ssub, 1:2]
# robust axis limits (1st-99th pctile) so a few extreme tracks don't squash the cloud
lim1 <- quantile(pca$x[, 1], c(.01, .99)); lim2 <- quantile(pca$x[, 2], c(.01, .99))
rng  <- max(abs(c(lim1, lim2)))
plot(sc, pch = 20, cex = 0.3, col = "#1F77B433",
     xlim = c(-rng, rng), ylim = c(-rng, rng),
     xlab = sprintf("PC1 (%.1f%%)", 100 * prop[1]),
     ylab = sprintf("PC2 (%.1f%%)", 100 * prop[2]),
     main = "Figure X8: PCA Biplot (PC1 vs PC2)")
abline(h = 0, v = 0, col = "grey70", lty = 3)
# scale loading arrows to the visible (robust) range, not to outlier scores
arr <- pca$rotation[, 1:2]
sf  <- 0.85 * rng / max(abs(arr))
arrows(0, 0, arr[, 1] * sf, arr[, 2] * sf, length = 0.1, col = "#D62728", lwd = 1.8)
text(arr[, 1] * sf * 1.08, arr[, 2] * sf * 1.08, rownames(arr),
     col = "#B40426", cex = 0.8, font = 2)
par(op); dev.off()
cat("[saved] figX8_biplot.png\n")

cat("\n============================================================\n")
cat(" DONE. All figures + CSV summaries saved to ", OUTPUT_DIR, "/\n", sep = "")
cat("============================================================\n")
