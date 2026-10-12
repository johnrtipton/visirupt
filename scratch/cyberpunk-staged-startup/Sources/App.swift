import SwiftUI
struct LoadFixture: UIViewControllerRepresentable {
 func makeUIViewController(context: Context) -> UIViewController { CPCreateAppStoreLoadController() }
 func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
@main struct AppStoreLoadProbe: App {
 var body: some Scene {
  WindowGroup {
   LoadFixture()
    .frame(minWidth:640,minHeight:360)
    .frame(maxWidth:.infinity,maxHeight:.infinity)
    .background(Color.black)
    .contentShape(Rectangle())
  }
  .windowStyle(.plain)
  .windowResizability(.contentMinSize)
  .defaultSize(width:1280,height:720)
 }
}
