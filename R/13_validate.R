# 13_validate.R -- 検証データによる安定性評価

# 学習済みの木に newdata をルーティングし、末端ノードごとに
# 学習時と検証時の「構成比」と「反応率（連続目的変数では平均）」を比較する。
# セグメントが検証データでも再現しているか（過剰適合していないか）の確認用。
#   fit           : chaid オブジェクト
#   newdata       : 検証データ
#   weights, freq : 検証データのケース重み・頻度重み
# 返り値: class "chaid_validation"
#   $nodes   : ノード別比較の data.frame（rate は factor なら「そのノードの
#              予測クラスの構成比」、numeric なら平均）
#   $overall : 全体指標（factor: accuracy / numeric: rmse, r2）
#' Evaluate a CHAID tree on holdout data
#'
#' Routes `newdata` down the fitted tree and compares, for each terminal
#' node, the node share and the response rate (node mean for continuous
#' responses) between training and validation data. Useful to check
#' whether the segments replicate on new data, i.e. whether the tree is
#' overfitting.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param newdata A data frame of validation cases containing the
#'   response and all predictors.
#' @param weights,freq Case and frequency weights for `newdata`.
#'
#' @return An object of class `"chaid_validation"`: a list with
#'   `nodes` (per-node comparison data frame with `train_pct_n`,
#'   `test_pct_n`, `train_rate`, `test_rate` and `diff_rate`),
#'   `overall` (accuracy for categorical responses; RMSE and R-squared
#'   for continuous ones), `n_test` and `ytype`. A `print()` method is
#'   available.
#'
#' @seealso [chaid_gains()], [predict.chaid()]
#' @examples
#' set.seed(1)
#' idx <- sample(nrow(iris), 100)
#' fit <- chaid(Species ~ ., data = iris[idx, ],
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' chaid_validate(fit, iris[-idx, ])
#' @export
chaid_validate <- function(fit, newdata, weights = NULL, freq = NULL) {
  stopifnot(inherits(fit, "chaid"))
  yname <- fit$response$name
  if (!yname %in% names(newdata)) {
    stop("chaid_validate: response '", yname, "' not found in newdata")
  }
  is_cat <- fit$response$type != "numeric"

  y <- newdata[[yname]]
  n <- nrow(newdata)
  w <- if (is.null(weights)) rep(1, n) else as.numeric(weights)
  f <- if (is.null(freq)) rep(1, n) else round(as.numeric(freq))
  keep <- !is.na(y) & !is.na(w) & w > 0 & !is.na(f) & f > 0
  if (!any(keep)) stop("chaid_validate: no valid validation cases")
  y <- y[keep]
  wf <- (w * f)[keep]
  nid <- predict(fit, newdata[keep, , drop = FALSE], type = "node")
  if (is_cat) y <- factor(y, levels = fit$response$levels)

  term <- Filter(function(nd) is.null(nd$split), fit$nodes)
  w_root <- fit$nodes[[1]]$W
  w_test <- sum(wf)

  # 末端ノードごとの nid == id 全走査（末端数 × O(n)）を避け、rowsum の
  # 1 パスで集計する。rowsum はデータ出現順に群別加算するため
  # sum(wf[sel]) と同一の加算順（= 同一値）になる。
  term_ids <- vapply(term, function(nd) nd$id, integer(1))
  nid_f <- factor(nid, levels = term_ids)
  # rowsum は空グループの行を返さないので term_ids に合わせて 0 埋めする
  fill_by_term <- function(agg) {
    out <- numeric(length(term_ids))
    out[match(rownames(agg), as.character(term_ids))] <- agg[, 1L]
    out
  }
  test_n <- fill_by_term(rowsum(wf, nid_f))

  if (is_cat) {
    # 行ごとのリスト索引（vapply(nid, ...)）を避け、ノード別テーブルを
    # 1 回作って参照する
    pred_at_node <- vapply(fit$nodes, function(nd) as.character(nd$prediction),
                           character(1))
    # 各ケースが「所属末端ノードの予測クラス」に一致した重みの群別和。
    # 指標 0 の項の加算は値を変えないため sum(wf[sel & y == pred]) と一致する
    hit <- wf * (pred_at_node[nid] == as.character(y))
    resp_sum <- fill_by_term(rowsum(hit, nid_f))
    pred_term <- pred_at_node[term_ids]
    train_rate <- vapply(term, function(nd) {
      unname(nd$dist[as.character(nd$prediction)]) / sum(nd$dist)
    }, numeric(1))
  } else {
    resp_sum <- fill_by_term(rowsum(wf * y, nid_f))
    pred_term <- rep(NA_character_, length(term_ids))
    train_rate <- vapply(term, function(nd) unname(nd$dist["mean"]), numeric(1))
  }
  test_rate <- resp_sum / test_n
  test_rate[test_n <= 0] <- NA_real_

  w_term <- vapply(term, function(nd) nd$W, numeric(1))
  nodes_df <- data.frame(node = term_ids,
                         prediction = pred_term,
                         train_pct_n = round(100 * w_term / w_root, 2),
                         test_pct_n = round(100 * test_n / w_test, 2),
                         train_rate = round(train_rate, 4),
                         test_rate = round(test_rate, 4),
                         diff_rate = round(test_rate - train_rate, 4),
                         stringsAsFactors = FALSE)
  if (!is_cat) nodes_df$prediction <- NULL

  overall <- if (is_cat) {
    # pred_class は character、y は factor / ordered factor。ordered でも
    # as.character(y) は水準名を返すので順序情報を捨てて等値比較できる。
    pred_class <- pred_at_node[nid]
    list(accuracy = sum(wf[pred_class == as.character(y)]) / w_test)
  } else {
    means_by_node <- vapply(fit$nodes, function(nd) unname(nd$dist["mean"]),
                            numeric(1))
    pred_mean <- means_by_node[nid]
    mse <- sum(wf * (y - pred_mean)^2) / w_test
    ybar <- sum(wf * y) / w_test
    list(rmse = sqrt(mse),
         r2 = 1 - mse / (sum(wf * (y - ybar)^2) / w_test))
  }

  structure(list(nodes = nodes_df, overall = overall,
                 n_test = sum(f[keep]), ytype = fit$response$type),
            class = "chaid_validation")
}

#' @rdname chaid_validate
#' @param x A `"chaid_validation"` object.
#' @param ... Ignored.
#' @export
print.chaid_validation <- function(x, ...) {
  cat("CHAID stability assessment (validation n =", x$n_test, ")\n")
  if (x$ytype != "numeric") {
    cat("Validation accuracy:", round(x$overall$accuracy, 4), "\n")
  } else {
    cat("Validation RMSE:", round(x$overall$rmse, 4),
        " R2:", round(x$overall$r2, 4), "\n")
  }
  cat("(rate = share of the predicted class, or the mean for continuous",
      "responses.\n Nodes with a large |diff_rate| do not replicate on the",
      "validation data.)\n\n")
  print(x$nodes, row.names = FALSE)
  invisible(x)
}
