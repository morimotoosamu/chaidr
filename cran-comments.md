## Test environments

* Local: Windows 11, R 4.6.1 (2026-06-24 ucrt), `devtools::check(remote = TRUE)`
* GitHub Actions: windows-latest (R release), macos-latest (R release),
  ubuntu-latest (R devel, R release, R oldrel-1) -- all passing
* win-builder: R devel <!-- TODO: check_win_devel() の結果を反映してからこのコメントを削除 -->

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Osamu Morimoto <galactic.supermarket@gmail.com>'
  New submission

This is a new release (first submission).

## Method references

The methods implemented in this package are described in Kass (1980)
<doi:10.2307/2986296> and Biggs, de Ville, and Suen (1991)
<doi:10.1080/02664769100000005>, both cited in the Description field.
