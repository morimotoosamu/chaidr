# 08_methods.R -- print / summary メソッド

# 分割グループの表示ラベル。連続変数は連続するビンを 1 つの区間表記へまとめ、
# カテゴリカル変数は水準名をカンマ区切りで並べる。
format_group <- function(pred, cats) {
  if (!is.null(pred$breaks)) {
    fmt <- function(v) format(v, digits = 4, trim = TRUE)
    br <- pred$breaks
    nb <- length(br)
    na_code <- if ("<NA>" %in% pred$levels) match("<NA>", pred$levels) else NA
    bins <- sort(setdiff(cats, na_code))
    lab <- character(0)
    if (length(bins)) {
      runs <- split(bins, cumsum(c(1, diff(bins) != 1)))
      lab <- vapply(runs, function(r) {
        lo <- min(r)
        hi <- max(r)
        if (lo == 1 && hi == nb) "all"
        else if (lo == 1) paste0("<= ", fmt(br[hi]))
        else if (hi == nb) paste0("> ", fmt(br[lo - 1]))
        else paste0("(", fmt(br[lo - 1]), ", ", fmt(br[hi]), "]")
      }, character(1))
    }
    if (!is.na(na_code) && na_code %in% cats) lab <- c(lab, "<NA>")
    return(paste(lab, collapse = " | "))
  }
  paste(pred$levels[sort(cats)], collapse = ", ")
}

# ノードの要約 1 行
format_node_stats <- function(object, nd) {
  if (object$response$type != "numeric") {
    d <- nd$dist
    p <- d / sum(d)
    sprintf("%s (%.1f%%), n=%d", nd$prediction, 100 * max(p), round(nd$Nf))
  } else {
    sprintf("mean=%.4g, sd=%.4g, n=%d",
            unname(nd$dist["mean"]), unname(nd$dist["sd"]), round(nd$Nf))
  }
}

#' Print and summarise a CHAID tree
#'
#' `print()` displays the tree structure with one line per node showing
#' the prediction, node size and split information. `summary()`
#' additionally reports the control settings and a risk estimate on the
#' training data (misclassification rate or expected misclassification
#' cost for categorical responses, weighted within-node variance for
#' continuous responses).
#'
#' @param x,object A fitted `"chaid"` object returned by [chaid()].
#' @param ... Ignored.
#'
#' @return The fitted object, invisibly.
#'
#' @seealso [chaid()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' print(fit)
#' summary(fit)
#' @export
print.chaid <- function(x, ...) {
  cat("CHAID decision tree (method = \"", x$method, "\")\n", sep = "")
  cat("Response:", x$response$name,
      switch(x$response$type, factor = "(categorical)",
             ordinal = "(ordinal categorical)", numeric = "(continuous)"), "\n")
  cat("Valid cases:", round(x$nodes[[1]]$Nf),
      paste0("(data: ", x$n, " rows",
             if (x$n_dropped > 0) paste0(", dropped: ", x$n_dropped, " rows"), ")"),
      "\n\n")

  print_node <- function(id, indent, branch_label) {
    nd <- x$nodes[[id]]
    pad <- strrep("  ", indent)
    head_ <- if (is.na(nd$parent)) "[1] root" else paste0("[", id, "] ", branch_label)
    cat(pad, head_, ": ", format_node_stats(x, nd), sep = "")
    if (!is.null(nd$split)) {
      s <- nd$split
      cat(sprintf(" | split: %s (adj.p=%.3g, %s=%.4g, B=%g)",
                  s$var, s$p_adj,
                  switch(x$response$type, factor = "chi2", ordinal = "H2",
                         numeric = "F"),
                  if (length(s$statistic) == 1) s$statistic else s$statistic[1],
                  s$B))
      # 変数間補正が有効なときだけ、分割判定に使った補正後 p 値を併記
      if (!identical(x$control$adjust_across, "none") &&
          !is.null(s$p_final)) {
        cat(sprintf(" [%s: final.p=%.3g, m=%d]",
                    x$control$adjust_across, s$p_final, s$n_family))
      }
    } else if (!is.null(nd$terminal_reason) && !is.na(nd$parent)) {
      cat(" *")
    }
    cat("\n")
    if (!is.null(nd$split)) {
      p <- x$predictors[[nd$split$var_index]]
      for (gi in seq_along(nd$split$children)) {
        lab <- paste0(nd$split$var, " in {", format_group(p, nd$split$groups[[gi]]), "}")
        print_node(nd$split$children[gi], indent + 1, lab)
      }
    }
  }
  print_node(1L, 0, "")
  invisible(x)
}

#' @rdname print.chaid
#' @export
summary.chaid <- function(object, ...) {
  print(object)
  ctl <- object$control
  cat("\nSettings: alpha_merge=", ctl$alpha_merge, ", alpha_split=", ctl$alpha_split,
      ", bonferroni=", ctl$bonferroni,
      ", adjust_across=", if (is.null(ctl$adjust_across)) "none" else ctl$adjust_across,
      ", max_depth=", ctl$max_depth,
      ", min_parent=", ctl$min_parent, ", min_child=", ctl$min_child,
      ", n_bins=", ctl$n_bins, "\n", sep = "")

  # リスク推定（末端ノードのシェア加重）
  # カテゴリカル: costs 無指定なら誤分類率、指定時は期待誤分類コスト
  # 連続: ノード内分散の加重平均（学習データ上の MSE 推定）
  term <- Filter(function(nd) is.null(nd$split), object$nodes)
  w_root <- object$nodes[[1]]$W
  if (object$response$type != "numeric") {
    risk <- sum(vapply(term, function(nd) {
      p <- nd$dist / sum(nd$dist)
      share <- nd$W / w_root
      if (is.null(object$costs)) {
        share * (1 - max(p))
      } else {
        share * sum(p * object$costs[, as.character(nd$prediction)])
      }
    }, numeric(1)))
    cat("\nRisk estimate (training data):", round(risk, 4),
        if (is.null(object$costs)) "(misclassification rate)"
        else "(expected misclassification cost)", "\n")
  } else {
    risk <- sum(vapply(term, function(nd) {
      (nd$W / w_root) * unname(nd$dist["sd"])^2
    }, numeric(1)))
    cat("\nRisk estimate (training data):", round(risk, 4),
        "(weighted mean of within-node variance)\n")
  }
  cat("\nTerminal nodes:", length(term), "\n")
  reasons <- table(vapply(term, function(nd) {
    if (is.null(nd$terminal_reason)) "split" else nd$terminal_reason
  }, character(1)))
  cat("Stopping reasons:\n")
  for (r in names(reasons)) cat("  ", r, ": ", reasons[[r]], "\n", sep = "")
  invisible(object)
}
