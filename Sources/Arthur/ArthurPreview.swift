#if DEBUG
import SwiftUI

struct ArthurPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            Button("Success") { Arthur.success("Saved") }
            Button("Error") { Arthur.error("Something went wrong", subtitle: "Please try again.") }
            Button("Warning") { Arthur.warning("Check your connection") }
            Button("Info") { Arthur.info("Updated") }
        }
        .padding()
        .arthur()
    }
}

#Preview("Arthur styles") {
    ArthurPreview()
}
#endif
