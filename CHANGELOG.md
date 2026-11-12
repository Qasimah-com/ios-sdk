# Changelog

All notable changes to `QasimhaCheckout` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this package
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-25

### Added

- `QasimhaCheckout.start(from:options:completion:)` presenting the hosted checkout in
  `SFSafariViewController` (default), `ASWebAuthenticationSession` with a callback scheme, or an
  opt-in hardened `WKWebView` (non-persistent data store, empty user-content controller, host
  allow-list, TLS and HTTP-auth challenges never overridden, no script bridges).
- `QasimhaCheckout.handleReturn(url:)` for Universal Links and custom-scheme returns delivered to
  the app; closes the presentation and completes with the parsed result.
- `CheckoutResult` (`success`, `failure(status:)`, `cancelled`) parsed from the return URL per the
  merchant return-URL contract: prefix match on scheme, host and path against the three merchant
  URLs; `orderId`, `orderReferenceId` and `status` read from the query; success only on
  `status=confirmed` with an order id, everything unverifiable reported as a failure.
- `CheckoutOptions` validation mirroring the server rules for merchant URLs (absolute, at most
  1024 characters, no fragment, `https` or a custom scheme, `http` for local development only) and
  `?lang=` propagation of the checkout language.
- `QasimhaPromoView` fed by `GET /api/v1/widget/plans` with the publishable key, rendering the
  headline plan with the riyal symbol drawn from its vector path to the left of the number, and
  rendering nothing on any failure.
- Privacy manifest declaring no tracking and no data collection; Swift Package Manager and
  CocoaPods packaging; iOS 14, Swift 5.9, no dependencies.
