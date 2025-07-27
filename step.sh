#!/bin/bash
set -ex

# Use the input environment variable from step.yml
# or a default value.
TEAMS_WEBHOOK_URL="${teams_webhook_url}"
APP_NAME="${app_name:-MyApp}"
APP_LOGO_URL="${app_logo_url}"
NOTIFICATION_ICON_URL="${notification_icon_url}"
NOTIFICATION_ENVIRONMENT_URL="${notification_environment_url}"
CHANGELOG_PATH="${changelog_path:-CHANGELOG.md}"
CHANGELOG="${changelog}"

if [ -z "$TEAMS_WEBHOOK_URL" ]; then
  echo "Error: Teams webhook URL is not set."
  exit 1
fi

# Map status code to string
if [ "$BITRISE_BUILD_STATUS" -eq 0 ]; then
  BUILD_STATUS_STRING="Succeeded"
else
  BUILD_STATUS_STRING="Failed"
fi

if [ "$BUILD_STATUS_STRING" == "Succeeded" ]; then
  repo_path=$(echo "$GIT_REPOSITORY_URL" | sed 's|git@ssh.dev.azure.com:v3/||')
  ORG_NAME=$(echo "$repo_path" | cut -d'/' -f1)
  PROJECT_NAME=$(echo "$repo_path" | cut -d'/' -f2)
  REPO_NAME=$(echo "$repo_path" | cut -d'/' -f3)

  changelog_link="https://dev.azure.com/${ORG_NAME}/${PROJECT_NAME}/_git/${REPO_NAME}?path=/${CHANGELOG_PATH}&version=GB${BITRISE_GIT_BRANCH}&_a=contents"
else
  changelog_link=""
fi

if [ -z "$APP_LOGO_URL" ]; then
  app_logo_url="$NOTIFICATION_ICON_URL"
else
  app_logo_url="$APP_LOGO_URL"
fi

temp_json=$(mktemp)

cat <<EOF > "$temp_json"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "0076D7",
    "summary": "$APP_NAME Build $BUILD_STATUS_STRING",
    "sections": [{
        "activityTitle": "$APP_NAME Build $BUILD_STATUS_STRING",
        "activitySubtitle": "On branch $BITRISE_GIT_BRANCH",
        "activityImage": "$app_logo_url",
        "facts": [
            {
                "name": "Build Version",
                "value": "$BITRISE_BUILD_NUMBER"
            },
            {
                "name": "Initiated By",
                "value": "$BITRISE_BUILD_USER"
            },
            {
                "name": "Platform",
                "value": "$BITRISE_APP_TITLE"
            }
        ],
        "markdown": true
    }, {
        "title": "Changelog",
        "text": "$CHANGELOG"
    }],
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "View Build",
            "targets": [
                { "os": "default", "uri": "$BITRISE_BUILD_URL" }
            ]
        },
        {
            "@type": "OpenUri",
            "name": "View Changelog",
            "targets": [
                { "os": "default", "uri": "$changelog_link" }
            ]
        }
    ]
}
EOF

cat "$temp_json"

curl --location --request POST "$TEAMS_WEBHOOK_URL" \
--header 'Content-Type: application/json' \
--data-binary @"$temp_json"

rm "$temp_json"