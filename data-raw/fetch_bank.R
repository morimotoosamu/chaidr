# data-raw/fetch_bank.R -- UCI Bank Marketing データセットの取得ヘルパ
#
# CHAID 本体（R/）には含めない。チュートリアル §5.10 の事例データを
# 取得するためのスクリプトで、ライブラリ機能ではない。
#
# 注意: ucimlrepo パッケージの fetch_ucirepo(id = 222) は**旧版**
# bank-full.csv（45,211行 × 17列、マクロ経済変数なし）を返すため、
# 本節が使う bank-additional-full.csv（41,188行 × 21列）は取得できない。
# 詳細は dev/TUTORIAL.Rmd §5.10 の注記を参照。

BANK_URL <- "https://archive.ics.uci.edu/static/public/222/bank+marketing.zip"
BANK_CSV <- "bank-additional-full.csv"

# UCI Bank Marketing の bank-additional-full.csv をキャッシュ付きで取得する。
#   cache_dir : キャッシュ先ディレクトリ。CSV があればそれを読み、
#               なければ UCI からダウンロードして保存する
#   quiet     : TRUE で進捗メッセージを抑制
# 返り値: data.frame（41,188 行 × 21 列。文字列列は factor）
#
# UCI の配布 zip は入れ子構造（bank+marketing.zip > bank-additional.zip > CSV）
# なので2段階で展開する。
load_bank_marketing <- function(cache_dir = "data-raw", quiet = FALSE) {
  csv_path <- file.path(cache_dir, BANK_CSV)

  if (!file.exists(csv_path)) {
    if (!quiet) {
      message("Bank Marketing データをダウンロード中（約 5.8MB）: ", BANK_URL)
    }
    dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
    outer_zip <- tempfile(fileext = ".zip")
    on.exit(unlink(outer_zip), add = TRUE)

    ok <- tryCatch({
      utils::download.file(BANK_URL, outer_zip, mode = "wb", quiet = quiet)
      TRUE
    }, error = function(e) {
      stop("load_bank_marketing: ダウンロードに失敗した（", conditionMessage(e), "）。\n",
           "  URL: ", BANK_URL, "\n",
           "  手動で取得して ", csv_path, " に配置しても動作する。",
           call. = FALSE)
    })
    if (!ok || !file.exists(outer_zip) || file.size(outer_zip) == 0) {
      stop("load_bank_marketing: ダウンロードしたファイルが空。URL: ", BANK_URL,
           call. = FALSE)
    }

    # 1段目: 外側 zip から bank-additional.zip を取り出す
    ex <- tempfile()
    dir.create(ex)
    on.exit(unlink(ex, recursive = TRUE), add = TRUE)
    inner_zip <- utils::unzip(outer_zip, files = "bank-additional.zip", exdir = ex)
    if (length(inner_zip) != 1 || !file.exists(inner_zip)) {
      stop("load_bank_marketing: zip 内に bank-additional.zip が見つからない。",
           "UCI 側の配布構造が変わった可能性がある（URL: ", BANK_URL, "）",
           call. = FALSE)
    }

    # 2段目: 内側 zip から目的の CSV を取り出してキャッシュへ移す
    inner_member <- file.path("bank-additional", BANK_CSV)
    got <- utils::unzip(inner_zip, files = inner_member, exdir = ex)
    if (length(got) != 1 || !file.exists(got)) {
      stop("load_bank_marketing: ", inner_member, " が zip 内に見つからない。",
           "UCI 側の配布構造が変わった可能性がある", call. = FALSE)
    }
    if (!file.copy(got, csv_path, overwrite = TRUE)) {
      stop("load_bank_marketing: キャッシュへの書き込みに失敗した: ", csv_path,
           call. = FALSE)
    }
    if (!quiet) message("キャッシュに保存: ", csv_path)
  }

  # UCI の CSV はセミコロン区切り・小数点はピリオド
  bk <- utils::read.csv2(csv_path, stringsAsFactors = TRUE, dec = ".")
  if (nrow(bk) != 41188L || ncol(bk) != 21L) {
    warning("load_bank_marketing: 想定と異なる形状（", nrow(bk), " 行 × ",
            ncol(bk), " 列。想定は 41188 × 21）。キャッシュ ", csv_path,
            " が壊れている可能性がある")
  }
  bk
}
