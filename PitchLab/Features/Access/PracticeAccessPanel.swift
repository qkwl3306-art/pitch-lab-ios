import StoreKit
import SwiftUI

struct PracticeAccessPanel: View {
    @EnvironmentObject private var store: PracticeAccessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("access.title").font(.headline)
            switch store.access {
            case .unlocked:
                Text("access.unlocked")
            case .trial(let end):
                Text("access.ends")
                Text(end, format: .dateTime.month().day().hour().minute())
            case .locked:
                Text(store.trialUsed ? "access.expired" : "access.description")
            }
            if store.access != .unlocked {
                Text("access.terms").font(.footnote)
                if !store.trialUsed,
                   let trial = store.products.first(where: { $0.id == PracticeAccessStore.trialID && $0.price == 0 }) {
                    Button("access.startTrial") { Task { await store.buy(trial) } }
                        .buttonStyle(.borderedProminent)
                }
                if let unlock = store.products.first(where: { $0.id == PracticeAccessStore.unlockID }) {
                    Button {
                        Task { await store.buy(unlock) }
                    } label: {
                        Text("access.buy \(unlock.displayPrice)")
                    }
                    .buttonStyle(.bordered)
                }
                Button("access.reload") { Task { await store.loadProducts() } }
            }
            Button("access.restore") { Task { await store.restore() } }
            if store.busy { ProgressView() }
            if let message = store.message { Text(message).font(.footnote) }
        }
        .disabled(store.busy)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct PracticeGate<Content: View>: View {
    @EnvironmentObject private var store: PracticeAccessStore
    @ViewBuilder let content: () -> Content

    var body: some View {
        if store.access.allowsPractice { content() }
        else { ScrollView { PracticeAccessPanel() } }
    }
}
