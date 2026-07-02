#!/bin/bash
# verify-ios-creds.sh
# Run this from /Users/sal/CODE/Termix/Mobile

set -e

CERTS_DIR="certs"
P12="$CERTS_DIR/FP_Distribution.p12"
PROFILE="$CERTS_DIR/TermixD.mobileprovision"

echo "=== Checking credential files exist ==="
if [ ! -f "$P12" ]; then echo "ERROR: $P12 not found"; exit 1; fi
if [ ! -f "$PROFILE" ]; then echo "ERROR: $PROFILE not found"; exit 1; fi
echo "✓ Both files exist"
echo ""

echo "=== Decoding provisioning profile ==="
TMP_PLIST="/tmp/termixd_profile.plist"
security cms -D -i "$PROFILE" 2>/dev/null > "$TMP_PLIST"

echo "--- Bundle ID ---"
plutil -extract application-identifier raw "$TMP_PLIST" 2>/dev/null || true
echo ""

echo "--- Profile Type Checks ---"
# App Store profiles should have ProvisionsAllDevices = true
if plutil -extract ProvisionsAllDevices raw "$TMP_PLIST" 2>/dev/null | grep -q "1"; then
  echo "✓ ProvisionsAllDevices = true (App Store profile)"
else
  echo "⚠ ProvisionsAllDevices is NOT true or missing"
  echo "  This profile may NOT be an App Store profile."
  echo "  In Apple Developer Portal, recreate it as: iOS App Store"
fi

# Ad Hoc profiles have ProvisionedDevices
if plutil -extract ProvisionedDevices xml1 "$TMP_PLIST" 2>/dev/null | grep -q "string"; then
  echo "⚠ This profile has ProvisionedDevices (Ad Hoc or Development, NOT App Store)"
fi

# Development profiles have get-task-allow = 1
if plutil -extract get-task-allow raw "$TMP_PLIST" 2>/dev/null | grep -q "1"; then
  echo "⚠ get-task-allow = 1 (Development profile, NOT App Store)"
else
  echo "✓ get-task-allow = 0 (Distribution profile)"
fi
echo ""

echo "=== Extracting certificate fingerprint from provisioning profile ==="
TMP_CERT="/tmp/cert_from_profile.cer"
plutil -extract DeveloperCertificates.0 raw "$TMP_PLIST" 2>/dev/null | base64 -D > "$TMP_CERT"
PROFILE_FP=$(openssl x509 -in "$TMP_CERT" -inform DER -noout -fingerprint -sha1 2>/dev/null)
echo "$PROFILE_FP"
echo ""

echo "=== Extracting certificate fingerprint from .p12 ==="
echo "Enter your .p12 export password:"
read -s P12_PASS
TMP_P12_CERT="/tmp/cert_from_p12.pem"
if openssl pkcs12 -in "$P12" -nokeys -out "$TMP_P12_CERT" -password pass:"$P12_PASS" 2>/dev/null; then
  P12_FP=$(openssl x509 -in "$TMP_P12_CERT" -noout -fingerprint -sha1 2>/dev/null)
  echo "$P12_FP"
  echo ""
  echo "=== COMPARISON ==="
  if [ "$PROFILE_FP" = "$P12_FP" ]; then
    echo "✓ Fingerprints MATCH — credentials are consistent"
  else
    echo "✗ Fingerprints DO NOT MATCH"
    echo "  The provisioning profile was created with a DIFFERENT certificate."
    echo "  Delete the profile in Apple Developer Portal and recreate it,"
    echo "  making sure to select the certificate that matches FP_Distribution.p12"
  fi
else
  echo "✗ Could not read .p12 — password may be wrong or file is corrupt"
fi
echo ""

rm -f "$TMP_PLIST" "$TMP_CERT" "$TMP_P12_CERT"
