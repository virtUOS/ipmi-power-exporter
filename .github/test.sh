#!/bin/bash
set -o errexit
set -o nounset

PASS=0
FAIL=0

assert_contains() {
    local description="$1" expected="$2" actual="$3"
    if echo "${actual}" | grep -qF "${expected}"; then
        echo "PASS: ${description}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${description}"
        echo "      expected to find: ${expected}"
        echo "      in: ${actual}"
        FAIL=$((FAIL + 1))
    fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

EXPECTED_HOST="$(cat /etc/hostname)"

MOCK_BIN="${TMPDIR}/bin"
mkdir -p "${MOCK_BIN}"
ln -s "${SCRIPT_DIR}/ipmitool-mock" "${MOCK_BIN}/ipmitool"
ln -s "${SCRIPT_DIR}/curl-mock"     "${MOCK_BIN}/curl"

cat > "${TMPDIR}/ipmi-power-exporter.conf" <<'EOF'
ACCESS_KEY="test-access-key"
SECRET_KEY="test-secret-key"
S3_ENDPOINT="s3.test.example.com"
BUCKET_NAME="test-bucket"
OBJECT_NAME="test/metrics"
EOF

export PATH="${MOCK_BIN}:${PATH}"
export CURL_CAPTURE_FILE="${TMPDIR}/captured-metrics"

# --- Test 1: happy path ---

(cd "${TMPDIR}" && "${REPO_DIR}/ipmi-power-exporter")

CAPTURED="$(cat "${CURL_CAPTURE_FILE}")"

assert_contains "instantaneous power metric present"  "power_watts{"                           "${CAPTURED}"
assert_contains "instantaneous power value 216"       "} 216"                                  "${CAPTURED}"
assert_contains "min power metric present"            "power_watts_min{"                        "${CAPTURED}"
assert_contains "min power value 212"                 "} 212"                                  "${CAPTURED}"
assert_contains "max power metric present"            "power_watts_max{"                        "${CAPTURED}"
assert_contains "max power value 246"                 "} 246"                                  "${CAPTURED}"
assert_contains "avg power metric present"            "power_watts_avg{"                        "${CAPTURED}"
assert_contains "avg power value 227"                 "} 227"                                  "${CAPTURED}"
assert_contains "manufacturer label"                  'manufacturer="FUJITSU"'                 "${CAPTURED}"
assert_contains "product label"                       'product="EXAMPLE SERVER X1"'            "${CAPTURED}"
assert_contains "host label"                          "host=\"${EXPECTED_HOST}\""              "${CAPTURED}"
assert_contains "updated metric present"              "updated{"                               "${CAPTURED}"

# --- Test 2: error on missing instantaneous power ---

cat > "${TMPDIR}/broken-dcmi.out" <<'EOF'
    Minimum during sampling period:                212 Watts
    Maximum during sampling period:                246 Watts
    Average power reading over sample period:      227 Watts
EOF

# Use a separate mock dir so we don't write through the symlink and clobber ipmitool-mock
MOCK_BIN2="${TMPDIR}/bin2"
mkdir -p "${MOCK_BIN2}"
cat > "${MOCK_BIN2}/ipmitool" <<EOF
#!/bin/bash
if [[ "\$1 \$2" == "fru print" ]]; then
    cat "${SCRIPT_DIR}/ipmitool-fru-print.out"
elif [[ "\$1 \$2 \$3" == "dcmi power reading" ]]; then
    cat "${TMPDIR}/broken-dcmi.out"
fi
EOF
chmod +x "${MOCK_BIN2}/ipmitool"
ln -s "${SCRIPT_DIR}/curl-mock" "${MOCK_BIN2}/curl"

ERROR_OUTPUT="$(
    PATH="${MOCK_BIN2}:${PATH}"
    CURL_CAPTURE_FILE="${TMPDIR}/captured-broken"
    cd "${TMPDIR}" && "${REPO_DIR}/ipmi-power-exporter" 2>&1
)" && EXIT_CODE=0 || EXIT_CODE=$?

if [[ "${EXIT_CODE}" -ne 0 ]]; then
    echo "PASS: script exits non-zero when instantaneous power is missing"
    PASS=$((PASS + 1))
else
    echo "FAIL: script should exit non-zero when instantaneous power is missing"
    FAIL=$((FAIL + 1))
fi

assert_contains "error message mentions failed power read" \
    "failed to read instantaneous power" "${ERROR_OUTPUT}"

# --- Test 3: shellcheck ---

if command -v shellcheck &>/dev/null; then
    shellcheck --severity=warning "${REPO_DIR}/ipmi-power-exporter" \
        && { echo "PASS: shellcheck"; PASS=$((PASS + 1)); } \
        || { echo "FAIL: shellcheck"; FAIL=$((FAIL + 1)); }
else
    echo "SKIP: shellcheck not installed"
fi

# --- Summary ---

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ "${FAIL}" -eq 0 ]]
