#!/usr/bin/env bash
set -euo pipefail

PROJECT="G Timer.xcodeproj"
SCHEME="G Timer"
CONFIGURATION="Release"
DERIVED_DATA="${DERIVED_DATA:-/tmp/gtimer-package-macos}"
OUTPUT_DIR="Dist"

mkdir -p "${OUTPUT_DIR}"

settings="$(
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "platform=macOS,arch=arm64,name=My Mac" \
    -derivedDataPath "${DERIVED_DATA}" \
    -showBuildSettings
)"

marketing_version="$(awk -F'= ' '/ MARKETING_VERSION = / { print $2; exit }' <<< "${settings}")"
build_number="$(awk -F'= ' '/ CURRENT_PROJECT_VERSION = / { print $2; exit }' <<< "${settings}")"
product_name="$(awk -F'= ' '/ FULL_PRODUCT_NAME = / { print $2; exit }' <<< "${settings}")"
built_products_dir="$(awk -F'= ' '/ BUILT_PRODUCTS_DIR = / { print $2; exit }' <<< "${settings}")"
bundle_identifier="$(awk -F'= ' '/ PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }' <<< "${settings}")"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "platform=macOS,arch=arm64,name=My Mac" \
  -derivedDataPath "${DERIVED_DATA}" \
  build

app_path="${built_products_dir}/${product_name}"
pkg_path="${OUTPUT_DIR}/gTimer-macOS-${marketing_version}-${build_number}-local.pkg"

if [[ ! -d "${app_path}" ]]; then
  echo "Built app was not found at ${app_path}" >&2
  exit 66
fi

xattr -cr "${app_path}"

COPYFILE_DISABLE=1 pkgbuild \
  --component "${app_path}" \
  --install-location "/Applications" \
  --identifier "${bundle_identifier}.pkg" \
  --version "${marketing_version}.${build_number}" \
  "${pkg_path}"

echo "Created ${pkg_path}"

if [[ -n "${GITHUB_REPOSITORY:-}" || -n "${DOWNLOAD_BASE_URL:-}" ]]; then
  Scripts/write-github-release-metadata.sh
else
  echo "Skipped GitHub release metadata. Set GITHUB_REPOSITORY=owner/repo or DOWNLOAD_BASE_URL=... to generate it."
fi
