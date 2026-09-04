#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: Scripts/bump-beta-build.sh <build-number> [marketing-version]" >&2
  exit 64
fi

build_number="$1"
marketing_version="${2:-0.9.0}"

if ! [[ "$build_number" =~ ^[0-9]+$ ]]; then
  echo "Build number must be an integer." >&2
  exit 64
fi

perl -pi -e "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\${1}${build_number};/g; s/(MARKETING_VERSION = )[0-9]+(\\.[0-9]+)*;/\${1}${marketing_version};/g" "G Timer.xcodeproj/project.pbxproj"
perl -pi -e "s/(\"CURRENT_PROJECT_VERSION\": \")[^\"]+\"/\${1}${build_number}\"/g; s/(\"MARKETING_VERSION\": \")[^\"]+\"/\${1}${marketing_version}\"/g" Project.json

echo "Set gTimer version ${marketing_version} (${build_number})."
