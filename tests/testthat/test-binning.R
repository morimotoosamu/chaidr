# 分位ビン分割のユニットテスト

test_that("等重みの 1..100 は 10 ビンへ均等分割される", {
  b <- bin_continuous(1:100, rep(1, 100), k = 10L)
  expect_identical(b$nbins, 10L)
  expect_identical(b$breaks, as.numeric(seq(10, 100, by = 10)))
  expect_identical(b$xbin, rep(1:10, each = 10))
})

test_that("単一値への 50% 集中はビン数を縮小させる", {
  x <- c(rep(5, 50), 6:55)
  b <- bin_continuous(x, rep(1, 100), k = 10L)
  expect_lt(b$nbins, 10)
  # 値 5 は必ず単独 1 ビン目
  expect_identical(unique(b$xbin[x == 5]), 1L)
  expect_gt(min(b$xbin[x != 5]), 1)
})

test_that("ユニーク値 4 個なら 4 ビン", {
  x <- rep(c(10, 20, 30, 40), each = 25)
  b <- bin_continuous(x, rep(1, 100), k = 10L)
  expect_identical(b$nbins, 4L)
  expect_identical(b$breaks, c(10, 20, 30, 40))
})

test_that("重み付きビン分割の手計算例が一致する", {
  # 値 1,2,3,4 に重み 4,4,1,1（W=10, k=2 → 分位点 0.5, 1.0）
  # S = 0.4, 0.8, 0.9, 1.0 → idx = ceil(2S) = 1, 2, 2, 2 → 2 ビン、境界 1 | 4
  b <- bin_continuous(c(1, 2, 3, 4), c(4, 4, 1, 1), k = 2L)
  expect_identical(b$nbins, 2L)
  expect_identical(b$breaks, c(1, 4))
  expect_identical(b$xbin, c(1L, 2L, 2L, 2L))
})

test_that("NA はビン化されず NA のまま", {
  b <- bin_continuous(c(1, NA, 3, 4), rep(1, 4), k = 2L)
  expect_identical(is.na(b$xbin), c(FALSE, TRUE, FALSE, FALSE))
})

test_that("bin_apply は学習境界で再割当する（上側境界は含む、範囲外は端へ丸め）", {
  breaks <- c(10, 20, 30)
  expect_identical(bin_apply(c(5, 10, 10.5, 20, 25, 30, 99), breaks),
                   c(1L, 1L, 2L, 2L, 3L, 3L, 3L))
  expect_identical(bin_apply(NA_real_, breaks), NA_integer_)
})
