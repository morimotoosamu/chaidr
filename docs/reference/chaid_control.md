# Control parameters for CHAID tree growing

Collects the algorithm parameters used by
[`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).
The defaults match the defaults of the IBM SPSS Statistics user
interface (alpha 0.05, Bonferroni adjustment on, no re-splitting,
maximum depth 3, minimum parent size 100, minimum child size 50, 10 bins
for continuous predictors).

## Usage

``` r
chaid_control(
  alpha_merge = 0.05,
  alpha_split = 0.05,
  alpha_split_merge = 0.05,
  resplit = FALSE,
  bonferroni = TRUE,
  stat = c("pearson", "lr"),
  exhaustive_adjust = c("spss", "biggs"),
  max_depth = 3L,
  min_parent = 100,
  min_child = 50,
  min_segment = NULL,
  n_bins = 10L,
  epsilon = 0.001,
  max_iter = 100L,
  adjust_across = c("none", "bonferroni", "holm", "hochberg", "hommel", "BH", "BY")
)
```

## Arguments

- alpha_merge:

  Significance level for merging predictor categories. Category pairs
  whose test p-value exceeds this threshold are merged.

- alpha_split:

  Significance level for splitting a node. A node is split only if the
  best (adjusted) p-value is at most this value.

- alpha_split_merge:

  Significance level for re-splitting a merged compound category. Only
  used when `resplit = TRUE`.

- resplit:

  Logical. If `TRUE`, compound categories consisting of three or more
  original categories are considered for a binary re-split during the
  merge step (SPSS "allow resplitting" option).

- bonferroni:

  Logical. If `TRUE` (default), split p-values are Bonferroni-adjusted
  by the number of ways the predictor categories can be merged into the
  final groups.

- stat:

  Chi-squared statistic for categorical responses: `"pearson"` (default)
  or `"lr"` (likelihood ratio).

- exhaustive_adjust:

  Bonferroni multiplier convention used by Exhaustive CHAID: `"spss"`
  (default) follows the IBM SPSS algorithm document, `"biggs"` follows
  Biggs, de Ville and Suen (1991).

- max_depth:

  Maximum tree depth (root has depth 0).

- min_parent:

  Minimum number of cases (frequency-weighted) a node must contain to be
  considered for splitting.

- min_child:

  Minimum number of cases (frequency-weighted) in each child node.

- min_segment:

  Optional minimum size for a merged category group during the merge
  step (SPSS algorithm step 7). Groups smaller than this are absorbed
  into the most similar allowable group. `NULL` (default) disables this
  step.

- n_bins:

  Number of quantile bins used to discretise continuous predictors.

- epsilon:

  Convergence tolerance for the iterative estimation of expected cell
  frequencies with case weights.

- max_iter:

  Maximum number of iterations for the same estimation.

- adjust_across:

  Multiple-comparison adjustment applied across predictors within a node
  before comparing against `alpha_split`. `"none"` (default, as in SPSS)
  or one of the
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) methods
  `"bonferroni"`, `"holm"`, `"hochberg"`, `"hommel"`, `"BH"`, `"BY"`.
  Note that the adjustment family is the node, not the whole tree, and
  that `"holm"` always yields the same tree as `"bonferroni"` because
  only the minimum adjusted p-value is compared with `alpha_split`.

## Value

An object of class `"chaid_control"`: a list of the validated parameter
values, to be passed to the `control` argument of
[`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

## See also

[`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md)

## Examples

``` r
ctl <- chaid_control(max_depth = 2, min_parent = 20, min_child = 5)
fit <- chaid(Species ~ ., data = iris, control = ctl)
fit
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
```
