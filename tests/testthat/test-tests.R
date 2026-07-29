# 検定（χ² / G² / F・IPF 期待度数）のユニットテスト

test_that("Pearson χ² は stats::chisq.test(correct=FALSE) と一致する", {
  set.seed(42)
  g <- sample(1:3, 200, replace = TRUE)
  y <- factor(sample(c("a", "b"), 200, replace = TRUE, prob = c(0.4, 0.6)))
  res <- pval_chisq(g, y, w = rep(1, 200), f = rep(1, 200), stat = "pearson")
  ref <- suppressWarnings(stats::chisq.test(table(g, y), correct = FALSE))
  expect_equal(res$statistic, unname(ref$statistic), tolerance = 1e-10)
  expect_equal(res$df, unname(ref$parameter))
  expect_equal(res$p, ref$p.value, tolerance = 1e-12)
})

test_that("尤度比 G² は手計算（2*Σ n log(n/m)）と一致する", {
  set.seed(42)
  g <- sample(1:3, 200, replace = TRUE)
  y <- factor(sample(c("a", "b"), 200, replace = TRUE, prob = c(0.4, 0.6)))
  res_lr <- pval_chisq(g, y, rep(1, 200), rep(1, 200), stat = "lr")
  tab <- table(g, y)
  m <- outer(rowSums(tab), colSums(tab)) / sum(tab)
  g2 <- 2 * sum(ifelse(tab == 0, 0, tab * log(tab / m)))
  expect_equal(res_lr$statistic, g2, tolerance = 1e-10)
})

test_that("頻度重み: 集計データと展開データで統計量が一致する", {
  df_agg <- expand.grid(g = 1:3, y = c("a", "b"))
  df_agg$n <- c(30, 10, 20, 15, 25, 40)
  g_exp <- rep(df_agg$g, df_agg$n)
  y_exp <- factor(rep(df_agg$y, df_agg$n))
  res_agg <- pval_chisq(df_agg$g, factor(df_agg$y), w = rep(1, 6), f = df_agg$n)
  res_exp <- pval_chisq(g_exp, y_exp, rep(1, length(g_exp)), rep(1, length(g_exp)))
  expect_equal(res_agg$statistic, res_exp$statistic, tolerance = 1e-10)
  expect_identical(res_agg$df, res_exp$df)
})

test_that("IPF: 単位重みなら閉形式と一致する", {
  nij <- matrix(c(30, 10, 20, 15, 25, 40), nrow = 3)
  m_ipf <- expected_freq(nij, nij + 0)  # wij == nij
  expect_equal(m_ipf, outer(rowSums(nij), colSums(nij)) / sum(nij),
               tolerance = 1e-10)
})

test_that("IPF: ケース重みありでも周辺和制約を満たす", {
  set.seed(42)
  nij <- matrix(c(30, 10, 20, 15, 25, 40), nrow = 3)
  wij <- nij * matrix(runif(6, 0.5, 2), nrow = 3)  # セルごとに平均重みが異なる
  m_w <- expected_freq(nij, wij, eps = 1e-10, max_iter = 1000L)
  expect_equal(rowSums(m_w), rowSums(nij), tolerance = 1e-6)
  expect_equal(colSums(m_w), colSums(nij), tolerance = 1e-6)

  # 本番既定（eps=1e-3, max_iter=100）でも警告なしに収束し、周辺和をほぼ満たす
  expect_no_warning(m_def <- expected_freq(nij, wij))
  expect_equal(rowSums(m_def), rowSums(nij), tolerance = 0.01)
  expect_equal(colSums(m_def), colSums(nij), tolerance = 0.01)
})

test_that("退化ケース（1 カテゴリ / 1 クラス）は p = 1", {
  expect_identical(pval_chisq(rep(1, 10), factor(rep(c("a", "b"), 5)),
                              rep(1, 10), rep(1, 10))$p, 1)
  expect_identical(pval_chisq(rep(1:2, 5), factor(rep("a", 10)),
                              rep(1, 10), rep(1, 10))$p, 1)
})

test_that("ANOVA F は stats::oneway.test(var.equal=TRUE) と一致する", {
  set.seed(42)
  yn <- rnorm(120, mean = rep(c(0, 1, 3), each = 40))
  gn <- rep(1:3, each = 40)
  res_f <- pval_ftest(gn, yn, rep(1, 120), rep(1, 120))
  ref_f <- stats::oneway.test(yn ~ factor(gn), var.equal = TRUE)
  expect_equal(res_f$statistic, unname(ref_f$statistic), tolerance = 1e-10)
  expect_equal(res_f$df, unname(ref_f$parameter))
  expect_equal(res_f$p, ref_f$p.value, tolerance = 1e-12)
})

test_that("F の退化: 群内分散ゼロ", {
  # 完全分離
  expect_identical(pval_ftest(rep(1:2, each = 5), rep(c(1, 2), each = 5),
                              rep(1, 10), rep(1, 10))$p, 0)
  # 全て同値
  expect_identical(pval_ftest(rep(1:2, each = 5), rep(1, 10),
                              rep(1, 10), rep(1, 10))$p, 1)
})
