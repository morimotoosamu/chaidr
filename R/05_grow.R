# 05_grow.R -- 再帰的な木構築・分割選択・停止規則
# 停止規則（IBM 仕様）:
#   (1) 純粋ノード（目的変数が単一値）
#   (2) 全予測変数がノード内で一定
#   (3) 最大深さ到達
#   (4) ノードの頻度重み合計 N_f < min_parent
#   (5) 最良分割の調整済み p 値 > alpha_split
#   (6) min_child 未満の子を最類似の子へ統合した結果、子が 1 つになった

# ノードの記述統計。カテゴリカル目的変数はクラス別 w*f 合計と予測クラス、
# 連続目的変数は加重平均と加重標準偏差。
# 予測クラスは通常は最頻クラス（argmax）だが、誤分類コスト行列 costs
# （C[truth, pred]）が指定されていれば期待コスト最小のクラスを選ぶ。
node_stats <- function(state, idx) {
  w <- state$w[idx]
  f <- state$f[idx]
  y <- state$y[idx]
  wf <- w * f
  nf <- sum(f)
  wt <- sum(wf)
  if (state$ytype != "numeric") {
    # クラス別 w*f 合計。levels ごとの走査（O(J·n)）ではなく rowsum 1 回で集計
    dsum <- rowsum(wf, as.integer(y))
    dist <- stats::setNames(numeric(nlevels(state$y)), levels(state$y))
    dist[as.integer(rownames(dsum))] <- dsum
    if (is.null(state$costs)) {
      pred <- names(dist)[which.max(dist)]
    } else {
      # 期待コスト = Σ_truth p(truth) * C[truth, pred]（列ごと）
      expcost <- as.numeric(dist %*% state$costs)
      pred <- colnames(state$costs)[which.min(expcost)]
    }
  } else {
    mu <- sum(wf * y) / wt
    sd_ <- if (nf > 1) sqrt(sum(wf * (y - mu)^2) / (nf - 1)) else 0
    dist <- c(mean = mu, sd = sd_)
    pred <- mu
  }
  list(n = length(idx), Nf = nf, W = wt, dist = dist, prediction = pred)
}

# 2 つの結合結果の優劣（TRUE なら a が b より良い）。
# 調整済み p 値 → 未調整 p 値 → 統計量（大きい方）→ 先着（変数順）で比較。
better_split <- function(a, b) {
  tol <- 1e-12
  if (a$p_adj < b$p_adj - tol) return(TRUE)
  if (a$p_adj > b$p_adj + tol) return(FALSE)
  if (a$p_unadj < b$p_unadj - tol) return(TRUE)
  if (a$p_unadj > b$p_unadj + tol) return(FALSE)
  a$statistic > b$statistic + tol
}

# 1 ノードを構築し、必要なら再帰的に子を構築する。ノード id を返す。
grow_node <- function(state, idx, depth, parent) {
  id <- state$next_id
  state$next_id <- id + 1L
  st <- node_stats(state, idx)
  node <- list(id = id, parent = parent, depth = depth,
               n = st$n, Nf = st$Nf, W = st$W,
               dist = st$dist, prediction = st$prediction,
               split = NULL, terminal_reason = NULL)
  state$nodes[[id]] <- node

  ctl <- state$control
  y <- state$y[idx]
  w_idx <- state$w[idx]
  f_idx <- state$f[idx]

  # 停止判定（分割前）。カテゴリカルは node_stats のクラス分布を再利用
  # （w*f > 0 が保証されているため dist > 0 ⇔ クラスが存在する）
  pure <- if (state$ytype != "numeric") {
    sum(st$dist > 0) < 2
  } else {
    stats::var(y) <= .Machine$double.eps * max(1, mean(y)^2)
  }
  reason <- if (pure) {
    "pure"
  } else if (depth >= ctl$max_depth) {
    "max_depth"
  } else if (st$Nf < ctl$min_parent) {
    "min_parent"
  } else {
    NULL
  }

  if (is.null(reason)) {
    # 各予測変数の結合フェーズを実行し、調整済み p 値最小の変数を選ぶ。
    # family（p_ids / p_vec）は検定を実行できた（非 NULL の）予測変数のみで
    # 構成する — 実在カテゴリ < 2 の変数は仮説自体が存在しないため除外。
    best <- NULL
    best_var <- NA_integer_
    p_ids <- integer(0)
    p_vec <- numeric(0)
    for (pi in seq_along(state$preds)) {
      p <- state$preds[[pi]]
      res <- merge_predictor(p$code[idx], y, w_idx, f_idx,
                             p$ptype, p$float_code, state$method,
                             state$ytype, ctl)
      if (is.null(res)) next
      p_ids <- c(p_ids, pi)
      p_vec <- c(p_vec, res$p_adj)
      if (is.null(best) || better_split(res, best)) {
        best <- res
        best_var <- pi
      }
    }
    # 予測変数間の多重比較補正（adjust_across）。変数選択は補正前の p_adj
    # で行い（p.adjust の全手法は単調なので argmin は不変）、alpha_split
    # との比較のみ補正後の p_final で行う。
    ac <- ctl$adjust_across
    if (is.null(ac)) ac <- "none"  # 旧 chaid_control オブジェクトへの防御
    p_final <- if (is.null(best)) {
      NA_real_
    } else {
      stats::p.adjust(p_vec, method = ac)[match(best_var, p_ids)]
    }
    if (is.null(best)) {
      reason <- "no_predictor"      # 全予測変数がノード内で一定
    } else if (p_final > ctl$alpha_split) {
      reason <- "not_significant"
    } else {
      # min_child: 小さすぎる子を最類似の子へ統合（1 つになれば分割しない）
      # 検定・グループサイズは merge_predictor が集計済みの十分統計量 best$ss
      # で計算する（ノード内生データの再集計は不要）
      p <- state$preds[[best_var]]
      pt <- if (best$ptype_eff == "floating") "ordinal" else best$ptype_eff
      groups <- absorb_small_groups(best$groups, best$ss, pt, ctl,
                                    ctl$min_child, p$float_code)
      if (length(groups) < 2) {
        reason <- "min_child"
      } else {
        # min_child 吸収でグループ構成が変わった場合は、報告する統計量・
        # 乗数 B・調整済み p 値を最終構成で再計算する（表示と実グループの
        # 整合のため）。分割の成否判定自体は結合フェーズの p 値で確定済み
        # （SPSS の min_child は分割成立後の子ノード統合として扱われる）。
        if (!identical(groups, best$groups)) {
          res2 <- config_pvalue(groups, best$ss, ctl)
          B2 <- if (isTRUE(ctl$bonferroni)) {
            bonferroni_multiplier(best$I_pres, length(groups), best$ptype_eff,
                                  state$method, ctl$exhaustive_adjust)
          } else {
            1
          }
          best$statistic <- res2$statistic
          best$df <- res2$df
          best$p_unadj <- res2$p
          best$B <- B2
          best$p_adj <- min(1, B2 * res2$p)
          # p_final も更新後の p_adj で再計算（表示整合のみ。分割可否は確定済み）
          p_vec[match(best_var, p_ids)] <- best$p_adj
          p_final <- stats::p.adjust(p_vec, method = ac)[match(best_var, p_ids)]
        }
        # 分割を確定して子ノードを再帰構築
        g <- assign_groups(p$code[idx], groups)
        stopifnot(!anyNA(g))
        children <- integer(length(groups))
        for (gi in seq_along(groups)) {
          children[gi] <- grow_node(state, idx[g == gi], depth + 1L, id)
        }
        node$split <- list(var = p$name, var_index = best_var,
                           groups = groups, children = children,
                           statistic = best$statistic, df = best$df,
                           p_unadj = best$p_unadj, B = best$B,
                           p_adj = best$p_adj, p_final = p_final,
                           n_family = length(p_vec), ptype = best$ptype_eff)
      }
    }
  }

  node$terminal_reason <- reason
  state$nodes[[id]] <- node
  id
}
