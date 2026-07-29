# 安定性評価（chaid_validate）のテスト
# fit_penguins_default は helper-fixtures.R で定義

test_that("newdata = 訓練データなら差分 ≈ 0、精度 = 訓練精度", {
  fit <- fit_penguins_default()
  v <- chaid_validate(fit, penguins)
  expect_s3_class(v, "chaid_validation")
  expect_lt(max(abs(v$nodes$diff_rate), na.rm = TRUE), 1e-3)  # 丸め分の許容
  expect_lt(max(abs(v$nodes$train_pct_n - v$nodes$test_pct_n)), 0.05)
  acc_train <- mean(predict(fit, penguins) == penguins$species)
  expect_equal(v$overall$accuracy, acc_train, tolerance = 1e-9)
  expect_identical(v$n_test, 344)
})

test_that("部分データ（ホールドアウト相当）でも動く", {
  set.seed(51)
  fit <- fit_penguins_default()
  v <- chaid_validate(fit, penguins)
  idx <- sample(344, 170)
  v2 <- chaid_validate(fit, penguins[idx, ])
  expect_identical(nrow(v2$nodes), nrow(v$nodes))
  expect_identical(v2$n_test, 170)
  expect_gt(v2$overall$accuracy, 0.8)  # 同一分布のサブサンプルなので高精度のはず
})

test_that("連続目的変数: RMSE / R2 が直接計算と一致する", {
  skip_if_not_installed("ggplot2")
  data(diamonds, package = "ggplot2")
  dd <- as.data.frame(diamonds)
  fit_d <- chaid(price ~ carat + cut + color + clarity, data = dd,
                 control = chaid_control(min_parent = 8000, min_child = 3000,
                                         max_depth = 2, n_bins = 5))
  vd <- chaid_validate(fit_d, dd)
  pr <- predict(fit_d, dd)
  rmse_direct <- sqrt(mean((dd$price - pr)^2))
  expect_equal(vd$overall$rmse, rmse_direct, tolerance = 1e-6)
  expect_equal(vd$overall$r2,
               1 - rmse_direct^2 / mean((dd$price - mean(dd$price))^2),
               tolerance = 1e-6)
  # 表示丸め(1e-4)×平均価格スケール
  expect_lt(max(abs(vd$nodes$diff_rate), na.rm = TRUE), 0.51)
})

test_that("頻度重み: Titanic 集計データで n_test が総頻度になる", {
  tit <- as.data.frame(Titanic)
  fit_t <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq)
  vt <- chaid_validate(fit_t, tit, freq = tit$Freq)
  expect_identical(vt$n_test, 2201)
  expect_lt(max(abs(vt$nodes$diff_rate), na.rm = TRUE), 1e-3)
})

test_that("print がエラーなく動き、目的変数のない newdata はエラー", {
  fit <- fit_penguins_default()
  v <- chaid_validate(fit, penguins)
  out <- capture.output(print(v))
  expect_match(out, "stability assessment", all = FALSE)
  expect_snapshot(error = TRUE, chaid_validate(fit, data.frame(a = 1)))
})
