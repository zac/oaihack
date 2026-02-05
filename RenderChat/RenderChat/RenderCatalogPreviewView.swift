import SwiftUI

struct RenderCatalogPreviewView: View {
    @State private var name: String = "Ava"
    @State private var isEnabled: Bool = true
    @State private var volume: Double = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                PreviewBlock(title: "Text") {
                    Text("Status: Online")
                        .font(.headline)
                }

                PreviewBlock(title: "Badge") {
                    Text("PRO")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }

                PreviewBlock(title: "Card") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Support Ticket")
                            .font(.headline)
                        Text("#1842 \u00b7 Pending response")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                PreviewBlock(title: "Stacked Layout") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Account Overview")
                            .font(.headline)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Users")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("1,248")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Churn")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("2.1%")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                PreviewBlock(title: "Text Field") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                PreviewBlock(title: "Toggle") {
                    Toggle("Notifications", isOn: $isEnabled)
                }

                PreviewBlock(title: "Slider") {
                    Slider(value: $volume, in: 0...1)
                }

                PreviewBlock(title: "Button") {
                    Button("Submit") {}
                        .buttonStyle(.borderedProminent)
                }

                PreviewBlock(title: "List") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(["Create ticket", "Assign agent", "Notify user"], id: \.self) { item in
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                Text(item)
                                Spacer()
                            }
                            if item != "Notify user" {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Render Catalog")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JSON Render Previews")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Visual targets for JSON-to-SwiftUI mapping. Keep these aligned with catalog components.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PreviewBlock<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

#Preview("Render Catalog") {
    NavigationStack {
        RenderCatalogPreviewView()
    }
    .frame(minWidth: 420, minHeight: 800)
}
