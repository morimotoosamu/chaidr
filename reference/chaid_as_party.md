# Convert a CHAID tree to a partykit constparty

Converts a fitted `"chaid"` object to a `partykit::constparty` object so
that the 'partykit' toolbox
([`plot()`](https://rdrr.io/r/graphics/plot.default.html),
[`print()`](https://rdrr.io/r/base/print.html), `nodeapply()`,
'ggparty', ...) can be used. Binned continuous predictors are
represented as ordered factors of the bin interval labels, and all
splits become index-type
[partykit::partysplit](https://rdrr.io/pkg/partykit/man/partysplit.html)
objects, so missing values (`"<NA>"` level) are routed explicitly and
split rules display the interval labels.

## Usage

``` r
chaid_as_party(x, data, weights = NULL, freq = NULL, ...)

# S3 method for class 'chaid'
as.party(obj, data, weights = NULL, freq = NULL, ...)
```

## Arguments

- x, obj:

  A fitted `"chaid"` object returned by
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

- data:

  The data frame used to fit the tree (the chaid object does not store
  the data).

- weights, freq:

  The case and frequency weights used in the fit, if any. Required to
  reproduce the case exclusions of the fit.

- ...:

  Ignored.

## Value

A `partykit::constparty` object.

## Details

The returned object is intended for visualisation and structural
inspection. For predictions on new data use
[`predict.chaid()`](https://morimotoosamu.github.io/chaidr/reference/predict.chaid.md);
the [`predict()`](https://rdrr.io/r/stats/predict.html) method of the
party object expects the converted data representation, not the original
one.

## See also

[`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md),
[`predict.chaid()`](https://morimotoosamu.github.io/chaidr/reference/predict.chaid.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
pt <- chaid_as_party(fit, data = iris)
print(pt)
#> 
#> Model formula:
#> Species ~ Sepal.Length + Sepal.Width + Petal.Length + Petal.Width
#> 
#> Fitted party:
#> [1] root
#> |   [2] Petal.Length <= 1.3, (1.3, 1.4], (1.4, 1.6]: setosa (n = 44, err = 0.0%)
#> |   [3] Petal.Length in (1.6, 3.8]: versicolor (n = 14, err = 42.9%)
#> |   [4] Petal.Length in (3.8, 4.3], (4.3, 4.6]: versicolor (n = 32, err = 3.1%)
#> |   [5] Petal.Length in (4.6, 4.9]: versicolor (n = 14, err = 35.7%)
#> |   [6] Petal.Length in (4.9, 5.3]: virginica (n = 16, err = 12.5%)
#> |   [7] Petal.Length in (5.3, 5.7], (5.7, 6.9]: virginica (n = 30, err = 0.0%)
#> 
#> Number of inner nodes:    1
#> Number of terminal nodes: 6
```
