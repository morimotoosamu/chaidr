# 整数パラメータの検証: 非整数値はエラー

    Code
      chaid_control(max_depth = 3.7)
    Condition
      Error in `chaid_control()`:
      ! chaid_control: max_depth must be an integer >= 1

---

    Code
      chaid_control(n_bins = 5.5)
    Condition
      Error in `chaid_control()`:
      ! chaid_control: n_bins must be an integer >= 2

---

    Code
      chaid_control(max_iter = 100.5)
    Condition
      Error in `chaid_control()`:
      ! chaid_control: max_iter must be an integer >= 1

---

    Code
      chaid_control(max_depth = NA)
    Condition
      Error in `chaid_control()`:
      ! chaid_control: max_depth must be an integer >= 1

# 未知水準の予測はフォールバックし警告が出る

    Code
      res_unk <- predict(fit_na2, nd_new)
    Condition
      Warning in `predict.chaid()`:
      predict.chaid: levels not seen during fitting detected; assigning those cases to the child with the largest node size

