# 15_plotly.R -- plotly によるインタラクティブな木描画
# ズーム・パン・ホバー（到達条件・クラス構成比・分割情報）に対応した
# htmlwidget を返す。R Markdown / HTML 保存にそのまま埋め込める。

# 学習済み CHAID 木のインタラクティブ描画。
#   palette   : クラス色（既定 hcl.colors "Dark 3"。plot.chaid と同一）
#   label_len : エッジ（分割グループ）ラベルの最大文字数
#' Interactive CHAID tree plot with plotly
#'
#' Draws the tree as an interactive 'plotly' htmlwidget with zoom, pan
#' and hover information (reaching rule, class distribution and split
#' details for each node). The widget can be embedded directly in
#' R Markdown documents or saved as HTML.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param palette Vector of class colours for categorical responses
#'   (default `grDevices::hcl.colors(n, "Dark 3")`, matching
#'   [plot.chaid()]).
#' @param label_len Maximum number of characters for edge (split group)
#'   labels.
#' @param ... Ignored.
#'
#' @return A 'plotly' htmlwidget.
#'
#' @seealso [plot.chaid()], [chaid_dot()]
#' @examplesIf requireNamespace("plotly", quietly = TRUE)
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' chaid_plotly(fit)
#' @export
chaid_plotly <- function(fit, palette = NULL, label_len = 20, ...) {
  if (!requireNamespace("plotly", quietly = TRUE)) {
    stop("chaid_plotly: the plotly package is required; run install.packages('plotly')")
  }
  stopifnot(inherits(fit, "chaid"))
  nodes <- fit$nodes
  is_cat <- fit$response$type != "numeric"
  lay <- tree_layout(fit)
  ids <- vapply(nodes, function(nd) nd$id, integer(1))
  rules <- chaid_rules(fit, nodes = ids, format = "text")
  fmtn <- function(v) format(v, digits = 4, trim = TRUE)
  root_nf <- nodes[[1]]$Nf

  # ホバーテキスト（ノードの全情報を集約）。plotly は HTML を解釈するため、
  # ユーザーデータ由来の文字列（クラス名・水準名・変数名・ルール文字列）は
  # 全て esc_html() を通して <, >, & を安全に処理する。
  hover <- vapply(nodes, function(nd) {
    h <- sprintf("<b>[%d]</b>  n=%d (%.1f%%)", nd$id, round(nd$Nf),
                 100 * nd$Nf / root_nf)
    if (is_cat) {
      p <- nd$dist / sum(nd$dist)
      h <- paste0(h, "<br>prediction: <b>", esc_html(as.character(nd$prediction)),
                  "</b><br>",
                  paste(sprintf("%s: %.1f%%", esc_html(names(p)), 100 * p),
                        collapse = "<br>"))
    } else {
      h <- paste0(h, sprintf("<br>mean=%s  sd=%s",
                             fmtn(unname(nd$dist["mean"])),
                             fmtn(unname(nd$dist["sd"]))))
    }
    if (!is.null(nd$split)) {
      h <- paste0(h, sprintf("<br>split: %s (adj.p=%s)",
                             esc_html(nd$split$var), fmtn(nd$split$p_adj)))
    }
    rule <- rules$rule[match(nd$id, rules$node)]
    paste0(h, "<br><i>", esc_html(rule), "</i>")
  }, character(1))

  ndf <- data.frame(
    id = ids, x = lay$x, y = -lay$depth,
    label = vapply(nodes, function(nd) {
      if (is_cat) sprintf("[%d] %s", nd$id, nd$prediction)
      else sprintf("[%d] %s", nd$id, fmtn(unname(nd$dist["mean"])))
    }, character(1)),
    hover = hover,
    stringsAsFactors = FALSE
  )

  # エッジの線分と分割グループラベル
  seg <- do.call(rbind, lapply(nodes, function(nd) {
    if (is.null(nd$split)) return(NULL)
    p <- fit$predictors[[nd$split$var_index]]
    do.call(rbind, lapply(seq_along(nd$split$children), function(gi) {
      cid <- nd$split$children[gi]
      data.frame(x0 = lay$x[nd$id], y0 = -lay$depth[nd$id] - 0.08,
                 x1 = lay$x[cid], y1 = -lay$depth[cid] + 0.12,
                 lab = trunc_label(format_group(p, nd$split$groups[[gi]]),
                                   label_len),
                 stringsAsFactors = FALSE)
    }))
  }))

  fig <- plotly::plot_ly(...)
  if (!is.null(seg)) {
    fig <- plotly::add_segments(fig, data = seg, x = ~x0, y = ~y0,
                                xend = ~x1, yend = ~y1,
                                line = list(color = "grey", width = 1),
                                hoverinfo = "none", showlegend = FALSE)
    fig <- plotly::add_text(fig, data = seg, x = ~x1, y = ~y1 + 0.12,
                            text = ~lab,
                            textfont = list(size = 9, color = "grey40"),
                            hoverinfo = "none", showlegend = FALSE)
  }

  if (is_cat) {
    lv <- fit$response$levels
    if (is.null(palette)) {
      palette <- grDevices::hcl.colors(max(3, length(lv)), "Dark 3")[seq_along(lv)]
    }
    pred_class <- vapply(nodes, function(nd) as.character(nd$prediction),
                         character(1))
    # クラスごとに 1 トレース（凡例エントリになる）
    for (j in seq_along(lv)) {
      sel <- pred_class == lv[j]
      if (!any(sel)) next
      fig <- plotly::add_markers(fig, data = ndf[sel, ], x = ~x, y = ~y,
                                 name = lv[j],
                                 marker = list(size = 22, symbol = "square",
                                               color = palette[j],
                                               line = list(color = "grey30",
                                                           width = 1)),
                                 text = ~hover, hoverinfo = "text")
    }
  } else {
    means <- vapply(nodes, function(nd) unname(nd$dist["mean"]), numeric(1))
    fig <- plotly::add_markers(fig, data = ndf, x = ~x, y = ~y,
                               marker = list(size = 22, symbol = "square",
                                             color = means, colorscale = "Blues",
                                             reversescale = TRUE, showscale = TRUE,
                                             colorbar = list(title = "mean"),
                                             line = list(color = "grey30",
                                                         width = 1)),
                               text = ~hover, hoverinfo = "text",
                               showlegend = FALSE)
  }
  fig <- plotly::add_text(fig, data = ndf, x = ~x, y = ~y - 0.17,
                          text = ~label, textfont = list(size = 10),
                          hoverinfo = "none", showlegend = FALSE)

  ax_off <- list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE,
                 title = "")
  plotly::layout(fig,
    title = list(text = sprintf("CHAID (%s): %s", fit$method,
                                fit$response$name)),
    xaxis = ax_off, yaxis = ax_off, hovermode = "closest",
    plot_bgcolor = "rgba(0,0,0,0)")
}
