#!/usr/bin/env bash
#
# fetch_models.sh — downloads ML models declared in models.json from truora/model-registry.
#
# Reads ios/validations/TruoraCamera/Resources/models.json (relative to this script's location),
# fetches each model's .dvc pointer from the model-registry repo over SSH, and downloads
# the binary from S3. Idempotent: if the local file's md5 matches the .dvc, skips download.
#
# Best-effort by default: if SSH/AWS pre-flight fails or a download errors, warns and exits
# successfully so the surrounding `mise run generate` can continue with the .tflite already
# tracked in git. The runtime SDK falls back to manual capture if the model is unusable.
# Set FETCH_MODELS_STRICT=1 to fail-fast instead (intended for CI release pipelines).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # ios/validations
MODELS_JSON="$REPO_DIR/TruoraCamera/Resources/models.json"
REGISTRY_REMOTE_BASE="ssh://git@bitbucket.org/truora"
STRICT="${FETCH_MODELS_STRICT:-0}"

log()  { printf '[fetch_models] %s\n' "$*"; }
warn() { printf '[fetch_models] WARN: %s\n' "$*" >&2; }
fail() { printf '[fetch_models] ERROR: %s\n' "$*" >&2; exit 1; }

# soft_fail: in strict mode, hard-fail. Otherwise warn + exit 0 so the calling
# `mise run generate` chain proceeds and `tuist generate` uses whatever .tflite
# is already on disk (always present since the binary is tracked in git).
soft_fail() {
  if [[ "$STRICT" == "1" ]]; then
    fail "$*"
  fi
  warn "$*"
  warn "Skipping model fetch — tuist generate will use whatever .tflite is currently on disk."
  exit 0
}

# soft_skip: in strict mode, hard-fail. Otherwise warn and let the for-loop
# advance to the next model entry. Atomic move guarantees the existing .tflite
# is never replaced by a partial download.
soft_skip() {
  if [[ "$STRICT" == "1" ]]; then
    fail "$*"
  fi
  warn "$*"
  warn "Skipping this model — keeping whatever's currently on disk for it."
}

# ----- Pre-flight: bitbucket SSH -----
log "Verifying SSH access to bitbucket.org/truora/model-registry…"
if ! git ls-remote "${REGISTRY_REMOTE_BASE}/model-registry.git" HEAD >/dev/null 2>&1; then
  soft_fail "Cannot reach ${REGISTRY_REMOTE_BASE}/model-registry.git. Ensure your bitbucket SSH key is configured."
fi

# ----- Pre-flight: AWS credentials -----
log "Verifying AWS credentials…"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  soft_fail "AWS credentials not available. Run 'aws sso login' (or set AWS_PROFILE) and ensure you have S3 read access on truora-model-registry. If you don't have access yet, request it from your DevOps channel."
fi

# ----- Locate and parse models.json -----
# Config errors are real repo bugs (not transient), so always hard-fail here.
[[ -f "$MODELS_JSON" ]] || fail "models.json not found at $MODELS_JSON"

# Use python3 for safe JSON parse.
# Note: avoid `mapfile`/`readarray` — bash 3.2 (default on macOS) lacks them.
MODELS=()
while IFS= read -r line; do
  MODELS+=("$line")
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
for m in cfg["models"]:
    print("\t".join([m["repository"], m["repository_path"], m["local_path"], m["bucket"]]))
' "$MODELS_JSON")

if [[ ${#MODELS[@]} -eq 0 ]]; then
  log "No models declared in $MODELS_JSON; nothing to do."
  exit 0
fi

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

for entry in "${MODELS[@]}"; do
  IFS=$'\t' read -r repository repository_path local_path bucket <<< "$entry"

  log "Processing model: $repository_path"

  dvc_file_path="${repository_path}.dvc"
  dvc_local="$TMPDIR_BASE/$(basename "$dvc_file_path")"
  registry_url="${REGISTRY_REMOTE_BASE}/${repository}.git"

  # ----- Fetch .dvc pointer via git archive -----
  if ! git archive --remote="$registry_url" master "$dvc_file_path" 2>/dev/null | tar -xO > "$dvc_local"; then
    soft_skip "Failed to fetch $dvc_file_path from $registry_url"
    continue
  fi
  if [[ ! -s "$dvc_local" ]]; then
    soft_skip "Empty .dvc fetched for $dvc_file_path; verify the path exists in ${repository}:master"
    continue
  fi

  # ----- Parse md5 and hash from .dvc YAML -----
  # The .dvc fetched from registry master IS the integrity source of truth:
  # this md5 is what we verify the downloaded S3 artifact against below.
  # We deliberately do not duplicate the checksum into models.json — the
  # registry owns it, and every fetch resolves the current value.
  expected_md5=$(awk '$1 == "-" && $2 == "md5:" { print $3 }' "$dvc_local")
  hash_type=$(awk '$1 == "hash:" { print $2 }' "$dvc_local")

  if [[ -z "$expected_md5" || -z "$hash_type" ]]; then
    soft_skip "Could not parse md5/hash from $dvc_file_path"
    continue
  fi

  # ----- Cache check: skip if local file already matches -----
  dest_path="$(dirname "$MODELS_JSON")/$local_path"
  if [[ -f "$dest_path" ]]; then
    actual_md5=$(md5 -q "$dest_path")
    if [[ "$actual_md5" == "$expected_md5" ]]; then
      log "✓ $local_path up-to-date (md5 $expected_md5)"
      continue
    fi
    log "$local_path md5 differs (local=$actual_md5 expected=$expected_md5); re-downloading"
  fi

  # ----- Download from S3 -----
  s3_key="files/${hash_type}/${expected_md5:0:2}/${expected_md5:2}"
  s3_url="s3://${bucket}/${s3_key}"

  tmp_dest="$TMPDIR_BASE/$(basename "$local_path").partial"
  log "Downloading $s3_url"
  if ! aws s3 cp "$s3_url" "$tmp_dest" >/dev/null; then
    soft_skip "Failed to download $s3_url. Check S3 read access on bucket: $bucket."
    continue
  fi

  # ----- Verify md5 of downloaded artifact -----
  downloaded_md5=$(md5 -q "$tmp_dest")
  if [[ "$downloaded_md5" != "$expected_md5" ]]; then
    soft_skip "md5 mismatch after download (got $downloaded_md5, expected $expected_md5)"
    continue
  fi

  # ----- Atomic move into final destination -----
  mkdir -p "$(dirname "$dest_path")"
  mv "$tmp_dest" "$dest_path"
  log "✓ $local_path downloaded ($(stat -f%z "$dest_path") bytes, md5 $expected_md5)"
done

log "Done."
