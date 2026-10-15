# Proof of concept

This PoC demonstrates the PayPal REST transaction-to-order binding failure in BeikeShop `v2.0.0.31` (`f41f390`). Use only against a local installation configured with PayPal Sandbox credentials and test accounts.

## Preconditions

- BeikeShop `v2.0.0.31` with the PayPal plugin in REST mode.
- Two local orders with different totals:
  - a cheap attacker-controlled order that will be paid through PayPal Sandbox;
  - a higher-value target order that remains unpaid.
- A genuine PayPal Sandbox order ID obtained by approving the cheap order.
- If the installation enforces Laravel CSRF protection, the session cookie and decoded XSRF token from the same checkout session.

Do not use real merchant credentials or third-party orders. The request changes local order state.

## Reproduction

1. Start checkout for the cheap local order through the normal UI.
2. Approve its low-value payment in PayPal Sandbox. Record the resulting PayPal order ID.
3. Before capturing it for the cheap local order, execute `poc.sh` with the PayPal ID but the local number of the higher-value target order:

```bash
BASE_URL='http://127.0.0.1:8000' \
PAYPAL_ORDER_ID='PAYPAL-SANDBOX-ORDER-ID-FOR-CHEAP-ORDER' \
TARGET_ORDER_NUMBER='TARGET-EXPENSIVE-LOCAL-ORDER-NUMBER' \
COOKIE='XSRF-TOKEN=...; beikeshop_session=...' \
XSRF_TOKEN='decoded-xsrf-token' \
bash ./poc.sh
```

4. Inspect the target order in the local database or administration panel.

## Vulnerable result

PayPal captures the genuine cheap Sandbox transaction and returns `COMPLETED`. BeikeShop applies that status to `TARGET_ORDER_NUMBER` and changes the unrelated target order to `PAID`, despite the captured amount belonging to a different local order.

The vulnerable REST branch does not compare:

- captured amount against the target order total;
- captured currency against the store/order currency;
- PayPal invoice or custom metadata against the local order number;
- the submitted PayPal order ID against a server-side binding created for the local order.

For a guest request, `OrderRepo::getOrderByNumber()` also omits the `customer_id` filter, so possession of the plaintext order number is treated as sufficient authority.

## Expected secure result

The server must reject the request before changing local order state because the PayPal transaction does not belong to the supplied local order and its amount does not equal the authoritative target total.

## Source-level verification

Run the accompanying checker against a checkout of the affected revision:

```bash
git clone https://github.com/beikeshop/beikeshop.git
git -C beikeshop checkout f41f390
bash ./verify-source.sh ./beikeshop
```

The checker is non-invasive. It identifies the unauthenticated routes, attacker-controlled request fields, guest lookup behavior, status-only success check and the amount/currency validation that exists only in the sibling NVP flow.

## Validation scope

The report was established through source review. The researchers did not move real funds or test a third-party production shop. This script is supplied to let the vendor or VulDB reproduce the chain safely with their own local installation and PayPal Sandbox account.
