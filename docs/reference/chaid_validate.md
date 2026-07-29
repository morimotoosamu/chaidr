# Evaluate a CHAID tree on holdout data

Routes `newdata` down the fitted tree and compares, for each terminal
node, the node share and the response rate (node mean for continuous
responses) between training and validation data. Useful to check whether
the segments replicate on new data, i.e. whether the tree is
overfitting.

## Usage

``` r
chaid_validate(fit, newdata, weights = NULL, freq = NULL)

# S3 method for class 'chaid_validation'
print(x, ...)
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by [`chaid()`](chaid.md).

- newdata:

  A data frame of validation cases containing the response and all
  predictors.

- weights, freq:

  Case and frequency weights for `newdata`.

- x:

  A `"chaid_validation"` object.

- ...:

  Ignored.

## Value

An object of class `"chaid_validation"`: a list with `nodes` (per-node
comparison data frame with `train_pct_n`, `test_pct_n`, `train_rate`,
`test_rate` and `diff_rate`), `overall` (accuracy for categorical
responses; RMSE and R-squared for continuous ones), `n_test` and
`ytype`. A [`print()`](https://rdrr.io/r/base/print.html) method is
available.

## See also

[`chaid_gains()`](chaid_gains.md), [`predict.chaid()`](predict.chaid.md)

## Examples

``` r
set.seed(1)
idx <- sample(nrow(iris), 100)
fit <- chaid(Species ~ ., data = iris[idx, ],
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_validate(fit, iris[-idx, ])
#> CHAID 安定性評価（検証データ n = 50 ）
#> 検証データ精度: 0.9 
#> （rate = 予測クラスの構成比 / 連続目的変数では平均。 diff_rate の絶対値が大きいノードは検証データで再現していない）
#> 
#>  node prediction train_pct_n test_pct_n train_rate test_rate diff_rate
#>     2     setosa          28         32     1.0000    1.0000    0.0000
#>     3     setosa          11          6     0.5455    0.0000   -0.5455
#>     4 versicolor          21         32     1.0000    0.9375   -0.0625
#>     5  virginica          40         30     0.8750    0.9333    0.0583
```
