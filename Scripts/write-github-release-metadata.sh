#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-G Timer.xcodeproj}"
SCHEME="${SCHEME:-G Timer}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64,name=My Mac}"
OUTPUT_DIR="${OUTPUT_DIR:-Dist}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/gtimer-package-macos}"

mkdir -p "${OUTPUT_DIR}"

settings="$(
  xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "${DESTINATION}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -showBuildSettings
)"

marketing_version="$(awk -F'= ' '/ MARKETING_VERSION = / { print $2; exit }' <<< "${settings}")"
build_number="$(awk -F'= ' '/ CURRENT_PROJECT_VERSION = / { print $2; exit }' <<< "${settings}")"
pkg_name="gTimer-macOS-${marketing_version}-${build_number}-local.pkg"
pkg_path="${OUTPUT_DIR}/${pkg_name}"

if [[ ! -f "${pkg_path}" ]]; then
  echo "Installer not found at ${pkg_path}. Run Scripts/package-macos-installer.sh first." >&2
  exit 66
fi

github_repository="${GITHUB_REPOSITORY:-}"
if [[ -z "${github_repository}" ]]; then
  remote_url="$(git config --get remote.github.url || git config --get remote.origin.url || true)"
  if [[ "${remote_url}" == *github.com* ]]; then
    github_repository="$(sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##' <<< "${remote_url}")"
  fi
fi

release_tag="${RELEASE_TAG:-v${marketing_version}}"
download_base_url="${DOWNLOAD_BASE_URL:-}"
if [[ -z "${download_base_url}" ]]; then
  if [[ -z "${github_repository}" ]]; then
    echo "Set GITHUB_REPOSITORY=owner/repo or DOWNLOAD_BASE_URL=https://github.com/owner/repo/releases/download/${release_tag}." >&2
    exit 64
  fi
  download_base_url="https://github.com/${github_repository}/releases/download/${release_tag}"
fi

release_notes_url="${RELEASE_NOTES_URL:-}"
if [[ -z "${release_notes_url}" ]]; then
  if [[ -n "${github_repository}" ]]; then
    release_notes_url="https://github.com/${github_repository}/releases/tag/${release_tag}"
  else
    release_notes_url="${download_base_url}"
  fi
fi

sha256="$(shasum -a 256 "${pkg_path}" | awk '{ print $1 }')"
sha_path="${OUTPUT_DIR}/${pkg_name}.sha256.txt"
metadata_path="${OUTPUT_DIR}/latest-gTimer.json"

printf '%s  %s\n' "${sha256}" "${pkg_name}" > "${sha_path}"

cat > "${metadata_path}" <<JSON
{
  "app": "gTimer",
  "platform": "macOS",
  "version": "${marketing_version}",
  "build": ${build_number},
  "minimum_os": "14.0",
  "published_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": "A newer gTimer build is available to download.",
  "download_url": "${download_base_url}/${pkg_name}",
  "sha256": "${sha256}",
  "sha256_url": "${download_base_url}/${pkg_name}.sha256.txt",
  "release_notes_url": "${release_notes_url}",
  "changes": {
    "new_features": [
      "GitHub-based update alerts can now notify users when a newer build is available."
    ],
    "minor_improvements": [
      "Release metadata and installer checksums are generated in a consistent format for future downloads."
    ],
    "bug_fixes": []
  }
}
JSON

echo "Wrote ${metadata_path}"
echo "Wrote ${sha_path}"
