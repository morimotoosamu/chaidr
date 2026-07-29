# ノード要約テーブル・ルール抽出・変数重要度のテスト

# r 形式ルールをデータ上で評価し、該当行番号を返す（NA は FALSE 扱い）
match_rule <- function(rule, data) {
  v <- eval(parse(text = rule), envir = data)
  if (length(v) == 1) v <- rep(v, nrow(data))
  v[is.na(v)] <- FALSE
  which(v)
}

# ルールとノード割当の厳密一致を検証する共通チェック
check_rules_exact <- function(fit, data) {
  nid <- predict(fit, data, type = "node")
  rules <- chaid_rules(fit, format = "r")
  for (k in seq_len(nrow(rules))) {
    expected <- which(nid == rules$node[k])
    got <- match_rule(rules$rule[k], data)
    expect_identical(got, expected,
                     label = sprintf("rule for node %d", rules$node[k]))
  }
}

test_that("penguins: ビン化連続変数 + Floating NA を含むルールが厳密一致する", {
  fit_p <- fit_penguins_default()
  check_rules_exact(fit_p, penguins)
})

test_that("Titanic exhaustive: 同一変数の再分割パスで intersect が効く", {
  tit <- as.data.frame(Titanic)
  tit_exp <- tit[rep(seq_len(nrow(tit)), tit$Freq),
                 c("Class", "Sex", "Age", "Survived")]
  fit_t <- chaid(Survived ~ Class + Sex + Age, data = tit_exp,
                 method = "exhaustive")
  # Class → Class の再分割が存在することを前提確認
  paths_reuse <- any(vapply(fit_t$nodes, function(nd) {
    if (is.null(nd$split) || is.na(nd$parent)) return(FALSE)
    par <- fit_t$nodes[[nd$parent]]
    !is.null(par$split) && par$split$var == nd$split$var
  }, logical(1)))
  expect_true(paths_reuse)
  check_rules_exact(fit_t, tit_exp)
})

test_that("diamonds: 順序 factor + ビン化のルールが厳密一致する", {
  skip_if_not_installed("ggplot2")
  data(diamonds, package = "ggplot2")
  dd <- as.data.frame(diamonds)
  fit_d <- chaid(price ~ carat + cut + color + clarity, data = dd,
                 control = chaid_control(min_parent = 8000, min_child = 3000,
                                         max_depth = 2, n_bins = 5))
  # 行数が多いので先頭 5000 行で照合
  check_rules_exact(fit_d, dd[1:5000, ])
})

test_that("sql / text 形式が空でなく変数名を含む", {
  fit_p <- fit_penguins_default()
  for (fmt in c("sql", "text")) {
    r <- chaid_rules(fit_p, format = fmt)
    expect_gt(nrow(r), 0)
    expect_gt(min(nchar(r$rule)), 0)
    expect_match(r$rule, "flipper_len", all = FALSE)
  }
  # 存在しないノード id はエラー
  expect_snapshot(error = TRUE, chaid_rules(fit_p, nodes = 999))
})

test_that("chaid_table が root 基準の要約を返す", {
  fit_p <- fit_penguins_default()
  tb <- chaid_table(fit_p)
  expect_identical(tb$node[1], 1L)
  expect_identical(tb$rule[1], "(root)")
  # 末端ノードの n 合計 = root の n
  expect_identical(sum(tb$n[-1]), tb$n[1])
  # クラス構成比は各行で和が 1（表は4桁丸めのため許容 1e-3）
  pcols <- grep("^p_", names(tb))
  expect_equal(rowSums(tb[, pcols]), rep(1, nrow(tb)), tolerance = 1e-3,
               ignore_attr = TRUE)
  # target 指定: root の index = 100
  tb2 <- chaid_table(fit_p, target = "Gentoo")
  expect_identical(tb2$index[1], 100)
  expect_contains(names(tb2), c("response_rate", "index"))
})

test_that("chaid_table: 連続目的変数と分割なしの木", {
  skip_if_not_installed("ggplot2")
  data(diamonds, package = "ggplot2")
  dd <- as.data.frame(diamonds)
  fit_d <- chaid(price ~ carat + cut + color + clarity, data = dd,
                 control = chaid_control(min_parent = 8000, min_child = 3000,
                                         max_depth = 2, n_bins = 5))
  tbd <- chaid_table(fit_d)
  expect_contains(names(tbd), c("mean", "sd", "index"))
  expect_identical(tbd$index[1], 100)
  # 分割なしの木は root のみ
  fit_null <- chaid(species ~ ., data = penguins,
                    control = chaid_control(min_parent = 10000))
  tb0 <- chaid_table(fit_null)
  expect_identical(nrow(tb0), 1L)
})

test_that("chaid_importance が p 値ベースの重要度を返す", {
  fit_p <- fit_penguins_default()
  imp <- chaid_importance(fit_p)
  expect_gte(nrow(imp), 1)
  expect_equal(sum(imp$importance_pct), 100, tolerance = 0.005)  # 丸め誤差許容
  expect_identical(imp$variable[1], "flipper_len")  # root 分割の変数が最重要
  expect_false(is.unsorted(rev(imp$importance)))    # 降順
  expect_identical(sum(imp$n_splits),
                   sum(vapply(fit_p$nodes, function(nd) !is.null(nd$split),
                              logical(1))))
  # 分割なしの木では空
  fit_null <- chaid(species ~ ., data = penguins,
                    control = chaid_control(min_parent = 10000))
  expect_identical(nrow(chaid_importance(fit_null)), 0L)
})
