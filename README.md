
<!-- README.md is generated from README.Rmd. Please edit that file -->

# timenow

<!-- badges: start -->

[![R-CMD-check](https://github.com/hypertidy/timenow/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hypertidy/timenow/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Quick timezone-aware timestamps for R.

Note that we `floor()` to integer seconds for aesthetic reasons. This
might change or become optional.

``` r
# install.packages("pak")
pak::pak("hypertidy/timenow")  
```

``` r
library(timenow)
# basic usage
timenow()
#> 2026-02-03 10:34:46 (UTC)
#> 2026-02-03 10:34:46 (Etc/UTC)
#> same as UTC

# fuzzy timezone matching
timenow("Perth")
#> 2026-02-03 10:34:46 (UTC)
#> 2026-02-03 18:34:46 (Australia/Perth)
#> +8h from UTC
timenow("new york")
#> 2026-02-03 10:34:46 (UTC)
#> 2026-02-03 05:34:46 (America/New_York)
#> -5h from UTC
timenow("tokyo")
#> 2026-02-03 10:34:46 (UTC)
#> 2026-02-03 19:34:46 (Asia/Tokyo)
#> +9h from UTC
```

## Why?

When working with vessels or traverses or servers where wall time or
`Sys.timezone()` returns `"UTC"`, it’s handy to still see your local
time. `timenow` uses a detection cascade to find your actual timezone.

## Configuration

If your system is UTC, set your timezone with:

``` r
timenow_set("Hobart")
# or fuzzy:
timenow_set("Perth Australia")
```

This writes to `~/.Renviron` and takes effect next session (also sets it
for the current session).

Or manually add to `~/.Renviron`:

    R_TIMENOW_TZ=Australia/Hobart

Or run `timenow_help()` for more options.

## Timezone detection cascade

1.  `getOption("timenow.tz")`
2.  `Sys.getenv("R_TIMENOW_TZ")`
3.  `/etc/timezone` (Debian/Ubuntu)
4.  `timedatectl show --property=Timezone` (systemd)
5.  `Sys.timezone()`

## Code of Conduct

Please note that the timenow project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
