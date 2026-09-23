import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
            Text("ihatefiles")
                .font(.title)
        }
        .frame(minWidth: 480, minHeight: 320)
    }
}

#Preview {
    ContentView()
}
