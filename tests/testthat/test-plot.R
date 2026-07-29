# plot.chaid のテスト（描画エラーが出ないことと基本的な引数処理を確認）
# expect_plot_ok は helper-fixtures.R で定義

test_that("カテゴリカル目的変数（多階層・多岐分割）を描画できる", {
  fit1 <- fit_iris_default()
  expect_plot_ok(fit1)
  expect_plot_ok(fit1, show_bar = FALSE, cex = 1, main = "custom title")
})

test_that("連続目的変数を描画できる", {
  set.seed(3)
  n <- 400
  dreg <- data.frame(y = rnorm(n) + rep(c(0, 3), each = n / 2),
                     g = factor(rep(c("a", "b"), each = n / 2)))
  fit2 <- chaid(y ~ g, data = dreg,
                control = chaid_control(min_parent = 50, min_child = 20))
  expect_plot_ok(fit2)
})

test_that("分割なし（単一ノード）の木でも落ちない", {
  fit3 <- chaid(Species ~ ., data = iris,
                control = chaid_control(min_parent = 1000))
  expect_null(fit3$nodes[[1]]$split)
  expect_plot_ok(fit3)
})

test_that("trunc_label がラベルを切り詰める", {
  expect_identical(trunc_label("abcdef", 6), "abcdef")
  expect_identical(trunc_label("abcdefg", 6), "abc...")
  expect_identical(trunc_label(c("short", "very long label"), 8),
                   c("short", "very ..."))
})
