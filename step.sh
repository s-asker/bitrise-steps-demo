#!/bin/bash
set -e
APP_NAME="${APP_NAME:-MyApp}"
CHANGELOG_PATH="${CHANGELOG_PATH:-CHANGELOG.md}"
BUILD_VERSION="${BUILD_VERSION:-1.0.0}"
# Use the tag from Azure DevOps pipeline
BUILD_TAG="${TAG_FROM_AZURE:-Unknown}"
# Map status code to string
if [ "$BITRISE_BUILD_STATUS" -eq 0 ]; then
  BUILD_STATUS_STRING="Succeeded"
else
  BUILD_STATUS_STRING="Failed"
fi
echo "Changelog: $CHANGELOG"
echo "Build Version: $BUILD_VERSION"
echo "Build Tag: $BUILD_TAG"
echo "Build Status: $BUILD_STATUS_STRING"
echo "Platform: $PLATFORM"
echo "App Name: $APP_NAME"
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
echo "Sending The Following JSON:"
cat <<EOF > "$temp_json"
{
    "team_id": "$TEAMS_GROUP_ID",
    "channel_id": "$TEAMS_CHANNEL_ID",
    "platform": "$PLATFORM",
    "app_name": "$APP_NAME",
    "app_logo": "$app_logo_url",
    "app_link": "$NOTIFICATION_ENVIRONMENT_URL",
    "build_status": "$BUILD_STATUS_STRING",
    "build_environment": "$BITRISE_GIT_BRANCH",
    "build_initiator": "$GIT_CLONE_COMMIT_AUTHOR_NAME",
    "build_version": "$BUILD_TAG",
    "build_link": "$BITRISE_BUILD_URL",
    "changelog": "$CHANGELOG",
    "changelog_link": "$changelog_link",
    "utc_offset": "3"
}
EOF
cat "$temp_json"
curl --location 'https://prod-53.westeurope.logic.azure.com:443/workflows/7b4dc98705d54289af87d4d99bb91439/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=Fp1nUBmNZkVwAKD2yKJhjGNozRbIOpvr_7jutwK8VKg' \
  --header 'Content-Type: application/json' \
  --data-binary @"$temp_json"
rm "$temp_json"
echo "Teams notification sent successfully!"