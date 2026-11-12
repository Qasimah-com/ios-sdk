# QasimhaCheckout for iOS

New to Qasimha? Start with [Getting started](../../docs/getting-started.md).

The library a merchant app embeds to accept Qasimha. Your server creates the checkout session
with a Qasimha server SDK and hands the app the `paymentUrl`; this package presents it, watches
for the return to your app and reports success, failure or cancellation. It holds no secret key,
stores nothing on the device, sends no analytics and has no third-party dependencies.

- iOS 14+, Swift 5.9+, Swift Package Manager and CocoaPods.
- Default presentation is the system browser sheet (`SFSafariViewController`);
  `ASWebAuthenticationSession` and a hardened `WKWebView` are available.
- Optional `QasimhaPromoView` ("split into 4 monthly payments of [symbol] 300") fed by the plans
  endpoint with your publishable key.

## Install

Version 0.1.0 is not yet published to CocoaPods or as a Swift package release. Add it from the
integrations repository that Qasimha shared with you; the package is in `mobile/ios` (it contains
both `Package.swift` and `QasimhaCheckout.podspec`). See
[Installation](../../docs/installation.md) for every package.

Swift Package Manager resolves a git URL only when `Package.swift` is at the repository root, so
use a local copy of the repository with either method below.

### Swift Package Manager (local package)

In Xcode: File ▸ Add Package Dependencies… ▸ Add Local…, choose the `mobile/ios` folder of your
copy of the repository, and add the `QasimhaCheckout` library to your app target.

In a `Package.swift` of your own, the path is relative to that file and the package name is the
folder name, `ios`:

```swift
dependencies: [
    .package(path: "../integrations-repository/mobile/ios"),
],
targets: [
    .target(name: "MyApp", dependencies: [.product(name: "QasimhaCheckout", package: "ios")]),
]
```

### CocoaPods (local pod)

In your `Podfile`, with the path relative to the `Podfile`:

```ruby
pod 'QasimhaCheckout', :path => '../integrations-repository/mobile/ios'
```

Then run `pod install`.

### Once published

```ruby
pod 'QasimhaCheckout', '~> 0.1'
```

or File ▸ Add Package Dependencies… with the release package URL.

## Configuration

[Configuration](../../docs/configuration.md) covers keys and environments for every package;
[Return URLs](../../docs/return-url-contract.md) gives the full return-URL rules.

### Keys and environments

- **No secret key in the app.** Your server holds the secret key (`sk_test_…` or `sk_live_…`),
  creates the checkout session and returns the `paymentUrl` and the merchant URLs it used. The
  app passes them to `CheckoutOptions` unchanged. There is no environment setting for the
  checkout: the `paymentUrl` already points at the environment your server used.
- **Publishable key, for the promo only.** `QasimhaPromoView` needs a publishable key:
  `pk_test_…` for sandbox, `pk_live_…` for production. The environment follows the key prefix:

  | Environment | Key | API host |
  |---|---|---|
  | Sandbox | `pk_test_…` | `https://api-uat.qasimha.com` |
  | Production | `pk_live_…` | `https://api.qasimha.com` |

  Have your backend return the key, or set it per build configuration. Give sandbox and
  production their own build configurations (and schemes), each based on an `.xcconfig`:

  ```
  // Sandbox.xcconfig
  QASIMHA_PUBLISHABLE_KEY = pk_test_XXXXXXXX
  QASIMHA_RETURN_SCHEME = myshop-sandbox
  QASIMHA_RETURN_HOST = sandbox.shop.example

  // Production.xcconfig
  QASIMHA_PUBLISHABLE_KEY = pk_live_XXXXXXXX
  QASIMHA_RETURN_SCHEME = myshop
  QASIMHA_RETURN_HOST = shop.example
  ```

  Expose the key through `Info.plist` and read it at run time:

  ```xml
  <key>QasimhaPublishableKey</key>
  <string>$(QASIMHA_PUBLISHABLE_KEY)</string>
  ```

  ```swift
  let key = Bundle.main.object(forInfoDictionaryKey: "QasimhaPublishableKey") as? String ?? ""
  let promo = QasimhaPromoView(amount: 1200, publicKey: key, lang: "ar")
  ```

  Use the sandbox key with a sandbox backend and the live key with a production backend.

### Return URLs

Use Universal Links (`https://shop.example/qasimha/return`, Associated Domains) or a custom
scheme (`myshop://qasimha/return`, `CFBundleURLTypes`); both are set up under
[How the result reaches the app](#how-the-result-reaches-the-app). Per build configuration, write
`$(QASIMHA_RETURN_SCHEME)` in `CFBundleURLSchemes` and `applinks:$(QASIMHA_RETURN_HOST)` in the
entitlements file. Your server must create each session with the return URLs of the build that
asked for it. Whatever comes back, confirm the order on your server with `orders.get` before
showing "paid".

## Quick start

```swift
import QasimhaCheckout

// 1. Your server: create the session with a server SDK and return paymentUrl + orderId to the app.
// 2. The app presents it.
let options = CheckoutOptions(
    paymentURL: session.paymentUrl,
    merchantURL: MerchantURL(
        success: URL(string: "https://shop.example/qasimha/return?order=1001")!,
        failure: URL(string: "https://shop.example/qasimha/return?order=1001")!,
        cancel:  URL(string: "https://shop.example/cart")!
    ),
    language: "ar"
)

QasimhaCheckout.start(from: viewController, options: options) { result in
    switch result {
    case .success(let orderId, let orderReferenceId):
        // 3. Never trust the return alone: ask your server, which calls orders.get(orderId).
        myServer.confirm(orderId) { order in show(order.status) }
    case .failure(let status, let orderId, _):
        show("not paid: \(status)")      // declined, expired, failed, unverified, …
    case .cancelled:
        show("cancelled")
    }
}
```

The `merchantURL` values must be the same three URLs your server passed to Qasimha when it created
the session; the hosted checkout redirects to them with `orderId`, `orderReferenceId` and
`status` appended. `cancel` defaults to `failure` when omitted, as on the server.

## How the result reaches the app

At the end of the journey the hosted page navigates to one of your three URLs. The SDK matches
the navigated URL against them by scheme, host and path prefix, reads the query and maps it:

| `status` | Result |
|---|---|
| `confirmed` on the success URL, with `orderId` | `.success(orderId:orderReferenceId:)` |
| `declined`, `expired`, `failed` | `.failure(status:orderId:orderReferenceId:)` |
| `cancelled` | `.cancelled` |
| missing on the cancel URL | `.cancelled` |
| anything else, or missing elsewhere | `.failure(status: "unverified", …)` |

There are two ways the navigation can reach the app, and you pick one when you choose the URLs.

### Universal Links (recommended)

Use `https://` URLs on a domain your app is associated with. iOS opens your app when the checkout
navigates there, and no other app can claim the link.

1. Add the Associated Domains capability. In the entitlements file:

   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
       <string>applinks:shop.example</string>
   </array>
   ```

2. Serve `https://shop.example/.well-known/apple-app-site-association` (JSON, no extension,
   `application/json`):

   ```json
   {
     "applinks": {
       "details": [
         { "appIDs": ["TEAMID.com.example.myapp"], "components": [ { "/": "/qasimha/*" }, { "/": "/cart" } ] }
       ]
     }
   }
   ```

3. Hand the URL to the SDK when iOS delivers it.

   SwiftUI:

   ```swift
   WindowGroup {
       ContentView().onOpenURL { url in
           _ = QasimhaCheckout.handleReturn(url: url)
       }
   }
   ```

   SceneDelegate:

   ```swift
   func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
       guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
             let url = userActivity.webpageURL else { return }
       _ = QasimhaCheckout.handleReturn(url: url)
   }
   ```

   AppDelegate (no scenes):

   ```swift
   func application(_ application: UIApplication, continue userActivity: NSUserActivity,
                    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
       guard let url = userActivity.webpageURL else { return false }
       return QasimhaCheckout.handleReturn(url: url)
   }
   ```

`handleReturn(url:)` returns `true` when the URL belongs to the checkout in progress; it then
closes the sheet and calls your completion. Pass every incoming URL to it; it ignores the rest.

### Custom URL scheme

Use `myshop://qasimha/return` style URLs when you cannot host an association file. Any app can
register the same scheme, so prefer Universal Links for production.

1. Register the scheme in `Info.plist`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLName</key>
           <string>checkout-return</string>
           <key>CFBundleURLSchemes</key>
           <array><string>myshop</string></array>
       </dict>
   </array>
   ```

2. Deliver the URL. SwiftUI's `.onOpenURL` receives both custom-scheme and Universal Link opens.
   SceneDelegate:

   ```swift
   func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
       for context in URLContexts {
           _ = QasimhaCheckout.handleReturn(url: context.url)
       }
   }
   ```

   AppDelegate:

   ```swift
   func application(_ app: UIApplication, open url: URL,
                    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
       QasimhaCheckout.handleReturn(url: url)
   }
   ```

The server accepts any scheme of at least three characters other than `http`, `https`,
`javascript`, `data`, `file`, `blob` and `vbscript`; the SDK validates the same rules before
presenting and completes with `.failure(status: "invalid_options")` if they fail.

## Presentation modes

`CheckoutOptions.presentation`:

| Mode | What happens | Choose it when |
|---|---|---|
| `.safariViewController` (default) | `SFSafariViewController` sheet with the platform's TLS, autofill and cookie isolation. The return comes back through `handleReturn(url:)`; dismissing the sheet completes with `.cancelled`. If the payment URL immediately redirects to a merchant URL (an already-finished session) the result is detected from that redirect, without the app having to receive the URL. | Almost always. The hosted checkout redirects to PSP pages and app switches that a WebView allow-list would have to track. |
| `.webAuthenticationSession(callbackScheme:)` | `ASWebAuthenticationSession` in an ephemeral browser session; iOS hands the SDK the first navigation to `callbackScheme://…` without leaving the app, so no `handleReturn` wiring is needed. The scheme must be the scheme of your merchant URLs. | You use a custom scheme and want the return handled without touching the app delegate. |
| `.webView` | A modal `WKWebView` inside your app, hardened as below. | Only when the checkout must not leave the app and you have confirmed with Qasimha every host the journey visits. |

The WebView is configured with a non-persistent website data store, an empty
`WKUserContentController`, JavaScript enabled for the checkout page only, no script message
handlers or `evaluateJavaScript` bridges, link previews and data detectors off, popups loaded in
place, TLS validation left to the platform (`.performDefaultHandling`, never overridden) and every
HTTP authentication challenge cancelled. Navigation is allowed only to `https` hosts on the
allow-list: the payment URL's host, your return hosts and `options.webView.extraAllowedHosts`
(empty by default). Anything else — other hosts, `http`, app-switch schemes — is blocked, and a
failed or interrupted load completes with `.cancelled`. The shopper can also cancel from the bar
button. Because payment-provider and identity hosts are not known to the SDK, a journey in this
mode dead-ends unless you add those hosts; this is why the browser sheet is the default.

`CheckoutOptions.language` (`"ar"` default, `"en"`) is appended to the payment URL as `lang` when
the URL does not already carry one, and sets the direction and copy of the WebView chrome.

## Results and the confirm-on-your-server rule

The return URL is a navigation, not a proof. A `.success` means the shopper came back on the
success URL with `status=confirmed`; it does not mean money moved. Before fulfilling, showing
"paid" or clearing the cart, ask your own server to fetch the order with its secret key
(`orders.get(orderId)` in every server SDK, `GET /merchant/orders/{orderId}`) and compare status,
amount and `orderReferenceId`. The example app does exactly this.

`.failure(status:)` carries the checkout's own status (`declined`, `expired`, `failed`) or one of
the SDK's: `unverified` (a return that could not be read as a confirmation), `invalid_options`
(validation failed before presenting) and `already_presenting` (a checkout is already open).
`.cancelled` covers the cancel URL, a dismissed sheet, a cancelled `ASWebAuthenticationSession`
and a WebView load that failed closed. Orders left behind by a cancel stay `AwaitingCheckout` on
the Qasimha side and expire on their own; your server may cancel them through the API.

Only one checkout can be presented at a time; `start` completes a second call immediately with
`already_presenting`.

## Promo view

```swift
let promo = QasimhaPromoView(amount: 1200, publicKey: key, lang: "ar")
view.addSubview(promo)
```

Set `amount`, `publicKey`, `language` or `apiBaseURL` and the view reloads. It calls
`GET /api/v1/widget/plans?amount=1200.00&currency=SAR&lang=ar` with `X-Public-Key`, a 5-second
timeout, no cookies and no cache; `pk_live_` keys go to `https://api.qasimha.com`, `pk_test_`
keys to `https://api-uat.qasimha.com` (`apiBaseURL` overrides for a local test server and
must be `https`, or `http` on `localhost` only). It shows the first plan the API returns as
"قسّمها على 4 دفعات شهرية بقيمة [symbol] 300" / "Split into 4 monthly payments of [symbol] 300"
with a trust line for Sharia-compliant plans.

Money is rendered as the Saudi riyal symbol, drawn from its vector path at run time (no asset
catalog, no font), placed to the left of the number inside a left-to-right isolate so the order
survives Arabic layout. The word ريال, the codes SAR/SR and the U+FDFC character never appear on
screen; VoiceOver reads the currency name. Latin digits, thousands separators, decimals only when
the halalas are non-zero.

The view fails closed: an invalid key, an amount outside the merchant's range, a network error,
a non-2xx response, a malformed body, an empty plan list or a symbol that could not be drawn all
leave the view hidden with a zero intrinsic size. It never computes or invents an instalment
figure. `font`, `textColor` and `accentColor` are adjustable.

## Security

- **No secret on the device.** The SDK never sees `sk_` keys; sessions are created on your
  server. The publishable `pk_` key can only read plan quotes.
- **No storage, no tracking, no fingerprinting.** Nothing is written to disk or `UserDefaults`;
  the WebView data store is non-persistent; the plans client uses an ephemeral session. The
  privacy manifest (`PrivacyInfo.xcprivacy`) declares no tracking, no collected data and no
  required-reason API use.
- **TLS is the platform's.** No certificate pinning (hosts rotate certificates) and no option to
  weaken validation anywhere.
- **PCI DSS.** No card data passes through this package or your app; card entry happens on the
  payment provider's hosted page inside the checkout. Merchants embedding the SDK stay in
  SAQ-A scope.
- **Application shielding.** The SDK holds nothing worth extracting, so it does not perform
  jailbreak detection, anti-tamper or anti-debugging. Merchant apps that handle payments
  should adopt an application-shielding product or the platform's own protections
  (App Attest, `DeviceCheck`) according to their own risk assessment; strip symbols in release
  builds as usual.
- **Return URLs.** Universal Links cannot be claimed by another app; custom schemes can, which is
  why the result is never trusted without the server call above.

Report a vulnerability privately to Qasimha Integration Support (customercare@qasimha.com); do
not open a public issue.

## Building and testing

```
swift build      # macOS host: the platform-independent core
swift test       # ReturnURL matching, options validation, money formatting, copy, SVG path parser, plans decoding
xcodebuild -scheme QasimhaCheckout -destination 'generic/platform=iOS' build   # the iOS UI layer
```

The UI layer (`Sources/QasimhaCheckout/UIKit/`) is guarded by `#if canImport(UIKit)` so the
package resolves and tests on a macOS host; it needs the iOS SDK to build. `ci-ios.yml` is a
GitHub Actions job for `macos-14` that builds the library for iOS with Xcode 16, runs `swift test`
and lints the podspec; copy it under `.github/workflows/` to enable it.

Tests use the Swift Testing framework (`import Testing`) and need a Swift 6 toolchain (Xcode 16 or
later); the library itself compiles with Swift 5.9.

## Example

`Example/` contains a SwiftUI app generated with XcodeGen (`Example/README.md`). It creates
the session through a merchant server you run, so no secret key is embedded.

## License

MIT — see `LICENSE`. Changes are listed in `CHANGELOG.md`.
