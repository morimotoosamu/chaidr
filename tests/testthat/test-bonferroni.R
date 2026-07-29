# Bonferroni 乗数のユニットテスト

test_that("スターリング数の既知値が一致する", {
  expect_identical(stirling2(0, 0), 1)
  expect_identical(stirling2(4, 2), 7)
  expect_identical(stirling2(4, 4), 1)
  expect_identical(stirling2(5, 3), 25)
  expect_identical(stirling2(10, 3), 9330)
  expect_identical(stirling2(3, 0), 0)
})

test_that("漸化式と交代和（IBM文書の閉形式）が I <= 15 で一致する", {
  stirling2_altsum <- function(n, k) {
    v <- 0:(k - 1)
    sum((-1)^v * (k - v)^n / (factorial(v) * factorial(k - v)))
  }
  for (n in 1:15) {
    for (k in 1:n) {
      expect_equal(stirling2(n, k), stirling2_altsum(n, k),
                   tolerance = 1e-6, label = sprintf("stirling2(%d, %d)", n, k))
    }
  }
})

test_that("標準 CHAID の Bonferroni 乗数の既知値が一致する", {
  expect_identical(bonferroni_multiplier(4, 2, "ordinal", "chaid"), 3)   # C(3,1)
  expect_identical(bonferroni_multiplier(4, 2, "nominal", "chaid"), 7)   # S(4,2)
  expect_identical(bonferroni_multiplier(4, 2, "floating", "chaid"), 5)  # C(2,0)+2*C(2,1)
  expect_identical(bonferroni_multiplier(5, 3, "ordinal", "chaid"), 6)   # C(4,2)
  expect_identical(bonferroni_multiplier(5, 3, "nominal", "chaid"), 25)  # S(5,3)
})

test_that("r = I なら乗数 1（結合なし）", {
  for (pt in c("ordinal", "nominal", "floating")) {
    expect_identical(bonferroni_multiplier(4, 4, pt, "chaid"), 1)
  }
})

test_that("Exhaustive CHAID の乗数は r 非依存で I のみで決まる", {
  for (r in 2:7) {
    expect_identical(bonferroni_multiplier(8, r, "ordinal", "exhaustive"), 28)   # 8*7/2
    expect_identical(bonferroni_multiplier(8, r, "nominal", "exhaustive"), 252)  # 8*63/2
    expect_identical(bonferroni_multiplier(8, r, "floating", "exhaustive"), 28)
  }
})

test_that("exhaustive_adjust = 'biggs' は名義型のみ SPSS 版の 1/3 になる", {
  # 名義型のみ I(I^2-1)/6。順序・浮動は両者同一
  for (r in 2:7) {
    expect_identical(bonferroni_multiplier(8, r, "nominal", "exhaustive", "biggs"), 84)
    expect_identical(bonferroni_multiplier(8, r, "ordinal", "exhaustive", "biggs"), 28)
    expect_identical(bonferroni_multiplier(8, r, "floating", "exhaustive", "biggs"), 28)
  }
  # biggs 版は結合列の全ペア検定数 Σ_{k=2}^{I} C(k,2) と一致するはず
  for (I in 3:12) {
    n_tests <- sum(vapply(2:I, function(k) choose(k, 2), numeric(1)))
    expect_identical(bonferroni_multiplier(I, 2, "nominal", "exhaustive", "biggs"),
                     n_tests)
  }
  # 標準 CHAID は exhaustive_adjust の影響を受けない
  expect_identical(bonferroni_multiplier(4, 2, "nominal", "chaid", "biggs"), 7)
})

test_that("不正入力（r > I）はエラー", {
  expect_snapshot(error = TRUE, bonferroni_multiplier(3, 4, "ordinal", "chaid"))
})
