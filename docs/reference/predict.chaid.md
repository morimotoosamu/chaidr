# Predict from a fitted CHAID tree

Routes the rows of `newdata` down the tree and returns predictions.
Factor levels unseen during training, and codes that did not occur in a
node when it was split, are routed to the child with the largest node
size (for ordinal predictors, to the group with the smallest code
distance); a warning is issued when unseen levels are detected.

## Usage

``` r
# S3 method for class 'chaid'
predict(object, newdata, type = c("response", "prob", "node"), ...)
```

## Arguments

- object:

  A fitted `"chaid"` object returned by
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

- newdata:

  A data frame containing all predictor variables used in the fit.

- type:

  `"response"` (default) returns predicted classes (or means for a
  continuous response), `"prob"` returns a matrix of class probabilities
  (categorical responses only), `"node"` returns the terminal node id
  for each row.

- ...:

  Ignored.

## Value

Depending on `type`: a factor (or numeric vector) of predictions, a
numeric matrix of class probabilities with one column per response
level, or an integer vector of node ids.

## See also

[`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
predict(fit, head(iris))
#> [1] setosa     setosa     setosa     setosa     setosa     versicolor
#> Levels: setosa versicolor virginica
predict(fit, head(iris), type = "prob")
#>         setosa versicolor virginica
#> [1,] 1.0000000  0.0000000         0
#> [2,] 1.0000000  0.0000000         0
#> [3,] 1.0000000  0.0000000         0
#> [4,] 1.0000000  0.0000000         0
#> [5,] 1.0000000  0.0000000         0
#> [6,] 0.4285714  0.5714286         0
predict(fit, head(iris), type = "node")
#> [1] 2 2 2 2 2 3
```
