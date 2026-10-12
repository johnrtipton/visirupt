import SwiftUI
struct AdapterChecksView: UIViewControllerRepresentable {
 func makeUIViewController(context: Context) -> UIViewController { CPCreateAdapterChecksController() }
 func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
@main struct AdapterChecksApp: App {
 var body: some Scene { WindowGroup { AdapterChecksView().frame(minWidth:600,minHeight:400) } }
}
