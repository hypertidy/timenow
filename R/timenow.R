#' Get current time with timezone awareness
#'
#' Reports the current timestamp in UTC and optionally in a local or specified
#' timezone. Uses a detection cascade to find your local timezone when the
#' system reports UTC.
#'
#' @param tz Optional timezone specification. Can be:
#'   - NULL (default): show UTC and detected local timezone
#'   - A valid IANA timezone name: "Australia/Hobart"
#'   - A fuzzy string: "Perth Australia", "new york", "tokyo"
#' @param quiet Suppress the local timezone detection message
#'
#' @return A named list of class "timenow" with UTC and local times (invisibly
#'
#' @details
#' ## Timezone detection cascade
#'
#' When your system timezone is UTC (common on servers), timenow uses this
#' cascade to find your actual local timezone:
#'
#' 1. `getOption("timenow.tz")` - set in .Rprofile

#' 2. `Sys.getenv("R_TIMENOW_TZ")` - set in .Renviron
#' 3. `/etc/timezone` file (Debian/Ubuntu)
#' 4. `timedatectl` output (systemd)
#' 5. `Sys.timezone()` - the R default
#'
#' ## Setting your timezone
#'
#' In `~/.Renviron`:
#' ```
#' R_TIMENOW_TZ=Australia/Hobart
#' ```
#'
#' Or in `~/.Rprofile`:
#' ```
#' options(timenow.tz = "Australia/Hobart")
#' ```
#'
#' @export
#' @examples
#' timenow()
#' timenow("Perth")
#' timenow("US Eastern")
timenow <- function(tz = NULL, quiet = FALSE) {
  utc_now <- clock::zoned_time_now("UTC")

  if (is.null(tz)) {
    local_tz <- detect_timezone(quiet = quiet)
  } else {
    local_tz <- resolve_timezone(tz)
  }

  local_now <- clock::zoned_time_now(local_tz)

  out <- structure(
    list(
      utc = utc_now,
      local = local_now,
      local_tz = local_tz
    ),
    class = "timenow"
  )

  print(out)
  invisible(out)
}

#' @export
print.timenow <- function(x, ...) {
  fmt <- "%Y-%m-%d %H:%M:%S"
  utc_str <- sub("\\.\\d+", "", format(x$utc, format = fmt))
  local_str <- sub("\\.\\d+", "", format(x$local, format = fmt))

  # Get offset from the zoned time info
  info <- clock::zoned_time_info(x$local)
  offset_secs <- as.integer(info$offset)
  offset_hrs <- offset_secs %/% 3600L
  offset_mins <- abs(offset_secs %% 3600L) %/% 60L

  if (offset_secs == 0L) {
    offset_str <- "same as UTC"
  } else {
    sign <- if (offset_secs > 0L) "+" else "-"
    if (offset_mins == 0L) {
      offset_str <- sprintf("%s%dh from UTC", sign, abs(offset_hrs))
    } else {
      offset_str <- sprintf("%s%dh%02dm from UTC", sign, abs(offset_hrs), offset_mins)
    }
  }

  cat(utc_str, " (UTC)\n", sep = "")
  cat(local_str, " (", x$local_tz, ")\n", sep = "")
  cat(offset_str, "\n", sep = "")

  invisible(x)
}

#' Detect the local timezone
#'
#' Uses a cascade of methods to determine the local timezone, useful when
#' the system timezone is set to UTC.
#'
#' @param quiet Suppress messages about detection method used
#' @return A valid IANA timezone string
#' @export
detect_timezone <- function(quiet = FALSE) {
  # 1. Package option
  opt_tz <- getOption("timenow.tz")
  if (!is.null(opt_tz) && is_valid_tz(opt_tz)) {
    if (!quiet) message("timenow: using timezone from option 'timenow.tz'")
    return(opt_tz)
  }

  # 2. Environment variable
  env_tz <- Sys.getenv("R_TIMENOW_TZ", unset = "")
  if (nzchar(env_tz) && is_valid_tz(env_tz)) {
    if (!quiet) message("timenow: using timezone from R_TIMENOW_TZ")
    return(env_tz)
  }

  # 3. /etc/timezone (Debian/Ubuntu)
  if (file.exists("/etc/timezone")) {
    etc_tz <- trimws(readLines("/etc/timezone", n = 1, warn = FALSE))
    if (nzchar(etc_tz) && is_valid_tz(etc_tz)) {
      return(etc_tz)
    }
  }

  # 4. timedatectl (systemd)
  tdc_tz <- tryCatch({
    out <- system2("timedatectl", c("show", "--property=Timezone", "--value"),
                   stdout = TRUE, stderr = NULL)
    trimws(out[1])
  }, error = function(e) "", warning = function(w) "")
  if (nzchar(tdc_tz) && is_valid_tz(tdc_tz)) {
    return(tdc_tz)
  }

  # 5. Sys.timezone() fallback
  sys_tz <- Sys.timezone()
  if (!is.null(sys_tz) && nzchar(sys_tz) && is_valid_tz(sys_tz)) {
    return(sys_tz)
  }

  # Final fallback
  if (!quiet) {
    warning("timenow: could not detect local timezone, using UTC. ",
            "See ?timenow for configuration options.", call. = FALSE)
  }
  "UTC"
}

#' Resolve a fuzzy timezone string
#'
#' Matches partial or fuzzy timezone specifications against IANA timezone
#' names.
#'
#' @param tz A timezone string, possibly fuzzy like "Perth" or "US Eastern"
#' @return A valid IANA timezone string
#' @export
#' @examples
#' resolve_timezone("Perth")
#' resolve_timezone("new york")
#' resolve_timezone("tokyo")
resolve_timezone <- function(tz) {
  # If already valid, return as-is
  if (is_valid_tz(tz)) {
    return(tz)
  }

  all_tz <- clock::tzdb_names()

  # Try case-insensitive exact match on final component
  tz_lower <- tolower(tz)
  tz_endings <- tolower(basename(all_tz))
  exact_idx <- which(tz_endings == tz_lower)
  if (length(exact_idx) == 1) {
    return(all_tz[exact_idx])
  }

  # Try grep match (words in any order)
  words <- strsplit(tz, "[^A-Za-z]+")[[1]]
  pattern <- paste0("(?=.*", words, ")", collapse = "")
  grep_idx <- grep(pattern, all_tz, ignore.case = TRUE, perl = TRUE)
  if (length(grep_idx) == 1) {
    return(all_tz[grep_idx])
  }
  if (length(grep_idx) > 1) {
    # Prefer shorter matches (more specific)
    matches <- all_tz[grep_idx]
    return(matches[which.min(nchar(matches))])
  }

  # Try agrep (fuzzy)
  agrep_idx <- agrep(tz, all_tz, ignore.case = TRUE, max.distance = 0.2)
  if (length(agrep_idx) >= 1) {
    matches <- all_tz[agrep_idx]
    return(matches[which.min(nchar(matches))])
  }

  stop("Could not resolve timezone '", tz, "'. ",
       "Use clock::tzdb_names() to see valid options.", call. = FALSE)
}

#' Check if a timezone string is valid
#' @param tz Timezone string to check
#' @return Logical
#' @noRd
is_valid_tz <- function(tz) {
  tz %in% clock::tzdb_names()
}

#' Show timezone configuration help
#'
#' Prints guidance on setting your local timezone for timenow.
#'
#' @export
timenow_help <- function() {
  cat("
timenow timezone configuration
==============================

If your system timezone is UTC (common on servers/containers), timenow
can still show your local time if you configure it.

Option 1: R environment variable (recommended)
----------------------------------------------
Add to ~/.Renviron:

    R_TIMENOW_TZ=Australia/Hobart

Option 2: R option
------------------
Add to ~/.Rprofile:

    options(timenow.tz = \"Australia/Hobart\")
Option 3: System timezone (Ubuntu/Debian)
-----------------------------------------
    sudo timedatectl set-timezone Australia/Hobart

Detection cascade
-----------------
timenow checks in order:
1. getOption('timenow.tz')
2. Sys.getenv('R_TIMENOW_TZ')
3. /etc/timezone file
4. timedatectl output
5. Sys.timezone()

Find valid timezone names with: clock::tzdb_names()
Or use fuzzy matching: timenow('Perth Australia')
")
}

#' Set your local timezone for timenow
#'
#' Writes your timezone preference to ~/.Renviron so it persists across
#' sessions. Supports fuzzy timezone matching.
#'
#' @param tz Timezone string (can be fuzzy like "Hobart" or "Perth Australia")
#' @param renviron Path to .Renviron file (default: ~/.Renviron)
#' @param restart Prompt to restart R after setting (default: TRUE)
#'
#' @return The resolved timezone string (invisibly)
#' @export
#' @examples
#' \dontrun{
#' timenow_set("Hobart")
#' timenow_set("Perth Australia")
#' }
timenow_set <- function(tz, renviron = "~/.Renviron", restart = TRUE) {
  # Resolve fuzzy input
  resolved <- resolve_timezone(tz)

  renviron <- path.expand(renviron)

  # Read existing .Renviron or start fresh
  if (file.exists(renviron)) {
    lines <- readLines(renviron, warn = FALSE)
  } else {
    lines <- character(0)
  }

  # Find and remove any existing R_TIMENOW_TZ line
  tz_pattern <- "^R_TIMENOW_TZ="
  existing_idx <- grep(tz_pattern, lines)
  if (length(existing_idx) > 0) {
    old_val <- sub("^R_TIMENOW_TZ=", "", lines[existing_idx[1]])
    lines <- lines[-existing_idx]
    message("Replacing R_TIMENOW_TZ=", old_val)
  }

  # Add new line
  new_line <- paste0("R_TIMENOW_TZ=", resolved)
  lines <- c(lines, new_line)

  # Write back
  writeLines(lines, renviron)

  cat("\n")
  cat("Added to", renviron, ":\n")
  cat(" ", new_line, "\n\n")

  # Also set for current session
  Sys.setenv(R_TIMENOW_TZ = resolved)
  cat("Set for current session too.\n\n")

  # Show what it looks like now
  cat("Current time:\n")
  timenow(quiet = TRUE)

  if (restart && interactive()) {
    cat("\nRestart R for this to take effect in new sessions.\n")
  }

  invisible(resolved)
}
