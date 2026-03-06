# timenow (development version)

* `timenow()` is now vectorized: `timenow(c("Hobart", "Tokyo", "Jackson, TN"))`
  prints all timezones and returns a list of `timenow` objects invisibly.
* `resolve_timezone()` now falls back to geocoding via the \pkg{location}
  package (if installed) before `agrep()`. This allows arbitrary place name
  strings like `"Jackson, TN"` or `"Davis Station, Antarctica"` to resolve
  to a timezone. Requires `location` and `lutz` in `Suggests`.
* The error message from `resolve_timezone()` now hints to install \pkg{location}
  if it is not available.

# timenow 0.1.0

* Initial release.
* `timenow()` reports current UTC and local time with offset.
* Timezone detection cascade: option → environment variable → `/etc/timezone`
  → `timedatectl` → `Sys.timezone()`.
* `resolve_timezone()` for fuzzy matching of timezone strings against
  `clock::tzdb_names()`.
* `detect_timezone()` exported for use in other packages.
* `timenow_set()` writes timezone to `~/.Renviron` for persistence.
* `timenow_help()` prints configuration guidance.
* Uses `clock` for all time arithmetic; no `lubridate` dependency.
