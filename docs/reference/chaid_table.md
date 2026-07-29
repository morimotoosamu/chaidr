# Summary table of CHAID terminal nodes

Builds a segment summary of the terminal nodes. The first row is the
root node, which serves as the baseline (index 100). For categorical
responses the table contains the predicted class and the class shares,
plus, when `target` is given, the response rate and the index value
(response rate relative to the root, times 100). For continuous
responses it contains the node mean, standard deviation and the index of
the mean.

## Usage

``` r
chaid_table(fit, target = NULL)
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by [`chaid()`](chaid.md).

- target:

  Optional response level of interest (categorical responses only). Adds
  `response_rate` and `index` columns.

## Value

A data frame with one row for the root followed by one row per terminal
node, including the reaching rule in the `rule` column.

## Details

Note that `n` is the sum of frequency weights while `pct_n` and the
class shares are computed with case weights included; the two scales
coincide unless case weights are used.

## See also

[`chaid_rules()`](chaid_rules.md), [`chaid_gains()`](chaid_gains.md),
[`chaid_importance()`](chaid_importance.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_table(fit)
#>   node depth   n pct_n prediction p_setosa p_versicolor p_virginica
#> 1    1     0 150 100.0     setosa   0.3333       0.3333      0.3333
#> 2    2     1  44  29.3     setosa   1.0000       0.0000      0.0000
#> 3    3     1  14   9.3 versicolor   0.4286       0.5714      0.0000
#> 4    4     1  32  21.3 versicolor   0.0000       0.9688      0.0312
#> 5    5     1  14   9.3 versicolor   0.0000       0.6429      0.3571
#> 6    6     1  16  10.7  virginica   0.0000       0.1250      0.8750
#> 7    7     1  30  20.0  virginica   0.0000       0.0000      1.0000
#>                         rule
#> 1                     (root)
#> 2         Petal.Length ≤ 1.6
#> 3 Petal.Length が (1.6, 3.8]
#> 4 Petal.Length が (3.8, 4.6]
#> 5 Petal.Length が (4.6, 4.9]
#> 6 Petal.Length が (4.9, 5.3]
#> 7         Petal.Length > 5.3
chaid_table(fit, target = "virginica")
#>   node depth   n pct_n prediction p_setosa p_versicolor p_virginica
#> 1    1     0 150 100.0     setosa   0.3333       0.3333      0.3333
#> 2    2     1  44  29.3     setosa   1.0000       0.0000      0.0000
#> 3    3     1  14   9.3 versicolor   0.4286       0.5714      0.0000
#> 4    4     1  32  21.3 versicolor   0.0000       0.9688      0.0312
#> 5    5     1  14   9.3 versicolor   0.0000       0.6429      0.3571
#> 6    6     1  16  10.7  virginica   0.0000       0.1250      0.8750
#> 7    7     1  30  20.0  virginica   0.0000       0.0000      1.0000
#>   response_rate index                       rule
#> 1        0.3333 100.0                     (root)
#> 2        0.0000   0.0         Petal.Length ≤ 1.6
#> 3        0.0000   0.0 Petal.Length が (1.6, 3.8]
#> 4        0.0312   9.4 Petal.Length が (3.8, 4.6]
#> 5        0.3571 107.1 Petal.Length が (4.6, 4.9]
#> 6        0.8750 262.5 Petal.Length が (4.9, 5.3]
#> 7        1.0000 300.0         Petal.Length > 5.3
```
