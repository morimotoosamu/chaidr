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

  A fitted `"chaid"` object returned by
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

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

[`chaid_gains()`](https://morimotoosamu.github.io/chaidr/reference/chaid_gains.md),
[`predict.chaid()`](https://morimotoosamu.github.io/chaidr/reference/predict.chaid.md)

## Examples

``` r
set.seed(1)
idx <- sample(nrow(iris), 100)
fit <- chaid(Species ~ ., data = iris[idx, ],
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_validate(fit, iris[-idx, ])
#> CHAID stability assessment (validation n = 50 )
#> Validation accuracy: 0.9 
#> (rate = share of the predicted class, or the mean for continuous responses.
#>  Nodes with a large |diff_rate| do not replicate on the validation data.)
#> 
#>  node prediction train_pct_n test_pct_n train_rate test_rate diff_rate
#>     2     setosa          28         32     1.0000    1.0000    0.0000
#>     3     setosa          11          6     0.5455    0.0000   -0.5455
#>     4 versicolor          21         32     1.0000    0.9375   -0.0625
#>     5  virginica          40         30     0.8750    0.9333    0.0583
```
