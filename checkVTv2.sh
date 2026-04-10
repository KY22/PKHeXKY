#!/usr/bin/env bash
# VirusTotal Large File Uploader (>32MB) - Linux Edition
# Fixed Target: ./Build/PKHeX.exe
# Fixed Key File: ./.cred/vt_api_key.txt
# API Version: v3
# Requires: curl, jq

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
FILE_PATH="./Build/PKHeX.exe"
KEY_FILE="./.cred/vt_api_key.txt"
VT_API_BASE="https://www.virustotal.com/api/v3"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
check_dependency() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: '$1' is required but not installed. Aborting."
        exit 1
    }
}

get_file_size() {
    stat -c%s "$1"
}

parse_vt_error() {
    local response="$1"
    local error_msg
    error_msg=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    if [[ -n "$error_msg" ]]; then
        echo "❌ VirusTotal API Error: $error_msg"
        exit 1
    fi
}

load_api_key() {
    if [[ ! -f "$KEY_FILE" ]]; then
        echo "❌ Error: API key file '$KEY_FILE' not found."
        exit 1
    fi
    API_KEY=$(tr -d '[:space:]' <"$KEY_FILE")
    if [[ -z "$API_KEY" ]]; then
        echo "❌ Error: API key file '$KEY_FILE' is empty."
        exit 1
    fi
}

print_report() {
    local analysis_id="$1"
    echo "📊 Fetching analysis report for ID: $analysis_id..."
    local report_response
    report_response=$(curl -s --max-time 30 \
        -X GET "${VT_API_BASE}/analyses/${analysis_id}" \
        -H "x-apikey: ${API_KEY}")

    parse_vt_error "$report_response"

    local status
    status=$(echo "$report_response" | jq -r '.data.attributes.status // "unknown"')
    if [[ "$status" != "completed" ]]; then
        echo "⚠️  Analysis status: '$status'. Results may be partial or still processing."
    fi

    local malicious suspicious undetected harmless
    malicious=$(echo "$report_response" | jq -r '.data.attributes.stats.malicious // 0')
    suspicious=$(echo "$report_response" | jq -r '.data.attributes.stats.suspicious // 0')
    undetected=$(echo "$report_response" | jq -r '.data.attributes.stats.undetected // 0')
    harmless=$(echo "$report_response" | jq -r '.data.attributes.stats.harmless // 0')

    echo ""
    echo "📈 VirusTotal Scan Summary:"
    echo "   🔴 Malicious:  $malicious"
    echo "   🟠 Suspicious: $suspicious"
    echo "   🟢 Undetected: $undetected"
    echo "   🔵 Harmless:   $harmless"

    if [[ "$malicious" -gt 0 || "$suspicious" -gt 0 ]]; then
        echo ""
        echo "🚨 Engines that flagged this file:"
        echo "$report_response" | jq -r '.data.attributes.results | to_entries[]? | select(.value.category == "malicious" or .value.category == "suspicious") | "   • \(.key): \(.value.result // "N/A")"'
    fi

    echo ""
    echo "🌐 Full interactive report: https://www.virustotal.com/gui/analysis/$analysis_id"
}

# -----------------------------------------------------------------------------
# Dependency & Mode Parsing
# -----------------------------------------------------------------------------
check_dependency curl
check_dependency jq

if [[ $# -eq 0 ]]; then
    MODE="upload"
elif [[ "$1" == "--check" || "$1" == "-c" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "❌ Error: --check requires an Analysis ID."
        echo "Usage: $0 --check <analysis_id>"
        exit 1
    fi
    MODE="check"
    ANALYSIS_ID="$2"
else
    echo "Usage: $0"
    echo "       Uploads: $FILE_PATH using key from $KEY_FILE"
    echo ""
    echo "       Check a previous report:"
    echo "       $0 --check <analysis_id>"
    exit 0
fi

load_api_key

# -----------------------------------------------------------------------------
# Upload Mode
# -----------------------------------------------------------------------------
if [[ "$MODE" == "upload" ]]; then
    if [[ ! -f "$FILE_PATH" ]]; then
        echo "❌ Error: Target file '$FILE_PATH' not found."
        exit 1
    fi

    FILE_SIZE=$(get_file_size "$FILE_PATH")
    FILE_SIZE_MB=$((FILE_SIZE / 1048576))
    VT_LIMIT=33554432

    echo "📁 File: $FILE_PATH"
    echo "📏 Size: ${FILE_SIZE_MB} MB"
    if [[ $FILE_SIZE -le $VT_LIMIT ]]; then
        echo "⚠️  Note: File is ≤32MB. Using large-file workflow (compatible with all sizes)."
    else
        echo "🚀 File exceeds 32MB. Using VirusTotal upload URL endpoint..."
    fi

    echo "[1/2] Requesting upload URL..."
    UPLOAD_RESPONSE=$(curl -s --max-time 30 \
        -X GET "${VT_API_BASE}/files/upload_url" \
        -H "x-apikey: ${API_KEY}")
    parse_vt_error "$UPLOAD_RESPONSE"

    UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.data // empty')
    if [[ -z "$UPLOAD_URL" || "$UPLOAD_URL" == "null" ]]; then
        echo "❌ Error: Failed to retrieve upload URL."
        exit 1
    fi

    echo "[2/2] Uploading to VirusTotal..."
    UPLOAD_RESULT=$(curl -s --max-time 600 -# \
        -X POST "$UPLOAD_URL" \
        -H "x-apikey: ${API_KEY}" \
        -F "file=@${FILE_PATH}")
    parse_vt_error "$UPLOAD_RESULT"

    ANALYSIS_ID=$(echo "$UPLOAD_RESULT" | jq -r '.data.id // empty')
    if [[ -z "$ANALYSIS_ID" ]]; then
        echo "❌ Upload failed."
        exit 1
    fi

    echo ""
    echo "✅ Upload successful!"
    echo "🆔 Analysis ID: $ANALYSIS_ID"
    echo ""
    echo "📝 To view the report later, run:"
    echo "   $0 --check $ANALYSIS_ID"
    echo ""
    echo "🌐 Or view online: https://www.virustotal.com/gui/analysis/$ANALYSIS_ID"

# -----------------------------------------------------------------------------
# Check Mode
# -----------------------------------------------------------------------------
elif [[ "$MODE" == "check" ]]; then
    print_report "$ANALYSIS_ID"
fi
