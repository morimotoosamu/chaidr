# 06_chaid.R -- ユーザー API: chaid_control() と chaid()

# アルゴリズムのパラメータ。既定値は SPSS UI の既定に合わせている
# （alpha 0.05 / Bonferroni オン / resplit オフ / 最大深さ 3 /
#   min_parent 100 / min_child 50 / ビン数 10）。
#
# adjust_across: ノードでの分割変数選択（予測変数間）の多重比較補正。
# SPSS はこの層を無補正（最小 p_adj を alpha_split と比較するだけ）なので
# 既定は "none"。それ以外は stats::p.adjust の同名手法をノード内の
# 「検定を実行できた予測変数の p_adj ベクトル」へ適用し、補正後の p 値
# （p_final）で分割可否を判定する。統計的注意:
#  - 補正の family はノード単位。木全体の FWER / FDR は制御されない
#    （ノード数が増えるほど木としての偽分割の期待数は増える。これは
#    SPSS 既定の無補正でも同じ構造的性質）
#  - 深いノードのデータは親の「データ依存の分割選択」で条件付けられて
#    いるため p 値は帰無分布に正確には従わない（選択後推論の問題）。
#    どの補正もこれは解決しない。CHAID の p 値は厳密な検定ではなく
#    分割の停止基準として解釈すること
#  - hochberg / hommel は検定間の正の従属（MTP2）、BH は PRDS を仮定する。
#    仮定を置きたくなければ holm（FWER・任意従属）か BY（FDR・任意従属）
#  - 入力はカテゴリ結合の Bonferroni 補正済みの保守的な p 値なので、
#    BH / BY の名目 FDR 水準は近似的な上界
#  - 分割可否は「最小の補正後 p 値 vs alpha_split」の単一判定なので、
#    holm は bonferroni と常に同一の木を与える（決定同値）。
#    Bonferroni より緩い補正が目的なら hochberg / hommel / BH を使う
#' Control parameters for CHAID tree growing
#'
#' Collects the algorithm parameters used by [chaid()]. The defaults match
#' the defaults of the IBM SPSS Statistics user interface (alpha 0.05,
#' Bonferroni adjustment on, no re-splitting, maximum depth 3, minimum
#' parent size 100, minimum child size 50, 10 bins for continuous
#' predictors).
#'
#' @param alpha_merge Significance level for merging predictor categories.
#'   Category pairs whose test p-value exceeds this threshold are merged.
#' @param alpha_split Significance level for splitting a node. A node is
#'   split only if the best (adjusted) p-value is at most this value.
#' @param alpha_split_merge Significance level for re-splitting a merged
#'   compound category. Only used when `resplit = TRUE`.
#' @param resplit Logical. If `TRUE`, compound categories consisting of
#'   three or more original categories are considered for a binary
#'   re-split during the merge step (SPSS "allow resplitting" option).
#' @param bonferroni Logical. If `TRUE` (default), split p-values are
#'   Bonferroni-adjusted by the number of ways the predictor categories
#'   can be merged into the final groups.
#' @param stat Chi-squared statistic for categorical responses:
#'   `"pearson"` (default) or `"lr"` (likelihood ratio).
#' @param exhaustive_adjust Bonferroni multiplier convention used by
#'   Exhaustive CHAID: `"spss"` (default) follows the IBM SPSS algorithm
#'   document, `"biggs"` follows Biggs, de Ville and Suen (1991).
#' @param max_depth Maximum tree depth (root has depth 0).
#' @param min_parent Minimum number of cases (frequency-weighted) a node
#'   must contain to be considered for splitting.
#' @param min_child Minimum number of cases (frequency-weighted) in each
#'   child node.
#' @param min_segment Optional minimum size for a merged category group
#'   during the merge step (SPSS algorithm step 7). Groups smaller than
#'   this are absorbed into the most similar allowable group. `NULL`
#'   (default) disables this step.
#' @param n_bins Number of quantile bins used to discretise continuous
#'   predictors.
#' @param epsilon Convergence tolerance for the iterative estimation of
#'   expected cell frequencies with case weights.
#' @param max_iter Maximum number of iterations for the same estimation.
#' @param adjust_across Multiple-comparison adjustment applied across
#'   predictors within a node before comparing against `alpha_split`.
#'   `"none"` (default, as in SPSS) or one of the [stats::p.adjust()]
#'   methods `"bonferroni"`, `"holm"`, `"hochberg"`, `"hommel"`, `"BH"`,
#'   `"BY"`. Note that the adjustment family is the node, not the whole
#'   tree, and that `"holm"` always yields the same tree as
#'   `"bonferroni"` because only the minimum adjusted p-value is compared
#'   with `alpha_split`.
#'
#' @return An object of class `"chaid_control"`: a list of the validated
#'   parameter values, to be passed to the `control` argument of
#'   [chaid()].
#'
#' @seealso [chaid()]
#' @examples
#' ctl <- chaid_control(max_depth = 2, min_parent = 20, min_child = 5)
#' fit <- chaid(Species ~ ., data = iris, control = ctl)
#' fit
#' @export
chaid_control <- function(alpha_merge = 0.05, alpha_split = 0.05,
                          alpha_split_merge = 0.05, resplit = FALSE,
                          bonferroni = TRUE, stat = c("pearson", "lr"),
                          exhaustive_adjust = c("spss", "biggs"),
                          max_depth = 3L, min_parent = 100, min_child = 50,
                          min_segment = NULL, n_bins = 10L,
                          epsilon = 1e-3, max_iter = 100L,
                          adjust_across = c("none", "bonferroni", "holm",
                                            "hochberg", "hommel", "BH", "BY")) {
  stat <- match.arg(stat)
  exhaustive_adjust <- match.arg(exhaustive_adjust)
  adjust_across <- match.arg(adjust_across)
  for (a in list(alpha_merge, alpha_split, alpha_split_merge)) {
    if (!is.numeric(a) || length(a) != 1 || a < 0 || a > 1) {
      stop("chaid_control: alpha must be a single value in [0, 1]")
    }
  }
  # 整数パラメータは silent 切り下げを避けるため厳格に検証する
  is_integerish <- function(v) {
    is.numeric(v) && length(v) == 1 && is.finite(v) && v == as.integer(v)
  }
  if (!is_integerish(max_depth) || max_depth < 1) {
    stop("chaid_control: max_depth must be an integer >= 1")
  }
  if (!is_integerish(n_bins) || n_bins < 2) {
    stop("chaid_control: n_bins must be an integer >= 2")
  }
  if (!is_integerish(max_iter) || max_iter < 1) {
    stop("chaid_control: max_iter must be an integer >= 1")
  }
  if (min_child < 1 || min_parent < 1) {
    stop("chaid_control: min_parent / min_child must be >= 1")
  }
  structure(list(alpha_merge = alpha_merge, alpha_split = alpha_split,
                 alpha_split_merge = alpha_split_merge, resplit = resplit,
                 bonferroni = bonferroni, stat = stat,
                 exhaustive_adjust = exhaustive_adjust,
                 adjust_across = adjust_across,
                 max_depth = as.integer(max_depth),
                 min_parent = min_parent, min_child = min_child,
                 min_segment = min_segment, n_bins = as.integer(n_bins),
                 epsilon = epsilon, max_iter = as.integer(max_iter)),
            class = "chaid_control")
}

# ビン境界から表示用ラベルを作る
bin_labels <- function(breaks) {
  nb <- length(breaks)
  fmt <- function(v) format(v, digits = 4, trim = TRUE)
  if (nb == 1) return(paste0("<= ", fmt(breaks[1])))
  c(paste0("<= ", fmt(breaks[1])),
    paste0("(", fmt(breaks[-nb]), ", ", fmt(breaks[-1]), "]"))
}

# 予測変数 1 本を内部表現へ変換する。
# numeric  -> 分位ビン分割して順序型（NA は浮動カテゴリ）
# ordered  -> 順序型（NA は浮動カテゴリ）
# factor   -> 名義型（NA は通常カテゴリ "<NA>" として追加）
prep_predictor <- function(x, name, wf, n_bins) {
  breaks <- NULL
  if (is.numeric(x)) {
    if (all(is.na(x))) stop("predictor '", name, "' is missing for all cases")
    b <- bin_continuous(x, wf, n_bins)
    code <- b$xbin
    breaks <- b$breaks
    labels <- bin_labels(breaks)
    ptype <- "ordinal"
    ncat <- b$nbins
  } else if (is.factor(x)) {
    code <- as.integer(x)
    labels <- levels(x)
    ptype <- if (is.ordered(x)) "ordinal" else "nominal"
    ncat <- nlevels(x)
  } else {
    stop("unsupported type (", class(x)[1], ") for predictor '", name,
         "'; use numeric, factor, or ordered")
  }
  float_code <- NA_integer_
  if (anyNA(code)) {
    # 順序型は浮動カテゴリ（任意グループと結合可能）、名義型は通常カテゴリ
    if (ptype == "ordinal") float_code <- ncat + 1L
    code[is.na(code)] <- ncat + 1L
    labels <- c(labels, "<NA>")
    ncat <- ncat + 1L
  }
  list(name = name, code = code, ptype = ptype, float_code = float_code,
       levels = labels, breaks = breaks, ncat = ncat)
}

# CHAID / Exhaustive CHAID 決定木の学習。
#   formula: 目的変数 ~ 予測変数
#   weights: ケース重み（期待度数の推定にのみ反映。欠損/0/負のケースは除外）
#   freq:    頻度重み（観測度数・自由度・ノードサイズを決める。整数へ丸め）
#   costs:   誤分類コスト行列 C[truth, pred]（rpart の loss と同じ規約。
#            対角 0・非負・行名列名は目的変数の水準に一致）。指定すると
#            ノードの予測クラスが argmax p から期待コスト最小に変わる。
#            SPSS 準拠で木の成長・検定には影響しない
#   y_scores: 順序型目的変数のクラススコア（levels 順の数値ベクトル）。
#             省略時はクラス順位 1..J。木の開始時に固定され、結合フェーズの
#             部分表でも再採番されない（IBM 仕様）
#' Fit a CHAID or Exhaustive CHAID decision tree
#'
#' Grows a CHAID (Chi-squared Automatic Interaction Detection) or
#' Exhaustive CHAID decision tree following the IBM SPSS Statistics
#' algorithm specification. Nominal (`factor`), ordinal (`ordered`) and
#' continuous (`numeric`) predictors are supported; continuous predictors
#' are discretised into quantile bins first. The response may be nominal
#' (Pearson or likelihood-ratio chi-squared test), ordinal (Goodman row
#' effects test) or continuous (one-way ANOVA F test).
#'
#' Missing predictor values are handled as in SPSS: for ordinal
#' predictors they form a floating category that may merge with any
#' group, for nominal predictors they form an ordinary extra category.
#' Cases with a missing response, missing/zero/negative weights, or all
#' predictors missing are dropped before fitting.
#'
#' @param formula A model formula of the form `response ~ predictors`.
#' @param data A data frame containing the variables in the formula.
#' @param weights Optional numeric vector of case weights. They only
#'   affect the estimation of expected cell frequencies; cases with
#'   missing, zero or negative weights are excluded.
#' @param freq Optional numeric vector of frequency weights. They
#'   determine observed counts, degrees of freedom and node sizes.
#'   Non-integer values are rounded to the nearest integer (IBM
#'   specification).
#' @param method `"chaid"` (default) for the Kass (1980) algorithm or
#'   `"exhaustive"` for Exhaustive CHAID (Biggs, de Ville and Suen,
#'   1991).
#' @param control A `"chaid_control"` object created by
#'   [chaid_control()].
#' @param costs Optional misclassification cost matrix `C[truth, pred]`
#'   for categorical responses (same convention as the `loss` matrix of
#'   'rpart': zero diagonal, non-negative entries, dimnames matching the
#'   response levels). When supplied, node predictions minimise expected
#'   cost instead of taking the majority class. As in SPSS, costs do not
#'   affect tree growing or the significance tests.
#' @param y_scores Optional numeric vector of class scores for an ordinal
#'   response, in the order of `levels(y)`. Defaults to the class ranks
#'   `1..J`. Fixed at the start of tree growing and not re-ranked in
#'   subtables (IBM specification).
#'
#' @return An object of class `"chaid"`: a list with components `call`,
#'   `method`, `control`, `response` (name, type, levels, scores),
#'   `predictors` (internal coding of each predictor), `nodes` (list of
#'   node records with distribution, prediction and split information),
#'   `costs`, `n` (number of cases used) and `n_dropped` (number of
#'   excluded cases).
#'
#' @references
#' Kass, G. V. (1980). An exploratory technique for investigating large
#' quantities of categorical data. *Applied Statistics*, 29(2), 119-127.
#'
#' Biggs, D., de Ville, B., & Suen, E. (1991). A method of choosing
#' multiway partitions for classification and decision trees. *Journal
#' of Applied Statistics*, 18(1), 49-62.
#'
#' @seealso [chaid_control()], [predict.chaid()], [chaid_table()],
#'   [chaid_rules()], [plot.chaid()]
#' @examples
#' fit <- chaid(Species ~ ., data = iris,
#'              control = chaid_control(min_parent = 30, min_child = 10))
#' print(fit)
#' predict(fit, head(iris))
#' @export
chaid <- function(formula, data, weights = NULL, freq = NULL,
                  method = c("chaid", "exhaustive"),
                  control = chaid_control(), costs = NULL, y_scores = NULL) {
  method <- match.arg(method)
  stopifnot(inherits(control, "chaid_control"))
  cl <- match.call()

  mf <- stats::model.frame(formula, data = data, na.action = stats::na.pass)
  y <- stats::model.response(mf)
  X <- mf[, -1, drop = FALSE]
  if (ncol(X) == 0) stop("chaid: no predictors specified")
  n <- nrow(mf)

  w <- if (is.null(weights)) rep(1, n) else as.numeric(weights)
  f0 <- if (is.null(freq)) rep(1, n) else as.numeric(freq)
  if (length(w) != n) stop("chaid: length of weights does not match the data")
  if (length(f0) != n) stop("chaid: length of freq does not match the data")
  f <- round(f0)  # 頻度重みの非整数は最近傍整数へ丸める（IBM 仕様）

  # ケース除外: 目的変数欠損 / 重み欠損・0・負 / 全予測変数欠損
  keep <- !is.na(y) & !is.na(w) & w > 0 & !is.na(f) & f > 0
  keep <- keep & !Reduce(`&`, lapply(X, is.na))
  n_dropped <- sum(!keep)
  if (!any(keep)) stop("chaid: no valid cases")

  y <- y[keep]
  X <- X[keep, , drop = FALSE]
  w <- w[keep]
  f <- f[keep]

  if (is.factor(y)) {
    ytype <- if (is.ordered(y)) "ordinal" else "factor"
    lv_before <- levels(y)
    y <- factor(y)  # 内部表現は factor で統一（水準順は元の順序を保持）
    # 順序型のクラススコア。既定はクラス順位 1..J（IBM 仕様）
    if (ytype == "ordinal") {
      scores <- if (is.null(y_scores)) {
        seq_len(length(lv_before))
      } else {
        as.numeric(y_scores)
      }
      if (length(scores) != length(lv_before)) {
        stop("chaid: length of y_scores (", length(scores),
             ") does not match the number of response levels (",
             length(lv_before), ")")
      }
      if (any(!is.finite(scores))) stop("chaid: y_scores must be finite")
      if (length(unique(scores)) < 2) stop("chaid: y_scores needs at least two distinct values")
      # 単調増加・単調減少のいずれでもない場合のみ警告する
      # （減少はアフィン反転と等価で H² は不変。意味論上も許容）
      if (is.unsorted(scores) && is.unsorted(rev(scores))) {
        warning("chaid: y_scores is not monotone; this departs from ordinal semantics")
      }
      # factor(y) が未使用水準を落とした場合はスコアも同期して間引く
      scores <- scores[match(levels(y), lv_before)]
    } else {
      if (!is.null(y_scores)) stop("chaid: y_scores is only for ordered factor responses")
      scores <- NULL
    }
  } else if (is.numeric(y)) {
    if (!is.null(y_scores)) stop("chaid: y_scores is only for ordered factor responses")
    ytype <- "numeric"
    scores <- NULL
  } else {
    stop("chaid: the response must be a factor or numeric")
  }
  # 結合フェーズへスコアを配管する（chaid_control のユーザー API は変えない）
  control$y_scores <- scores

  # 誤分類コスト行列の検証（カテゴリカル目的変数のみ）
  if (!is.null(costs)) {
    if (ytype == "numeric") stop("chaid: costs is only for categorical responses")
    lv <- levels(y)
    J <- length(lv)
    if (!is.matrix(costs) || !all(dim(costs) == c(J, J))) {
      stop("chaid: costs must be a ", J, "x", J, " matrix")
    }
    if (is.null(dimnames(costs))) {
      dimnames(costs) <- list(lv, lv)
    } else if (!identical(rownames(costs), lv) || !identical(colnames(costs), lv)) {
      stop("chaid: dimnames of costs must match the response levels (",
           paste(lv, collapse = ", "), ")")
    }
    if (any(diag(costs) != 0)) stop("chaid: the diagonal of costs must be 0")
    if (any(costs < 0)) stop("chaid: costs must be non-negative")
  }

  preds <- lapply(seq_along(X), function(i) {
    prep_predictor(X[[i]], names(X)[i], w * f, control$n_bins)
  })
  names(preds) <- names(X)

  state <- new.env(parent = emptyenv())
  state$y <- y
  state$ytype <- ytype
  state$preds <- preds
  state$w <- w
  state$f <- f
  state$control <- control
  state$method <- method
  state$costs <- costs
  state$nodes <- list()
  state$next_id <- 1L

  grow_node(state, seq_along(y), depth = 0L, parent = NA_integer_)

  structure(list(
    call = cl,
    method = method,
    control = control,
    response = list(name = deparse(formula[[2]]), type = ytype,
                    levels = if (ytype != "numeric") levels(y) else NULL,
                    scores = scores),
    predictors = preds,
    nodes = state$nodes,
    costs = costs,
    n = length(y),
    n_dropped = n_dropped
  ), class = "chaid")
}
