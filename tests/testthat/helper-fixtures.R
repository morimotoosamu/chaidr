# 複数のテストファイルで共有するフィクスチャ（コンストラクタ関数）。
# 「既定の小さめ制約（min_parent = 30, min_child = 10）」での学習は
# 多くのファイルで使うためここに集約する。ファイル固有のデータ生成は
# 各テストファイル側に置く。

# iris（連続予測 × 3クラス目的変数）の既定フィット
fit_iris_default <- function() {
  chaid(Species ~ ., data = iris,
        control = chaid_control(min_parent = 30, min_child = 10))
}

# penguins（連続 + factor 予測、NA あり × 3クラス目的変数）の既定フィット
fit_penguins_default <- function() {
  chaid(species ~ ., data = penguins,
        control = chaid_control(min_parent = 30, min_child = 10))
}

# png デバイスに描画してエラーが出ないことを確認する共通 expectation。
# withr::defer は LIFO なので dev.off() がファイル削除より先に実行される。
expect_plot_ok <- function(fit, ..., width = 900, height = 600) {
  f <- withr::local_tempfile(fileext = ".png")
  grDevices::png(f, width = width, height = height)
  withr::defer(grDevices::dev.off())
  expect_no_error(plot(fit, ...))
}
