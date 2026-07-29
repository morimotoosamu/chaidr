# ゲイン・リフト表のテスト

# 2ノードに完全分離する玩具データ: x=a → y=yes 80/100, x=b → y=yes 20/100
make_gains_data <- function() {
  data.frame(
    x = factor(rep(c("a", "b"), each = 100)),
    y = factor(c(rep(c("yes", "no"), c(80, 20)),
                 rep(c("yes", "no"), c(20, 80))))
  )
}

test_that("玩具データでゲイン表が手計算と一致する", {
  d <- make_gains_data()
  fit <- chaid(y ~ x, data = d,
               control = chaid_control(min_parent = 10, min_child = 5))
  expect_type(fit$nodes[[1]]$split, "list")
  g <- chaid_gains(fit, target = "yes")
  tab <- g$table
  expect_identical(nrow(tab), 2L)
  # 1行目 = 高反応ノード（rate 0.8, index 160）
  expect_equal(tab$rate[1], 0.8, tolerance = 1e-9)
  expect_equal(tab$rate[2], 0.2, tolerance = 1e-9)
  expect_equal(g$overall, 0.5, tolerance = 1e-9)
  expect_equal(tab$index[1], 160, tolerance = 0.1)
  expect_equal(tab$index[2], 40, tolerance = 0.1)
  # %target: 80/100 → 80%
  expect_equal(tab$pct_resp[1], 80, tolerance = 0.01)
  # 累積の端点は 100
  expect_equal(tab$cum_pct_n[nrow(tab)], 100, tolerance = 1e-6)
  expect_equal(tab$cum_pct_resp[nrow(tab)], 100, tolerance = 1e-6)
  # リフトの1点目 = index/100
  expect_equal(tab$cum_lift[1], 1.6, tolerance = 0.01)
  # 最終累積リフトは 1
  expect_equal(tab$cum_lift[nrow(tab)], 1, tolerance = 1e-6)
})

test_that("data 指定（同一データ）と訓練統計が一致する", {
  d <- make_gains_data()
  fit <- chaid(y ~ x, data = d,
               control = chaid_control(min_parent = 10, min_child = 5))
  g <- chaid_gains(fit, target = "yes")
  g2 <- chaid_gains(fit, data = d, target = "yes")
  expect_identical(g$table$node, g2$table$node)
  expect_equal(g$table$rate, g2$table$rate, tolerance = 1e-9)
})

test_that("2値なら target 省略で第2水準が選ばれる（メッセージつき）", {
  d <- make_gains_data()
  fit <- chaid(y ~ x, data = d,
               control = chaid_control(min_parent = 10, min_child = 5))
  expect_message(g3 <- chaid_gains(fit), "yes")
  expect_identical(g3$target, "yes")
})

test_that("3クラスでは target 必須、指定すれば動く", {
  fit_p <- fit_penguins_default()
  expect_snapshot(error = TRUE, chaid_gains(fit_p))
  gp <- chaid_gains(fit_p, target = "Gentoo")
  expect_gte(nrow(gp$table), 2)
  # index の加重平均（重み = pct_n）は 100
  expect_equal(sum(gp$table$index * gp$table$pct_n) / 100, 100,
               tolerance = 0.005)
  # rate 降順
  expect_false(is.unsorted(rev(gp$table$rate)))
})

test_that("連続目的変数: rate = ノード平均で降順に並ぶ", {
  skip_if_not_installed("ggplot2")
  data(diamonds, package = "ggplot2")
  dd <- as.data.frame(diamonds)
  fit_d <- chaid(price ~ carat + cut + color + clarity, data = dd,
                 control = chaid_control(min_parent = 8000, min_child = 3000,
                                         max_depth = 2, n_bins = 5))
  gd <- chaid_gains(fit_d)
  expect_false(is.unsorted(rev(gd$table$rate)))
  expect_equal(gd$table$cum_pct_resp[nrow(gd$table)], 100, tolerance = 1e-6)
  # 全体平均 = root の平均
  expect_equal(gd$overall, unname(fit_d$nodes[[1]]$dist["mean"]),
               tolerance = 1e-6)
})

test_that("頻度重み: freq 付き再集計でも訓練統計と一致する", {
  tit <- as.data.frame(Titanic)
  fit_t <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq)
  gt_train <- chaid_gains(fit_t, target = "Yes")
  gt_data <- chaid_gains(fit_t, data = tit, freq = tit$Freq, target = "Yes")
  expect_identical(gt_train$table$node, gt_data$table$node)
  expect_equal(gt_train$table$rate, gt_data$table$rate, tolerance = 1e-9)
})

test_that("縮退ケース: 全ノード平均 0 でも index が NA になり Inf にならない", {
  # y ≡ 0 のデータで overall = 0 でも表が壊れずに返ることを確認
  dz <- data.frame(y0 = rep(0, 200), g = factor(rep(c("a", "b"), each = 100)))
  fit_z <- chaid(y0 ~ g, data = dz,
                 control = chaid_control(min_parent = 20, min_child = 10))
  # 全ノード平均 = 0 なので分割は不成立になるが、gains 表は返る（root のみ）
  gz <- chaid_gains(fit_z)
  expect_identical(is.finite(gz$table$index) | is.na(gz$table$index),
                   rep(TRUE, nrow(gz$table)))
  expect_false(any(is.nan(gz$table$cum_lift)))
  expect_false(any(is.infinite(gz$table$cum_lift)))
})

test_that("print / plot がエラーなく動く", {
  fit_p <- fit_penguins_default()
  gp <- chaid_gains(fit_p, target = "Gentoo")
  out <- capture.output(print(gp))
  expect_match(out, "Gentoo", all = FALSE)
  tmp <- withr::local_tempfile(fileext = ".png")
  grDevices::png(tmp, width = 700, height = 500)
  withr::defer(grDevices::dev.off())
  expect_no_error(plot(gp))
  expect_no_error(plot(gp, type = "lift"))
})
