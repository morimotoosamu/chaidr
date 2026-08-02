# 07_predict.R -- 学習済み CHAID 木による予測

# newdata の各予測変数を学習時のコード体系へ変換する。
# 未知の因子水準は NA_integer_（後段でフォールバック）。
recode_newdata <- function(object, newdata) {
  lapply(object$predictors, function(p) {
    if (!p$name %in% names(newdata)) {
      stop("predict.chaid: variable '", p$name, "' not found in newdata")
    }
    x <- newdata[[p$name]]
    if (!is.null(p$breaks)) {
      if (!is.numeric(x)) stop("predict.chaid: '", p$name, "' must be numeric")
      code <- bin_apply(x, p$breaks)
    } else {
      code <- match(as.character(x), setdiff(p$levels, "<NA>"))
    }
    # 学習時に NA カテゴリがあれば NA をそのコードへ
    if ("<NA>" %in% p$levels) {
      na_code <- match("<NA>", p$levels)
      code[is.na(x)] <- na_code
    }
    code
  })
}

# 分割時のグループに含まれないコード（= そのノードには実在しなかった
# 元カテゴリ、および学習時に未知だった水準・NA）を子ノードへ振り分ける。
# 順序型: コード距離が最小のグループへ（外挿的だが自然）。
# 名義型・NA・その他フォールバック: 最大ノードサイズ（N_f）の子へ。
route_children <- function(node, codes_var, ordinal, nodes) {
  groups <- node$split$groups
  children <- node$split$children
  gmap <- rep(NA_integer_, max(unlist(groups), codes_var, na.rm = TRUE))
  for (gi in seq_along(groups)) gmap[groups[[gi]]] <- gi
  gi <- ifelse(is.na(codes_var), NA_integer_, gmap[codes_var])
  unmapped <- which(is.na(gi))
  if (length(unmapped)) {
    nf_child <- vapply(children, function(cid) nodes[[cid]]$Nf, numeric(1))
    fallback <- which.max(nf_child)
    for (r in unmapped) {
      code <- codes_var[r]
      if (ordinal && !is.na(code)) {
        d <- vapply(groups, function(g) min(abs(g - code)), numeric(1))
        gi[r] <- which.min(d)
      } else {
        gi[r] <- fallback
      }
    }
  }
  children[gi]
}

#' Predict from a fitted CHAID tree
#'
#' Routes the rows of `newdata` down the tree and returns predictions.
#' Factor levels unseen during training, and codes that did not occur in
#' a node when it was split, are routed to the child with the largest
#' node size (for ordinal predictors, to the group with the smallest
#' code distance); a warning is issued when unseen levels are detected.
#'
#' @param object A fitted `"chaid"` object returned by [chaid()].
#' @param newdata A data frame containing all predictor variables used
#'   in the fit.
#' @param type `"response"` (default) returns predicted classes (or
#'   means for a continuous response), `"prob"` returns a matrix of
#'   class probabilities (categorical responses only), `"node"` returns
#'   the terminal node id for each row.
#' @param ... Ignored.
#'
#' @return Depending on `type`: a factor (or numeric vector) of
#'   predictions, a numeric matrix of class probabilities with one
#'   column per response level, or an integer vector of node ids.
#'
#' @seealso [chaid()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' predict(fit, head(iris))
#' predict(fit, head(iris), type = "prob")
#' predict(fit, head(iris), type = "node")
#' @export
predict.chaid <- function(object, newdata,
                          type = c("response", "prob", "node"), ...) {
  type <- match.arg(type)
  codes <- recode_newdata(object, newdata)
  n <- nrow(newdata)
  nodes <- object$nodes

  # 未知水準の検出は recode_newdata の結果を再利用する
  # （code が NA になるのは「未知水準」か「NA カテゴリ未学習の欠損」のみで、
  #   後者は !is.na(x) で除外される）
  unknown_seen <- FALSE
  for (pi in seq_along(object$predictors)) {
    p <- object$predictors[[pi]]
    if (is.null(p$breaks)) {
      if (any(is.na(codes[[pi]]) & !is.na(newdata[[p$name]]))) {
        unknown_seen <- TRUE
      }
    }
  }
  if (unknown_seen) {
    warning("predict.chaid: levels not seen during fitting detected; ",
            "assigning those cases to the child with the largest node size")
  }

  # nodes は grow_node の深さ優先前順（親が必ず子より前）なので 1 パスで
  # 全行をルーティングできる。ノード id ごとの行番号バケットを持たせて
  # cur の全走査（which(cur == id)）を排除する。
  cur <- rep(1L, n)
  bucket <- vector("list", length(nodes))
  bucket[[1L]] <- seq_len(n)
  for (nd in nodes) {
    rows <- bucket[[nd$id]]
    if (is.null(nd$split) || !length(rows)) next
    p <- object$predictors[[nd$split$var_index]]
    child <- route_children(nd, codes[[nd$split$var_index]][rows],
                            ordinal = (p$ptype == "ordinal"), nodes)
    cur[rows] <- child
    for (cid in nd$split$children) {
      bucket[[cid]] <- rows[child == cid]
    }
    bucket[nd$id] <- list(NULL)  # 配分済みバケットを解放
  }

  if (type == "node") return(cur)
  if (type == "response") {
    # 行ごとのリスト索引を避け、ノード別テーブルを 1 回作って参照する
    if (object$response$type != "numeric") {
      preds_by_node <- vapply(nodes, function(nd) nd$prediction, character(1))
      return(factor(preds_by_node[cur], levels = object$response$levels,
                    ordered = (object$response$type == "ordinal")))
    }
    means_by_node <- vapply(nodes, function(nd) nd$prediction, numeric(1))
    return(means_by_node[cur])
  }
  # type == "prob"（カテゴリカル・順序目的変数のみ）
  if (object$response$type == "numeric") {
    stop("predict.chaid: type='prob' is only for categorical responses")
  }
  probs_by_node <- t(vapply(nodes, function(nd) {
    d <- nd$dist
    d / sum(d)
  }, numeric(length(object$response$levels))))
  probs <- probs_by_node[cur, , drop = FALSE]
  colnames(probs) <- object$response$levels
  probs
}
