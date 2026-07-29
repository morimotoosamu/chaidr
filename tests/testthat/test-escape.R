# 特殊文字（< > & " など）を含む水準名でのエスケープ回帰テスト

make_escape_fit <- function() {
  d_esc <- data.frame(
    y = factor(rep(c("A", "B"), each = 60)),
    x = factor(rep(c("R&D", "pre<post", "quo\"te"), 40))
  )
  list(data = d_esc,
       fit = chaid(y ~ x, data = d_esc,
                   control = chaid_control(min_parent = 10, min_child = 5,
                                           alpha_split = 1,
                                           bonferroni = FALSE)))
}

test_that("esc_html が < > & をエンティティ化する", {
  expect_identical(esc_html("R&D"), "R&amp;D")
  expect_identical(esc_html("a<b>c"), "a&lt;b&gt;c")
  # 既存エンティティは二重エスケープになる（プレースホルダなしのシンプル版）
  expect_identical(esc_html("&amp;"), "&amp;amp;")
  expect_identical(esc_html(c("a<", "b&", "c>")), c("a&lt;", "b&amp;", "c&gt;"))
})

test_that("esc_dot はプレースホルダ経由の2段階置換で二重エスケープを回避する", {
  expect_identical(esc_dot("R&D"), "R&amp;D")
  expect_identical(esc_dot("a<b>c"), "a&lt;b&gt;c")
  expect_identical(esc_dot("&amp;"), "&amp;amp;")  # `&amp;` の `&` だけエスケープ
  expect_identical(esc_dot("\"quote\""), "\\\"quote\\\"")
  # 複数の & が並んでも二重エスケープにならない
  expect_identical(esc_dot("R&D & QA"), "R&amp;D &amp; QA")
})

test_that("特殊文字を含む factor level で chaid_dot が有効な DOT を返す", {
  fit_esc <- make_escape_fit()$fit
  dot <- unclass(chaid_dot(fit_esc))
  expect_match(dot, "^digraph")
  # 元の水準名（`<` / `&`）は生では出現しない
  expect_no_match(dot, "pre<post", fixed = TRUE)
  expect_no_match(dot, "R&D", fixed = TRUE)
  expect_match(dot, "R&amp;D", fixed = TRUE)
  expect_match(dot, "pre&lt;post", fixed = TRUE)
})

test_that("特殊文字を含む水準でも r 形式ルールのノード割当が一致する", {
  esc <- make_escape_fit()
  nid <- predict(esc$fit, esc$data, type = "node")
  rules <- chaid_rules(esc$fit, format = "r")
  for (k in seq_len(nrow(rules))) {
    v <- eval(parse(text = rules$rule[k]), envir = esc$data)
    if (length(v) == 1) v <- rep(v, nrow(esc$data))
    v[is.na(v)] <- FALSE
    expect_identical(which(v), which(nid == rules$node[k]),
                     label = sprintf("rule for node %d", rules$node[k]))
  }
})

test_that("plotly hover の HTML エスケープが効いている", {
  skip_if_not_installed("plotly")
  fit_esc <- make_escape_fit()$fit
  # chaid_plotly() の hover 文字列は plotly ハンドラ内で生成されるため、
  # plotly_build() で最終レンダリング直前のデータを取り出して検証する
  pw <- chaid_plotly(fit_esc)
  expect_s3_class(pw, "plotly")
  built <- plotly::plotly_build(pw)
  hover_texts <- unlist(lapply(built$x$data, function(tr) {
    if (any(tr$hoverinfo == "text", na.rm = TRUE)) tr$text else NULL
  }))
  expect_gt(length(hover_texts), 0)
  # ユーザーデータ由来の `<`/`&` は全てエンティティ化されている
  expect_match(hover_texts, "&lt;", fixed = TRUE, all = FALSE)
  expect_match(hover_texts, "&amp;", fixed = TRUE, all = FALSE)
  expect_no_match(hover_texts, "pre<post", fixed = TRUE)
  expect_no_match(hover_texts, "R&D", fixed = TRUE)
})
