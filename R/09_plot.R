# 09_plot.R -- 学習済み CHAID 木の可視化（base graphics のみ、追加依存なし）

# ラベルの切り詰め（プロット内での重なり防止）
trunc_label <- function(s, n) {
  ifelse(nchar(s) > n, paste0(substr(s, 1, n - 3), "..."), s)
}

# 木の描画レイアウト。末端ノードを DFS 順に等間隔配置し、内部ノードは
# 子の中央に置く。plot.chaid / chaid_plotly で共用。
# 返り値: list(kids = 子ノード id のリスト, depth = 深さ,
#              x = 横位置（末端番号スケール）, n_term = 末端ノード数)
tree_layout <- function(fit) {
  nodes <- fit$nodes
  kids <- lapply(nodes, function(nd) {
    if (is.null(nd$split)) integer(0) else nd$split$children
  })
  depth <- vapply(nodes, function(nd) nd$depth, integer(1))
  xpos <- rep(NA_real_, length(nodes))
  counter <- 0
  # 末端 = 到達順で 1..n_term を採番、内部 = 子の平均位置。
  # counter / xpos は再帰内で更新するため `<<-` で親環境へ書き戻す
  # （tree_layout のローカルスコープに閉じている）。
  assign_x <- function(id) {
    ch <- kids[[id]]
    if (length(ch) == 0) {
      counter <<- counter + 1
      xpos[id] <<- counter
    } else {
      for (c in ch) assign_x(c)
      xpos[id] <<- mean(xpos[ch])
    }
  }
  assign_x(1L)
  list(kids = kids, depth = depth, x = xpos, n_term = counter)
}

# 木のプロット。
#   x         : chaid オブジェクト
#   cex       : 文字サイズの基準
#   label_len : エッジ（分割グループ）ラベルの最大文字数
#   palette   : カテゴリカル目的変数のクラス色（既定 hcl.colors "Dark 3"）
#   show_bar  : ノード内にクラス分布の帯を描くか（カテゴリカルのみ）
#   main      : タイトル（既定は目的変数名と手法）
#' Plot a CHAID tree with base graphics
#'
#' Draws the tree top-down using base graphics only. For categorical
#' responses each node shows the predicted class, its share, the node
#' size and optionally a horizontal bar of the class distribution.
#' Edges are labelled with the (possibly merged) predictor categories.
#'
#' @param x A fitted `"chaid"` object returned by [chaid()].
#' @param cex Base character expansion for node and edge labels.
#' @param label_len Maximum number of characters for edge (split group)
#'   labels; longer labels are truncated.
#' @param palette Vector of class colours for categorical responses.
#'   Defaults to `grDevices::hcl.colors(n, "Dark 3")`.
#' @param show_bar Logical. Draw a class distribution bar inside each
#'   node (categorical responses only).
#' @param main Plot title. Defaults to the response name and method.
#' @param ... Ignored.
#'
#' @return The fitted object, invisibly.
#'
#' @seealso [chaid()], [chaid_dot()] for publication-quality Graphviz
#'   output, [chaid_plotly()] for an interactive version.
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' plot(fit)
#' @export
plot.chaid <- function(x, cex = 0.8, label_len = 22, palette = NULL,
                       show_bar = TRUE, main = NULL, ...) {
  nodes <- x$nodes
  is_factor <- x$response$type != "numeric"
  lay <- tree_layout(x)
  kids <- lay$kids
  depth <- lay$depth
  xpos <- lay$x
  n_term <- lay$n_term
  max_depth <- max(depth)

  # 座標系: x = 末端ノード番号、y = -depth（ルートが最上段）
  box_h <- 0.34
  box_w <- min(0.92, n_term / max(1, length(nodes)) + 0.55)
  old_par <- graphics::par(mar = c(0.5, 0.5, if (is.null(main)) 2.5 else 2.5, 0.5))
  on.exit(graphics::par(old_par), add = TRUE)
  graphics::plot.new()
  graphics::plot.window(xlim = c(0.4, n_term + 0.6),
                        ylim = c(-max_depth - 0.55, 0.45))

  if (is.null(main)) {
    main <- sprintf("CHAID (%s): %s", x$method, x$response$name)
  }
  graphics::title(main = main, cex.main = cex * 1.3)

  # クラス色（カテゴリカル目的変数）
  if (is_factor) {
    lv <- x$response$levels
    if (is.null(palette)) {
      palette <- grDevices::hcl.colors(max(3, length(lv)), "Dark 3")[seq_along(lv)]
    }
    graphics::legend("topright", legend = lv, fill = palette,
                     bty = "n", cex = cex * 0.9, border = NA)
  }

  # エッジと分割グループラベル（ノードより先に描いて箱を上書きさせる）
  for (nd in nodes) {
    if (is.null(nd$split)) next
    p <- x$predictors[[nd$split$var_index]]
    y0 <- -nd$depth - box_h / 2
    # 分割変数名と p 値を親ノードの直下に表示
    graphics::text(xpos[nd$id], y0 - 0.06,
                   sprintf("%s (adj.p=%.2g)", nd$split$var, nd$split$p_adj),
                   cex = cex * 0.85, font = 3, col = "grey25")
    for (gi in seq_along(nd$split$children)) {
      cid <- nd$split$children[gi]
      y1 <- -depth[cid] + box_h / 2
      graphics::segments(xpos[nd$id], y0 - 0.12, xpos[cid], y1, col = "grey40")
      lab <- trunc_label(format_group(p, nd$split$groups[[gi]]), label_len)
      # エッジラベルは子ノードの直上に置く（中点よりも重なりにくい）
      graphics::text(xpos[cid], y1 + 0.075, lab, cex = cex * 0.75, col = "grey15")
    }
  }

  # ノードの箱
  for (nd in nodes) {
    cx <- xpos[nd$id]
    cy <- -nd$depth
    terminal <- length(kids[[nd$id]]) == 0
    graphics::rect(cx - box_w / 2, cy - box_h / 2, cx + box_w / 2, cy + box_h / 2,
                   col = if (terminal) "grey95" else "white", border = "grey30")
    if (is_factor) {
      prop <- nd$dist / sum(nd$dist)
      line1 <- sprintf("[%d] %s", nd$id, nd$prediction)
      line2 <- sprintf("%.1f%%  n=%d", 100 * max(prop), round(nd$Nf))
      graphics::text(cx, cy + box_h * 0.24, line1, cex = cex, font = 2)
      graphics::text(cx, cy + box_h * 0.0, line2, cex = cex * 0.85)
      if (show_bar) {
        # クラス分布の帯グラフ（箱の下部）
        bar_y0 <- cy - box_h * 0.36
        bar_y1 <- cy - box_h * 0.16
        edges <- cumsum(c(0, prop)) * (box_w * 0.86)
        x0 <- cx - box_w * 0.43
        for (j in seq_along(prop)) {
          if (prop[j] <= 0) next
          graphics::rect(x0 + edges[j], bar_y0, x0 + edges[j + 1], bar_y1,
                         col = palette[j], border = NA)
        }
      }
    } else {
      graphics::text(cx, cy + box_h * 0.18, sprintf("[%d] mean=%.4g", nd$id, nd$dist["mean"]),
                     cex = cex, font = 2)
      graphics::text(cx, cy - box_h * 0.18,
                     sprintf("sd=%.3g  n=%d", nd$dist["sd"], round(nd$Nf)),
                     cex = cex * 0.85)
    }
  }
  invisible(x)
}
