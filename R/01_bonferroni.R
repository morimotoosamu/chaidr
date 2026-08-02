# 01_bonferroni.R -- Bonferroni 補正乗数
# Adjusted p = min(1, B * p_unadjusted)
# 出典: IBM SPSS Statistics Algorithms (TREE-CHAID), Kass (1980),
#       Biggs, de Ville & Suen (1991)

# 第2種スターリング数 S(n, k)。
# 交代和（IBM文書の閉形式）は大きな n で桁落ちするため漸化式
# S(n,k) = k*S(n-1,k) + S(n-1,k-1) で計算する。
# 木構築中はノード×名義予測変数ごとに同じ (n, k) で繰り返し呼ばれるため、
# 計算済みの値をパッケージローカル環境にキャッシュする（n, k は元カテゴリ数
# 以下の小さい整数なのでキーは高々数十個）。
.stirling2_cache <- new.env(parent = emptyenv())

stirling2 <- function(n, k) {
  if (k < 0 || k > n) return(0)
  if (n == 0) return(as.numeric(k == 0))
  if (k == 0) return(0)
  key <- paste(n, k)
  hit <- .stirling2_cache[[key]]
  if (!is.null(hit)) return(hit)
  S <- matrix(0, nrow = n + 1, ncol = k + 1)  # S[i+1, j+1] = S(i, j)
  S[1, 1] <- 1
  for (nn in seq_len(n)) {
    for (kk in seq_len(min(nn, k))) {
      S[nn + 1, kk + 1] <- kk * S[nn, kk + 1] + S[nn, kk]
    }
  }
  val <- S[n + 1, k + 1]
  .stirling2_cache[[key]] <- val
  val
}

# 補正乗数 B。
# I: ノード内に実在する（度数 > 0 の）元カテゴリ数（floating では欠損カテゴリ込み）
# r: 結合後のグループ数
# 標準CHAID (Kass 1980):
#   順序型:   B = C(I-1, r-1)
#   名義型:   B = S(I, r)  （第2種スターリング数）
#   浮動型:   B = C(I-2, r-2) + r * C(I-2, r-1)
# Exhaustive CHAID (Biggs et al. 1991): r に依存せず I のみで決まる。
#   順序型・浮動型: B = I(I-1)/2（結合列で調べる隣接ペア検定の総数
#                   Σ_{k=2}^{I} (k-1) と一致。IBM・文献とも同じ式）
#   名義型は出典間で不一致があり exhaustive_adjust で切り替える:
#     "spss"  : B = I(I^2-1)/2（IBM SPSS Algorithms の閉形式。SPSS 再現用）
#     "biggs" : B = I(I^2-1)/6（Ritschard 2010 による Biggs 流。結合列の
#               全ペア検定数 Σ_{k=2}^{I} C(k,2) = C(I+1,3) に一致し、
#               「実施した検定数でペナルティ」という設計思想と整合する。
#               SPSS 版はそのちょうど 3 倍で、より保守的）
bonferroni_multiplier <- function(I, r,
                                  ptype = c("ordinal", "nominal", "floating"),
                                  method = c("chaid", "exhaustive"),
                                  exhaustive_adjust = c("spss", "biggs")) {
  ptype <- match.arg(ptype)
  method <- match.arg(method)
  exhaustive_adjust <- match.arg(exhaustive_adjust)
  if (I < 1 || r < 1 || r > I) {
    stop("bonferroni_multiplier: 1 <= r <= I must hold (I=", I, ", r=", r, ")")
  }
  if (method == "exhaustive") {
    B <- switch(ptype,
      ordinal  = I * (I - 1) / 2,
      floating = I * (I - 1) / 2,
      nominal  = if (exhaustive_adjust == "spss") {
        I * (I^2 - 1) / 2
      } else {
        I * (I^2 - 1) / 6
      }
    )
    return(max(1, B))
  }
  B <- switch(ptype,
    ordinal  = choose(I - 1, r - 1),
    nominal  = stirling2(I, r),
    floating = choose(I - 2, r - 2) + r * choose(I - 2, r - 1)
  )
  max(1, B)
}
