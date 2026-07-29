# CHAID 実装アーキテクチャ

## 概要

`R/` 配下は、IBM SPSS の CHAID / Exhaustive CHAID 決定木を base R
のみで再実装したスクリプト群である。IBM SPSS Statistics Algorithms の
“CHAID and Exhaustive CHAID Algorithms”（リポジトリ同梱の
`TREE-CHAID.pdf`）を仕様の正とし、Kass (1980) の標準アルゴリズム、Biggs
et al. (1991) の Exhaustive 版、順序型＋欠損の Floating
処理までを網羅する。目的変数はカテゴリカル（名義）・順序カテゴリカル・連続の3型に対応し、それぞれ
Pearson χ² / Goodman row effects H² / 一元配置 ANOVA F
で分割の有意性を判定する。

本リポジトリは正式な R パッケージ（パッケージ名
`chaidr`）である。`DESCRIPTION` / `NAMESPACE`
を持ち、[`devtools::load_all()`](https://devtools.r-lib.org/reference/load_all.html)
で開発ロード、[`devtools::test()`](https://devtools.r-lib.org/reference/test.html)（testthat）でテスト、[`devtools::document()`](https://devtools.r-lib.org/reference/document.html)（roxygen2）でドキュメント生成を行う。ファイル名の連番
`00`〜`15`
は概念上の依存順を表しており、後ろのファイルは前のファイルの関数に依存してよいが逆は許されない、というのがこのリポジトリのモジュール規約である（各ファイルは関数定義のみのため、パッケージとしてのロード順には影響しない）。可視化・外部連携（partykit
/ DiagrammeR / plotly）はすべて `Suggests`
のソフト依存で、該当関数を呼んだときだけ
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)
で存在を確認する。本体の学習・予測は追加パッケージなしで動く。

## アーキテクチャ図

``` mermaid
flowchart TD
    subgraph API["ユーザー API"]
        CTL["chaid_control()<br/>06_chaid.R"]
        FIT["chaid()<br/>06_chaid.R"]
        PRED["predict.chaid()<br/>07_predict.R"]
    end

    subgraph CORE["学習コア"]
        BIN["bin_continuous()<br/>02_binning.R"]
        GROW["grow_node() 再帰<br/>05_grow.R"]
        MERGE["merge_predictor()<br/>04_merge.R"]
        TEST["suffstat_pvalue()<br/>03_tests.R"]
        BONF["bonferroni_multiplier()<br/>01_bonferroni.R"]
    end

    subgraph UTIL["共通基盤 00_utils.R"]
        SS["suffstat_build / collapse"]
        AP["allowable_pairs / assign_groups"]
    end

    OBJ[("chaid オブジェクト<br/>nodes / predictors / response")]

    subgraph OUT["出力層"]
        INSPECT["chaid_table / chaid_rules<br/>chaid_importance — 11_inspect.R"]
        GAINS["chaid_gains — 12_gains.R"]
        VALID["chaid_validate — 13_validate.R"]
        VIZ["plot.chaid / chaid_dot<br/>chaid_plotly / chaid_as_party"]
    end

    CTL --> FIT
    FIT --> BIN --> GROW
    GROW --> MERGE --> TEST
    MERGE --> BONF
    MERGE --> SS
    MERGE --> AP
    TEST --> SS
    GROW --> OBJ
    OBJ --> PRED
    OBJ --> OUT
    PRED --> GAINS
    PRED --> VALID
    PRED --> VIZ
```

## ロード順とファイル構成

| 番号 | ファイル | 役割 |
|----|----|----|
| 00 | `R/00_utils.R` | 共通ヘルパ。グループ割当・許容ペア列挙・十分統計量の集計・HTML エスケープ |
| 01 | `R/01_bonferroni.R` | Bonferroni 補正乗数（第2種スターリング数を含む） |
| 02 | `R/02_binning.R` | 連続予測変数の分位ビン分割と、予測時のビン割当 |
| 03 | `R/03_tests.R` | p 値計算。χ² / G² / row effects H² / ANOVA F と期待度数推定 |
| 04 | `R/04_merge.R` | 結合フェーズ。カテゴリ統合ループの中核 |
| 05 | `R/05_grow.R` | 木の再帰構築・分割変数選択・停止規則 |
| 06 | `R/06_chaid.R` | ユーザー API。[`chaid_control()`](reference/chaid_control.md) と [`chaid()`](reference/chaid.md) |
| 07 | `R/07_predict.R` | 学習済み木による予測とルーティング |
| 08 | `R/08_methods.R` | `print` / `summary` メソッドと分割ラベル整形 |
| 09 | `R/09_plot.R` | base graphics による木の描画。レイアウト計算を他の可視化と共用 |
| 10 | `R/10_partykit.R` | partykit `constparty` への変換（ソフト依存） |
| 11 | `R/11_inspect.R` | ノード要約表・ルール抽出（text / SQL / R）・変数重要度 |
| 12 | `R/12_gains.R` | ゲイン・リフト表とチャート |
| 13 | `R/13_validate.R` | 検証データによる安定性評価 |
| 14 | `R/14_graphviz.R` | Graphviz DOT 生成と DiagrammeR レンダリング（ソフト依存） |
| 15 | `R/15_plotly.R` | plotly によるインタラクティブ描画（ソフト依存） |

`R/` 直下に `.R` 以外を置くと `run_all.R` の
[`list.files()`](https://rdrr.io/r/base/list.files.html)
が拾わないため実行対象外になる。逆に `.R` 拡張子のバックアップを `R/`
内に置くと二重定義で読み込まれるので、旧版は `backup_before_speedup/`
のように別ディレクトリへ退避する。

## 学習パイプライン

### 前処理（`chaid()`）

[`chaid()`](reference/chaid.md)
は式とデータフレームを受け取り、[`stats::model.frame()`](https://rdrr.io/r/stats/model.frame.html)
で目的変数と予測変数を切り出す。欠損は `na.pass` でそのまま通し、CHAID
自身のルールで扱う。

ケース除外の条件は「目的変数が欠損」「ケース重み `weights`
が欠損・0・負」「頻度重み `freq`
が欠損・0以下」「全予測変数が欠損」の論理和で、除外件数は結果オブジェクトの
`n_dropped` に記録される。

2種類の重みは役割が異なる。この区別が検定・ノード統計の全体を貫く。

| 重み | 引数 | 意味 | 影響範囲 |
|----|----|----|----|
| ケース重み | `weights`（内部 `w`） | 観測の精度・信頼度 | 期待度数の推定（IPF）にのみ反映 |
| 頻度重み | `freq`（内部 `f`） | 同一ケースの反復数。最近傍整数へ丸める | 観測度数・自由度・ノードサイズ（`Nf`）を決める |

ノードの記述統計と描画上のシェアには両者の積 `w × f` を使う（ノードの
`W`）。重みを指定しなければ両者とも 1 で、`Nf` と `W` は一致する。

### 予測変数の内部表現

`prep_predictor()`
が変数1本を型に応じて整数コード列へ変換する。以降のアルゴリズムは元の型を一切参照せず、この整数コードとメタデータだけで動く。

| 入力型 | 分割型（`ptype`） | コード化 | 欠損の扱い |
|----|----|----|----|
| numeric | `ordinal` | `bin_continuous()` で分位ビン化 | 浮動カテゴリ（`float_code` を設定） |
| ordered factor | `ordinal` | 水準番号 | 浮動カテゴリ |
| factor | `nominal` | 水準番号 | 通常カテゴリ `<NA>` として末尾に追加 |

浮動カテゴリ（floating）とは、順序型でありながら結合の隣接制約を受けず任意のグループと統合できる特別なカテゴリを指す。Kass
(1980) の Floating
拡張にあたり、順序尺度上に位置づけられない欠損を扱うための仕組みである。

ビン分割は木の構築前に学習データ全体で1回だけ実行し、以後は固定した順序カテゴリとして扱う。同一値へ重みが集中している場合やユニーク値数が目標ビン数に満たない場合、ビン数は自動的に縮小する（同一値が必ず同一ビンに入る制約を優先するため）。

### 再帰構築（`grow_node()`）

木の可変状態は `new.env(parent = emptyenv())` の `state`
に置き、ノードリスト `state$nodes` と採番カウンタ `state$next_id`
を再帰の中で更新する。参照セマンティクスを使うことで、深い再帰から浅い階層へ結果を戻す配管が不要になっている。

ノード id はプレオーダー DFS で採番される。`grow_node()` は入口で id
を確保してノードの骨格を `state$nodes`
に書き込み、子を再帰構築したあとに分割情報を加えて同じ位置を上書きする。この結果、**親の
id は必ず子の id
より小さい**という不変条件が成立し、予測時のルーティング（後述）がこれを利用する。

停止規則は IBM 仕様の6種類で、成立した理由が `terminal_reason`
に記録される。

| 理由              | 条件                                               |
|-------------------|----------------------------------------------------|
| `pure`            | 目的変数が単一値（連続では分散ゼロ）               |
| `max_depth`       | 最大深さ到達                                       |
| `min_parent`      | ノードの頻度重み合計が閾値未満                     |
| `no_predictor`    | 全予測変数がノード内で一定（検定できる変数がない） |
| `not_significant` | 最良分割の調整済み p 値が `alpha_split` を超える   |
| `min_child`       | 小さすぎる子を統合した結果、子が1つになった        |

分割変数の選択は「全予測変数について結合フェーズを実行し、調整済み p
値が最小の変数を採る」。同点時は未調整 p
値、統計量の大きさ、変数の並び順の優先で決着する（`better_split()`）。

`adjust_across` を指定すると、ノード内で検定できた予測変数の p
値ベクトルに
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html)
を適用し、補正後の値 `p_final` で `alpha_split`
との比較を行う。変数の選択自体は補正前の値で行うが、`p.adjust`
の全手法は単調なので最小値をとる変数は変わらない。SPSS
既定はこの層を無補正とするため、既定値は `"none"`。

## 結合フェーズ

CHAID
の中核は「予測変数のカテゴリを、目的変数との関連が似ているもの同士で統合していく」結合フェーズである。`merge_predictor()`
が入口となり、3つの経路へ分岐する。

``` mermaid
flowchart TD
    MP["merge_predictor()<br/>実在カテゴリ2未満なら NULL"] --> SS["suffstat_build()<br/>十分統計量表を1回だけ集計"]
    SS --> BR{"浮動カテゴリを含むか"}
    BR -->|Yes| FL["merge_floating()<br/>非欠損で結合 → 欠損を統合 or 独立で比較"]
    BR -->|No, method=chaid| ST["merge_core_standard()<br/>p値最大ペアを alpha_merge 超の間だけ統合"]
    BR -->|No, method=exhaustive| EX["merge_core_exhaustive()<br/>2群まで強制統合し全履歴の最良を採用"]
    FL --> ABS
    ST --> ABS
    EX --> ABS
    ABS["absorb_small_groups()<br/>min_segment 未満のグループを吸収"] --> CFG["config_pvalue()<br/>最終構成の全表検定"]
    CFG --> BONF["bonferroni_multiplier()<br/>p_adj = min(1, B × p)"]
```

統合を許すペアの範囲は分割型で決まる（`allowable_pairs()`）。順序型は最小コード順に並べた隣接ペアのみ、名義型は全ペア、浮動カテゴリを含むグループは順序型であっても任意のグループと組める。

標準 CHAID は「最も似ている（ペア p 値が最大の）ペアが `alpha_merge`
を超える限り統合する」という貪欲ループで、グループ数が2になるか全ペアが有意になった時点で止まる。`resplit`
を有効にすると、3個以上の元カテゴリからなる複合グループについて最良の2分割を探索し、それが十分有意なら分割し直す（公式ステップ5）。統合と再分割が振動しうるため反復回数の上限ガードを持ち、上限に達した場合は警告を出して途中の構成で打ち切る。

Exhaustive CHAID は `alpha_merge`
を無視して2グループまで統合を続け、初期構成を含む全履歴のうち全表 p
値が最小の構成を採用する。探索が網羅的な分、Bonferroni
補正の乗数も大きくなる。

### 十分統計量による高速化

すべての検定は「グループ ×
目的変数クラス」の分割表（連続目的では群別の十分統計量）だけで計算できる。この性質を使い、`merge_predictor()`
の入口で `suffstat_build()`
がノード内データを1回だけ走査して表を作り、以後の全検定は表の行を畳み込むだけで済ませる。

| 目的変数の型 | 集計内容 |
|----|----|
| factor / ordinal | カテゴリ × クラスの観測度数 `nij`（Σf）と重み付き度数 `wij`（Σw·f） |
| numeric | カテゴリ別の Σf, Σw·f, Σw·f·y, Σw·f·y²（`y` はノード加重平均で中心化） |

ペア p 値は「そのペアに属するケースのみ」で計算するという IBM
仕様なので、生データを部分抽出する実装と表の2行を取り出す実装は数値的に等価である。さらに結合ループはペア
p
値をキャッシュし、統合によって値が変わりうる「統合後グループが絡むペア」だけを再計算する（`fill_pair_cache()`
/
`drop_merge_cache()`）。キャッシュは上三角行列で保持し、浮動カテゴリのペアが逆順で来る場合に備えて添字を正規化してから引く。

この2段の最適化により、bank
データ（41,188行・19変数）での学習は約8倍、連続目的変数では約20倍速くなっている。木の構造と
p 値は最適化前と一致する。

### 検定層

`suffstat_pvalue()`
が目的変数の型を見て表ベースの検定コアへ振り分ける。生データを受ける従来シグネチャの関数（`pval_chisq()`
など）も互換ラッパーとして残っており、テストと外部からの直接呼び出しに使える。

| 目的変数の型 | 検定 | 統計量 | 自由度 |
|----|----|----|----|
| factor | Pearson χ² または尤度比 G²（`stat` で選択） | χ² | (I−1)(J−1) |
| ordinal | Goodman row effects 尤度比 | H² | I−1（クラス数に依存しない） |
| numeric | 一元配置 ANOVA F | F | (I−1, N_f−I) |

期待度数の推定（`expected_freq()`）はケース重みの有無で分岐する。重みがなければ閉形式の周辺積、あれば反復比例フィッティング（IPF）で推定する。順序型の
row effects
モデルはさらに別の反復（`roweffects_expected()`）を持ち、`γ^z`
の桁あふれを避けるため対数空間で計算する。どちらの反復も上限回数で打ち切り、収束しなければ警告を出す。

順序型目的変数のクラススコアは木の開始時に固定される。部分表で空クラスの列が落ちても残りのスコアを再採番しない（中心化のみ表ごとに再計算する）のが
IBM 仕様であり、実装もこれに従う。

### Bonferroni 補正

結合フェーズは「多数のカテゴリ統合パターンを試して最良を選ぶ」ため、そのまま
p 値を使うと有意になりすぎる。補正乗数 `B` を掛けて
`p_adj = min(1, B × p)` とする。

| 手法 | 分割型 | 乗数 |
|----|----|----|
| 標準 | ordinal | C(I−1, r−1) |
| 標準 | nominal | 第2種スターリング数 S(I, r) |
| 標準 | floating | C(I−2, r−2) + r × C(I−2, r−1) |
| Exhaustive | ordinal / floating | I(I−1)/2 |
| Exhaustive | nominal | I(I²−1)/2（`"spss"`）または I(I²−1)/6（`"biggs"`） |

`I` はノード内に実在する元カテゴリ数、`r`
は結合後のグループ数。Exhaustive の名義型は出典間で式が食い違うため
`exhaustive_adjust` で切り替える。SPSS 版は Biggs
流のちょうど3倍で、より保守的になる。第2種スターリング数は交代和の閉形式が大きな
`I` で桁落ちするため、漸化式で計算している。

## 木オブジェクトのデータ構造

[`chaid()`](reference/chaid.md) の返り値は S3 クラス `"chaid"`
のリストで、可視化・検査・予測のすべてがこの構造を契約点として参照する。ここを変更すると出力層全体に波及する。

    chaid
    ├─ call        : 呼び出し式
    ├─ method      : "chaid" | "exhaustive"
    ├─ control     : chaid_control の内容（y_scores が注入済み）
    ├─ response    : list(name, type, levels, scores)
    ├─ predictors  : 予測変数ごとの内部表現（name, code, ptype, float_code,
    │                levels, breaks, ncat）。code は学習データのコード列
    ├─ nodes       : ノードのフラットリスト。位置 = ノード id
    ├─ costs       : 誤分類コスト行列または NULL
    ├─ n           : 有効ケース数
    └─ n_dropped   : 除外件数

ノード1件の構造は次のとおり。`nodes`
はフラットなリストで、**位置とノード id が一致する**（`nodes[[id]]`
で直接引ける）ことを全ファイルが前提にしている。

| フィールド | 内容 |
|----|----|
| `id` / `parent` / `depth` | 木構造。root は `id = 1`、`parent = NA` |
| `n` / `Nf` / `W` | ケース数 / 頻度重み合計 / `w × f` 合計 |
| `dist` | カテゴリカルはクラス別 `w × f` 合計、連続は `mean` と `sd` |
| `prediction` | 予測クラス名または予測平均 |
| `split` | 分割情報（下記）。末端ノードでは `NULL` |
| `terminal_reason` | 停止理由。分割したノードでは `NULL` |

`split` の中身は `var`（変数名）、`var_index`（`predictors`
内の位置）、`groups`（グループごとの元カテゴリコード集合）、`children`（子ノード
id）、検定結果（`statistic`, `df`, `p_unadj`, `B`, `p_adj`, `p_final`,
`n_family`）、`ptype`（有効な分割型）である。「末端ノードか否か」の判定は一貫して
`is.null(nd$split)` で行う。

`predictors[[i]]$code`
は学習データのコード列を保持しているため、木オブジェクトは元データを持たなくても構造の検査ができる。ただし
partykit
変換のようにケース単位の再現が必要な処理では、学習に使ったデータフレームを別途渡す必要がある。

## 予測とルーティング

[`predict.chaid()`](reference/predict.chaid.md) は3ステップで動く。

1.  `recode_newdata()`
    が新データを学習時のコード体系へ変換する。連続変数は学習時の境界で
    `bin_apply()`、カテゴリカルは水準名のマッチで整数化する。学習時に存在しなかった水準は
    `NA` になる。
2.  全ケースを root に置き、ノードを id
    順に走査して該当ノードにいるケースを子へ送る。親の id
    が子より小さいという不変条件により、**1回の走査で全ケースが末端に到達する**（2周目は移動が起きず終了する）。
3.  `type` に応じて末端ノードの情報を返す（`"response"` / `"prob"` /
    `"node"`）。

分割時のグループに含まれないコード —
そのノードには実在しなかった元カテゴリ、学習時に未知だった水準、欠損 —
のフォールバックは `route_children()`
が決める。順序型はコード距離が最小のグループへ送り、名義型とその他は最大ノードサイズの子へ送る。未知水準を検出した場合は警告を出す。

[`chaid_gains()`](reference/chaid_gains.md) /
[`chaid_validate()`](reference/chaid_validate.md) /
[`chaid_as_party()`](reference/chaid_as_party.md) はいずれも内部で
`predict(..., type = "node")`
を呼び、末端ノードへの割当を得てから集計する。

## 分析・検査 API

| 関数 | 用途 | 特記事項 |
|----|----|----|
| [`chaid_table()`](reference/chaid_table.md) | 末端ノードの要約表。構成比・反応率・インデックス値 | 先頭行が root（インデックス100の基準）。`target` 指定で反応率とインデックスを追加 |
| [`chaid_rules()`](reference/chaid_rules.md) | ノード到達条件のルール化 | `"text"`（日本語）/ `"sql"`（WHERE 句）/ `"r"`（論理式）。R 形式は `eval` でノード割当を厳密に再現でき、17有効桁で数値を出力する |
| [`chaid_importance()`](reference/chaid_importance.md) | 変数重要度 | SPSS に公式指標がないための独自ヒューリスティック。ノードサイズ比 × (−log10 p_adj) の総和 |
| [`chaid_gains()`](reference/chaid_gains.md) | ゲイン・リフト表 | 学習時統計または新データで集計。[`plot()`](https://rdrr.io/r/graphics/plot.default.html) で累積ゲイン曲線／リフト曲線 |
| [`chaid_validate()`](reference/chaid_validate.md) | 検証データでの安定性評価 | ノード別の構成比・反応率を学習時と比較。全体指標は accuracy または RMSE / R² |

ルール生成は `node_conditions()` が root
からのパスを辿って変数ごとの許容コード集合を集める（同じ変数が複数回使われた場合は交差を取る）。`render_condition()`
が形式ごとに条件文へ整形し、連続変数は隣接ビンを1つの区間表記にまとめる。文字列リテラルのクォートは
R 形式では [`deparse()`](https://rdrr.io/r/base/deparse.html)、SQL
形式では ANSI の二重化で処理する。

[`chaid_importance()`](reference/chaid_importance.md)
が独自指標である点は注意が必要である。χ² と F
は自由度が異なり直接加算できないため p
値ベースの指標を採っているが、SPSS の出力と一致する保証はない。

## 可視化層

4つの描画経路があり、すべて同じ木オブジェクトを入力に取る。

| 関数 | 出力 | 依存 |
|----|----|----|
| [`plot.chaid()`](reference/plot.chaid.md) | base graphics のプロット | なし |
| [`chaid_dot()`](reference/chaid_dot.md) / [`chaid_graphviz()`](reference/chaid_dot.md) | Graphviz DOT 文字列 / htmlwidget | DiagrammeR（レンダリング時のみ） |
| [`chaid_plotly()`](reference/chaid_plotly.md) | インタラクティブ htmlwidget | plotly |
| [`chaid_as_party()`](reference/chaid_as_party.md) | partykit `constparty` | partykit |

共有部品が3つある。**レイアウト計算**
`tree_layout()`（`09_plot.R`）は末端ノードを DFS
順に等間隔配置し内部ノードを子の中央に置くもので、[`plot.chaid()`](reference/plot.chaid.md)
と [`chaid_plotly()`](reference/chaid_plotly.md)
が共用する。**分割ラベル整形**
`format_group()`（`08_methods.R`）は連続変数の隣接ビンを区間表記へまとめるもので、`print`
/ base plot / DOT / plotly の4か所から呼ばれる。**HTML エスケープ**
`esc_html()`（`00_utils.R`）は Graphviz の HTML-like ラベルと plotly
のホバーテキストで共用する。Graphviz の通常引用文字列にはさらに
`esc_dot()` を使い、`<` と `&` を保守的にエンティティ化する。

partykit 変換は、ビン化された連続変数を「区間ラベルの順序 factor」として
party のデータフレームに載せ、全分割を index 型 `partysplit`
に統一する。これにより欠損も明示的な水準としてルーティングされる。変換した
party オブジェクトは可視化・構造検査用であり、新データの予測には
[`predict.chaid()`](reference/predict.chaid.md) を使う。

## 設定リファレンス

[`chaid_control()`](reference/chaid_control.md) の既定値は SPSS UI
の既定に合わせてある。

| パラメータ | 既定 | 影響範囲 |
|----|----|----|
| `alpha_merge` | 0.05 | 結合ループの停止閾値（標準 CHAID のみ） |
| `alpha_split` | 0.05 | 分割の有意性判定 |
| `alpha_split_merge` | 0.05 | resplit の判定閾値 |
| `resplit` | FALSE | 公式ステップ5の再分割を行うか |
| `bonferroni` | TRUE | 補正乗数を適用するか |
| `stat` | `"pearson"` | カテゴリカル目的の統計量（`"lr"` で尤度比） |
| `exhaustive_adjust` | `"spss"` | Exhaustive 名義型の乗数の出典 |
| `max_depth` | 3 | 最大深さ |
| `min_parent` / `min_child` | 100 / 50 | 分割元・分割先の最小サイズ（頻度重み合計） |
| `min_segment` | NULL | 結合フェーズでのグループ最小サイズ（公式ステップ7） |
| `n_bins` | 10 | 連続予測変数のビン数 |
| `epsilon` / `max_iter` | 1e-3 / 100 | IPF・row effects 反復の収束条件 |
| `adjust_across` | `"none"` | 予測変数間の多重比較補正 |

[`chaid()`](reference/chaid.md) 側の引数では `costs`（誤分類コスト行列
`C[truth, pred]`、rpart の loss と同じ規約）と
`y_scores`（順序型目的変数のクラススコア）が挙動を変える。コスト行列はノードの予測クラスを最頻クラスから期待コスト最小のクラスへ変えるが、SPSS
準拠で**木の成長と検定には影響しない**。

`adjust_across` を既定以外にする場合の統計的な注意点は `R/06_chaid.R`
の冒頭コメントに詳しい。要点は、補正の family
がノード単位であって木全体の FWER / FDR は制御されないこと、深いノードの
p
値は選択後推論の問題を抱えるためどの補正でも解決しないこと、分割可否が単一判定であるため
holm は bonferroni と常に同一の木を与えることの3点である。

## コード参照

| 領域 | ファイル | 主要シンボル |
|----|----|----|
| 共通基盤 | `R/00_utils.R` | `assign_groups()`, `allowable_pairs()`, `weighted_xtab()`, `suffstat_build()`, `suffstat_collapse()`, `esc_html()` |
| 補正 | `R/01_bonferroni.R` | `bonferroni_multiplier()`, `stirling2()` |
| ビン分割 | `R/02_binning.R` | `bin_continuous()`, `bin_apply()` |
| 検定 | `R/03_tests.R` | `suffstat_pvalue()`, `pval_chisq_tab()`, `pval_ftest_tab()`, `pval_roweffects_tab()`, `expected_freq()`, `roweffects_expected()`, `node_pvalue()` |
| 結合 | `R/04_merge.R` | `merge_predictor()`, `merge_core_standard()`, `merge_core_exhaustive()`, `merge_floating()`, `absorb_small_groups()`, `pair_pvalue()`, `config_pvalue()`, `fill_pair_cache()`, `drop_merge_cache()`, `best_binary_split()` |
| 成長 | `R/05_grow.R` | `grow_node()`, `node_stats()`, `better_split()` |
| API | `R/06_chaid.R` | [`chaid()`](reference/chaid.md), [`chaid_control()`](reference/chaid_control.md), `prep_predictor()`, `bin_labels()` |
| 予測 | `R/07_predict.R` | [`predict.chaid()`](reference/predict.chaid.md), `recode_newdata()`, `route_children()` |
| 表示 | `R/08_methods.R` | [`print.chaid()`](reference/print.chaid.md), [`summary.chaid()`](reference/print.chaid.md), `format_group()`, `format_node_stats()` |
| 描画 | `R/09_plot.R` | [`plot.chaid()`](reference/plot.chaid.md), `tree_layout()`, `trunc_label()` |
| partykit | `R/10_partykit.R` | [`chaid_as_party()`](reference/chaid_as_party.md), [`as.party.chaid()`](reference/chaid_as_party.md) |
| 検査 | `R/11_inspect.R` | [`chaid_table()`](reference/chaid_table.md), [`chaid_rules()`](reference/chaid_rules.md), [`chaid_importance()`](reference/chaid_importance.md), `node_conditions()`, `render_condition()` |
| ゲイン | `R/12_gains.R` | [`chaid_gains()`](reference/chaid_gains.md), [`print.chaid_gains()`](reference/chaid_gains.md), [`plot.chaid_gains()`](reference/chaid_gains.md) |
| 検証 | `R/13_validate.R` | [`chaid_validate()`](reference/chaid_validate.md), [`print.chaid_validation()`](reference/chaid_validate.md) |
| Graphviz | `R/14_graphviz.R` | [`chaid_dot()`](reference/chaid_dot.md), [`chaid_graphviz()`](reference/chaid_dot.md), `esc_dot()`, [`print.chaid_dot()`](reference/chaid_dot.md) |
| plotly | `R/15_plotly.R` | [`chaid_plotly()`](reference/chaid_plotly.md) |

テストは `tests/test_*.R` に領域別に置かれ、`tests/run_all.R` が `R/`
を番号順に source してから全テストを実行する。`stopifnot`
ベースで、失敗すると該当ファイル名とともに停止する。

## 変更時の注意点

- **ノードリストの位置と id
  の一致**は予測ルーティングと全出力層の前提である。ノードの削除・並べ替えを導入する場合、`nodes[[id]]`
  で引いている全箇所を洗い出す必要がある。
- **親の id が子より小さい**という不変条件が
  [`predict.chaid()`](reference/predict.chaid.md)
  の単一走査ルーティングを成立させている。採番順を変えると予測が壊れる。
- **`split` の構造**は `print` / 4種の可視化 / ルール抽出 / 重要度 /
  ゲイン表がすべて参照する契約点である。フィールドの追加は安全だが、名前の変更や削除は広範囲に波及する。
- **2種類の重みの役割分担**（`w` は期待度数のみ、`f`
  は観測度数・自由度・ノードサイズ）を崩すと SPSS
  との一致が失われる。新しい集計を書くときはどちらを使うべきか確認すること。
- **検定はグループの分割表だけに依存する**という性質が十分統計量による高速化とペア
  p
  値キャッシュの正当性を支えている。ケース単位の情報を要する検定を追加する場合、この前提が崩れるため結合フェーズの設計から見直す必要がある。
- 可視化系を追加する場合、レイアウトは `tree_layout()`、ラベルは
  `format_group()`、エスケープは `esc_html()`
  を再利用する。独自実装すると表記が他の出力とずれる。

## 用語集

| 用語 | 定義 |
|----|----|
| 結合フェーズ（merging） | 予測変数のカテゴリを目的変数との関連が似ているもの同士で統合していく段階。CHAID の中核 |
| 浮動カテゴリ（floating） | 順序型でありながら隣接制約を受けず任意のグループと統合できるカテゴリ。順序尺度に位置づけられない欠損に使う |
| 分割型（ptype） | 予測変数の結合ルール。`"ordinal"`（隣接のみ）/ `"nominal"`（全ペア）/ `"floating"`（浮動カテゴリを含む有効型） |
| ケース重み（w） | 観測の精度を表す重み。期待度数の推定にのみ反映される |
| 頻度重み（f） | 同一ケースの反復数。観測度数・自由度・ノードサイズを決める。整数へ丸められる |
| N_f | ノードの頻度重み合計。停止規則の `min_parent` / `min_child` はこの値で判定する |
| 十分統計量表 | ノード×予測変数ごとに1回だけ集計する分割表。以後の全検定はこの表の行の畳み込みで計算する |
| IPF | 反復比例フィッティング。ケース重みがある場合の期待度数推定に使う |
| row effects モデル | 順序型目的変数に対する Goodman (1979) のモデル。統計量 H² の自由度はクラス数に依存せず I−1 |
| Exhaustive CHAID | Biggs et al. (1991) の変種。2グループまで統合を続け全履歴の最良構成を選ぶ |
| resplit | 統合した複合カテゴリを最良の2分割で分け直す公式ステップ5の処理。SPSS UI 既定はオフ |
| インデックス値 | 全体を100としたときの反応率（連続では平均）の相対値。セグメントの強さを表す |
