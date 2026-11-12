# QasimhaCheckout example app

New to Qasimha? Start with [Getting started](../../../docs/getting-started.md).

A minimal SwiftUI app that creates a checkout session through a small merchant server, presents
it with `QasimhaCheckout`, receives the return on a custom scheme and confirms the order with the
merchant server before showing "paid". It embeds no secret key: only the sandbox publishable key
placeholder in `QasimhaExample/ExampleConfig.swift`.

## Generate the project

The Xcode project is generated, not checked in.

```
brew install xcodegen
cd Example
xcodegen generate
open QasimhaExample.xcodeproj
```

Requirements: Xcode 16 or later, an iOS 14+ simulator or device. The generated `Info.plist`
registers the `qasimhaexample://` URL scheme and allows local networking for the merchant server.
`project.yml` adds the package as a local Swift package (`path: ..`), the same way an app adds
it from a copy of the repository.

## Merchant server

The app expects a small merchant server on `http://localhost:4311` (`ExampleConfig.merchantServer`).
You run it: it holds the secret key, uses a Qasimha server SDK and exposes:

| Method and path | Body / response |
|---|---|
| `POST /sessions` | request `{ amount, orderReferenceId, merchantUrl: { success, failure, cancel } }`; response `{ orderId, paymentUrl }` from `checkout.createSession` |
| `GET /orders/{orderId}` | response `{ orderId, status, orderReferenceId }` from `orders.get` |

Give it your sandbox secret key (`sk_test_…`); sessions are then created in the sandbox. The
demo merchant backends under `sdks/<language>/examples/` expose a different API (port 4300,
`POST /api/checkout`), so they do not serve this app as they are. Key and environment rules:
[Configuration](../../../docs/configuration.md).

## Flow

1. Enter an amount; the promo view under it calls the plans endpoint with the placeholder key and
   renders nothing until you replace `pk_test_example` with your sandbox publishable key.
2. Tap "Pay with Qasimha". The app posts to the merchant server, receives `paymentUrl` and calls
   `QasimhaCheckout.start`.
3. Complete or cancel the checkout. The hosted page redirects to
   `qasimhaexample://checkout/return?orderId=…&status=…`; iOS opens the app, `onOpenURL` calls
   `QasimhaCheckout.handleReturn`, the sheet closes and the completion runs.
4. On `.success` the app calls `GET /orders/{orderId}` and shows the status the server reports.
   The return URL alone is never treated as proof of payment.

The presentation picker switches between `SFSafariViewController`, `ASWebAuthenticationSession`
(callback scheme `qasimhaexample`) and the hardened `WKWebView`.
