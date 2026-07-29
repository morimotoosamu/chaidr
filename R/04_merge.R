# 04_merge.R -- 結合（Merging）フェーズ
# 標準 CHAID（Kass 1980, 公式8ステップ）と Exhaustive CHAID
# （Biggs et al. 1991, 公式9ステップ）、および順序型＋欠損の Floating 処理。
#
# 高速化の設計:
#  - merge_predictor の入口で十分統計量表（suffstat_build）を 1 回だけ集計し、
#    以後の全検定は表の行の畳み込み（suffstat_pvalue）だけで計算する。
#    ペア p 値は「その 2 グループのケース」だけで決まる（IBM 仕様）ため、
#    生データの部分抽出と数値的に厳密に一致する。
#  - 結合ループはペア p 値をキャッシュし、統合で値が変わり得る
#    「統合後グループが絡むペア」だけを再計算する（結果は全再計算と同一）。

# グループペアの類似度 p 値。IBM 仕様どおり「そのペアに属するケースのみ」の
# 2 グループ表（カテゴリカル目的）/ 2 群 F 検定（連続目的）で計算する。
pair_pvalue <- function(groups, i, j, ss, control) {
  suffstat_pvalue(ss, groups[c(i, j)], control)$p
}

# 現在のグループ構成に対する全表の検定（グループ外コードのケースは除外 =
# 表に行として現れないだけで同じこと）
config_pvalue <- function(groups, ss, control) {
  suffstat_pvalue(ss, groups, control)
}

# ペア p 値キャッシュの遅延充填。pairs（allowable_pairs の返り値）の各行に
# ついて、キャッシュ pvmat に無い値だけ計算して埋め、pairs 順の p 値ベクトル
# を返す。pvmat は上三角（i < j）で保持する。
fill_pair_cache <- function(pvmat, pairs, groups, ss, control) {
  a <- pmin(pairs[, 1], pairs[, 2])
  b <- pmax(pairs[, 1], pairs[, 2])
  for (r in which(is.na(pvmat[cbind(a, b)]))) {
    pvmat[a[r], b[r]] <- pair_pvalue(groups, a[r], b[r], ss, control)
  }
  list(pvmat = pvmat, pv = pvmat[cbind(a, b)])
}

# グループ j を i に統合したときのキャッシュ更新: j の行・列を落とし、
# 統合後の i（j 削除による添字ずれを補正）が絡む値を無効化する
drop_merge_cache <- function(pvmat, i, j) {
  pvmat <- pvmat[-j, -j, drop = FALSE]
  ii <- if (i > j) i - 1L else i
  pvmat[ii, ] <- NA_real_
  pvmat[, ii] <- NA_real_
  pvmat
}

# 複合カテゴリの最良2分割を探索（resplit オプション用）。
# 順序型はカット位置 m-1 通り、名義型は全2分割（組合せ爆発を避けるため
# 元カテゴリ 12 個超はスキップ）。複合カテゴリ内のケースのみで p 値を計算。
best_binary_split <- function(cats, ss, ptype, control) {
  m <- length(cats)
  if (m < 2) return(NULL)
  splits <- list()
  if (ptype == "ordinal") {
    cs <- sort(cats)
    for (t in seq_len(m - 1)) {
      splits[[t]] <- list(g1 = cs[seq_len(t)], g2 = cs[(t + 1):m])
    }
  } else {
    if (m > 12) return(NULL)
    for (size in seq_len(floor(m / 2))) {
      for (cc in utils::combn(m, size, simplify = FALSE)) {
        if (size * 2 == m && !(1L %in% cc)) next  # 補集合との重複を除去
        splits[[length(splits) + 1]] <- list(g1 = cats[cc], g2 = cats[-cc])
      }
    }
  }
  pv <- vapply(splits, function(s) {
    pair_pvalue(list(s$g1, s$g2), 1L, 2L, ss, control)
  }, numeric(1))
  b <- which.min(pv)
  list(g1 = splits[[b]]$g1, g2 = splits[[b]]$g2, p = pv[b])
}

# 標準 CHAID の結合ループ（Bonferroni 調整前のグループ構成を返す）。
# 最類似（p 値最大）ペアが alpha_merge を超える限り統合を反復し、
# 全ペア有意またはグループ数 2 で終了する。
merge_core_standard <- function(cats, ss, ptype, control) {
  groups <- as.list(sort(cats))
  if (length(groups) <= 2) return(groups)
  pvmat <- matrix(NA_real_, length(groups), length(groups))
  guard <- 0L
  repeat {
    if (length(groups) <= 2) break
    guard <- guard + 1L
    # resplit オフの理論上限は length(cats) - 2。resplit オンの振動を許容しても
    # 10 倍あれば十分。大きすぎるガードは名義型高カーディナリティで実行時間を悪化させる
    if (guard > 10L * length(cats)) {
      warning("merge_core_standard: merge loop reached the iteration limit; ",
              "stopped at the current group configuration. resplit=TRUE with ",
              "alpha_split_merge > alpha_merge can oscillate between merging ",
              "and resplitting; reconsider these settings")
      break
    }
    pairs <- allowable_pairs(groups, ptype)
    fc <- fill_pair_cache(pvmat, pairs, groups, ss, control)
    pvmat <- fc$pvmat
    pv <- fc$pv
    b <- which.max(pv)
    if (pv[b] <= control$alpha_merge) break
    i <- pairs[b, 1]
    j <- pairs[b, 2]
    merged <- sort(c(groups[[i]], groups[[j]]))
    groups[[i]] <- merged
    groups <- groups[-j]
    pvmat <- drop_merge_cache(pvmat, i, j)
    # resplit（公式ステップ5、SPSS UI 既定はオフ）:
    # 3 個以上の元カテゴリからなる複合カテゴリの最良 2 分割が
    # alpha_split_merge 以下なら分割し直す
    if (isTRUE(control$resplit) && length(merged) >= 3) {
      sp <- best_binary_split(merged, ss, ptype, control)
      if (!is.null(sp) && sp$p <= control$alpha_split_merge) {
        gi <- which(vapply(groups, function(g) identical(g, merged), logical(1)))
        groups[[gi]] <- sp$g1
        groups <- c(groups, list(sp$g2))
        # 分割で構成が変わった gi と末尾の新グループのキャッシュを無効化
        pvmat <- rbind(cbind(pvmat, NA_real_), NA_real_)
        pvmat[gi, ] <- NA_real_
        pvmat[, gi] <- NA_real_
      }
    }
  }
  groups
}

# Exhaustive CHAID の結合ループ。alpha_merge を無視して 2 グループまで
# 強制的に統合を続け、全履歴（初期構成 index=0 を含む）の中から
# 全表 p 値が最小の構成を返す。
merge_core_exhaustive <- function(cats, ss, ptype, control) {
  groups <- as.list(sort(cats))
  best_groups <- groups
  best_p <- config_pvalue(groups, ss, control)$p
  pvmat <- matrix(NA_real_, length(groups), length(groups))
  while (length(groups) > 2) {
    pairs <- allowable_pairs(groups, ptype)
    fc <- fill_pair_cache(pvmat, pairs, groups, ss, control)
    pvmat <- fc$pvmat
    pv <- fc$pv
    b <- which.max(pv)
    i <- pairs[b, 1]
    j <- pairs[b, 2]
    groups[[i]] <- sort(c(groups[[i]], groups[[j]]))
    groups <- groups[-j]
    pvmat <- drop_merge_cache(pvmat, i, j)
    p_now <- config_pvalue(groups, ss, control)$p
    if (p_now < best_p) {
      best_p <- p_now
      best_groups <- groups
    }
  }
  best_groups
}

# 浮動カテゴリ（欠損）コードを含むグループ番号を返す。なければ NA。
find_float_group <- function(groups, float_code) {
  if (is.na(float_code)) return(NA_integer_)
  hit <- which(vapply(groups, function(g) float_code %in% g, logical(1)))
  if (length(hit) == 1) hit else NA_integer_
}

# 頻度重み合計が閾値未満のグループを最類似（p 値最大）の許容グループへ
# 統合する。結合フェーズの min_segment オプション（公式ステップ7）と、
# 分割時の min_child 制約の両方で使う。
# 統合の許容範囲は結合時と同じ（順序型=隣接、名義型=全ペア、浮動=任意）。
absorb_small_groups <- function(groups, ss, ptype, control,
                                min_size, float_code = NA_integer_) {
  repeat {
    if (length(groups) <= 1) break
    nf_g <- vapply(groups, function(g) sum(ss$fcat[g]), numeric(1))
    small <- which(nf_g < min_size)
    if (length(small) == 0) break
    if (length(groups) == 2) {
      # 統合すると 1 グループになる = 分割不成立の合図として単一グループを返す
      return(list(sort(unlist(groups))))
    }
    s <- small[which.min(nf_g[small])]
    float_group <- find_float_group(groups, float_code)
    pairs <- allowable_pairs(groups, ptype, float_group)
    pairs <- pairs[pairs[, 1] == s | pairs[, 2] == s, , drop = FALSE]
    if (nrow(pairs) == 0) break
    pv <- vapply(seq_len(nrow(pairs)), function(r) {
      pair_pvalue(groups, pairs[r, 1], pairs[r, 2], ss, control)
    }, numeric(1))
    b <- which.max(pv)
    i <- pairs[b, 1]
    j <- pairs[b, 2]
    groups[[i]] <- sort(c(groups[[i]], groups[[j]]))
    groups <- groups[-j]
  }
  groups
}

# 順序型＋欠損（Floating）の結合。
# 1. 非欠損カテゴリのみで通常の順序型結合を実行
#    （検定はグループの行しか参照しないため、表から float 行を除く必要はない）
# 2. 欠損カテゴリに最も類似（ペア p 値最大）のグループを特定
# 3. 「統合した構成」と「欠損を独立カテゴリとした構成」の全表 p 値を比較し
#    小さい方を採用（IBM 仕様）
merge_floating <- function(cats, float_code, ss, method, control) {
  nm_cats <- setdiff(cats, float_code)
  if (length(nm_cats) == 0) return(NULL)
  core <- if (length(nm_cats) == 1) {
    list(nm_cats)
  } else if (method == "chaid") {
    merge_core_standard(nm_cats, ss, "ordinal", control)
  } else {
    merge_core_exhaustive(nm_cats, ss, "ordinal", control)
  }
  # 欠損カテゴリと最類似のグループ
  gtest <- c(core, list(float_code))
  fi <- length(gtest)
  pv <- vapply(seq_along(core), function(i) {
    pair_pvalue(gtest, i, fi, ss, control)
  }, numeric(1))
  gstar <- which.max(pv)
  cand_merged <- core
  cand_merged[[gstar]] <- sort(c(core[[gstar]], float_code))
  cand_indep <- c(core, list(float_code))
  res_m <- config_pvalue(cand_merged, ss, control)
  res_i <- config_pvalue(cand_indep, ss, control)
  if (res_m$p <= res_i$p) {
    list(groups = cand_merged, res = res_m)
  } else {
    list(groups = cand_indep, res = res_i)
  }
}

# 1 予測変数に対する結合フェーズの入口。
# xcode/y/w/f はノード内ケースのみを渡す。
# 返り値: list(groups, statistic, df, p_unadj, B, p_adj, ptype_eff, I_pres, ss)。
# I_pres / ss は呼び出し側（grow_node の min_child 再計算）での再集計を
# 省くために返す。分割不能（実在カテゴリ < 2 など）のときは NULL。
merge_predictor <- function(xcode, y, w, f, ptype, float_code, method, ytype, control) {
  cats <- which(tabulate(xcode, max(xcode)) > 0L)
  I_pres <- length(cats)
  if (I_pres < 2) return(NULL)
  ss <- suffstat_build(xcode, y, w, f, ytype)
  has_float <- !is.na(float_code) && float_code %in% cats

  if (has_float) {
    fl <- merge_floating(cats, float_code, ss, method, control)
    if (is.null(fl)) return(NULL)
    groups <- fl$groups
    res <- fl$res
    ptype_eff <- "floating"
  } else {
    groups <- if (method == "chaid") {
      merge_core_standard(cats, ss, ptype, control)
    } else {
      merge_core_exhaustive(cats, ss, ptype, control)
    }
    res <- config_pvalue(groups, ss, control)
    ptype_eff <- ptype
  }

  # min_segment オプション（公式ステップ7）: 小さすぎるグループを吸収
  if (!is.null(control$min_segment) && length(groups) > 1) {
    pt <- if (ptype_eff == "floating") "ordinal" else ptype_eff
    groups2 <- absorb_small_groups(groups, ss, pt, control,
                                   control$min_segment, float_code)
    if (!identical(groups2, groups)) {
      groups <- groups2
      res <- config_pvalue(groups, ss, control)
    }
  }

  r <- length(groups)
  if (r < 2) return(NULL)
  B <- if (isTRUE(control$bonferroni)) {
    bonferroni_multiplier(I_pres, r, ptype_eff, method,
                          control$exhaustive_adjust)
  } else {
    1
  }
  list(groups = groups, statistic = res$statistic, df = res$df,
       p_unadj = res$p, B = B, p_adj = min(1, B * res$p),
       ptype_eff = ptype_eff, I_pres = I_pres, ss = ss)
}
