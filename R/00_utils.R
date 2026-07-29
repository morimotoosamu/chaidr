# 00_utils.R -- CHAID 共通ヘルパ
# 参照: IBM SPSS Statistics Algorithms "CHAID and Exhaustive CHAID Algorithms"

# groups（元カテゴリコードの整数ベクトルのリスト）に基づき、各ケースの
# グループ番号を返す。どのグループにも属さないコードは NA。
assign_groups <- function(xcode, groups) {
  m <- max(xcode, unlist(groups))
  gmap <- rep(NA_integer_, m)
  for (gi in seq_along(groups)) gmap[groups[[gi]]] <- gi
  gmap[xcode]
}

# 結合を許容するグループペアの列挙（2列の行列で返す）。
# 順序型: グループを最小コード順に並べた隣接ペアのみ。
# 名義型: 全ペア。
# float_group: 浮動カテゴリ（欠損）を含むグループ番号。順序型でも任意の
# グループと結合可能（Kass 1980 の Floating 拡張）。
allowable_pairs <- function(groups, ptype, float_group = NA_integer_) {
  k <- length(groups)
  if (k < 2) return(matrix(integer(0), ncol = 2))
  if (ptype == "nominal") {
    return(t(utils::combn(k, 2)))
  }
  ord <- order(vapply(groups, min, integer(1)))
  non_float <- ord[!ord %in% float_group]
  pairs <- if (length(non_float) >= 2) {
    cbind(non_float[-length(non_float)], non_float[-1])
  } else {
    matrix(integer(0), ncol = 2)
  }
  if (!is.na(float_group) && length(float_group) == 1) {
    pairs <- rbind(pairs, cbind(float_group, setdiff(seq_len(k), float_group)))
  }
  pairs
}

# HTML / SVG に埋め込む文字列の共通エスケープ。Graphviz HTML-like label と
# plotly のホバーテキストの両方で使う。順序は `&` を先にすること（&lt; を壊さない）。
esc_html <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  gsub(">", "&gt;", s, fixed = TRUE)
}

# 重み付きクロス集計。観測度数 n_ij は頻度重み f のみ、w_ij は w*f で集計
# （IBM 仕様: 検定の観測度数は頻度重みで決まり、ケース重みは期待度数の
# 推定にのみ反映される）。
weighted_xtab <- function(g, y, w, f) {
  gi <- factor(g)
  yj <- factor(y)
  nij <- tapply(f, list(gi, yj), sum, default = 0)
  wij <- tapply(w * f, list(gi, yj), sum, default = 0)
  list(n = nij, w = wij)
}

# ノード内データの (カテゴリコード × 目的変数) 十分統計量。ノード×変数ごとに
# 1 回だけ生データを走査し、以後の結合フェーズの全検定（ペア・全表）は
# この表の行の畳み込みだけで計算する（生データの部分抽出＋再集計を排除）。
#   カテゴリカル/順序目的: nij = Σf、wij = Σw*f（ncat × J。欠番カテゴリは 0 行）
#   連続目的:              st  = ncat × 4（Σf, Σwf, Σwf·y, Σwf·y²）。
#                          y はノード加重平均で中心化する（F 統計量は不変で、
#                          平方和の十分統計量計算の桁落ちを抑える）
#   fcat    = カテゴリ別の頻度重み合計（グループサイズ判定用）
#   present = カテゴリにケースが 1 件以上あるか
#   unweighted = 全ケース w == 1（期待度数のクローズドフォーム分岐用）
suffstat_build <- function(xcode, y, w, f, ytype) {
  ncat <- max(xcode)
  wf <- w * f
  present <- tabulate(xcode, ncat) > 0L
  if (ytype != "numeric") {
    J <- nlevels(y)
    # (i, j) セルの列優先線形添字に対する rowsum で 2 つの表を同時に集計
    grp <- xcode + ncat * (as.integer(y) - 1L)
    agg <- rowsum(cbind(f, wf), grp)
    cell <- as.integer(rownames(agg))
    nij <- matrix(0, ncat, J, dimnames = list(NULL, levels(y)))
    wij <- matrix(0, ncat, J, dimnames = list(NULL, levels(y)))
    nij[cell] <- agg[, 1L]
    wij[cell] <- agg[, 2L]
    list(ytype = ytype, nij = nij, wij = wij, fcat = rowSums(nij),
         present = present, unweighted = all(w == 1))
  } else {
    yc <- y - sum(wf * y) / sum(wf)
    agg <- rowsum(cbind(f, wf, wf * yc, wf * yc * yc), xcode)
    st <- matrix(0, ncat, 4L)
    st[as.integer(rownames(agg)), ] <- agg
    list(ytype = ytype, st = st, fcat = st[, 1L],
         present = present, unweighted = all(w == 1))
  }
}

# groups（カテゴリコード集合のリスト）の各要素を十分統計量表の 1 行へ畳み込む
suffstat_collapse <- function(ss, groups) {
  one <- function(m) {
    do.call(rbind, lapply(groups, function(g) colSums(m[g, , drop = FALSE])))
  }
  if (ss$ytype == "numeric") {
    list(st = one(ss$st))
  } else {
    list(nij = one(ss$nij), wij = one(ss$wij))
  }
}
