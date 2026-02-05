import SwiftUI

struct NodeView: View {
    @Bindable private var box: NodeBox
    private let runtime: RenderRuntime

    init(box: NodeBox, runtime: RenderRuntime) {
        _box = Bindable(box)
        self.runtime = runtime
    }

    var body: some View {
        render(kind: box.node.kind)
            .applyNodeLayout(box.node.style)
    }

    @ViewBuilder
    private func render(kind: RenderNodeKind) -> some View {
        switch kind {
        case let .root(children):
            VStack(alignment: .leading, spacing: box.node.style.gap ?? 12) {
                childNodes(for: children)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .vStack(children):
            VStack(alignment: .leading, spacing: box.node.style.gap ?? 12) {
                childNodes(for: children)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .hStack(children):
            HStack(spacing: box.node.style.gap ?? 12) {
                childNodes(for: children)
            }

        case let .text(content):
            Text(content)
                .applyTextStyle(box.node.style)

        case let .badge(content):
            Text(content)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
                .applyTextStyle(box.node.style)

        case let .card(children):
            VStack(alignment: .leading, spacing: box.node.style.gap ?? 8) {
                childNodes(for: children)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: box.node.style.borderRadius ?? 12, style: .continuous))

        case .divider:
            Divider()

        case let .button(title, action):
            Button(title) {
                guard let action else { return }
                runtime.run(action: action)
            }
            .buttonStyle(.borderedProminent)
            .applyForegroundStyle(box.node.style)

        case let .textField(placeholder, binding):
            if let binding {
                TextField(placeholder, text: runtime.dataStore.stringBinding(path: binding))
                    .textFieldStyle(.roundedBorder)
                    .applyTextStyle(box.node.style)
            } else {
                GuardrailNodeView(message: "text-field missing valid binding")
            }

        case let .list(children):
            VStack(alignment: .leading, spacing: box.node.style.gap ?? 8) {
                ForEach(Array(children.enumerated()), id: \.offset) { index, key in
                    if let childBox = runtime.graphStore.box(for: key) {
                        NodeView(box: childBox, runtime: runtime)
                    } else {
                        GuardrailNodeView(message: "Missing child node '\(key)'")
                    }

                    if index < children.count - 1 {
                        Divider()
                    }
                }
            }

        case let .guardrail(message):
            GuardrailNodeView(message: message)
        }
    }

    @ViewBuilder
    private func childNodes(for keys: [String]) -> some View {
        ForEach(keys, id: \.self) { key in
            if let childBox = runtime.graphStore.box(for: key) {
                NodeView(box: childBox, runtime: runtime)
            } else {
                GuardrailNodeView(message: "Missing child node '\(key)'")
            }
        }
    }
}

private struct GuardrailNodeView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Guardrail")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
    }
}
