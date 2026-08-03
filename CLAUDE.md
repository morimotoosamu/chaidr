# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## リポジトリ概要

chaidr は CHAID / Exhaustive CHAID 決定木の base R 実装パッケージ。IBM
SPSS Statistics Algorithms 文書を仕様の正とし、コア（学習・予測）は base
R のみに依存する。可視化・partykit 連携は Suggests
のソフト依存で、呼び出し時に
[`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) で確認する。

詳細な設計は
[ARCHITECTURE.md](https://morimotoosamu.github.io/chaidr/ARCHITECTURE.md)
を必ず参照すること（アルゴリズム、データ構造、モジュール構成、変更時の注意点を網羅）。ただし同文書の「`tests/test_*.R` +
`run_all.R`」の記述は旧構成で、現在のテストは
testthat（`tests/testthat/`）に移行済み。

## 環境（このマシン固有）

- R は PATH 外: `C:\R\R-4.6.1\bin\Rscript.exe` を使う
- pandoc も PATH 外: vignette ビルドや `devtools::check()` の前に
  `/c/Program Files/RStudio/resources/app/bin/quarto/bin/tools` を PATH
  に追加する（Bash）。追加しないと vignette ビルドが失敗する
- LaTeX なし: `devtools::check()` は `manual = FALSE` で実行する（PDF
  マニュアル検査は win-builder に委ねる）

## よく使うコマンド

``` bash
# テスト全実行
"/c/R/R-4.6.1/bin/Rscript.exe" -e "devtools::test()"

# 単一テストファイル（例: test-merge.R）
"/c/R/R-4.6.1/bin/Rscript.exe" -e "devtools::test(filter = 'merge')"

# ドキュメント再生成（roxygen2、markdown 記法）
"/c/R/R-4.6.1/bin/Rscript.exe" -e "devtools::document()"

# フルチェック（pandoc を PATH に入れてから）
export PATH="/c/Program Files/RStudio/resources/app/bin/quarto/bin/tools:$PATH"
"/c/R/R-4.6.1/bin/Rscript.exe" -e "devtools::check(document = FALSE, manual = FALSE)"

# スペルチェック（新出単語は inst/WORDLIST に追加）
"/c/R/R-4.6.1/bin/Rscript.exe" -e "spelling::spell_check_package(vignettes = TRUE)"
```

CI は GitHub Actions（`.github/workflows/R-CMD-check.yaml`）で
win/mac/ubuntu × R devel/release/oldrel-1 の R CMD check、`pkgdown.yaml`
で <https://morimotoosamu.github.io/chaidr/> へ自動デプロイ。

## 構造の要点

- `R/` のファイル名接頭の連番 `00`〜`15`
  は概念上の依存順。**後ろの番号は前の番号の関数に依存してよいが、逆は不可**
- パイプライン:
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md) (06)
  → 連続変数ビン化 (02) → 再帰成長 (05) → カテゴリ結合 (04) →
  検定 (03) + Bonferroni (01)。返り値は S3 クラス `"chaid"`
- 出力層（predict / plot / DOT / plotly / partykit / rules / gains /
  validate）はすべて chaid オブジェクトの `nodes` と `split`
  構造を契約点として参照する

## 壊してはいけない不変条件（詳細は ARCHITECTURE.md「変更時の注意点」）

1.  `nodes` リストは**位置 = ノード id**（`nodes[[id]]`
    で直接参照される）
2.  **親の id \< 子の
    id**（プレオーダー採番）。[`predict.chaid()`](https://morimotoosamu.github.io/chaidr/reference/predict.chaid.md)
    の単一走査ルーティングがこれに依存
3.  2種類の重みの役割分担: ケース重み `w` は期待度数の推定のみ、頻度重み
    `f` は観測度数・自由度・ノードサイズ。混同すると SPSS
    との一致が崩れる
4.  検定は十分統計量表（グループ×クラスの分割表）のみに依存する。この性質が高速化とペア
    p 値キャッシュの正当性を支える
5.  高速化の変更は**ビット単位で同一の結果**を保つこと（コミット f1a0b4d
    の方針）

## 実装規約

- コアは base R のみ（Imports は graphics/grDevices/stats/utils
  のみ）。tidyverse 等を Imports に追加しない
- 可視化の新規追加時はレイアウト `tree_layout()` (09)、ラベル整形
  `format_group()` (08)、エスケープ `esc_html()` (00) を再利用する
- roxygen2 の例で Suggests パッケージを使う場合は
  `@examplesIf requireNamespace(...)` で保護（`\dontrun{}`
  は使わない。CRAN 方針）
- testthat edition
  3。スナップショットテスト（`tests/testthat/_snaps/`）あり。print
  出力を変えるとスナップショット更新が必要
- vignette は英語版 `chaidr.Rmd` と日本語版 `chaidr-ja.Rmd`
  の2本。ユーザー向け文書の変更は両方に反映する

## CRAN 関連

- 初回申請進行中（2026-08）。`cran-comments.md`
  が提出コメント、`.Rbuildignore` が tarball 除外の管理点
- `README.md` は `README.Rmd` から生成。**README.md
  を直接編集しない**。`README.Rmd` 編集後に `devtools::build_readme()`
- `inst/CITATION` の CRAN URL は公開前 404 だが定型なので変更しない
