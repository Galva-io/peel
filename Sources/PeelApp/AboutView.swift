import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop.degreesign")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)
            Text("Peel").font(.title.weight(.semibold))
            Text(version).font(.caption).foregroundStyle(.secondary)
            Text("App Store Server API workbench").font(.callout).foregroundStyle(.secondary)
            Divider().padding(.vertical, 6)
            Text("By the team behind Habitify.").font(.callout)
            HStack(spacing: 14) {
                Link("peel-app.com", destination: URL(string: "https://peel-app.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/galva/peel")!)
                Link("Privacy", destination: URL(string: "https://peel-app.com/privacy")!)
            }
            .font(.caption)
        }
        .multilineTextAlignment(.center)
        .frame(width: 340)
        .padding(28)
    }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0-dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "Version \(short) (\(build))"
    }
}
