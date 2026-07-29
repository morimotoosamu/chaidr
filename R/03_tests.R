# 03_tests.R -- p 値計算（Pearson χ² / 尤度比 G² / 一元配置 ANOVA F）
# IBM SPSS Algorithms (TREE-CHAID) 準拠。
# Yates 連続性補正・最小期待度数規則は公式アルゴリズムに存在しないため実装しない。
#
# 各検定は「表ベースのコア（*_tab / suffstat_pvalue）」と「生データを受ける
# 互換ラッパー（pval_chisq / pval_ftest / pval_roweffects / node_pvalue）」の
# 2 層構成。結合フェーズのホットパスは suffstat_build（00_utils.R）で
# 事前集計した表だけを使い、生データの再走査を行わない。

# 期待度数の推定。
# ケース重みなし（w_ij == n_ij）: 閉形式 m_ij = n_i. * n_.j / n_..
# ケース重みあり: 反復比例フィッティング（IPF）
#   w̄_ij = w_ij / n_ij,  m_ij = w̄_ij^{-1} * α_i * β_j
#   α_i ← n_i. / Σ_j w̄_ij^{-1} β_j,  β_j ← n_.j / Σ_i w̄_ij^{-1} α_i
#   max|m^{(k+1)} - m^{(k)}| < eps で収束（既定 eps=0.001, 上限 100 回）
# セル平均ケース重み w̄_ij = w_ij / n_ij。
# 空セル（n_ij = 0）の平均重みは定義できないため全体平均重みで代用する
cell_mean_weight <- function(nij, wij) {
  wbar <- wij / nij
  wbar[nij == 0] <- sum(wij) / sum(nij)
  wbar
}

# unweighted: 全ケース w == 1 と事前に判明していれば TRUE（重みつき比較を省略）。
# NA なら従来どおり表の一致で判定する
expected_freq <- function(nij, wij, eps = 1e-3, max_iter = 100L, unweighted = NA) {
  ni <- rowSums(nij)
  nj <- colSums(nij)
  n <- sum(nij)
  if (is.na(unweighted)) {
    unweighted <- isTRUE(all.equal(as.numeric(wij), as.numeric(nij)))
  }
  if (unweighted) {
    return(outer(ni, nj) / n)
  }
  wbar <- cell_mean_weight(nij, wij)
  inv <- 1 / wbar
  alpha <- rep(1, nrow(nij))
  beta <- rep(1, ncol(nij))
  m <- inv * outer(alpha, beta)
  converged <- FALSE
  for (it in seq_len(max_iter)) {
    m_old <- m
    alpha <- ni / as.numeric(inv %*% beta)
    beta <- nj / as.numeric(t(inv) %*% alpha)
    m <- inv * outer(alpha, beta)
    if (max(abs(m - m_old)) < eps) {
      converged <- TRUE
      break
    }
  }
  if (!converged) {
    warning("expected_freq: IPF did not converge after ", max_iter,
            " iterations (residual ", format(max(abs(m - m_old)), digits = 3),
            "); p values may be less accurate")
  }
  m
}

# カテゴリカル目的変数の検定（表ベースのコア）。
# nij / wij: グループ × クラスの観測度数表（空行・空列は内部で除去）。
# 返り値: list(statistic, df, p)
pval_chisq_tab <- function(nij, wij, stat = "pearson", eps = 1e-3,
                           max_iter = 100L, unweighted = NA) {
  keep_r <- rowSums(nij) > 0
  keep_c <- colSums(nij) > 0
  nij <- nij[keep_r, keep_c, drop = FALSE]
  wij <- wij[keep_r, keep_c, drop = FALSE]
  I <- nrow(nij)
  J <- ncol(nij)
  if (I < 2 || J < 2) {
    return(list(statistic = 0, df = 0, p = 1))
  }
  m <- expected_freq(nij, wij, eps, max_iter, unweighted)
  if (stat == "pearson") {
    x2 <- sum((nij - m)^2 / m)
  } else {
    terms <- nij * log(nij / m)
    terms[nij == 0] <- 0  # lim_{n→0} n log(n/m) = 0
    x2 <- 2 * sum(terms)
  }
  df <- (I - 1) * (J - 1)
  list(statistic = x2, df = df, p = stats::pchisq(x2, df, lower.tail = FALSE))
}

# 互換ラッパー: 生データ（g, y, w, f）から表を作って表ベースコアへ
pval_chisq <- function(g, y, w, f, stat = "pearson", eps = 1e-3, max_iter = 100L) {
  tab <- weighted_xtab(g, y, w, f)
  pval_chisq_tab(tab$n, tab$w, stat, eps, max_iter)
}

# 連続目的変数の一元配置 ANOVA F 検定。
# 平方和は w*f で加重するが、自由度は頻度重み合計 N_f = Σf で決まる（IBM 仕様）。
pval_ftest <- function(g, y, w, f) {
  wf <- w * f
  gi <- factor(g)
  I <- nlevels(gi)
  Nf <- sum(f)
  df1 <- I - 1
  df2 <- Nf - I
  if (I < 2 || df2 <= 0) {
    return(list(statistic = 0, df = c(df1, max(df2, 0)), p = 1))
  }
  swf <- tapply(wf, gi, sum)
  ybar_i <- tapply(wf * y, gi, sum) / swf
  ybar <- sum(wf * y) / sum(wf)
  ssb <- sum(swf * (ybar_i - ybar)^2)
  ssw <- sum(wf * (y - ybar_i[gi])^2)
  # 群内分散ゼロの退化: 群平均に差があれば完全分離（p→0）、なければ差なし（p=1）
  if (ssw <= .Machine$double.eps * max(1, ssb)) {
    if (ssb > .Machine$double.eps) {
      return(list(statistic = Inf, df = c(df1, df2), p = 0))
    }
    return(list(statistic = 0, df = c(df1, df2), p = 1))
  }
  fstat <- (ssb / df1) / (ssw / df2)
  list(statistic = fstat, df = c(df1, df2),
       p = stats::pf(fstat, df1, df2, lower.tail = FALSE))
}

# F 検定の十分統計量版。st はグループ × 4 行列（Σf, Σwf, Σwf·y, Σwf·y²）。
# ssw = Σ_g (Σwf·y² − (Σwf·y)²/Σwf) は展開式のため生データ版と加算順序が
# 異なり、最下位ビットレベルの差が出うる（suffstat_build 側の中心化で
# 桁落ちは抑制済み）。判定ロジック・退化ケースの扱いは生データ版と同一。
pval_ftest_tab <- function(st) {
  st <- st[st[, 1L] > 0, , drop = FALSE]  # ケースのないグループは検定に現れない
  sf <- st[, 1L]
  swf <- st[, 2L]
  swfy <- st[, 3L]
  swfy2 <- st[, 4L]
  I <- nrow(st)
  Nf <- sum(sf)
  df1 <- I - 1
  df2 <- Nf - I
  if (I < 2 || df2 <= 0) {
    return(list(statistic = 0, df = c(df1, max(df2, 0)), p = 1))
  }
  ybar_i <- swfy / swf
  ybar <- sum(swfy) / sum(swf)
  ssb <- sum(swf * (ybar_i - ybar)^2)
  ssw <- max(0, sum(swfy2 - swfy^2 / swf))  # 数値誤差による負値は 0 へ
  if (ssw <= .Machine$double.eps * max(1, ssb)) {
    if (ssb > .Machine$double.eps) {
      return(list(statistic = Inf, df = c(df1, df2), p = 0))
    }
    return(list(statistic = 0, df = c(df1, df2), p = 1))
  }
  fstat <- (ssb / df1) / (ssw / df2)
  list(statistic = fstat, df = c(df1, df2),
       p = stats::pf(fstat, df1, df2, lower.tail = FALSE))
}

# row effects model の期待度数 m̂̂_ij（Goodman 1979 / IBM TREE-CHAID 準拠）。
#   m_ij = w̄_ij⁻¹ α_i β_j γ_i^z_j（z_j = s_j − s̄ は中心化スコア）
# γ^z の桁あふれを避けるため対数空間で反復する。
#   1. α=β=γ=1, m⁽⁰⁾ = w̄⁻¹
#   2. α_i ← α_i · n_i. / Σ_j m_ij      （PDF の第1形は分子が誤植。等価形を採用）
#   3. β_j ← n_.j / Σ_i w̄_ij⁻¹ α_i γ_i^z_j
#   4. m* を計算し G_i = 1 + Σ_j z_j(n_ij − m*_ij) / Σ_j z_j² m*_ij
#   5. G_i > 0（かつ有限）のとき γ_i ← γ_i G_i
#   6-7. m を更新し max|Δm| < eps で停止
roweffects_expected <- function(nij, wbar, z, eps = 1e-3, max_iter = 100L) {
  ni <- rowSums(nij)
  nj <- colSums(nij)
  I <- nrow(nij)
  lw <- -log(wbar)                 # log w̄⁻¹（行列）
  la <- numeric(I)                 # log α
  lb <- numeric(ncol(nij))         # log β
  lg <- numeric(I)                 # log γ
  logm <- lw
  for (k in seq_len(max_iter)) {
    m_old <- exp(logm)
    la <- la + log(ni) - log(rowSums(m_old))
    lb <- log(nj) - log(colSums(exp(lw + la + outer(lg, z))))
    mstar <- exp(lw + outer(la, lb, "+") + outer(lg, z))
    num <- as.numeric((nij - mstar) %*% z)
    den <- as.numeric(mstar %*% (z^2))
    gi <- 1 + num / den
    upd <- is.finite(gi) & gi > 0
    lg[upd] <- lg[upd] + log(gi[upd])
    logm <- lw + outer(la, lb, "+") + outer(lg, z)
    m_new <- exp(logm)
    if (max(abs(m_new - m_old)) < eps) return(m_new)
  }
  warning("roweffects_expected: iteration did not converge after ", max_iter,
          " iterations (complete monotone separation suspected; ",
          "the p value is pinned near 0)")
  exp(logm)
}

# 順序型目的変数の Goodman row effects 尤度比検定（表ベースのコア）。
#   H² = 2 Σ m̂̂_ij ln(m̂̂_ij / m̂_ij)、df = I − 1（J に依存しない）
# scores は nij の列に対応する数値（NULL なら列順位 1..J）。木の開始時に
# 固定され、部分表で空クラスを落としても残クラスのスコアは再採番しない
# （s̄ の中心化のみ表ごとに再計算する = IBM 仕様）。
pval_roweffects_tab <- function(nij, wij, scores = NULL,
                                eps = 1e-3, max_iter = 100L, unweighted = NA) {
  if (is.null(scores)) scores <- seq_len(ncol(nij))
  keep_r <- rowSums(nij) > 0
  keep_c <- colSums(nij) > 0
  nij <- nij[keep_r, keep_c, drop = FALSE]
  wij <- wij[keep_r, keep_c, drop = FALSE]
  sj <- scores[keep_c]
  I <- nrow(nij)
  J <- ncol(nij)
  if (I < 2 || J < 2) return(list(statistic = 0, df = max(I - 1L, 0L), p = 1))
  sbar <- sum(colSums(wij) * sj) / sum(wij)
  z <- sj - sbar
  if (all(abs(z) < 1e-12)) return(list(statistic = 0, df = I - 1L, p = 1))
  m0 <- expected_freq(nij, wij, eps, max_iter, unweighted)
  wbar <- cell_mean_weight(nij, wij)
  m1 <- roweffects_expected(nij, wbar, z, eps, max_iter)
  h2 <- max(0, 2 * sum(m1 * log(m1 / m0)))   # 数値誤差による負値は 0 へ
  df <- I - 1L
  list(statistic = h2, df = df, p = stats::pchisq(h2, df, lower.tail = FALSE))
}

# 互換ラッパー: 生データから表を作り、列名を levels(y) に対応付けて
# スコアを整列してから表ベースコアへ（スコア自体は再採番しない = IBM 仕様）
pval_roweffects <- function(g, y, w, f, scores = NULL,
                            eps = 1e-3, max_iter = 100L) {
  if (is.null(scores)) scores <- seq_len(nlevels(y))
  tab <- weighted_xtab(g, y, w, f)
  sj_all <- scores[match(colnames(tab$n), levels(y))]
  pval_roweffects_tab(tab$n, tab$w, sj_all, eps, max_iter)
}

# 十分統計量表（suffstat_build）に対する検定のディスパッチ。
# groups の行を畳み込み、目的変数の型に応じた表ベースコアを呼ぶ。
# 結合フェーズのペア p 値・全表 p 値はすべてここを通る。
suffstat_pvalue <- function(ss, groups, control) {
  cl <- suffstat_collapse(ss, groups)
  if (ss$ytype == "factor") {
    pval_chisq_tab(cl$nij, cl$wij, control$stat, control$epsilon,
                   control$max_iter, ss$unweighted)
  } else if (ss$ytype == "ordinal") {
    pval_roweffects_tab(cl$nij, cl$wij, control$y_scores, control$epsilon,
                        control$max_iter, ss$unweighted)
  } else {
    pval_ftest_tab(cl$st)
  }
}

# 目的変数の型に応じた検定のディスパッチ（生データ版・互換用）。
# control から stat（χ²の種類）・epsilon/max_iter（反復収束条件）・
# y_scores（順序型スコア。chaid() がフィット時に注入）を取る。
node_pvalue <- function(g, y, w, f, ytype, control) {
  if (ytype == "factor") {
    pval_chisq(g, y, w, f, control$stat, control$epsilon, control$max_iter)
  } else if (ytype == "ordinal") {
    pval_roweffects(g, y, w, f, control$y_scores,
                    control$epsilon, control$max_iter)
  } else {
    pval_ftest(g, y, w, f)
  }
}
