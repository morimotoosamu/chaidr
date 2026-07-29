# 不正なコスト行列はエラー

    Code
      chaid(y ~ x, data = d, control = ctl_costs, costs = matrix(1, 3, 3))
    Condition
      Error in `chaid()`:
      ! chaid: costs must be a 2x2 matrix

---

    Code
      chaid(y ~ x, data = d, control = ctl_costs, costs = matrix(c(1, 1, 1, 0), 2, 2,
      dimnames = list(lv, lv)))
    Condition
      Error in `chaid()`:
      ! chaid: the diagonal of costs must be 0

---

    Code
      chaid(y ~ x, data = d, control = ctl_costs, costs = matrix(c(0, -1, 1, 0), 2, 2,
      dimnames = list(lv, lv)))
    Condition
      Error in `chaid()`:
      ! chaid: costs must be non-negative

---

    Code
      chaid(y ~ x, data = d, control = ctl_costs, costs = matrix(0, 2, 2, dimnames = list(
        rev(lv), rev(lv))))
    Condition
      Error in `chaid()`:
      ! chaid: dimnames of costs must match the response levels (neg, pos)

# 連続目的変数では costs を使えない

    Code
      chaid(yn ~ x, data = dn, control = ctl_costs, costs = c01)
    Condition
      Error in `chaid()`:
      ! chaid: costs is only for categorical responses

