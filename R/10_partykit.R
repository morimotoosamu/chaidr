# 10_partykit.R -- partykit パッケージ連携（constparty への変換）
# 本体は base R のみで動く。partykit はこのファイルの関数を呼ぶときだけ必要
# （ソフト依存）。partykit 側の対応・変更は不要 — partynode / partysplit /
# constparty という公開インフラに変換するだけで plot / print / nodeapply 等が使える。
#
# 表現方法: ビン化された連続予測変数は「ビン区間ラベルの順序 factor」として
# party のデータフレームに載せ、全分割を index 型 partysplit で統一する。
# これにより NA（"<NA>" 水準）も明示的な水準としてルーティングされ、
# 分割規則の表示にも区間ラベルがそのまま出る。
#
# 注意: 返り値の party オブジェクトは可視化・構造検査用。新データの予測は
# predict.chaid() を使うこと（party 側の predict は変換後のデータ表現を要求する）。

# chaid オブジェクトを partykit::constparty へ変換する。
#   x    : chaid オブジェクト
#   data : 学習に使ったデータフレーム（chaid はデータを保存しないため必須）
#   weights, freq: 学習時に指定した場合は同じものを渡す（ケース除外の再現に必要）
#' Convert a CHAID tree to a partykit constparty
#'
#' Converts a fitted `"chaid"` object to a
#' `partykit::constparty` object so that the 'partykit' toolbox
#' (`plot()`, `print()`, `nodeapply()`, 'ggparty', ...) can be used.
#' Binned continuous predictors are represented as ordered factors of
#' the bin interval labels, and all splits become index-type
#' [partykit::partysplit] objects, so missing values (`"<NA>"` level)
#' are routed explicitly and split rules display the interval labels.
#'
#' The returned object is intended for visualisation and structural
#' inspection. For predictions on new data use [predict.chaid()]; the
#' `predict()` method of the party object expects the converted data
#' representation, not the original one.
#'
#' @param x,obj A fitted `"chaid"` object returned by [chaid()].
#' @param data The data frame used to fit the tree (the chaid object
#'   does not store the data).
#' @param weights,freq The case and frequency weights used in the fit,
#'   if any. Required to reproduce the case exclusions of the fit.
#' @param ... Ignored.
#'
#' @return A `partykit::constparty` object.
#'
#' @seealso [chaid()], [predict.chaid()]
#' @examplesIf requireNamespace("partykit", quietly = TRUE)
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' pt <- chaid_as_party(fit, data = iris)
#' print(pt)
#' @export
chaid_as_party <- function(x, data, weights = NULL, freq = NULL, ...) {
  if (!requireNamespace("partykit", quietly = TRUE)) {
    stop("chaid_as_party: the partykit package is required; run install.packages('partykit')")
  }
  stopifnot(inherits(x, "chaid"))

  # --- 学習時と同じケース除外を再現 ---
  yname <- x$response$name
  if (!yname %in% names(data)) stop("chaid_as_party: response '", yname, "' not found in data")
  n <- nrow(data)
  y <- data[[yname]]
  w <- if (is.null(weights)) rep(1, n) else as.numeric(weights)
  f <- if (is.null(freq)) rep(1, n) else round(as.numeric(freq))
  keep <- !is.na(y) & !is.na(w) & w > 0 & !is.na(f) & f > 0
  pred_cols <- lapply(x$predictors, function(p) data[[p$name]])
  keep <- keep & !Reduce(`&`, lapply(pred_cols, is.na))
  d <- data[keep, , drop = FALSE]
  y <- y[keep]
  f <- f[keep]
  if (x$response$type != "numeric") {
    y <- factor(y, levels = x$response$levels,
                ordered = (x$response$type == "ordinal"))
  }

  # --- 予測変数を学習時のコード体系の factor へ変換（recode_newdata を再利用）---
  codes <- recode_newdata(x, d)
  mf <- data.frame(row.names = seq_len(nrow(d)))
  mf[[yname]] <- y
  for (i in seq_along(x$predictors)) {
    p <- x$predictors[[i]]
    mf[[p$name]] <- factor(p$levels[codes[[i]]], levels = p$levels,
                           ordered = (p$ptype == "ordinal"))
  }

  # --- ノード構造を partynode へ再帰変換 ---
  build <- function(id) {
    nd <- x$nodes[[id]]
    if (is.null(nd$split)) {
      return(partykit::partynode(as.integer(id)))
    }
    s <- nd$split
    p <- x$predictors[[s$var_index]]
    idx <- rep(NA_integer_, length(p$levels))
    for (gi in seq_along(s$groups)) idx[s$groups[[gi]]] <- gi
    sp <- partykit::partysplit(as.integer(s$var_index + 1L),  # mf 内の列位置（1列目は目的変数）
                               index = as.integer(idx),
                               info = list(p.value = s$p_adj, statistic = s$statistic))
    # ノード側にも p.value を入れる。ggparty は split ではなくノードの info を
    # 参照するため、これがないと aes(label = p.value) が NA になる
    partykit::partynode(as.integer(id), split = sp,
                        kids = lapply(s$children, build),
                        info = list(p.value = s$p_adj, statistic = s$statistic,
                                    variable = s$var))
  }
  node <- build(1L)

  # --- fitted（各ケースの末端ノード）と constparty の構築 ---
  fitted_df <- data.frame(
    "(fitted)" = predict(x, d, type = "node"),
    "(response)" = y,
    "(weights)" = as.integer(f),
    check.names = FALSE
  )
  trm <- stats::terms(
    stats::reformulate(vapply(x$predictors, `[[`, character(1), "name"),
                       response = as.name(yname)),
    data = mf
  )
  ret <- partykit::party(node, data = mf, fitted = fitted_df, terms = trm)
  partykit::as.constparty(ret)
}

# partykit::as.party() のジェネリックから使えるよう S3 メソッドも提供する
# （例: partykit::as.party(fit, data = iris)）
#' @rdname chaid_as_party
#' @exportS3Method partykit::as.party
as.party.chaid <- function(obj, data, weights = NULL, freq = NULL, ...) {
  chaid_as_party(obj, data = data, weights = weights, freq = freq, ...)
}
