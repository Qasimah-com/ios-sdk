import SwiftUI
import QasimhaCheckout

@main
struct QasimhaExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = QasimhaCheckout.handleReturn(url: url)
                }
        }
    }
}
