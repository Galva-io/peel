import SwiftUI
import PeelCore
import PeelAPI

public struct MainContent: View {
    @Bindable public var store: PeelAppStore
    @State private var endpoint: EndpointID = .getAllSubscriptionStatuses
    @State private var parameters: RequestParameters = RequestParameters()
    @State private var lastResult: PeelAppStore.DispatchResult?
    @State private var lastError: PeelError?

    public init(store: PeelAppStore) { self.store = store }

    public var body: some View {
        HSplitView {
            RequestPanel(
                store: store,
                endpoint: $endpoint,
                parameters: $parameters,
                lastResult: $lastResult,
                lastError: $lastError
            )
            .frame(minWidth: 360, idealWidth: 420)

            ResponseViewer(
                store: store,
                lastResult: $lastResult
            )
        }
    }
}
