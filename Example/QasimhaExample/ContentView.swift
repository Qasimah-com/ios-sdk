import SwiftUI
import UIKit
import QasimhaCheckout

struct ContentView: View {
    @State private var amountText = "1200"
    @State private var language = "ar"
    @State private var mode = 0
    @State private var status = "Ready"
    @State private var busy = false

    private var amount: Decimal { Decimal(string: amountText) ?? 0 }

    private var presentation: Presentation {
        switch mode {
        case 1: return .webAuthenticationSession(callbackScheme: ExampleConfig.callbackScheme)
        case 2: return .webView
        default: return .safariViewController
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Order")) {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("Language", selection: $language) {
                        Text("العربية").tag("ar")
                        Text("English").tag("en")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    PromoView(amount: amount, publicKey: ExampleConfig.publicKey, language: language)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Section(header: Text("Presentation")) {
                    Picker("Mode", selection: $mode) {
                        Text("Safari").tag(0)
                        Text("Web auth").tag(1)
                        Text("Web view").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                Section {
                    Button(action: pay) {
                        Text(busy ? "Working…" : "Pay with Qasimha")
                    }
                    .disabled(busy || amount <= 0)
                    Text(status).font(.footnote)
                }
            }
            .navigationBarTitle("Qasimha Example")
        }
    }

    private func pay() {
        busy = true
        status = "Creating the session on the merchant server…"
        MerchantServerClient.createSession(amount: amount, merchantURL: ExampleConfig.merchantURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    busy = false
                    status = "Session failed: \(error.localizedDescription)"
                case .success(let session):
                    present(session)
                }
            }
        }
    }

    private func present(_ session: SessionResponse) {
        guard let presenter = UIApplication.shared.topViewController else {
            busy = false
            status = "No view controller to present from"
            return
        }
        let options = CheckoutOptions(paymentURL: session.paymentUrl,
                                      merchantURL: ExampleConfig.merchantURL,
                                      presentation: presentation,
                                      language: language)
        status = "Checkout open for order \(session.orderId)"
        QasimhaCheckout.start(from: presenter, options: options) { result in
            switch result {
            case .success(let orderId, _):
                status = "Returned as paid, confirming with the merchant server…"
                confirm(orderId)
            case .failure(let reason, let orderId, _):
                busy = false
                status = "Not paid: \(reason)" + (orderId.map { " (order \($0))" } ?? "")
            case .cancelled:
                busy = false
                status = "Cancelled"
            }
        }
    }

    private func confirm(_ orderId: String) {
        MerchantServerClient.order(id: orderId) { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let order):
                    status = "Merchant server confirms order \(order.orderId): \(order.status)"
                case .failure(let error):
                    status = "Could not confirm: \(error.localizedDescription)"
                }
            }
        }
    }
}
