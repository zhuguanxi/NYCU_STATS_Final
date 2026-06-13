df <- read.csv("Spotify_Youtube_Clean.csv", fileEncoding="UTF-8-BOM", check.names=TRUE)
df$ln_Duration <- log(df$Duration_ms)
keep <- is.finite(df$Stream) & df$Stream > 0
d <- df[keep, ]
rows <- c(4775,4776,4777,4778,4779,4780,4781,4782,4783,4784)
print(d[rows, c("Artist","Track","Stream","Views","Danceability","official_video")])
