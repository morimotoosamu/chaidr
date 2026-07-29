# Print and summarise a CHAID tree

[`print()`](https://rdrr.io/r/base/print.html) displays the tree
structure with one line per node showing the prediction, node size and
split information. [`summary()`](https://rdrr.io/r/base/summary.html)
additionally reports the control settings and a risk estimate on the
training data (misclassification rate or expected misclassification cost
for categorical responses, weighted within-node variance for continuous
responses).

## Usage

``` r
# S3 method for class 'chaid'
print(x, ...)

# S3 method for class 'chaid'
summary(object, ...)
```

## Arguments

- x, object:

  A fitted `"chaid"` object returned by [`chaid()`](chaid.md).

- ...:

  Ignored.

## Value

The fitted object, invisibly.

## See also

[`chaid()`](chaid.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
print(fit)
#> CHAID 決定木 (method = "chaid")
#> 目的変数: Species (カテゴリカル) 
#> 有効ケース数: 150 （データ 150 行） 
#> 
#> [1] root: setosa (33.3%), n=150 | 分割: Petal.Length (adj.p=1.35e-44, chi2=243.8, B=126)
#>   [2] Petal.Length in {<= 1.6}: setosa (100.0%), n=44 *
#>   [3] Petal.Length in {(1.6, 3.8]}: versicolor (57.1%), n=14 *
#>   [4] Petal.Length in {(3.8, 4.6]}: versicolor (96.9%), n=32 *
#>   [5] Petal.Length in {(4.6, 4.9]}: versicolor (64.3%), n=14 *
#>   [6] Petal.Length in {(4.9, 5.3]}: virginica (87.5%), n=16 *
#>   [7] Petal.Length in {> 5.3}: virginica (100.0%), n=30 *
summary(fit)
#> CHAID 決定木 (method = "chaid")
#> 目的変数: Species (カテゴリカル) 
#> 有効ケース数: 150 （データ 150 行） 
#> 
#> [1] root: setosa (33.3%), n=150 | 分割: Petal.Length (adj.p=1.35e-44, chi2=243.8, B=126)
#>   [2] Petal.Length in {<= 1.6}: setosa (100.0%), n=44 *
#>   [3] Petal.Length in {(1.6, 3.8]}: versicolor (57.1%), n=14 *
#>   [4] Petal.Length in {(3.8, 4.6]}: versicolor (96.9%), n=32 *
#>   [5] Petal.Length in {(4.6, 4.9]}: versicolor (64.3%), n=14 *
#>   [6] Petal.Length in {(4.9, 5.3]}: virginica (87.5%), n=16 *
#>   [7] Petal.Length in {> 5.3}: virginica (100.0%), n=30 *
#> 
#> 設定: alpha_merge=0.05, alpha_split=0.05, bonferroni=TRUE, adjust_across=none, max_depth=3, min_parent=30, min_child=10, n_bins=10
#> 
#> リスク推定（学習データ）: 0.0933 （誤分類率） 
#> 
#> 末端ノード: 6 個
#> 停止理由:
#>   min_child: 1
#>   min_parent: 3
#>   pure: 2
```
