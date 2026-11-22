import SwiftUI

@main
struct CabinCrewEnglishApp: App {
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
                .environmentObject(progress)
                .preferredColorScheme(.dark)
        }
    }
}
