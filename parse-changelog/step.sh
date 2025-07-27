#!/bin/bash
set -ex

# Use the input environment variable from step.yml
# or a default value.
CHANGELOG_FILE_PATH="${changelog_file:-CHANGELOG.md}"

if [ ! -f "$CHANGELOG_FILE_PATH" ]; then
  echo "Changelog file not found at path: $CHANGELOG_FILE_PATH"
  exit 1
fi

# Convert UNIX timestamp to YYYY-MM-DD (UTC)
TARGET_DATE=$(date -u -d @"$BITRISE_BUILD_TRIGGER_TIMESTAMP" +%Y-%m-%d)

CHANGELOG_CONTENT=$(awk -v target_date="$TARGET_DATE" '
  function trim(str) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", str)
      gsub(/"/, "", str)
      return str
  }

  BEGIN {
      current_type = ""
      capture_changes = 0
      split("", seen_entries)
      current_version = ""
  }

  /^## \[.*\]/ {
      split($0, parts, " - ")
      current_date = trim(parts[2])

      if (target_date == "" || current_date == target_date) {
          capture_changes = 1
      } else {
          if (capture_changes == 1) {
            exit
          }
      }
  }

  capture_changes == 1 {
      if (/^### /) {
          current_type = trim($2)
      } else if (!/^## \[.*\]/ && NF > 0) {
          line = trim($0)
          if (line != "" && !(line in seen_entries)) {
              if (!(current_type in changes)) {
                  changes[current_type] = ""
              }
              changes[current_type] = changes[current_type] "- " line "\n"
              seen_entries[line] = 1
          }
      }
  }

  END {
      for (type in changes) {
          if (changes[type] != "") {
              print "### " type
              printf "%s", changes[type]
          }
      }
  }
' "$CHANGELOG_FILE_PATH")

if [ -n "$CHANGELOG_CONTENT" ]; then
  echo "$CHANGELOG_CONTENT"
  envman add --key CHANGELOG --value "$CHANGELOG_CONTENT"
else
  echo "No new changes found in the changelog file for date $TARGET_DATE"
  envman add --key CHANGELOG --value "No changes found for date $TARGET_DATE"
fi