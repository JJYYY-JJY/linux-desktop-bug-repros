#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  comment-existing)
    bugzilla --bugzilla https://bugzilla.mozilla.org \
      modify 776866 \
      --comment "$(cat "$(dirname "$0")/bugzilla-comment-776866.md")"
    ;;
  new-bug)
    bugzilla --bugzilla https://bugzilla.mozilla.org \
      new \
      --product Core \
      --component "Widget: Gtk" \
      --version "Firefox 151" \
      --os Linux \
      --arch x86_64 \
      --severity S3 \
      --field type=defect \
      --url "https://github.com/JJYYY-JJY/linux-desktop-bug-repros/tree/main/firefox-nautilus-double-open" \
      --summary "Linux: Show in Folder opens two Nautilus windows when FileManager1 ShowItems times out during Nautilus cold start" \
      --comment "$(sed '1,/^## Description$/d' "$(dirname "$0")/bugzilla-report.md")"
    ;;
  *)
    cat <<'USAGE'
Usage:
  ./submit-bugzilla.sh comment-existing
  ./submit-bugzilla.sh new-bug

Authentication:
  Run this first and paste a Mozilla Bugzilla API key when prompted:
    bugzilla --bugzilla https://bugzilla.mozilla.org login --api-key

Recommended first action:
  ./submit-bugzilla.sh comment-existing

Bug 776866 is already open and covers the broad "Open containing folder may
open the file manager multiple times" behavior. If maintainers ask for a
separate issue, use:
  ./submit-bugzilla.sh new-bug
USAGE
    exit 2
    ;;
esac
