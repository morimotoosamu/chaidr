# y_scores のバリデーション

    Code
      chaid(y ~ xnum, data = dord, y_scores = 1:3)
    Condition
      Error in `chaid()`:
      ! chaid: length of y_scores (3) does not match the number of response levels (4)

---

    Code
      chaid(y ~ xnum, data = dord, y_scores = c(1, 2, NA, 4))
    Condition
      Error in `chaid()`:
      ! chaid: y_scores must be finite

---

    Code
      chaid(y ~ xnum, data = dnom, y_scores = 1:4)
    Condition
      Error in `chaid()`:
      ! chaid: y_scores is only for ordered factor responses

