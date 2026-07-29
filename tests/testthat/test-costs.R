# 誤分類コスト行列のテスト

# ノード分布が 60/40 になる玩具データ
make_cost_data <- function() {
  data.frame(
    x = factor(rep(c("a", "b"), each = 100)),
    y = factor(c(rep(c("pos", "neg"), c(60, 40)),
                 rep(c("pos", "neg"), c(30, 70))))
  )
}
ctl_costs <- chaid_control(min_parent = 10, min_child = 5)

test_that("一様な対称コスト（0/1 損失）は argmax と同一の予測になる", {
  d <- make_cost_data()
  fit0 <- chaid(y ~ x, data = d, control = ctl_costs)
  expect_type(fit0$nodes[[1]]$split, "list")

  lv <- levels(d$y)
  c01 <- matrix(1, 2, 2, dimnames = list(lv, lv)) - diag(2)
  fit01 <- chaid(y ~ x, data = d, control = ctl_costs, costs = c01)
  p0 <- vapply(fit0$nodes, function(nd) as.character(nd$prediction), character(1))
  p1 <- vapply(fit01$nodes, function(nd) as.character(nd$prediction), character(1))
  expect_identical(p0, p1)
  # 木構造自体は不変（成長に影響しない）
  sig <- function(f) lapply(f$nodes, function(nd) {
    list(nd$parent, nd$Nf, if (is.null(nd$split)) NULL else nd$split$groups)
  })
  expect_identical(sig(fit0), sig(fit01))
})

test_that("偏ったコスト: pos の見逃しを高コストにすると予測が pos に倒れる", {
  d <- make_cost_data()
  # ノード x=b は pos 30% / neg 70%。argmax なら neg 予測だが、
  # C[pos, neg]=5（真値 pos を neg と誤分類するコスト 5）なら
  # 期待コスト: pred=neg → 0.3*5=1.5, pred=pos → 0.7*1=0.7 → pos 予測に変わる
  # matrix() は列優先充填なので c(0, 5, 1, 0) で C[pos,neg]=5, C[neg,pos]=1 になる
  cb <- matrix(c(0, 5, 1, 0), 2, 2,
               dimnames = list(c("neg", "pos"), c("neg", "pos")))
  expect_identical(cb["pos", "neg"], 5)
  expect_identical(cb["neg", "pos"], 1)
  # 注意: levels(d$y) は c("neg","pos")（アルファベット順）
  expect_identical(levels(d$y), c("neg", "pos"))
  fitb <- chaid(y ~ x, data = d, control = ctl_costs, costs = cb)
  node_b <- Filter(function(nd) {
    is.null(nd$split) && nd$dist["pos"] / sum(nd$dist) < 0.5
  }, fitb$nodes)[[1]]
  expect_identical(as.character(node_b$prediction), "pos")  # argmax なら neg
  # predict も新しい予測クラスを返す
  pr <- predict(fitb, data.frame(x = factor("b", levels = c("a", "b"))))
  expect_identical(as.character(pr), "pos")
})

test_that("summary のリスク値が手計算と一致する", {
  d <- make_cost_data()
  fit0 <- chaid(y ~ x, data = d, control = ctl_costs)
  # fit0（コストなし）: 誤分類率 = 0.5*0.4 + 0.5*0.3 = 0.35
  out0 <- capture.output(summary(fit0))
  risk_line <- grep("Risk estimate", out0, value = TRUE)
  expect_length(risk_line, 1)
  expect_match(risk_line, "0.35", fixed = TRUE)

  # fitb（コストあり）: ノードa: pred=pos, コスト=0.4*1=0.4;
  #   ノードb: pred=pos, コスト=0.7*1=0.7 → リスク=0.5*0.4+0.5*0.7=0.55
  cb <- matrix(c(0, 5, 1, 0), 2, 2,
               dimnames = list(c("neg", "pos"), c("neg", "pos")))
  fitb <- chaid(y ~ x, data = d, control = ctl_costs, costs = cb)
  outb <- capture.output(summary(fitb))
  risk_lineb <- grep("Risk estimate", outb, value = TRUE)
  expect_match(risk_lineb, "0.55", fixed = TRUE)
  expect_match(risk_lineb, "expected misclassification cost")
})

test_that("不正なコスト行列はエラー", {
  d <- make_cost_data()
  lv <- levels(d$y)
  expect_snapshot(error = TRUE, {
    chaid(y ~ x, data = d, control = ctl_costs,
          costs = matrix(1, 3, 3))                                # 次元不一致
  })
  expect_snapshot(error = TRUE, {
    chaid(y ~ x, data = d, control = ctl_costs,
          costs = matrix(c(1, 1, 1, 0), 2, 2, dimnames = list(lv, lv)))  # 対角非0
  })
  expect_snapshot(error = TRUE, {
    chaid(y ~ x, data = d, control = ctl_costs,
          costs = matrix(c(0, -1, 1, 0), 2, 2, dimnames = list(lv, lv))) # 負値
  })
  expect_snapshot(error = TRUE, {
    chaid(y ~ x, data = d, control = ctl_costs,
          costs = matrix(0, 2, 2, dimnames = list(rev(lv), rev(lv))))    # 水準名不一致
  })
})

test_that("連続目的変数では costs を使えない", {
  set.seed(41)
  d <- make_cost_data()
  lv <- levels(d$y)
  c01 <- matrix(1, 2, 2, dimnames = list(lv, lv)) - diag(2)
  dn <- data.frame(yn = rnorm(200), x = d$x)
  expect_snapshot(error = TRUE,
                  chaid(yn ~ x, data = dn, control = ctl_costs, costs = c01))
})
