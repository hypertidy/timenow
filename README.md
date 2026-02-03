# timenow
Quick timezone-aware timestamps for R.

```r
# install
pak::pak("hypertidy/timenow")  

# basic usage
timenow()
#> 2025-02-03T12:34:56+00:00 (UTC)
#> 2025-02-03T23:34:56+11:00 (Australia/Hobart)
#> +11h from UTC

# fuzzy timezone matching
timenow("Perth")
timenow("new york")
timenow("tokyo")
```

## Why?

When working on servers or containers where `Sys.timezone()` returns `"UTC"`, it's handy to still see your local time. `timenow` uses a detection cascade to find your actual timezone.
## Configuration

If your system is UTC, set your timezone with:

```r
timenow_set("Hobart")
# or fuzzy:
timenow_set("Perth Australia")
```

This writes to `~/.Renviron` and takes effect next session (also sets it for the current session).

Or manually add to `~/.Renviron`:

```
R_TIMENOW_TZ=Australia/Hobart
```

Or run `timenow_help()` for more options.

## Timezone detection cascade

1. `getOption("timenow.tz")`
2. `Sys.getenv("R_TIMENOW_TZ")`
3. `/etc/timezone` (Debian/Ubuntu)
4. `timedatectl show --property=Timezone` (systemd)
5. `Sys.timezone()`

## Dependencies

Just `{clock}` from CRAN.
