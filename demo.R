# demo.R -- CHAID / Exhaustive CHAID のデモ
# 使い方: Rscript demo.R  （リポジトリルートから）

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
root <- if (length(file_arg) == 1) normalizePath(dirname(file_arg)) else normalizePath(".")
for (src in sort(list.files(file.path(root, "R"), full.names = TRUE))) {
  source(src, encoding = "UTF-8")
}

line <- function() cat(strrep("=", 70), "\n")

# ---------------------------------------------------------------------------
line()
cat("デモ 1: iris — 連続予測変数 × カテゴリカル目的変数（χ²検定 + 自動ビン分割）\n")
line()
fit_iris <- chaid(Species ~ ., data = iris,
                  control = chaid_control(min_parent = 30, min_child = 10))
print(fit_iris)
acc <- mean(predict(fit_iris, iris) == iris$Species)
cat(sprintf("\n訓練データ精度: %.1f%%\n\n", 100 * acc))

# ---------------------------------------------------------------------------
line()
cat("デモ 2: Titanic — 頻度重み。標準CHAID と Exhaustive CHAID の比較\n")
line()
tit <- as.data.frame(Titanic)
cat("\n--- 標準 CHAID ---\n")
fit_std <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq)
print(fit_std)

cat("\n--- Exhaustive CHAID ---\n")
fit_ex <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq,
                method = "exhaustive")
print(fit_ex)

# 頻度重みの等価性確認: 集計データと個票展開データで木が一致する
tit_exp <- tit[rep(seq_len(nrow(tit)), tit$Freq), c("Class", "Sex", "Age", "Survived")]
fit_exp <- chaid(Survived ~ Class + Sex + Age, data = tit_exp)
sig <- function(fit) lapply(fit$nodes, function(nd) {
  list(nd$parent, nd$Nf, if (is.null(nd$split)) NULL else nd$split$groups)
})
cat("\n頻度重み（集計）と個票展開の木構造一致:",
    identical(sig(fit_std), sig(fit_exp)), "\n\n")

# ---------------------------------------------------------------------------
line()
cat("デモ 3: U字型関係 — 連続目的変数（F検定）。多岐分割による非線形検出\n")
cat("（資料 §5.1: 年齢と医療費の U 字型関係を 1 階層で捉える例の再現）\n")
line()
set.seed(1)
n <- 1000
age <- runif(n, 20, 80)
cost <- 30 - 25 * dnorm(age, mean = 50, sd = 12) / dnorm(50, 50, 12) * 1 +
        ((age - 50) / 30)^2 * 40 + rnorm(n, sd = 3)
du <- data.frame(cost = cost, age = age)
fit_u <- chaid(cost ~ age, data = du,
               control = chaid_control(min_parent = 100, min_child = 50,
                                       max_depth = 1))
print(fit_u)
k <- length(fit_u$nodes[[1]]$split$children)
cat(sprintf("\nルートの子ノード数: %d（二分木では 1 階層で表現できない多岐分割）\n", k))
cat("中間ビン同士が統合され、U字の谷が 1 つのグループにまとまることを確認\n\n")

# ---------------------------------------------------------------------------
line()
cat("デモ 4: 欠損値の Floating 処理 — NA が最も類似したカテゴリへ自動統合\n")
line()
set.seed(2)
# petal に欠損を混ぜる。noise は無情報のダミー予測変数
# （予測変数が 1 本だけだと「全予測変数欠損」ルールで NA ケースが除外されるため）
dna <- data.frame(y = iris$Species, petal = iris$Petal.Length,
                  noise = runif(150))
dna$petal[sample(150, 25)] <- NA
fit_na <- chaid(y ~ petal + noise, data = dna,
                control = chaid_control(min_parent = 30, min_child = 10))
print(fit_na)
cat("\n（分割グループ内の <NA> 表記が欠損カテゴリの割当先を示す）\n")

# ---------------------------------------------------------------------------
line()
cat("デモ 5: plot() による木の可視化 — demo_tree.png へ保存\n")
line()
png_path <- file.path(root, "demo_tree.png")
grDevices::png(png_path, width = 1100, height = 700)
plot(fit_std, main = "CHAID: Titanic 生存分析")
grDevices::dev.off()
cat("保存先:", png_path, "\n")
