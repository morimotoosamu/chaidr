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

  rows <- lapply(term, function(nd) {
    sel <- nid == nd$id
    test_n <- sum(wf[sel])
    train_share <- nd$W / w_root
    if (is_cat) {
      pred <- as.character(nd$prediction)
      train_rate <- unname(nd$dist[pred]) / sum(nd$dist)
      test_rate <- if (test_n > 0) sum(wf[sel & y == pred]) / test_n else NA_real_
    } else {
      pred <- NA_character_
      train_rate <- unname(nd$dist["mean"])
      test_rate <- if (test_n > 0) sum(wf[sel] * y[sel]) / test_n else NA_real_
    }
    data.frame(node = nd$id,
               prediction = pred,
               train_pct_n = round(100 * train_share, 2),
               test_pct_n = round(100 * test_n / w_test, 2),
               train_rate = round(train_rate, 4),
               test_rate = round(test_rate, 4),
               diff_rate = round(test_rate - train_rate, 4),
               stringsAsFactors = FALSE)
  })
  nodes_df <- do.call(rbind, rows)
  if (!is_cat) nodes_df$prediction <- NULL

  overall <- if (is_cat) {
    # pred_class は character、y は factor / ordered factor。ordered でも
    # as.character(y) は水準名を返すので順序情報を捨てて等値比較できる。
    pred_class <- vapply(nid, function(i) as.character(fit$nodes[[i]]$prediction),
                         character(1))
    list(accuracy = sum(wf[pred_class == as.character(y)]) / w_test)
  } else {
    pred_mean <- vapply(nid, function(i) unname(fit$nodes[[i]]$dist["mean"]),
                        numeric(1))
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
