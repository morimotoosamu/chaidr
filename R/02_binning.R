# 02_binning.R -- 連続予測変数の分位ビン分割（離散化）
# 資料 §2.1 / IBM SPSS Algorithms (TREE-CHAID) 準拠。
# 木構築前に学習データ全体へ一括1回実行し、以後は順序カテゴリとして扱う。

# x:  数値ベクトル（NA 可。NA はビン化されず NA のまま返る）
# wf: ケース重み × 頻度重み
# k:  目標ビン数（既定 10 = 十分位）
# 返り値: list(xbin  = 各ケースのビン番号 1..nbins,
#              breaks = 各ビンの上側境界値（そのビンに属する最大の観測値）,
#              nbins  = 実際に生成されたビン数)
# 同一値への重み集中（> 1/k）やユニーク値数 < k のとき nbins は自動縮小する。
bin_continuous <- function(x, wf, k = 10L) {
  stopifnot(k >= 1)
  ok <- !is.na(x)
  if (!any(ok)) stop("bin_continuous: cannot bin a variable whose cases are all missing")
  ux <- sort(unique(x[ok]))
  w_by_val <- vapply(split(wf[ok], factor(x[ok], levels = ux)), sum, numeric(1))
  # 累積相対周波数 S(u) をビンインデックス B(u) = ceiling(k * S(u)) へ写像
  S <- cumsum(w_by_val) / sum(w_by_val)
  idx <- as.integer(ceiling(k * S - 1e-8))  # 浮動小数点誤差の許容
  idx[idx < 1L] <- 1L
  # インデックスが変わる位置が新ビンの開始。同一値は必ず同一ビンに入るため、
  # 重みが集中した値がインデックスを飛ばすとビン数が縮小する。
  changed <- idx[-1L] != idx[-length(idx)]
  bin_of_val <- cumsum(c(1L, as.integer(changed)))
  breaks <- as.numeric(ux[c(changed, TRUE)])  # 各ビンの上側境界 = そのビン最後の観測値
  xbin <- rep(NA_integer_, length(x))
  xbin[ok] <- bin_of_val[match(x[ok], ux)]
  list(xbin = xbin, breaks = breaks, nbins = bin_of_val[length(bin_of_val)])
}

# 学習済み breaks による新データのビン割当（predict 用）。
# ビン b は (breaks[b-1], breaks[b]] を覆う。範囲外は端のビンへ丸める。
bin_apply <- function(x, breaks) {
  nb <- length(breaks)
  b <- findInterval(x, breaks, left.open = TRUE) + 1L
  b[!is.na(b) & b > nb] <- nb
  as.integer(b)
}
