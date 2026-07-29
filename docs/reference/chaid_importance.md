# Heuristic variable importance for a CHAID tree

SPSS defines no official importance measure for CHAID, and the
chi-squared and F statistics of different splits are not directly
comparable because their degrees of freedom differ. This function
therefore uses a p-value based heuristic: for each predictor,
`importance` is the sum over its splits of
`(node size / root size) * (-log10(adjusted p-value))`, i.e. a variable
is important when it splits large nodes with strong significance.

## Usage

``` r
chaid_importance(fit)
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by [`chaid()`](chaid.md).

## Value

A data frame with one row per predictor actually used for a split,
sorted by decreasing importance: `variable`, `n_splits`, `min_p_adj`,
`importance` and `importance_pct` (share of the total importance in
percent).

## See also

[`chaid()`](chaid.md), [`chaid_table()`](chaid_table.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_importance(fit)
#>       variable n_splits    min_p_adj importance importance_pct
#> 1 Petal.Length        1 1.354149e-44   43.86833            100
```
