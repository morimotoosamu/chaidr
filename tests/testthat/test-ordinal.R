# 順序型目的変数（Goodman row effects model / H² 検定）のテスト

# glm(poisson) による H² の独立照合。
# row effects model は対数線形モデル
#   log m_ij = -log(wbar_ij) + λ + λ_i^X + λ_j^Y + τ_i (s_j - sbar)
# なので、poisson glm の逸脱度差が H²、残差自由度差が I-1 になるはず
h2_glm <- function(nij, wij, sj) {
  I <- nrow(nij)
  J <- ncol(nij)
  wbar <- wij / nij
  wbar[nij == 0] <- sum(wij) / sum(nij)
  sbar <- sum(colSums(wij) * sj) / sum(wij)
  d <- data.frame(n = as.vector(nij),
                  row = factor(rep(seq_len(I), J)),
                  col = factor(rep(seq_len(J), each = I)),
                  z = rep(sj - sbar, each = I),
                  off = -log(as.vector(wbar)))
  m0 <- suppressWarnings(stats::glm(n ~ row + col + offset(off),
                                    family = poisson, data = d))
  m1 <- suppressWarnings(stats::glm(n ~ row + col + row:z + offset(off),
                                    family = poisson, data = d))
  list(h2 = m0$deviance - m1$deviance, df = m0$df.residual - m1$df.residual)
}

# 木レベルの統合テスト用: 単調な関連を持つ順序目的変数データ
make_ordinal_data <- function() {
  set.seed(61)
  n <- 600
  xnum <- runif(n)
  grp <- factor(sample(c("p", "q", "r"), n, TRUE))
  lat <- 2 * xnum + (grp == "r") * 1.5 + rnorm(n, sd = 0.7)
  yord <- cut(lat, breaks = c(-Inf, 0.7, 1.4, 2.1, Inf),
              labels = c("低", "中", "高", "最高"), ordered_result = TRUE)
  data.frame(y = yord, xnum = xnum, grp = grp)
}

test_that("H² が glm(poisson) の逸脱度差と一致する（重みあり/なし × 5 反復）", {
  set.seed(61)
  for (rep in 1:5) {
    g <- sample(1:4, 400, TRUE)
    y <- factor(vapply(g, function(gi) {
      sample(5, 1, prob = stats::dpois(0:4, lambda = gi))
    }, integer(1)), levels = 1:5)
    w <- runif(400, 0.5, 2)
    f <- rep(1, 400)
    for (use_w in c(TRUE, FALSE)) {
      ww <- if (use_w) w else rep(1, 400)
      res <- pval_roweffects(g, y, ww, f, scores = 1:5,
                             eps = 1e-10, max_iter = 5000L)
      tab <- weighted_xtab(g, y, ww, f)
      keep_c <- colSums(tab$n) > 0
      ref <- h2_glm(tab$n[, keep_c, drop = FALSE],
                    tab$w[, keep_c, drop = FALSE], (1:5)[keep_c])
      expect_equal(res$statistic, ref$h2, tolerance = 1e-6)
      expect_identical(res$df, ref$df)
    }
  }
})

test_that("十分統計量の保存: 行和・列和・スコア和が観測と一致する", {
  set.seed(62)
  g <- sample(1:3, 300, TRUE)
  y <- factor(pmin(5, pmax(1, g + sample(-1:2, 300, TRUE))), levels = 1:5)
  tab <- weighted_xtab(g, y, runif(300, 0.5, 2), rep(1, 300))
  sj <- 1:5
  sbar <- sum(colSums(tab$w) * sj) / sum(tab$w)
  z <- sj - sbar
  m1 <- roweffects_expected(tab$n, cell_mean_weight(tab$n, tab$w), z,
                            eps = 1e-10, max_iter = 5000L)
  expect_equal(rowSums(m1), rowSums(tab$n), tolerance = 1e-6)
  expect_equal(colSums(m1), colSums(tab$n), tolerance = 1e-6)
  expect_equal(as.numeric(m1 %*% z), as.numeric(tab$n %*% z), tolerance = 1e-6)
})

test_that("J=2 の退化恒等: row effects model は飽和し H² = G²", {
  set.seed(63)
  g2 <- sample(1:4, 300, TRUE)
  y2 <- factor(rbinom(300, 1, plogis(g2 - 2.5)), levels = 0:1)
  w2 <- runif(300, 0.5, 2)
  res_o <- pval_roweffects(g2, y2, w2, rep(1, 300),
                           eps = 1e-10, max_iter = 5000L)
  res_n <- pval_chisq(g2, y2, w2, rep(1, 300), stat = "lr",
                      eps = 1e-10, max_iter = 5000L)
  expect_equal(res_o$statistic, res_n$statistic, tolerance = 1e-6)
  expect_equal(res_o$df, res_n$df)
  expect_equal(res_o$p, res_n$p, tolerance = 1e-8)
})

test_that("スコアの不変性: アフィン変換・反転で不変、非等間隔では変わる", {
  set.seed(62)
  g <- sample(1:3, 300, TRUE)
  y <- factor(pmin(5, pmax(1, g + sample(-1:2, 300, TRUE))), levels = 1:5)
  base <- pval_roweffects(g, y, rep(1, 300), rep(1, 300), scores = 1:5,
                          eps = 1e-10, max_iter = 5000L)
  # 正のアフィン変換で不変
  aff <- pval_roweffects(g, y, rep(1, 300), rep(1, 300),
                         scores = 10 + 3 * (1:5),
                         eps = 1e-10, max_iter = 5000L)
  expect_equal(base$statistic, aff$statistic, tolerance = 1e-6)
  # 反転（負の係数）でも不変（γ → 1/γ の再パラメータ化）
  rev_ <- pval_roweffects(g, y, rep(1, 300), rep(1, 300),
                          scores = rev(1:5) * -1,
                          eps = 1e-10, max_iter = 5000L)
  expect_equal(base$statistic, rev_$statistic, tolerance = 1e-6)
  # 非等間隔スコアは異なる統計量を与える（スコアが実際に効いている）
  neq <- pval_roweffects(g, y, rep(1, 300), rep(1, 300),
                         scores = c(1, 2, 5, 9, 20),
                         eps = 1e-10, max_iter = 5000L)
  expect_gt(abs(base$statistic - neq$statistic), 1e-4)
})

test_that("退化ケース（1 カテゴリ / 1 クラス）は p = 1", {
  expect_identical(pval_roweffects(rep(1, 20), factor(rep(1:2, 10)),
                                   rep(1, 20), rep(1, 20))$p, 1)
  expect_identical(pval_roweffects(rep(1:2, 10), factor(rep("a", 20)),
                                   rep(1, 20), rep(1, 20))$p, 1)
})

test_that("頻度重み等価性: 集計データと展開データで H² が一致する", {
  set.seed(64)
  d_agg <- expand.grid(g = 1:3, y = 1:4)
  d_agg$n <- sample(5:40, 12)
  g_exp <- rep(d_agg$g, d_agg$n)
  y_exp <- factor(rep(d_agg$y, d_agg$n), levels = 1:4)
  r_agg <- pval_roweffects(d_agg$g, factor(d_agg$y, levels = 1:4),
                           rep(1, 12), d_agg$n, eps = 1e-10, max_iter = 5000L)
  r_exp <- pval_roweffects(g_exp, y_exp, rep(1, length(g_exp)),
                           rep(1, length(g_exp)),
                           eps = 1e-10, max_iter = 5000L)
  expect_equal(r_agg$statistic, r_exp$statistic, tolerance = 1e-6)
  expect_identical(r_agg$df, r_exp$df)
})

test_that("木レベル: 順序目的変数で学習でき、既定スコアは 1..J", {
  dord <- make_ordinal_data()
  fit_o <- chaid(y ~ xnum + grp, data = dord,
                 control = chaid_control(min_parent = 60, min_child = 25))
  expect_identical(fit_o$response$type, "ordinal")
  expect_equal(fit_o$response$scores, 1:4)
  expect_type(fit_o$nodes[[1]]$split, "list")
  # 警告なしで学習できている（v1 の名義扱い警告が消えた）
  expect_no_warning(suppressMessages(
    chaid(y ~ xnum, data = dord,
          control = chaid_control(min_parent = 60, min_child = 25))
  ))
})

test_that("木レベル: predict は ordered factor / 確率 / ノード id を返す", {
  dord <- make_ordinal_data()
  fit_o <- chaid(y ~ xnum + grp, data = dord,
                 control = chaid_control(min_parent = 60, min_child = 25))
  pr <- predict(fit_o, dord)
  expect_s3_class(pr, "ordered")
  expect_identical(levels(pr), levels(dord$y))
  pp <- predict(fit_o, dord, type = "prob")
  expect_identical(ncol(pp), 4L)
  expect_equal(rowSums(pp), rep(1, nrow(dord)), tolerance = 1e-12,
               ignore_attr = TRUE)
})

test_that("木レベル: print に H2 ラベルと順序型表記が出る", {
  dord <- make_ordinal_data()
  fit_o <- chaid(y ~ xnum + grp, data = dord,
                 control = chaid_control(min_parent = 60, min_child = 25))
  out <- capture.output(print(fit_o))
  expect_match(out, "H2", all = FALSE)
  expect_match(out, "ordinal categorical", all = FALSE)
})

test_that("名義型扱いと順序型で検定が変わる", {
  # H² の df = I-1 は χ² の (I-1)(J-1) より小さく（J=4 > 2）、p 値も異なる
  dord <- make_ordinal_data()
  fit_o <- chaid(y ~ xnum + grp, data = dord,
                 control = chaid_control(min_parent = 60, min_child = 25))
  fit_n <- chaid(y ~ xnum + grp,
                 data = transform(dord, y = factor(y, ordered = FALSE)),
                 control = chaid_control(min_parent = 60, min_child = 25))
  expect_lt(fit_o$nodes[[1]]$split$df, fit_n$nodes[[1]]$split$df)
  # 統計量も異なる（H² と Pearson χ²。p 値は両方 0 に underflow しうるため
  # 統計量で比較）
  expect_gt(abs(fit_o$nodes[[1]]$split$statistic -
                  fit_n$nodes[[1]]$split$statistic), 1e-6)
})

test_that("y_scores のバリデーション", {
  dord <- make_ordinal_data()
  expect_snapshot(error = TRUE,
                  chaid(y ~ xnum, data = dord, y_scores = 1:3))          # 長さ不一致
  expect_snapshot(error = TRUE,
                  chaid(y ~ xnum, data = dord, y_scores = c(1, 2, NA, 4)))  # 非有限
  dnom <- transform(dord, y = factor(y, ordered = FALSE))
  expect_snapshot(error = TRUE,
                  chaid(y ~ xnum, data = dnom, y_scores = 1:4))          # 名義 y への指定
  # カスタムスコアで学習でき、既定スコアと結果が変わりうる
  fit_s <- chaid(y ~ xnum + grp, data = dord, y_scores = c(1, 2, 3, 10),
                 control = chaid_control(min_parent = 60, min_child = 25))
  expect_identical(fit_s$response$scores, c(1, 2, 3, 10))
})

test_that("レポーティング機能も順序型で動く", {
  dord <- make_ordinal_data()
  fit_o <- chaid(y ~ xnum + grp, data = dord,
                 control = chaid_control(min_parent = 60, min_child = 25))
  tb <- chaid_table(fit_o, target = "最高")
  expect_gte(nrow(tb), 2)
  gn <- suppressMessages(chaid_gains(fit_o, target = "最高"))
  expect_equal(gn$table$cum_pct_resp[nrow(gn$table)], 100, tolerance = 1e-6)
  v <- chaid_validate(fit_o, dord)
  expect_lt(max(abs(v$nodes$diff_rate), na.rm = TRUE), 1e-3)
})
