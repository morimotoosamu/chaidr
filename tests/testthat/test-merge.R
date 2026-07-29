# 結合フェーズのユニットテスト

ctl <- chaid_control(min_parent = 2, min_child = 1)

# 玩具データ: カテゴリ 1 と 2 は y 分布が同一、カテゴリ 3 だけ異なる
make_toy <- function(n_per = 60) {
  xcode <- rep(1:3, each = n_per)
  y <- factor(c(
    rep(c("a", "b"), c(30, 30)),   # cat1: 50/50
    rep(c("a", "b"), c(30, 30)),   # cat2: 50/50（cat1 と同一分布）
    rep(c("a", "b"), c(55, 5))     # cat3: 92/8
  ))
  list(xcode = xcode, y = y, w = rep(1, 3 * n_per), f = rep(1, 3 * n_per))
}

group_keys <- function(res) {
  vapply(res$groups, function(g) paste(g, collapse = ","), character(1))
}

test_that("標準CHAID（名義型）: 類似カテゴリ 1,2 が統合され {1,2}|{3} になる", {
  d <- make_toy()
  res <- merge_predictor(d$xcode, d$y, d$w, d$f, ptype = "nominal",
                         float_code = NA_integer_, method = "chaid",
                         ytype = "factor", control = ctl)
  expect_length(res$groups, 2)
  expect_setequal(group_keys(res), c("1,2", "3"))
  # 乗数は名義 I=3, r=2 → S(3,2) = 3
  expect_identical(res$B, 3)
  expect_lte(res$p_adj, 1)
  expect_gte(res$p_adj, res$p_unadj)
})

test_that("順序型は隣接ペアのみ結合可能", {
  # cat1 と cat3 が同一分布、cat2 だけ異なるデータでは、順序型は {1},{2},{3} のまま
  xcode2 <- rep(1:3, each = 60)
  y2 <- factor(c(rep(c("a", "b"), c(55, 5)),
                 rep(c("a", "b"), c(30, 30)),
                 rep(c("a", "b"), c(55, 5))))
  res2 <- merge_predictor(xcode2, y2, rep(1, 180), rep(1, 180), "ordinal",
                          NA_integer_, "chaid", "factor", ctl)
  expect_length(res2$groups, 3)  # 1-2, 2-3 とも有意差あり → 統合なし

  # 一方、名義型なら 1 と 3 が統合される
  res2n <- merge_predictor(xcode2, y2, rep(1, 180), rep(1, 180), "nominal",
                           NA_integer_, "chaid", "factor", ctl)
  expect_setequal(group_keys(res2n), c("1,3", "2"))
})

test_that("alpha_merge 境界: 0 で常に統合、1 で統合なし", {
  d <- make_toy()
  # alpha_merge = 0 なら p > 0 の限り常に統合され 2 グループまで進む
  ctl_all <- chaid_control(alpha_merge = 0, min_parent = 2, min_child = 1)
  res3 <- merge_predictor(d$xcode, d$y, d$w, d$f, "nominal", NA_integer_,
                          "chaid", "factor", ctl_all)
  expect_length(res3$groups, 2)

  # alpha_merge = 1 なら p が 1 を超えることはなく統合は一切起きない
  ctl_none <- chaid_control(alpha_merge = 1, min_parent = 2, min_child = 1)
  res4 <- merge_predictor(d$xcode, d$y, d$w, d$f, "nominal", NA_integer_,
                          "chaid", "factor", ctl_none)
  expect_length(res4$groups, 3)
})

test_that("Exhaustive は全履歴から p 最小の構成を選ぶ", {
  d <- make_toy()
  res5 <- merge_predictor(d$xcode, d$y, d$w, d$f, "nominal", NA_integer_,
                          "exhaustive", "factor", ctl)
  expect_setequal(group_keys(res5), c("1,2", "3"))  # {1,2}|{3} が最有意
  # Exhaustive 乗数は I=3 名義 → 3*(9-1)/2 = 12
  expect_identical(res5$B, 12)

  # Exhaustive は alpha_merge に依存しない
  ctl_none <- chaid_control(alpha_merge = 1, min_parent = 2, min_child = 1)
  res5b <- merge_predictor(d$xcode, d$y, d$w, d$f, "nominal", NA_integer_,
                           "exhaustive", "factor", ctl_none)
  expect_identical(res5$groups, res5b$groups)

  # exhaustive_adjust = "biggs": グループ構成は同じまま乗数だけ 1/3 になる
  ctl_biggs <- chaid_control(exhaustive_adjust = "biggs",
                             min_parent = 2, min_child = 1)
  res5c <- merge_predictor(d$xcode, d$y, d$w, d$f, "nominal", NA_integer_,
                           "exhaustive", "factor", ctl_biggs)
  expect_identical(res5$groups, res5c$groups)
  expect_identical(res5c$B, 4)            # I=3 名義: 3*(9-1)/6 = 4
  expect_lte(res5c$p_adj, res5$p_adj)     # biggs の方が緩い補正
})

test_that("Exhaustive: 初期構成（結合なし）が最有意ならそれを保持する", {
  xcode2 <- rep(1:3, each = 60)
  y2 <- factor(c(rep(c("a", "b"), c(55, 5)),
                 rep(c("a", "b"), c(30, 30)),
                 rep(c("a", "b"), c(55, 5))))
  res6 <- merge_predictor(xcode2, y2, rep(1, 180), rep(1, 180), "nominal",
                          NA_integer_, "exhaustive", "factor", ctl)
  expect_setequal(group_keys(res6), c("1,3", "2"))
})

test_that("Floating: NA カテゴリは分布の近いカテゴリへ統合される", {
  # NA の y 分布が cat3 と同じ → cat3 側へ統合されるはず
  xcode_f <- c(rep(1:3, each = 60), rep(4L, 30))  # 4 = "<NA>"
  y_f <- factor(c(rep(c("a", "b"), c(30, 30)),
                  rep(c("a", "b"), c(32, 28)),
                  rep(c("a", "b"), c(55, 5)),
                  rep(c("a", "b"), c(27, 3))))    # NA: 90/10 ≒ cat3
  res7 <- merge_predictor(xcode_f, y_f, rep(1, 210), rep(1, 210), "ordinal",
                          4L, "chaid", "factor", ctl)
  na_group <- res7$groups[[which(vapply(res7$groups, function(g) 4L %in% g,
                                        logical(1)))]]
  expect_contains(na_group, 3L)        # NA は cat3 を含むグループへ
  expect_identical(res7$ptype_eff, "floating")

  # NA の分布がどのカテゴリとも大きく異なる → 独立カテゴリとして残る
  y_f2 <- factor(c(rep(c("a", "b"), c(30, 30)),
                   rep(c("a", "b"), c(32, 28)),
                   rep(c("a", "b"), c(55, 5)),
                   rep(c("a", "b"), c(1, 29))))   # NA: 3/97 どこにも似ていない
  res8 <- merge_predictor(xcode_f, y_f2, rep(1, 210), rep(1, 210), "ordinal",
                          4L, "chaid", "factor", ctl)
  na_group8 <- res8$groups[[which(vapply(res8$groups, function(g) 4L %in% g,
                                         logical(1)))]]
  expect_identical(na_group8, 4L)      # 独立のまま
})

test_that("実在カテゴリ 1 つなら分割不能（NULL）", {
  d <- make_toy()
  expect_null(merge_predictor(rep(1L, 50), d$y[1:50], rep(1, 50), rep(1, 50),
                              "nominal", NA_integer_, "chaid", "factor", ctl))
})

test_that("連続目的変数（F 検定経路）でも結合が動く", {
  set.seed(123)
  d <- make_toy()
  yn <- c(rnorm(60, 0), rnorm(60, 0.1), rnorm(60, 5))
  res9 <- merge_predictor(d$xcode, yn, d$w, d$f, "nominal", NA_integer_,
                          "chaid", "numeric", ctl)
  expect_setequal(group_keys(res9), c("1,2", "3"))
})
