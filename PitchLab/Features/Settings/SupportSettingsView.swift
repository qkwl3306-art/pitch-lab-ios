import SwiftUI

struct SupportSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showMailUnavailable = false
    @State private var copied = false
    private static let email = "1694463808@qq.com"

    var body: some View {
        NavigationStack {
            List {
                Section { PracticeAccessPanel() }
                Section {
                    Button {
                        sendFeedback()
                    } label: {
                        Label("support.feedback", systemImage: "envelope")
                    }
                    LabeledContent("support.email", value: Self.email)
                        .textSelection(.enabled)
                    Button {
                        UIPasteboard.general.string = Self.email
                        copied = true
                    } label: {
                        Label("support.copy", systemImage: "doc.on.doc")
                    }
                } footer: {
                    Text("support.footer")
                }
            }
            .navigationTitle("support.title")
            .alert("support.noMail", isPresented: $showMailUnavailable) {
                Button("support.copy") {
                    UIPasteboard.general.string = Self.email
                }
                Button("support.ok", role: .cancel) {}
            } message: {
                Text(verbatim: Self.email)
            }
            .alert("support.copied", isPresented: $copied) {
                Button("support.ok", role: .cancel) {}
            }
        }
    }

    private func sendFeedback() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.email
        components.queryItems = [URLQueryItem(name: "subject", value: String(localized: "support.subject"))]
        guard let url = components.url else { showMailUnavailable = true; return }
        openURL(url) { accepted in
            if !accepted { showMailUnavailable = true }
        }
    }
}
