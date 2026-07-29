# partykit 連携（chaid_as_party / as.party.chaid）のテスト
# partykit 未導入の環境ではスキップする（ソフト依存のため）

test_that("iris: constparty 変換でノード構造と割当が一致する", {
  skip_if_not_installed("partykit")
  fit <- fit_iris_default()
  pt <- chaid_as_party(fit, iris)
  expect_s3_class(pt, "constparty")

  # ノード数・末端ノード数が一致（length(party) は全ノード数、width は末端数）
  expect_identical(length(pt), length(fit$nodes))
  expect_equal(partykit::width(partykit::node_party(pt)),
               sum(vapply(fit$nodes, function(nd) is.null(nd$split),
                          logical(1))))

  # fitted の末端ノード割当が predict.chaid と一致
  expect_identical(partykit::fitted_node(partykit::node_party(pt),
                                         data = pt$data),
                   predict(fit, iris, type = "node"))

  # print / plot がエラーなく動く
  out <- capture.output(print(pt))
  expect_gt(length(out), 3)
  expect_plot_ok(pt, width = 1000, height = 700)
})

test_that("as.party ジェネリック経由でも呼べる", {
  skip_if_not_installed("partykit")
  fit <- fit_iris_default()
  pt2 <- partykit::as.party(fit, data = iris)
  expect_s3_class(pt2, "constparty")
})

test_that("Titanic: 頻度重みが (weights) に反映され末端の重み合計が Nf と一致", {
  skip_if_not_installed("partykit")
  tit <- as.data.frame(Titanic)
  fit_t <- chaid(Survived ~ Class + Sex + Age, data = tit, freq = tit$Freq)
  pt_t <- chaid_as_party(fit_t, tit, freq = tit$Freq)
  wsum <- tapply(pt_t$fitted[["(weights)"]], pt_t$fitted[["(fitted)"]], sum)
  for (nid in names(wsum)) {
    expect_identical(as.numeric(wsum[[nid]]),
                     fit_t$nodes[[as.integer(nid)]]$Nf,
                     label = sprintf("weight sum of node %s", nid))
  }
})

test_that("連続目的変数（回帰木）も constparty になり描画できる", {
  skip_if_not_installed("partykit")
  set.seed(5)
  n <- 400
  dreg <- data.frame(y = rnorm(n) + rep(c(0, 3), each = n / 2),
                     g = factor(rep(c("a", "b"), each = n / 2)))
  fit_r <- chaid(y ~ g, data = dreg,
                 control = chaid_control(min_parent = 50, min_child = 20))
  pt_r <- chaid_as_party(fit_r, dreg)
  expect_s3_class(pt_r, "constparty")
  expect_plot_ok(pt_r, width = 800, height = 600)
})

test_that("欠損 Floating: '<NA>' 水準経由で party 側でも全ケースがルーティングされる", {
  skip_if_not_installed("partykit")
  set.seed(5)
  dna <- data.frame(sp = iris$Species, petal = iris$Petal.Length,
                    noise = runif(150))
  dna$petal[sample(150, 25)] <- NA
  fit_na <- chaid(sp ~ petal + noise, data = dna,
                  control = chaid_control(min_parent = 30, min_child = 10))
  pt_na <- chaid_as_party(fit_na, dna)
  expect_identical(nrow(pt_na$fitted), 150L)  # NA ケースも除外されない
  expect_false(anyNA(pt_na$fitted[["(fitted)"]]))
})

test_that("ggparty で party オブジェクトがそのまま描画できる", {
  skip_if_not_installed("partykit")
  skip_if_not_installed("ggparty")
  skip_if_not_installed("ggplot2")
  fit <- fit_iris_default()
  pt <- chaid_as_party(fit, iris)
  # suppressWarnings: ggparty が内部で渡す label.size を新しい ggplot2 が
  # 受け付けない既知の互換性警告（描画には無害）を抑制する
  g <- suppressWarnings(
    ggparty::ggparty(pt) +
      ggparty::geom_edge() +
      ggparty::geom_edge_label() +
      ggparty::geom_node_label(ggplot2::aes(label = splitvar), ids = "inner") +
      ggparty::geom_node_plot(gglist = list(
        ggplot2::geom_bar(ggplot2::aes(x = "", fill = Species),
                          position = "fill")))
  )
  tmp <- withr::local_tempfile(fileext = ".png")
  expect_no_error(
    suppressWarnings(ggplot2::ggsave(tmp, g, width = 10, height = 6, dpi = 72))
  )
})
