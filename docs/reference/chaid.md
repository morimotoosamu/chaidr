# Fit a CHAID or Exhaustive CHAID decision tree

Grows a CHAID (Chi-squared Automatic Interaction Detection) or
Exhaustive CHAID decision tree following the IBM SPSS Statistics
algorithm specification. Nominal (`factor`), ordinal (`ordered`) and
continuous (`numeric`) predictors are supported; continuous predictors
are discretised into quantile bins first. The response may be nominal
(Pearson or likelihood-ratio chi-squared test), ordinal (Goodman row
effects test) or continuous (one-way ANOVA F test).

## Usage

``` r
chaid(
  formula,
  data,
  weights = NULL,
  freq = NULL,
  method = c("chaid", "exhaustive"),
  control = chaid_control(),
  costs = NULL,
  y_scores = NULL
)
```

## Arguments

- formula:

  A model formula of the form `response ~ predictors`.

- data:

  A data frame containing the variables in the formula.

- weights:

  Optional numeric vector of case weights. They only affect the
  estimation of expected cell frequencies; cases with missing, zero or
  negative weights are excluded.

- freq:

  Optional numeric vector of frequency weights. They determine observed
  counts, degrees of freedom and node sizes. Non-integer values are
  rounded to the nearest integer (IBM specification).

- method:

  `"chaid"` (default) for the Kass (1980) algorithm or `"exhaustive"`
  for Exhaustive CHAID (Biggs, de Ville and Suen, 1991).

- control:

  A `"chaid_control"` object created by
  [`chaid_control()`](https://morimotoosamu.github.io/chaidr/reference/chaid_control.md).

- costs:

  Optional misclassification cost matrix `C[truth, pred]` for
  categorical responses (same convention as the `loss` matrix of
  'rpart': zero diagonal, non-negative entries, dimnames matching the
  response levels). When supplied, node predictions minimise expected
  cost instead of taking the majority class. As in SPSS, costs do not
  affect tree growing or the significance tests.

- y_scores:

  Optional numeric vector of class scores for an ordinal response, in
  the order of `levels(y)`. Defaults to the class ranks `1..J`. Fixed at
  the start of tree growing and not re-ranked in subtables (IBM
  specification).

## Value

An object of class `"chaid"`: a list with components `call`, `method`,
`control`, `response` (name, type, levels, scores), `predictors`
(internal coding of each predictor), `nodes` (list of node records with
distribution, prediction and split information), `costs`, `n` (number of
cases used) and `n_dropped` (number of excluded cases).

## Details

Missing predictor values are handled as in SPSS: for ordinal predictors
they form a floating category that may merge with any group, for nominal
predictors they form an ordinary extra category. Cases with a missing
response, missing/zero/negative weights, or all predictors missing are
dropped before fitting.

## References

Kass, G. V. (1980). An exploratory technique for investigating large
quantities of categorical data. *Applied Statistics*, 29(2), 119-127.

Biggs, D., de Ville, B., & Suen, E. (1991). A method of choosing
multiway partitions for classification and decision trees. *Journal of
Applied Statistics*, 18(1), 49-62.

## See also

[`chaid_control()`](https://morimotoosamu.github.io/chaidr/reference/chaid_control.md),
[`predict.chaid()`](https://morimotoosamu.github.io/chaidr/reference/predict.chaid.md),
[`chaid_table()`](https://morimotoosamu.github.io/chaidr/reference/chaid_table.md),
[`chaid_rules()`](https://morimotoosamu.github.io/chaidr/reference/chaid_rules.md),
[`plot.chaid()`](https://morimotoosamu.github.io/chaidr/reference/plot.chaid.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
print(fit)
#> CHAID decision tree (method = "chaid")
#> Response: Species (categorical) 
#> Valid cases: 150 (data: 150 rows) 
#> 
#> [1] root: setosa (33.3%), n=150 | split: Petal.Length (adj.p=1.35e-44, chi2=243.8, B=126)
#>   [2] Petal.Length in {<= 1.6}: setosa (100.0%), n=44 *
#>   [3] Petal.Length in {(1.6, 3.8]}: versicolor (57.1%), n=14 *
#>   [4] Petal.Length in {(3.8, 4.6]}: versicolor (96.9%), n=32 *
#>   [5] Petal.Length in {(4.6, 4.9]}: versicolor (64.3%), n=14 *
#>   [6] Petal.Length in {(4.9, 5.3]}: virginica (87.5%), n=16 *
#>   [7] Petal.Length in {> 5.3}: virginica (100.0%), n=30 *
predict(fit, head(iris))
#> [1] setosa     setosa     setosa     setosa     setosa     versicolor
#> Levels: setosa versicolor virginica
```
