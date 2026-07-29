# 予測変数間の多重比較補正（adjust_across）のテスト

node_signature2 <- function(fit) {
  lapply(fit$nodes, function(nd) {
    list(parent = nd$parent, depth = nd$depth, Nf = nd$Nf,
         var = if (is.null(nd$split)) NA_character_ else nd$split$var,
         groups = if (is.null(nd$split)) NULL else nd$split$groups,
         p_final = if (is.null(nd$split)) NA_real_ else round(nd$split$p_final, 12))
  })
}
n_nodes <- function(fit) length(fit$nodes)

# 多変数データ: Titanic 個票 + ノイズ factor 3 本
make_titanic_noise <- function() {
  set.seed(99)
  tit <- as.data.frame(Titanic)
  tit_exp <- tit[rep(seq_len(nrow(tit)), tit$Freq),
                 c("Class", "Sex", "Age", "Survived")]
  tit_exp$noise1 <- factor(sample(letters[1:3], nrow(tit_exp), replace = TRUE))
  tit_exp$noise2 <- factor(sample(letters[1:4], nrow(tit_exp), replace = TRUE))
  tit_exp$noise3 <- factor(sample(letters[1:2], nrow(tit_exp), replace = TRUE))
  tit_exp
}
fml_noise <- Survived ~ Class + Sex + Age + noise1 + noise2 + noise3

test_that("後方互換: 既定は 'none' で従来と同一の木・p_final == p_adj", {
  expect_identical(chaid_control()$adjust_across, "none")
  ctl0 <- chaid_control(min_parent = 30, min_child = 10)
  fit_def <- chaid(Species ~ ., data = iris, control = ctl0)
  fit_none <- chaid(Species ~ ., data = iris,
                    control = chaid_control(min_parent = 30, min_child = 10,
                                            adjust_across = "none"))
  expect_identical(node_signature2(fit_def), node_signature2(fit_none))
  for (nd in fit_def$nodes) {
    if (!is.null(nd$split)) {
      expect_equal(nd$split$p_final, nd$split$p_adj, tolerance = 1e-15)
      expect_gte(nd$split$n_family, 1)
    }
  }
})

test_that("p.adjust との数値一致: family を手動再構成して照合する", {
  for (m in c("holm", "hochberg", "hommel", "BH", "BY", "bonferroni")) {
    ctl_m <- chaid_control(min_parent = 30, min_child = 10, adjust_across = m)
    fit_m <- chaid(Species ~ ., data = iris, control = ctl_m)
    s <- fit_m$nodes[[1]]$split
    expect_type(s, "list")
    # ルートノードの family を手動再構成（学習時と同じコード体系を使う）
    y <- factor(iris$Species)
    ones <- rep(1, 150)
    p_vec <- numeric(0)
    vars <- character(0)
    for (p in fit_m$predictors) {
      res <- merge_predictor(p$code, y, ones, ones, p$ptype, p$float_code,
                             "chaid", "factor", ctl_m)
      if (is.null(res)) next
      p_vec <- c(p_vec, res$p_adj)
      vars <- c(vars, p$name)
    }
    expect_identical(s$n_family, length(p_vec))
    p_ref <- stats::p.adjust(p_vec, method = m)[match(s$var, vars)]
    expect_equal(s$p_final, p_ref, tolerance = 1e-12,
                 label = sprintf("p_final (method = %s)", m))
  }
})

test_that("決定同値: holm と bonferroni は常に同一の木を与える", {
  tit_exp <- make_titanic_noise()
  f_holm <- chaid(fml_noise, data = tit_exp,
                  control = chaid_control(adjust_across = "holm"))
  f_bonf <- chaid(fml_noise, data = tit_exp,
                  control = chaid_control(adjust_across = "bonferroni"))
  expect_identical(node_signature2(f_holm), node_signature2(f_bonf))
})

test_that("入れ子性: 補正が厳しいほど木は小さい", {
  # none >= BH >= hochberg >= holm。
  # 境界的な分割で差が出やすいよう alpha_split を厳しめに設定
  tit_exp <- make_titanic_noise()
  fit_t <- function(m, alpha = 0.05) {
    chaid(fml_noise, data = tit_exp,
          control = chaid_control(alpha_split = alpha, adjust_across = m))
  }
  f_none <- fit_t("none", alpha = 0.01)
  f_bh <- fit_t("BH", alpha = 0.01)
  f_hoch <- fit_t("hochberg", alpha = 0.01)
  f_holm2 <- fit_t("holm", alpha = 0.01)
  expect_gte(n_nodes(f_none), n_nodes(f_bh))
  expect_gte(n_nodes(f_bh), n_nodes(f_hoch))
  expect_gte(n_nodes(f_hoch), n_nodes(f_holm2))
  # ルートの分割変数は補正に依存しない（選択は補正前 p_adj で行うため）
  expect_identical(f_none$nodes[[1]]$split$var, f_holm2$nodes[[1]]$split$var)
})

test_that("family 除外: 定数予測変数は検定不能なので family に数えない", {
  iris_c <- iris
  iris_c$constant <- factor("only")
  fit_c <- chaid(Species ~ ., data = iris_c,
                 control = chaid_control(min_parent = 30, min_child = 10,
                                         adjust_across = "holm"))
  expect_identical(fit_c$nodes[[1]]$split$n_family, 4L)  # iris の4変数のみ
})

test_that("min_child 吸収が起きる設定でも p_final が有限で記録される", {
  fit_ab <- chaid(Species ~ ., data = iris,
                  control = chaid_control(min_parent = 30, min_child = 40,
                                          adjust_across = "BH"))
  for (nd in fit_ab$nodes) {
    if (!is.null(nd$split)) expect_lt(nd$split$p_final, Inf)
  }
})

test_that("print: adjust_across 有効時のみ final.p を表示する", {
  tit_exp <- make_titanic_noise()
  f_bh <- chaid(fml_noise, data = tit_exp,
                control = chaid_control(alpha_split = 0.01,
                                        adjust_across = "BH"))
  fit_def <- chaid(Species ~ ., data = iris,
                   control = chaid_control(min_parent = 30, min_child = 10))
  out_bh <- capture.output(print(f_bh))
  expect_match(out_bh, "final.p", fixed = TRUE, all = FALSE)
  out_def <- capture.output(print(fit_def))
  expect_no_match(out_def, "final.p", fixed = TRUE)
})
