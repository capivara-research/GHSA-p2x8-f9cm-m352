#!/usr/bin/env bash
set -euo pipefail

repo="${1:-.}"
controller="$repo/plugins/Paypal/Controllers/PaypalController.php"
service="$repo/plugins/Paypal/Services/PaypalService.php"
orders="$repo/beike/Repositories/OrderRepo.php"
routes="$repo/plugins/Paypal/Routes/shop.php"

for source in "$controller" "$service" "$orders" "$routes"; do
  [[ -f "$source" ]] || { printf 'Missing source file: %s\n' "$source" >&2; exit 1; }
done

checks=(
  "$routes|Route::post('/capture'"
  "$controller|paypalOrderId"
  "$controller|capturePaymentOrder(\$paypalOrderId)"
  "$controller|OrderRepo::getOrderByNumber(\$orderNumber, \$customer)"
  "$service|return \$status === 'COMPLETED'"
  "$service|validateNvpDetails"
  "$service|PayPal payment amount does not match the order amount"
  "$service|PayPal payment currency does not match the order currency"
  "$orders|if (\$customerId)"
  "$orders|rand(10000, 99999)"
)

for check in "${checks[@]}"; do
  file=${check%%|*}
  needle=${check#*|}
  if grep -Fq "$needle" "$file"; then
    printf '[FOUND] %s :: %s\n' "${file#"$repo"/}" "$needle"
  else
    printf '[MISSING] %s :: %s\n' "${file#"$repo"/}" "$needle" >&2
    exit 1
  fi
done

printf '\nAffected source pattern confirmed. This checker does not modify the installation.\n'
