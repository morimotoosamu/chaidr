# Graphviz (DOT) / plotly 可視化のテスト
# fit_penguins_default は helper-fixtures.R で定義

make_reg_fit <- function() {
  set.seed(71)
  dreg <- data.frame(y = rnorm(300) + rep(c(0, 3, 6), each = 100),
                     g = factor(rep(c("a", "b", "c"), each = 100)))
  list(data = dreg,
       fit = chaid(y ~ g, data = dreg,
                   control = chaid_control(min_parent = 50, min_child = 20)))
}

test_that("chaid_dot が有効な DOT 構造を返す", {
  fit <- fit_penguins_default()
  dot <- chaid_dot(fit)
  expect_s3_class(dot, "chaid_dot")
  expect_match(unclass(dot), "^digraph")
  # ノード定義数 = 木のノード数（凡例は別名なので数えない）
  dot_lines <- strsplit(unclass(dot), "\n")[[1]]
  expect_identical(sum(grepl("^  n[0-9]+ \\[label=", dot_lines)),
                   length(fit$nodes))
  # エッジ数 = 子ノードの総数
  n_edges <- sum(vapply(fit$nodes, function(nd) {
    if (is.null(nd$split)) 0L else length(nd$split$children)
  }, integer(1)))
  expect_identical(sum(grepl("^  n[0-9]+ -> n[0-9]+", dot_lines)), n_edges)
  # 凡例の有無
  expect_match(unclass(dot), "legend")
  expect_no_match(unclass(chaid_dot(fit, legend = FALSE)), "legend")
  # エッジラベルに Floating の <NA> グループが含まれる（< と > はエスケープ済み）
  expect_match(unclass(dot), "&lt;NA&gt;", fixed = TRUE)
})

test_that("chaid_dot の file 書き出しが動く", {
  fit <- fit_penguins_default()
  tmp <- withr::local_tempfile(fileext = ".gv")
  chaid_dot(fit, file = tmp)
  expect_true(file.exists(tmp))
  expect_match(readLines(tmp, warn = FALSE), "digraph", all = FALSE)
})

test_that("連続目的変数 / 順序目的変数 / 単一ノード木でも DOT を生成できる", {
  reg <- make_reg_fit()
  expect_match(unclass(chaid_dot(reg$fit)), "mean=")

  yord <- cut(reg$data$y, c(-Inf, 1, 4, Inf), labels = c("低", "中", "高"),
              ordered_result = TRUE)
  # 完全な単調分離データなので roweffects の収束警告が出る（既知・無害）
  fit_o <- suppressWarnings(
    chaid(y2 ~ g, data = data.frame(y2 = yord, g = reg$data$g),
          control = chaid_control(min_parent = 50, min_child = 20))
  )
  expect_match(unclass(chaid_dot(fit_o)), "digraph")

  fit_null <- chaid(species ~ ., data = penguins,
                    control = chaid_control(min_parent = 10000))
  expect_match(unclass(chaid_dot(fit_null)), "digraph")
})

test_that("DOT/HTML の特殊文字を含む水準名で壊れない", {
  d_esc <- data.frame(
    y = factor(rep(c("A", "B"), each = 60)),
    x = factor(rep(c('lv"quote', "lv<tag>", "lv&amp"), 40))
  )
  fit_esc <- chaid(y ~ x, data = d_esc,
                   control = chaid_control(min_parent = 10, min_child = 5,
                                           alpha_split = 1,
                                           bonferroni = FALSE))
  dot_esc <- unclass(chaid_dot(fit_esc))
  expect_match(dot_esc, "digraph")
  expect_no_match(dot_esc, "lv<tag>", fixed = TRUE)  # < はエスケープ済みのはず
})

test_that("chaid_graphviz が htmlwidget を返す", {
  skip_if_not_installed("DiagrammeR")
  fit <- fit_penguins_default()
  g <- chaid_graphviz(fit)
  expect_s3_class(g, "htmlwidget")
  expect_s3_class(g, "grViz")
  if (requireNamespace("htmlwidgets", quietly = TRUE)) {
    # saveWidget は HTML と依存ライブラリのフォルダを併設するため
    # 専用の一時ディレクトリごと後始末する
    dir <- withr::local_tempdir()
    tmp <- file.path(dir, "widget.html")
    htmlwidgets::saveWidget(g, tmp, selfcontained = FALSE)
    expect_true(file.exists(tmp))
  }
})

test_that("chaid_plotly が plotly widget を返す", {
  skip_if_not_installed("plotly")
  fit <- fit_penguins_default()
  pw <- chaid_plotly(fit)
  expect_s3_class(pw, "htmlwidget")
  expect_s3_class(pw, "plotly")
  reg <- make_reg_fit()
  pw_r <- chaid_plotly(reg$fit)      # 連続目的変数
  expect_s3_class(pw_r, "plotly")
  fit_null <- chaid(species ~ ., data = penguins,
                    control = chaid_control(min_parent = 10000))
  pw_null <- chaid_plotly(fit_null)  # 単一ノード
  expect_s3_class(pw_null, "plotly")
})
