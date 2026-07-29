# Extract decision rules from a CHAID tree

Returns the condition that a case must satisfy to reach each terminal
node (or each of the requested nodes) as a rule string.

## Usage

``` r
chaid_rules(fit, nodes = NULL, format = c("text", "sql", "r"))
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by [`chaid()`](chaid.md).

- nodes:

  Integer vector of node ids. Defaults to all terminal nodes.

- format:

  `"text"` (default) for human-readable conditions, `"sql"` for SQL
  `WHERE` clauses, or `"r"` for R logical expressions that reproduce the
  node assignment exactly when evaluated against the data.

## Value

A data frame with columns `node` (integer id) and `rule` (character).

## See also

[`chaid()`](chaid.md), [`chaid_table()`](chaid_table.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_rules(fit)
#>   node                       rule
#> 1    2         Petal.Length ≤ 1.6
#> 2    3 Petal.Length が (1.6, 3.8]
#> 3    4 Petal.Length が (3.8, 4.6]
#> 4    5 Petal.Length が (4.6, 4.9]
#> 5    6 Petal.Length が (4.9, 5.3]
#> 6    7         Petal.Length > 5.3
chaid_rules(fit, format = "sql")
#>   node
#> 1    2
#> 2    3
#> 3    4
#> 4    5
#> 5    6
#> 6    7
#>                                                                         rule
#> 1                                         Petal.Length <= 1.6000000000000001
#> 2 (Petal.Length > 1.6000000000000001 AND Petal.Length <= 3.7999999999999998)
#> 3 (Petal.Length > 3.7999999999999998 AND Petal.Length <= 4.5999999999999996)
#> 4 (Petal.Length > 4.5999999999999996 AND Petal.Length <= 4.9000000000000004)
#> 5 (Petal.Length > 4.9000000000000004 AND Petal.Length <= 5.2999999999999998)
#> 6                                          Petal.Length > 5.2999999999999998
```
