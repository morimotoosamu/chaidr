# 12_gains.R -- ゲイン・リフト表とチャート（SPSS の gains table 相当）

# 末端ノードを反応率（連続目的変数では平均）の降順に並べ、累積ゲイン・
# リフトを算出する。
#   fit    : chaid オブジェクト
#   data   : NULL なら学習時のノード統計（w×f 加重）を使う。
#            指定すると predict でルーティングして再集計（検証データの評価用）
#   target : カテゴリカル目的変数の注目水準。2値なら第2水準が既定、
#            3水準以上では必須
#   weights, freq : data 指定時のケース重み・頻度重み
# 返り値: class "chaid_gains"（print / plot メソッドあり）
#' Gains and lift table for a CHAID tree
#'
#' Sorts the terminal nodes by decreasing response rate (node mean for
#' continuous responses) and computes cumulative gains and lift,
#' corresponding to the SPSS gains table.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param data Optional data frame. If `NULL` (default), node statistics
#'   from training are used. If supplied, cases are routed with
#'   [predict.chaid()] and the table is recomputed, e.g. for evaluation
#'   on holdout data.
#' @param target Response level of interest for categorical responses.
#'   For a binary response the second level is used by default; for
#'   three or more levels `target` is required.
#' @param weights,freq Case and frequency weights for `data`, when
#'   supplied.
#'
#' @return An object of class `"chaid_gains"`, a list with the gains
#'   table (`table`), the `target` level, the response type (`ytype`),
#'   the overall rate (`overall`) and the data `source` (`"training"`
#'   or `"newdata"`). `print()` and `plot()` methods are available.
#'
#' @seealso [chaid_table()], [chaid_validate()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' g <- chaid_gains(fit, target = "virginica")
#' print(g)
#' plot(g)
#' plot(g, type = "lift")
#' @export
chaid_gains <- function(fit, data = NULL, target = NULL,
                        weights = NULL, freq = NULL) {
  stopifnot(inherits(fit, "chaid"))
  ytype <- fit$response$type
  is_cat <- ytype != "numeric"
  if (is_cat) {
    lv <- fit$response$levels
    if (is.null(target)) {
      if (length(lv) == 2) {
        target <- lv[2]
        message("chaid_gains: using target = \"", target, "\" (the second level)")
      } else {
        stop("chaid_gains: specify target for responses with 3 or more levels")
      }
    }
    if (!target %in% lv) stop("chaid_gains: target is not a response level: ", target)
  }

  # 「ノードリストの位置 == id」の不変条件（ARCHITECTURE.md）により
  # id の取り出しは末端判定の 1 パスで済む
  term_ids <- which(vapply(fit$nodes, function(nd) is.null(nd$split),
                           logical(1)))

  if (is.null(data)) {
    # 学習時のノード統計から集計（dist は w×f 加重）
    n_eff <- vapply(term_ids, function(i) fit$nodes[[i]]$W, numeric(1))
    resp <- vapply(term_ids, function(i) {
      nd <- fit$nodes[[i]]
      if (is_cat) unname(nd$dist[target]) else unname(nd$dist["mean"]) * nd$W
    }, numeric(1))
  } else {
    y <- data[[fit$response$name]]
    n <- nrow(data)
    w <- if (is.null(weights)) rep(1, n) else as.numeric(weights)
    f <- if (is.null(freq)) rep(1, n) else round(as.numeric(freq))
    keep <- !is.na(y) & !is.na(w) & w > 0 & !is.na(f) & f > 0
    y <- y[keep]
    wf <- (w * f)[keep]
    nid <- predict(fit, data[keep, , drop = FALSE], type = "node")
    # 末端ノードごとの nid == i 全走査（2 × 末端数 × O(n)）を避け、
    # rowsum の 1 パスで集計する。rowsum はデータ出現順に群別加算するため
    # sum(wf[sel]) と同一の加算順（= 同一値）。指標 0 の項の加算は値を
    # 変えないため sum(wf[sel & y == target]) とも一致する。
    nid_f <- factor(nid, levels = term_ids)
    fill_by_term <- function(agg) {
      # rowsum は空グループの行を返さないので term_ids に合わせて 0 埋め
      out <- numeric(length(term_ids))
      out[match(rownames(agg), as.character(term_ids))] <- agg[, 1L]
      out
    }
    n_eff <- fill_by_term(rowsum(wf, nid_f))
    resp <- fill_by_term(rowsum(if (is_cat) wf * (y == target) else wf * y,
                                nid_f))
  }

  present <- n_eff > 0
  term_ids <- term_ids[present]
  n_eff <- n_eff[present]
  resp <- resp[present]
  rate <- resp / n_eff             # カテゴリカル: 反応率、連続: ノード平均
  overall <- sum(resp) / sum(n_eff)

  ord <- order(-rate)
  # 縮退ケース（overall=0: 連続目的変数が全 0、または target クラスが 0 件）は
  # index / cum_pct_resp / cum_lift を NA にして Inf/NaN を回避する
  degenerate <- !isTRUE(sum(resp) > 0)
  tab <- data.frame(
    node = term_ids[ord],
    n = round(n_eff[ord], 1),
    pct_n = round(100 * n_eff[ord] / sum(n_eff), 2),
    resp = round(resp[ord], 1),
    pct_resp = if (degenerate) NA_real_ else round(100 * resp[ord] / sum(resp), 2),
    rate = round(rate[ord], 4),
    index = if (degenerate) NA_real_ else round(100 * rate[ord] / overall, 1)
  )
  tab$cum_pct_n <- round(cumsum(100 * n_eff[ord] / sum(n_eff)), 2)
  tab$cum_pct_resp <- if (degenerate) NA_real_ else
    round(cumsum(100 * resp[ord] / sum(resp)), 2)                    # 累積ゲイン
  tab$cum_lift <- if (degenerate) NA_real_ else
    round(tab$cum_pct_resp / tab$cum_pct_n, 3)

  structure(list(table = tab, target = if (is_cat) target else NULL,
                 ytype = ytype, overall = overall,
                 source = if (is.null(data)) "training" else "newdata"),
            class = "chaid_gains")
}

#' @rdname chaid_gains
#' @param x A `"chaid_gains"` object.
#' @param ... For `plot()`, further arguments passed to
#'   [graphics::plot()]; ignored by `print()`.
#' @export
print.chaid_gains <- function(x, ...) {
  cat("CHAID gains table",
      if (!is.null(x$target)) paste0("(target = ", x$target, ")"),
      if (x$source == "newdata") "[validation data]", "\n")
  cat(if (x$ytype == "numeric") "Overall mean:" else "Overall response rate:",
      round(x$overall, 4), "\n\n")
  print(x$table, row.names = FALSE)
  invisible(x)
}

# type = "gains": 累積ゲイン曲線（x: 上位ノードから累積した %ケース、
#                 y: 捕捉した %ターゲット。対角線がランダム基準）
# type = "lift" : 累積リフト曲線（y = ゲイン% / ケース%。1 がランダム基準）
#' @rdname chaid_gains
#' @param type `"gains"` (default) draws the cumulative gains curve
#'   (percentage of cases vs. percentage of captured targets, diagonal
#'   = random), `"lift"` draws the cumulative lift curve (1 = random).
#' @export
plot.chaid_gains <- function(x, type = c("gains", "lift"), ...) {
  type <- match.arg(type)
  tab <- x$table
  main_tail <- if (!is.null(x$target)) paste0(" (target = ", x$target, ")") else ""
  if (type == "gains") {
    graphics::plot(c(0, tab$cum_pct_n), c(0, tab$cum_pct_resp), type = "b",
                   pch = 19, col = "steelblue", lwd = 2,
                   xlab = "Cumulative cases %", ylab = "Cumulative targets captured %",
                   main = paste0("Cumulative gains curve", main_tail),
                   xlim = c(0, 100), ylim = c(0, 100), ...)
    graphics::abline(0, 1, lty = 2, col = "grey50")
    graphics::text(c(0, tab$cum_pct_n)[-1], c(0, tab$cum_pct_resp)[-1],
                   labels = tab$node, pos = 3, cex = 0.75, col = "grey30")
  } else {
    graphics::plot(tab$cum_pct_n, tab$cum_lift, type = "b",
                   pch = 19, col = "indianred", lwd = 2,
                   xlab = "Cumulative cases %", ylab = "Cumulative lift",
                   main = paste0("Lift curve", main_tail),
                   xlim = c(0, 100), ylim = c(0, max(tab$cum_lift) * 1.1), ...)
    graphics::abline(h = 1, lty = 2, col = "grey50")
    graphics::text(tab$cum_pct_n, tab$cum_lift, labels = tab$node,
                   pos = 3, cex = 0.75, col = "grey30")
  }
  invisible(x)
}
