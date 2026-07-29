# 14_graphviz.R -- Graphviz (DOT) 形式による出版品質の木描画
# chaid_dot() は純 base R で DOT 文字列を生成する。レンダリングは
# chaid_graphviz()（DiagrammeR、viz.js 同梱なので Graphviz バイナリ不要）か、
# .gv ファイルを書き出して外部の `dot -Tpng` / `dot -Tsvg` で行う。

# esc_html は 00_utils.R に移設（14_graphviz.R と 15_plotly.R で共有）
#
# DOT の通常引用文字列用のエスケープ。バックスラッシュ・ダブルクォートの
# 通常エスケープに加え、< と & は Graphviz が HTML-like ラベル記号として
# 曖昧解釈しうるため保守的に HTML エンティティ化する。&amp; などの既存
# エンティティを壊さないよう、プレースホルダ経由の2段階置換を使う。
esc_dot <- function(s) {
  s <- gsub("&", "\x01AMP\x01", s, fixed = TRUE)
  s <- gsub("\\", "\\\\", s, fixed = TRUE)
  s <- gsub("\"", "\\\"", s, fixed = TRUE)
  s <- gsub("<", "\x01LT\x01", s, fixed = TRUE)
  s <- gsub(">", "\x01GT\x01", s, fixed = TRUE)
  s <- gsub("\x01AMP\x01", "&amp;", s, fixed = TRUE)
  s <- gsub("\x01LT\x01", "&lt;", s, fixed = TRUE)
  gsub("\x01GT\x01", "&gt;", s, fixed = TRUE)
}

# 学習済み CHAID 木を Graphviz DOT 文字列に変換する。
#   palette   : クラス色（既定 hcl.colors "Dark 3"。plot.chaid と同一）
#   rankdir   : "TB"（上から下、既定）や "LR"（左から右）
#   label_len : エッジ（分割グループ）ラベルの最大文字数
#   legend    : クラス色の凡例ノードを付けるか（カテゴリカルのみ）
#   file      : 指定すると DOT を UTF-8 で書き出す（外部 dot コマンド用）
#' Render a CHAID tree as Graphviz DOT
#'
#' `chaid_dot()` generates a publication-quality Graphviz DOT
#' description of the tree using base R only. It can be rendered with
#' `chaid_graphviz()` (which uses 'DiagrammeR', bundling viz.js so no
#' Graphviz binary is needed) or written to a `.gv` file and rendered
#' externally with `dot -Tpng` / `dot -Tsvg`.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param palette Vector of class colours for categorical responses
#'   (default `grDevices::hcl.colors(n, "Dark 3")`, matching
#'   [plot.chaid()]). For continuous responses node fills use a
#'   white-to-steelblue gradient of the node means.
#' @param rankdir Graph direction: `"TB"` (top to bottom, default) or
#'   `"LR"` (left to right).
#' @param label_len Maximum number of characters for edge (split group)
#'   labels.
#' @param legend Logical. Add a legend node with the class colours
#'   (categorical responses only).
#' @param file Optional path; when given, the DOT source is also
#'   written there in UTF-8 for use with the external `dot` command.
#'
#' @return For `chaid_dot()`, the DOT source as a character string of
#'   class `"chaid_dot"` (returned invisibly; its `print()` method
#'   outputs the source). For `chaid_graphviz()`, an 'htmlwidget' as
#'   returned by [DiagrammeR::grViz()].
#'
#' @seealso [plot.chaid()], [chaid_plotly()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' dot <- chaid_dot(fit)
#' @export
chaid_dot <- function(fit, palette = NULL, rankdir = "TB", label_len = 28,
                      legend = TRUE, file = NULL) {
  stopifnot(inherits(fit, "chaid"))
  nodes <- fit$nodes
  is_cat <- fit$response$type != "numeric"
  fmtn <- function(v) format(v, digits = 4, trim = TRUE)

  if (is_cat) {
    lv <- fit$response$levels
    if (is.null(palette)) {
      palette <- grDevices::hcl.colors(max(3, length(lv)), "Dark 3")[seq_along(lv)]
    }
  } else {
    # 連続目的変数: ノード塗りを平均値のグラデーションに
    means <- vapply(nodes, function(nd) unname(nd$dist["mean"]), numeric(1))
    ramp <- grDevices::colorRamp(c("#FFFFFF", "#4682B4"))
    rng <- range(means)
    fill_of <- function(m) {
      t <- if (diff(rng) > 0) (m - rng[1]) / diff(rng) else 0.5
      grDevices::rgb(ramp(t), maxColorValue = 255)
    }
  }

  node_label <- function(nd) {
    terminal <- is.null(nd$split)
    rows <- character(0)
    if (is_cat) {
      p <- nd$dist / sum(nd$dist)
      rows <- c(rows, sprintf('<tr><td><b>[%d] %s</b></td></tr>',
                              nd$id, esc_html(as.character(nd$prediction))))
      rows <- c(rows, sprintf('<tr><td>%.1f%% &#8226; n=%d</td></tr>',
                              100 * max(p), round(nd$Nf)))
      # クラス分布の積み上げバー（幅を構成比に比例させた色付きセル）
      cells <- character(0)
      for (j in seq_along(p)) {
        if (p[j] <= 0) next
        wpx <- max(2L, round(120 * p[j]))
        cells <- c(cells, sprintf(
          '<td bgcolor="%s" width="%d" height="10" fixedsize="true" title="%s: %.1f%%"></td>',
          palette[j], wpx, esc_html(lv[j]), 100 * p[j]))
      }
      rows <- c(rows, sprintf(
        '<tr><td><table border="0" cellborder="0" cellspacing="0" cellpadding="0"><tr>%s</tr></table></td></tr>',
        paste(cells, collapse = "")))
    } else {
      rows <- c(rows, sprintf('<tr><td><b>[%d] mean=%s</b></td></tr>',
                              nd$id, fmtn(unname(nd$dist["mean"]))))
      rows <- c(rows, sprintf('<tr><td>sd=%s &#8226; n=%d</td></tr>',
                              fmtn(unname(nd$dist["sd"])), round(nd$Nf)))
    }
    if (!terminal) {
      s <- nd$split
      rows <- c(rows, sprintf('<tr><td><i><font color="grey25">%s (adj.p=%s)</font></i></td></tr>',
                              esc_html(s$var), fmtn(s$p_adj)))
    }
    bg <- if (is_cat) {
      if (terminal) ' bgcolor="grey96"' else ""
    } else {
      sprintf(' bgcolor="%s"', fill_of(unname(nd$dist["mean"])))
    }
    sprintf('<<table border="1" cellborder="0" cellspacing="0" cellpadding="3" style="rounded" color="grey40"%s>%s</table>>',
            bg, paste(rows, collapse = ""))
  }

  lines <- c(
    "digraph chaid {",
    sprintf('  graph [rankdir=%s, splines=line, ranksep=0.5, nodesep=0.35];', rankdir),
    '  node [shape=none, fontname="Helvetica", fontsize=11];',
    '  edge [fontname="Helvetica", fontsize=9, color=grey55, fontcolor=grey20, arrowsize=0.6];'
  )
  for (nd in nodes) {
    lines <- c(lines, sprintf("  n%d [label=%s];", nd$id, node_label(nd)))
  }
  for (nd in nodes) {
    if (is.null(nd$split)) next
    p <- fit$predictors[[nd$split$var_index]]
    for (gi in seq_along(nd$split$children)) {
      lab <- trunc_label(format_group(p, nd$split$groups[[gi]]), label_len)
      lines <- c(lines, sprintf('  n%d -> n%d [label="%s"];',
                                nd$id, nd$split$children[gi], esc_dot(lab)))
    }
  }
  if (is_cat && legend) {
    cells <- paste(sprintf(
      '<tr><td bgcolor="%s" width="12" height="12" fixedsize="true"></td><td align="left">%s</td></tr>',
      palette[seq_along(lv)], esc_html(lv)), collapse = "")
    lines <- c(lines,
      sprintf('  legend [label=<<table border="0" cellborder="0" cellspacing="1" cellpadding="1">%s</table>>];', cells),
      "  { rank=min; legend; }")
  }
  lines <- c(lines, "}")
  dot <- paste(lines, collapse = "\n")
  if (!is.null(file)) {
    con <- file(file, open = "w", encoding = "UTF-8")
    on.exit(close(con), add = TRUE)
    writeLines(dot, con)
  }
  invisible(structure(dot, class = c("chaid_dot", "character")))
}

#' @rdname chaid_dot
#' @param x A `"chaid_dot"` object.
#' @param ... For `chaid_graphviz()`, arguments passed on to
#'   `chaid_dot()`; ignored by `print()`.
#' @export
print.chaid_dot <- function(x, ...) {
  cat(unclass(x), "\n")
  invisible(x)
}

# DiagrammeR による DOT のレンダリング（htmlwidget を返す）。
# RStudio Viewer・ブラウザ・R Markdown にそのまま埋め込める。
#' @rdname chaid_dot
#' @export
chaid_graphviz <- function(fit, ...) {
  if (!requireNamespace("DiagrammeR", quietly = TRUE)) {
    stop("chaid_graphviz: the DiagrammeR package is required; ",
         "run install.packages('DiagrammeR')")
  }
  DiagrammeR::grViz(unclass(chaid_dot(fit, ...)))
}
