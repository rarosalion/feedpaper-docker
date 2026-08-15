#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${FEEDPAPER_OUTPUT_DIR:-/output}"
KEEP_UNREAD="${FEEDPAPER_KEEP_UNREAD:-false}"
mkdir -p "$OUTPUT_DIR"

ARGS=( -o "$OUTPUT_DIR" )
if [[ "$KEEP_UNREAD" == "true" ]]; then
  ARGS+=( --keep-unread )
fi

set +e
feedpaper "${ARGS[@]}" "$@"
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  echo "feedpaper exited with status $status; not sending email." >&2
  exit "$status"
fi

if [[ "${FEEDPAPER_EMAIL_ENABLED:-false}" != "true" ]]; then
  exit 0
fi

: "${FEEDPAPER_EMAIL_TO:?FEEDPAPER_EMAIL_TO must be set when FEEDPAPER_EMAIL_ENABLED=true}"
: "${FEEDPAPER_EMAIL_FROM:?FEEDPAPER_EMAIL_FROM must be set when FEEDPAPER_EMAIL_ENABLED=true}"
: "${FEEDPAPER_SMTP_HOST:?FEEDPAPER_SMTP_HOST must be set when FEEDPAPER_EMAIL_ENABLED=true}"

EPUB_PATH="$OUTPUT_DIR/feedpaper-$(date +%F).epub"

if [[ ! -f "$EPUB_PATH" ]]; then
  echo "No EPUB file was generated at $EPUB_PATH; skipping email delivery."
  exit 0
fi

python3 /usr/local/bin/send-feedpaper-email.py "$EPUB_PATH"
