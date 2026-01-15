import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("GitBar")
                .font(.headline)
            Text("Menu bar app ready")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
