import SwiftUI
import QasimhaCheckout

struct PromoView: UIViewRepresentable {
    let amount: Decimal
    let publicKey: String
    let language: String

    func makeUIView(context: Context) -> QasimhaPromoView {
        QasimhaPromoView(amount: amount, publicKey: publicKey, lang: language)
    }

    func updateUIView(_ view: QasimhaPromoView, context: Context) {
        view.amount = amount
        view.publicKey = publicKey
        view.language = language
    }
}
