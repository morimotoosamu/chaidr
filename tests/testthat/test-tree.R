# 木構築・API・predict の結合テスト
# fit_iris_default は helper-fixtures.R で定義

test_that("iris（連続予測 × カテゴリカル目的）は Petal 系で分割される", {
  fit <- fit_iris_default()
  expect_s3_class(fit, "chaid")
  root <- fit$nodes[[1]]
  expect_type(root$split, "list")
  expect_contains(c("Petal.Length", "Petal.Width"), root$split$var)
  expect_lte(root$split$p_adj, 0.05)
})

test_that("predict の自己一致精度が訓練データで 90% 以上", {
  fit <- fit_iris_default()
  pr <- predict(fit, iris)
  expect_s3_class(pr, "factor")
  expect_identical(levels(pr), levels(iris$Species))
  expect_gt(mean(pr == iris$Species), 0.9)

  # type="prob" は行和 1 の行列
  pp <- predict(fit, iris, type = "prob")
  expect_identical(dim(pp), c(150L, 3L))
  expect_equal(rowSums(pp), rep(1, 150), tolerance = 1e-12,
               ignore_attr = TRUE)

  # type="node" は末端ノード id
  nn <- predict(fit, iris, type = "node")
  expect_identical(vapply(fit$nodes[nn], function(x) is.null(x$split),
                          logical(1)),
                   rep(TRUE, 150))
})

test_that("整数パラメータの検証: 非整数値はエラー", {
  expect_snapshot(error = TRUE, chaid_control(max_depth = 3.7))
  expect_snapshot(error = TRUE, chaid_control(n_bins = 5.5))
  expect_snapshot(error = TRUE, chaid_control(max_iter = 100.5))
  expect_snapshot(error = TRUE, chaid_control(max_depth = NA))
  # 整数値の numeric（3.0）は受理される
  expect_s3_class(chaid_control(max_depth = 3.0), "chaid_control")
})

test_that("停止規則: max_depth = 1 では深さ 2 のノードが存在しない", {
  fit_d1 <- chaid(Species ~ ., data = iris,
                  control = chaid_control(max_depth = 1, min_parent = 30,
                                          min_child = 10))
  expect_lte(max(vapply(fit_d1$nodes, function(n) n$depth, integer(1))), 1)
})

test_that("停止規則: min_parent が巨大なら分割されない", {
  fit_np <- chaid(Species ~ ., data = iris,
                  control = chaid_control(min_parent = 1000))
  expect_null(fit_np$nodes[[1]]$split)
  expect_identical(fit_np$nodes[[1]]$terminal_reason, "min_parent")
})

test_that("min_child: 子ノードは全て min_child 以上", {
  fit2 <- chaid(Species ~ ., data = iris,
                control = chaid_control(min_parent = 30, min_child = 20))
  child_nf <- vapply(Filter(function(nd) !is.na(nd$parent), fit2$nodes),
                     function(nd) nd$Nf, numeric(1))
  expect_gte(min(child_nf), 20)
})

test_that("連続目的変数（回帰木）が学習・予測できる", {
  set.seed(7)
  n <- 400
  xnum <- runif(n)
  grp <- factor(sample(c("p", "q", "r"), n, replace = TRUE))
  ycont <- ifelse(grp == "r", 5, 0) + xnum * 2 + rnorm(n, sd = 0.3)
  dreg <- data.frame(y = ycont, xnum = xnum, grp = grp)
  fitr <- chaid(y ~ xnum + grp, data = dreg,
                control = chaid_control(min_parent = 50, min_child = 20))
  expect_type(fitr$nodes[[1]]$split, "list")
  expect_identical(fitr$nodes[[1]]$split$var, "grp")  # 効果が最大の変数
  prr <- predict(fitr, dreg)
  expect_type(prr, "double")
  expect_gt(cor(prr, ycont), 0.8)
})

test_that("頻度重み: 集計データと展開データで木が完全一致する", {
  tit <- as.data.frame(Titanic)
  tit_exp <- tit[rep(seq_len(nrow(tit)), tit$Freq),
                 c("Class", "Sex", "Age", "Survived")]
  fit_agg <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq)
  fit_exp <- chaid(Survived ~ Class + Sex + Age, data = tit_exp)

  node_signature <- function(fit) {
    lapply(fit$nodes, function(nd) {
      list(parent = nd$parent, depth = nd$depth, Nf = nd$Nf,
           var = if (is.null(nd$split)) NA_character_ else nd$split$var,
           groups = if (is.null(nd$split)) NULL else nd$split$groups,
           p_adj = if (is.null(nd$split)) NA_real_ else round(nd$split$p_adj, 12))
    })
  }
  expect_identical(node_signature(fit_agg), node_signature(fit_exp))
})

test_that("Exhaustive CHAID も同一データで動作し、木が得られる", {
  tit <- as.data.frame(Titanic)
  fit_ex <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq,
                  method = "exhaustive")
  expect_type(fit_ex$nodes[[1]]$split, "list")
  expect_identical(fit_ex$nodes[[1]]$split$var, "Sex")  # Titanic の最強分割は Sex
})

test_that("欠損値（Floating）: NA を含む順序予測変数で学習・予測できる", {
  # 注意: 予測変数 1 本だと「全予測変数欠損ケースは無視」（IBM 仕様）で NA 行が
  # 落ちて Floating が発動しないため、ダミー変数を加えて NA 行を保持させる
  set.seed(7)
  dna <- data.frame(y = iris$Species, pl = iris$Petal.Length,
                    noise = runif(150))
  dna$pl[sample(150, 20)] <- NA
  fit_na <- chaid(y ~ pl + noise, data = dna,
                  control = chaid_control(min_parent = 30, min_child = 10))
  expect_identical(fit_na$n, 150L)              # NA 行は除外されない
  expect_type(fit_na$nodes[[1]]$split, "list")
  expect_identical(fit_na$nodes[[1]]$split$var, "pl")
  # 分割グループのどこかに <NA> カテゴリ（float_code）が必ず入っている
  na_code <- fit_na$predictors$pl$float_code
  expect_false(is.na(na_code))
  expect_contains(unlist(fit_na$nodes[[1]]$split$groups), na_code)
  pr_na <- predict(fit_na, dna)
  expect_false(anyNA(pr_na))

  # 予測変数 1 本のときは全予測変数欠損ルールにより NA 行が除外される（IBM 仕様）
  fit_na1 <- chaid(y ~ pl, data = dna,
                   control = chaid_control(min_parent = 30, min_child = 10))
  expect_identical(fit_na1$n, 130L)
  expect_identical(fit_na1$n_dropped, 20L)
})

test_that("名義型予測変数の NA は通常カテゴリとして扱われる", {
  set.seed(7)
  dna2 <- data.frame(y = iris$Species,
                     g = factor(sample(c("u", "v"), 150, replace = TRUE)))
  dna2$g[sample(150, 30)] <- NA
  fit_na2 <- chaid(y ~ g, data = dna2,
                   control = chaid_control(min_parent = 30, min_child = 10))
  expect_s3_class(fit_na2, "chaid")  # エラーなく学習できる
})

test_that("ケース重み: weights を付けても実行できる", {
  set.seed(7)
  wts <- runif(150, 0.5, 2)
  fit_w <- chaid(Species ~ ., data = iris, weights = wts,
                 control = chaid_control(min_parent = 30, min_child = 10))
  expect_type(fit_w$nodes[[1]]$split, "list")
})

test_that("print / summary がエラーなく出力される", {
  fit <- fit_iris_default()
  out <- capture.output(print(fit))
  expect_gt(length(out), 3)
  expect_match(out, "root", all = FALSE)
  out2 <- capture.output(summary(fit))
  expect_match(out2, "Terminal nodes", all = FALSE)
})

test_that("未知水準の予測はフォールバックし警告が出る", {
  set.seed(7)
  dna2 <- data.frame(y = iris$Species,
                     g = factor(sample(c("u", "v"), 150, replace = TRUE)))
  dna2$g[sample(150, 30)] <- NA
  fit_na2 <- chaid(y ~ g, data = dna2,
                   control = chaid_control(min_parent = 30, min_child = 10))
  nd_new <- data.frame(g = factor("zzz"))
  expect_snapshot(res_unk <- predict(fit_na2, nd_new))
  expect_length(res_unk, 1)
  expect_false(is.na(res_unk))
})
