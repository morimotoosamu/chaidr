# 11_inspect.R -- ノード要約テーブル・ルール抽出・変数重要度

# root から指定ノードまでのパスを辿り、変数ごとに許容カテゴリコード集合を
# 蓄積する。同一変数が複数回分割に使われた場合は交差（intersect）を取る。
# 返り値: list(変数名 = 整数コードベクトル)
node_conditions <- function(fit, id) {
  conds <- list()
  nd <- fit$nodes[[id]]
  while (!is.na(nd$parent)) {
    par <- fit$nodes[[nd$parent]]
    gi <- match(nd$id, par$split$children)
    codes <- par$split$groups[[gi]]
    vn <- par$split$var
    conds[[vn]] <- if (is.null(conds[[vn]])) codes else intersect(conds[[vn]], codes)
    nd <- par
  }
  conds
}

# 数値を eval で往復可能な文字列にする（text 形式のみ表示用に丸める）。
# IEEE 754 double の完全な往復には 17 有効桁が必要
fmt_num <- function(v, format) {
  if (format == "text") format(v, digits = 4, trim = TRUE) else sprintf("%.17g", v)
}

# 1 変数分の条件をレンダリングする。制約なし（全カテゴリ）なら NULL。
render_condition <- function(p, codes, format) {
  codes <- sort(unique(codes))
  if (setequal(codes, seq_len(p$ncat))) return(NULL)
  var <- p$name
  na_code <- if ("<NA>" %in% p$levels) match("<NA>", p$levels) else NA_integer_
  has_na <- !is.na(na_code) && na_code %in% codes
  or_sep <- switch(format, r = " | ", sql = " OR ", text = " or ")
  na_cond <- switch(format,
    r = paste0("is.na(", var, ")"),
    sql = paste0(var, " IS NULL"),
    text = paste0(var, " is missing"))
  not_na_cond <- switch(format,
    r = paste0("!is.na(", var, ")"),
    sql = paste0(var, " IS NOT NULL"),
    text = paste0(var, " is not missing"))

  if (!is.null(p$breaks)) {
    # ビン化された連続変数: 連続する run ごとに区間条件を作る
    nb <- length(p$breaks)
    bins <- setdiff(codes, na_code)
    parts <- character(0)
    full_range <- length(bins) > 0 && setequal(bins, seq_len(nb))
    if (full_range) {
      # 非欠損の全域: NA を含まないなら「欠損でない」だけが条件
      if (!has_na && !is.na(na_code)) return(not_na_cond)
      if (has_na) return(NULL)  # 全カテゴリ（先頭の setequal で通常捕捉済み）
    } else if (length(bins)) {
      runs <- split(bins, cumsum(c(1, diff(bins) != 1)))
      br <- p$breaks
      parts <- vapply(runs, function(r) {
        lo <- min(r)
        hi <- max(r)
        a <- if (lo > 1) fmt_num(br[lo - 1], format) else NULL
        b <- if (hi < nb) fmt_num(br[hi], format) else NULL
        if (format == "text") {
          if (is.null(a)) paste0(var, " <= ", b)
          else if (is.null(b)) paste0(var, " > ", a)
          else paste0(var, " in (", a, ", ", b, "]")
        } else {
          cmp_and <- if (format == "sql") " AND " else " & "
          if (is.null(a)) paste0(var, " <= ", b)
          else if (is.null(b)) paste0(var, " > ", a)
          else paste0("(", var, " > ", a, cmp_and, var, " <= ", b, ")")
        }
      }, character(1))
    }
    if (has_na) parts <- c(parts, na_cond)
    if (length(parts) == 0) return(NULL)
    if (length(parts) == 1) return(parts)
    return(paste0("(", paste(parts, collapse = or_sep), ")"))
  }

  # factor / ordered
  lv_codes <- setdiff(codes, na_code)
  lv <- p$levels[lv_codes]
  all_nonna <- setequal(lv_codes, setdiff(seq_len(p$ncat), na_code))
  parts <- character(0)
  if (length(lv)) {
    if (all_nonna && !has_na && !is.na(na_code)) return(not_na_cond)
    if (!all_nonna) {
      parts <- switch(format,
        # deparse で R の文字列リテラルとして安全に quote する（"quo\"te" 等）
        r = paste0(var, " %in% c(",
                   paste(vapply(lv, deparse, character(1)), collapse = ", "), ")"),
        # SQL は ' を '' に二重化するのが標準（ANSI）
        sql = paste0(var, " IN (",
                     paste0("'", gsub("'", "''", lv, fixed = TRUE), "'",
                            collapse = ", "), ")"),
        text = paste0(var, " in {", paste(lv, collapse = ", "), "}"))
    }
  }
  if (has_na) parts <- c(parts, na_cond)
  if (length(parts) == 0) return(NULL)
  if (length(parts) == 1) return(parts)
  paste0("(", paste(parts, collapse = or_sep), ")")
}

# 末端ノード（または指定ノード）の到達条件をルールとして出力する。
#   format = "r"    : R の論理式（eval でノード割当を厳密に再現できる）
#            "sql"  : SQL の WHERE 句
#            "text" : 人間可読の条件文
# 返り値: data.frame(node, rule)
#' Extract decision rules from a CHAID tree
#'
#' Returns the condition that a case must satisfy to reach each terminal
#' node (or each of the requested nodes) as a rule string.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param nodes Integer vector of node ids. Defaults to all terminal
#'   nodes.
#' @param format `"text"` (default) for human-readable conditions,
#'   `"sql"` for SQL `WHERE` clauses, or `"r"` for R logical
#'   expressions that reproduce the node assignment exactly when
#'   evaluated against the data.
#'
#' @return A data frame with columns `node` (integer id) and `rule`
#'   (character).
#'
#' @seealso [chaid()], [chaid_table()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' chaid_rules(fit)
#' chaid_rules(fit, format = "sql")
#' @export
chaid_rules <- function(fit, nodes = NULL, format = c("text", "sql", "r")) {
  format <- match.arg(format)
  stopifnot(inherits(fit, "chaid"))
  if (is.null(nodes)) {
    nodes <- vapply(Filter(function(nd) is.null(nd$split), fit$nodes),
                    function(nd) nd$id, integer(1))
  }
  bad <- setdiff(nodes, vapply(fit$nodes, function(nd) nd$id, integer(1)))
  if (length(bad)) stop("chaid_rules: unknown node ids: ", paste(bad, collapse = ", "))
  everything <- switch(format, r = "TRUE", sql = "1=1", text = "(all cases)")
  rules <- vapply(nodes, function(id) {
    conds <- node_conditions(fit, id)
    if (!length(conds)) return(everything)
    parts <- unlist(lapply(names(conds), function(vn) {
      render_condition(fit$predictors[[vn]], conds[[vn]], format)
    }))
    if (!length(parts)) return(everything)
    paste(parts, collapse = switch(format, r = " & ", sql = " AND ", text = " and "))
  }, character(1))
  data.frame(node = as.integer(nodes), rule = rules, stringsAsFactors = FALSE)
}

# 末端ノードの要約テーブル。
# カテゴリカル目的変数: 予測クラス・クラス別構成比・（target 指定時）反応率と
# インデックス値（= 反応率 / 全体反応率 × 100）。
# 連続目的変数: 平均・標準偏差・インデックス値（= 平均 / 全体平均 × 100）。
# 先頭行は root（インデックス 100 の基準）。
# 注意: n は頻度重み合計（N_f）、pct_n / 構成比はケース重み込み（w×f）で
# 集計する。ケース重みを使わない限り両者のスケールは一致する。
#' Summary table of CHAID terminal nodes
#'
#' Builds a segment summary of the terminal nodes. The first row is the
#' root node, which serves as the baseline (index 100). For categorical
#' responses the table contains the predicted class and the class
#' shares, plus, when `target` is given, the response rate and the
#' index value (response rate relative to the root, times 100). For
#' continuous responses it contains the node mean, standard deviation
#' and the index of the mean.
#'
#' Note that `n` is the sum of frequency weights while `pct_n` and the
#' class shares are computed with case weights included; the two scales
#' coincide unless case weights are used.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#' @param target Optional response level of interest (categorical
#'   responses only). Adds `response_rate` and `index` columns.
#'
#' @return A data frame with one row for the root followed by one row
#'   per terminal node, including the reaching rule in the `rule`
#'   column.
#'
#' @seealso [chaid_rules()], [chaid_gains()], [chaid_importance()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' chaid_table(fit)
#' chaid_table(fit, target = "virginica")
#' @export
chaid_table <- function(fit, target = NULL) {
  stopifnot(inherits(fit, "chaid"))
  terms <- Filter(function(nd) is.null(nd$split), fit$nodes)
  root <- fit$nodes[[1]]
  rules <- chaid_rules(fit, format = "text")
  ids <- c(1L, vapply(terms, function(nd) nd$id, integer(1)))
  ids <- unique(ids)

  base <- data.frame(
    node = ids,
    depth = vapply(ids, function(i) fit$nodes[[i]]$depth, integer(1)),
    n = round(vapply(ids, function(i) fit$nodes[[i]]$Nf, numeric(1))),
    pct_n = round(100 * vapply(ids, function(i) fit$nodes[[i]]$W, numeric(1)) / root$W, 1),
    stringsAsFactors = FALSE
  )

  if (fit$response$type == "numeric") {
    base$mean <- vapply(ids, function(i) unname(fit$nodes[[i]]$dist["mean"]), numeric(1))
    base$sd <- vapply(ids, function(i) unname(fit$nodes[[i]]$dist["sd"]), numeric(1))
    base$index <- round(100 * base$mean / base$mean[1], 1)
  } else {
    lv <- fit$response$levels
    shares <- t(vapply(ids, function(i) {
      d <- fit$nodes[[i]]$dist
      d / sum(d)
    }, numeric(length(lv))))
    colnames(shares) <- paste0("p_", lv)
    base$prediction <- vapply(ids, function(i) as.character(fit$nodes[[i]]$prediction),
                              character(1))
    base <- cbind(base, round(shares, 4))
    if (!is.null(target)) {
      if (!target %in% lv) stop("chaid_table: target is not a response level: ", target)
      rate <- shares[, paste0("p_", target)]
      base$response_rate <- round(rate, 4)
      base$index <- round(100 * rate / rate[1], 1)
    }
  }
  base$rule <- c("(root)", rules$rule[match(ids[-1], rules$node)])
  base
}

# 変数重要度（ヒューリスティック）。
# SPSS に CHAID の公式な重要度指標は存在しない。χ²/F は自由度が異なり
# 直接加算できないため、ここでは p 値ベースの指標を採用する:
#   importance = Σ_分割 (ノードの N_f / root の N_f) × (−log10(max(p_adj, 1e-300)))
# 「大きなノードを強い有意性で分割した変数ほど重要」という解釈。
#' Heuristic variable importance for a CHAID tree
#'
#' SPSS defines no official importance measure for CHAID, and the
#' chi-squared and F statistics of different splits are not directly
#' comparable because their degrees of freedom differ. This function
#' therefore uses a p-value based heuristic: for each predictor,
#' `importance` is the sum over its splits of
#' `(node size / root size) * (-log10(adjusted p-value))`, i.e. a
#' variable is important when it splits large nodes with strong
#' significance.
#'
#' @param fit A fitted `"chaid"` object returned by [chaid()].
#'
#' @return A data frame with one row per predictor actually used for a
#'   split, sorted by decreasing importance: `variable`, `n_splits`,
#'   `min_p_adj`, `importance` and `importance_pct` (share of the total
#'   importance in percent).
#'
#' @seealso [chaid()], [chaid_table()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' chaid_importance(fit)
#' @export
chaid_importance <- function(fit) {
  stopifnot(inherits(fit, "chaid"))
  splits <- Filter(function(nd) !is.null(nd$split), fit$nodes)
  vars <- vapply(fit$predictors, `[[`, character(1), "name")
  if (length(splits) == 0) {
    return(data.frame(variable = character(0), n_splits = integer(0),
                      min_p_adj = numeric(0), importance = numeric(0),
                      importance_pct = numeric(0)))
  }
  root_nf <- fit$nodes[[1]]$Nf
  imp <- setNames(numeric(length(vars)), vars)
  cnt <- setNames(integer(length(vars)), vars)
  minp <- setNames(rep(1, length(vars)), vars)
  for (nd in splits) {
    v <- nd$split$var
    imp[v] <- imp[v] + (nd$Nf / root_nf) * (-log10(max(nd$split$p_adj, 1e-300)))
    cnt[v] <- cnt[v] + 1L
    minp[v] <- min(minp[v], nd$split$p_adj)
  }
  used <- cnt > 0
  out <- data.frame(variable = vars[used], n_splits = cnt[used],
                    min_p_adj = minp[used], importance = imp[used],
                    row.names = NULL, stringsAsFactors = FALSE)
  total <- sum(out$importance)
  out$importance_pct <- if (total > 0) round(100 * out$importance / total, 1) else 0
  out[order(-out$importance), ]
}
