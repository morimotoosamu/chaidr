# chaidr

chaidr は、CHAID（Chi-squared Automatic Interaction Detection）および
Exhaustive CHAID 決定木アルゴリズムの base R 実装です。IBM SPSS
Statistics Algorithms ドキュメントの仕様（Kass 1980; Biggs, de Ville,
and Suen 1991）に 準拠しています。学習・予測のコアは base R
のみで動作し、可視化バックエンドと ‘partykit’
連携はオプションのソフト依存です。

English version:
[README.md](https://github.com/morimotoosamu/chaidr/blob/HEAD/README.md)

## 特徴

- 多岐分割による標準 **CHAID** と **Exhaustive CHAID** の木構築。
- 予測変数: 名義、順序（欠損値の *floating* カテゴリ対応）、連続
  （分位ビンへ自動離散化）。
- 目的変数: 名義（Pearson カイ二乗検定）、順序（Goodman row-effects
  モデル）、連続（一元配置 ANOVA F 検定）。
- `freq` による頻度重み。集計済みデータでも個票と同じ結果を再現。
- [`predict()`](https://rdrr.io/r/stats/predict.html)
  によるクラス・クラス確率・所属ノードの予測。
- モデル検査:
  ノード表（[`chaid_table()`](https://morimotoosamu.github.io/chaidr/reference/chaid_table.md)）、決定ルール
  （[`chaid_rules()`](https://morimotoosamu.github.io/chaidr/reference/chaid_rules.md)）、予測変数重要度（[`chaid_importance()`](https://morimotoosamu.github.io/chaidr/reference/chaid_importance.md)）。
- 評価:
  ゲイン・リフト分析（[`chaid_gains()`](https://morimotoosamu.github.io/chaidr/reference/chaid_gains.md)）とホールドアウトデータでの
  検証（[`chaid_validate()`](https://morimotoosamu.github.io/chaidr/reference/chaid_validate.md)）。
- 可視化: base graphics の
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html)、‘Graphviz’
  DOT 出力
  （[`chaid_dot()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)、[`chaid_graphviz()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)）、‘plotly’
  による対話的な木
  （[`chaid_plotly()`](https://morimotoosamu.github.io/chaidr/reference/chaid_plotly.md)）、‘partykit’
  オブジェクトへの変換
  （[`chaid_as_party()`](https://morimotoosamu.github.io/chaidr/reference/chaid_as_party.md)）。

## インストール

CRAN 公開後はリリース版をインストールできます。

``` r

install.packages("chaidr")
```

それまでは、[GitHub](https://github.com/morimotoosamu/chaidr)
から開発版を インストールできます。

``` r

# install.packages("remotes")
remotes::install_github("morimotoosamu/chaidr")
```

## クイックスタート

`penguins` データセット（R \>= 4.5 に同梱）は連続予測変数と欠損値を
含んでおり、どちらも CHAID がそのまま扱えます。

``` r

library(chaidr)

data(penguins)
fit <- chaid(species ~ ., data = penguins,
             control = chaid_control(min_parent = 30, min_child = 10))
print(fit)
#> CHAID decision tree (method = "chaid")
#> Response: species (categorical) 
#> Valid cases: 344 (data: 344 rows) 
#> 
#> [1] root: Adelie (44.2%), n=344 | split: flipper_len (adj.p=2.48e-63, chi2=328.5, B=714)
#>   [2] flipper_len in {<= 190}: Adelie (84.8%), n=99 | split: bill_len (adj.p=2.92e-16, chi2=78.21, B=28)
#>     [3] bill_len in {<= 40.1}: Adelie (100.0%), n=70 *
#>     [4] bill_len in {(40.1, 41.8]}: Adelie (92.3%), n=13 *
#>     [5] bill_len in {(41.8, 47.3] | > 49.3}: Chinstrap (87.5%), n=16 *
#>   [6] flipper_len in {(190, 196]}: Adelie (67.2%), n=67 | split: bill_len (adj.p=1.66e-13, chi2=58.69, B=9)
#>     [7] bill_len in {<= 44.4}: Adelie (100.0%), n=43 *
#>     [8] bill_len in {> 44.4}: Chinstrap (91.7%), n=24 *
#>   [9] flipper_len in {(196, 202]}: Chinstrap (52.6%), n=38 | split: bill_len (adj.p=2.31e-07, chi2=30.78, B=8)
#>     [10] bill_len in {<= 45.9}: Adelie (90.0%), n=20 *
#>     [11] bill_len in {> 47.3}: Chinstrap (100.0%), n=18 *
#>   [12] flipper_len in {(202, 214] | <NA>}: Gentoo (73.8%), n=61 | split: bill_dep (adj.p=9.69e-12, chi2=56.14, B=15)
#>     [13] bill_dep in {<= 16.7}: Gentoo (100.0%), n=44 *
#>     [14] bill_dep in {> 17.8 | <NA>}: Chinstrap (64.7%), n=17 *
#>   [15] flipper_len in {> 214}: Gentoo (100.0%), n=79 *
```

`flipper_len` のような連続予測変数は、木構築の前に分位ビンへ離散化され、
統計的に類似したビン同士が再統合されて多岐分割になります。`<NA>` を含む
グループは、欠損値が floating カテゴリとして統合された先を示します。
末端ノードには `*` が付きます。

同じ木は base graphics でプロットできます（ノード内の帯は各ノードの
クラス分布）。

``` r

plot(fit, main = "CHAID: penguins (species)")
```

![](reference/figures/README-plot-1.png)

予測は標準の S3 [`predict()`](https://rdrr.io/r/stats/predict.html)
インターフェースで行います。

``` r

pred <- predict(fit, penguins)          # クラスラベル（factor）
mean(pred == penguins$species)          # 訓練データ精度
#> [1] 0.9622093

round(predict(fit, head(penguins, 3), type = "prob"), 3)
#>      Adelie Chinstrap Gentoo
#> [1,]      1         0      0
#> [2,]      1         0      0
#> [3,]      1         0      0
```

全末端ノードの決定ルール:

``` r

chaid_rules(fit)
#>    node
#> 1     3
#> 2     4
#> 3     5
#> 4     7
#> 5     8
#> 6    10
#> 7    11
#> 8    13
#> 9    14
#> 10   15
#>                                                                                                  rule
#> 1                                                             bill_len <= 40.1 and flipper_len <= 190
#> 2                                                     bill_len in (40.1, 41.8] and flipper_len <= 190
#> 3                                (bill_len in (41.8, 47.3] or bill_len > 49.3) and flipper_len <= 190
#> 4                                                      bill_len <= 44.4 and flipper_len in (190, 196]
#> 5                                                       bill_len > 44.4 and flipper_len in (190, 196]
#> 6                                                      bill_len <= 45.9 and flipper_len in (196, 202]
#> 7                                                       bill_len > 47.3 and flipper_len in (196, 202]
#> 8                          bill_dep <= 16.7 and (flipper_len in (202, 214] or flipper_len is missing)
#> 9  (bill_dep > 17.8 or bill_dep is missing) and (flipper_len in (202, 214] or flipper_len is missing)
#> 10                                                                                  flipper_len > 214
```

## 主要関数

| タスク | 関数 |
|----|----|
| モデル学習 | [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md)、[`chaid_control()`](https://morimotoosamu.github.io/chaidr/reference/chaid_control.md) |
| 予測 | [`predict()`](https://rdrr.io/r/stats/predict.html) |
| 検査 | [`print()`](https://rdrr.io/r/base/print.html)、[`summary()`](https://rdrr.io/r/base/summary.html)、[`chaid_table()`](https://morimotoosamu.github.io/chaidr/reference/chaid_table.md)、[`chaid_rules()`](https://morimotoosamu.github.io/chaidr/reference/chaid_rules.md)、[`chaid_importance()`](https://morimotoosamu.github.io/chaidr/reference/chaid_importance.md) |
| 評価 | [`chaid_gains()`](https://morimotoosamu.github.io/chaidr/reference/chaid_gains.md)、[`chaid_validate()`](https://morimotoosamu.github.io/chaidr/reference/chaid_validate.md) |
| 可視化 | [`plot()`](https://rdrr.io/r/graphics/plot.default.html)、[`chaid_dot()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)、[`chaid_graphviz()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)、[`chaid_plotly()`](https://morimotoosamu.github.io/chaidr/reference/chaid_plotly.md) |
| partykit 連携 | [`chaid_as_party()`](https://morimotoosamu.github.io/chaidr/reference/chaid_as_party.md) |

## ドキュメント

- [`vignette("chaidr")`](https://morimotoosamu.github.io/chaidr/articles/chaidr.md)
  – 英語の入門編。
- [`vignette("chaidr-ja")`](https://morimotoosamu.github.io/chaidr/articles/chaidr-ja.md)
  – アルゴリズム・全オプション設定・評価・
  可視化を網羅した詳細チュートリアル（日本語）。

## 参考文献

- Kass, G. V. (1980). An exploratory technique for investigating large
  quantities of categorical data. *Applied Statistics*, 29(2), 119–127.
- Biggs, D., de Ville, B., & Suen, E. (1991). A method of choosing
  multiway partitions for classification and decision trees. *Journal of
  Applied Statistics*, 18(1), 49–62.
- IBM Corp. *IBM SPSS Statistics Algorithms* – “CHAID and Exhaustive
  CHAID Algorithms”.

## ライセンス

MIT (c) Osamu Morimoto
