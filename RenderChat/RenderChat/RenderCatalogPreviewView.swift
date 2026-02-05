import SwiftUI
import SwiftUIRender

struct RenderCatalogPreviewView: View {
    @State private var showJSONSource = false

    private let scenarios = RenderCatalogScenario.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                Toggle("Show JSON source", isOn: $showJSONSource)
                    .toggleStyle(.switch)

                ForEach(scenarios) { scenario in
                    RenderScenarioBlock(
                        scenario: scenario,
                        showJSONSource: showJSONSource
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle("Render Catalog")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("JSON Render Previews")
                .font(.title2)
                .fontWeight(.semibold)

            Text("These examples are rendered by SwiftUIRender from hard-coded JSON specs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RenderScenarioBlock: View {
    let scenario: RenderCatalogScenario
    let showJSONSource: Bool

    @State private var diagnostics = RenderDiagnostics()

    var body: some View {
        PreviewBlock(title: scenario.title) {
            Text(scenario.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            RenderView(
                source: .jsonString(scenario.specJSON),
                configuration: scenario.configuration,
                diagnostics: diagnostics
            )
            .frame(minHeight: 220, maxHeight: 300)

            if !diagnostics.issues.isEmpty {
                diagnosticsView
            }

            if showJSONSource {
                ScrollView(.horizontal) {
                    Text(scenario.prettySpecJSON)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diagnostics")
                .font(.caption)
                .fontWeight(.semibold)

            ForEach(diagnostics.issues) { issue in
                let pathSuffix = issue.path.map { " (\($0))" } ?? ""
                Text("\(issue.severity.rawValue.uppercased()): \(issue.message)\(pathSuffix)")
                    .font(.caption)
                    .foregroundStyle(issueColor(for: issue.severity))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func issueColor(for severity: GuardrailSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct RenderCatalogScenario: Identifiable {
    let id: String
    let title: String
    let description: String
    let specJSON: String
    let initialData: JSONValue
    let styleClasses: [String: [String: JSONValue]]
    let styleVariables: [String: JSONValue]

    var configuration: RenderConfiguration {
        RenderConfiguration(
            styleClasses: styleClasses,
            styleVariables: styleVariables,
            initialData: initialData,
            emitUnsupportedStyleWarnings: true
        )
    }

    var prettySpecJSON: String {
        guard let data = specJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return specJSON
        }

        return pretty
    }

    static let defaultStyleClasses: [String: [String: JSONValue]] = [
        "surface": [
            "padding": .number(12),
            "border-radius": .number(12),
            "background-color": .string("var(--surface-bg)"),
            "border-width": .number(1),
            "border-color": .string("#D0D7E2"),
        ],
        "muted": [
            "color": .string("#667085"),
        ],
        "accent": [
            "color": .string("#0D63F3"),
            "font-weight": .string("bold"),
        ],
    ]

    static let defaultStyleVariables: [String: JSONValue] = [
        "surface-bg": .string("#F6F8FC"),
    ]

    static let all: [RenderCatalogScenario] = [
        RenderCatalogScenario(
            id: "support-form",
            title: "Support Form",
            description: "Text, divider, text-field binding, and set_data action rendered from JSON.",
            specJSON: #"""
            {
              "root": "root",
              "elements": {
                "root": {
                  "type": "root",
                  "children": {
                    "children": ["title", "subtitle", "divider", "nameField", "saveButton"]
                  }
                },
                "title": {
                  "type": "text",
                  "parentKey": "root",
                  "props": {
                    "text": "Support Dashboard"
                  },
                  "styles": {
                    "font-size": 24,
                    "font-weight": "bold"
                  }
                },
                "subtitle": {
                  "type": "text",
                  "parentKey": "root",
                  "props": {
                    "text": "Ticket #1842 - Pending"
                  },
                  "styles": {
                    "color": "secondary"
                  }
                },
                "divider": {
                  "type": "divider",
                  "parentKey": "root"
                },
                "nameField": {
                  "type": "text-field",
                  "parentKey": "root",
                  "props": {
                    "placeholder": "Customer name",
                    "binding": "$data.customer.name"
                  }
                },
                "saveButton": {
                  "type": "button",
                  "parentKey": "root",
                  "props": {
                    "text": "Save Customer",
                    "action": {
                      "name": "set_data",
                      "params": {
                        "path": "$data.customer.saved",
                        "value": true
                      }
                    }
                  }
                }
              }
            }
            """#,
            initialData: .object([
                "customer": .object([
                    "name": .string("Ava"),
                    "saved": .bool(false),
                ]),
            ]),
            styleClasses: defaultStyleClasses,
            styleVariables: defaultStyleVariables
        ),
        RenderCatalogScenario(
            id: "layout-gallery",
            title: "Layout Gallery",
            description: "v-stack, h-stack, card, badge, and list components using shared style classes.",
            specJSON: #"""
            {
              "root": "root",
              "elements": {
                "root": {
                  "type": "root",
                  "children": {
                    "children": ["heading", "metricsRow", "todoTitle", "todoList"]
                  }
                },
                "heading": {
                  "type": "text",
                  "parentKey": "root",
                  "props": {
                    "text": "Account Overview"
                  },
                  "styles": {
                    "font-size": 22,
                    "font-weight": "bold"
                  }
                },
                "metricsRow": {
                  "type": "h-stack",
                  "parentKey": "root",
                  "children": {
                    "children": ["activeCard", "churnCard", "proBadge"]
                  },
                  "styles": {
                    "gap": 12
                  }
                },
                "activeCard": {
                  "type": "card",
                  "parentKey": "metricsRow",
                  "children": {
                    "children": ["activeLabel", "activeValue"]
                  },
                  "classNames": ["surface"]
                },
                "activeLabel": {
                  "type": "text",
                  "parentKey": "activeCard",
                  "props": {
                    "text": "Active Users"
                  },
                  "classNames": ["muted"]
                },
                "activeValue": {
                  "type": "text",
                  "parentKey": "activeCard",
                  "props": {
                    "text": "1,248"
                  },
                  "styles": {
                    "font-size": 20,
                    "font-weight": "bold"
                  }
                },
                "churnCard": {
                  "type": "card",
                  "parentKey": "metricsRow",
                  "children": {
                    "children": ["churnLabel", "churnValue"]
                  },
                  "classNames": ["surface"]
                },
                "churnLabel": {
                  "type": "text",
                  "parentKey": "churnCard",
                  "props": {
                    "text": "Churn"
                  },
                  "classNames": ["muted"]
                },
                "churnValue": {
                  "type": "text",
                  "parentKey": "churnCard",
                  "props": {
                    "text": "2.1%"
                  },
                  "styles": {
                    "font-size": 20,
                    "font-weight": "bold"
                  }
                },
                "proBadge": {
                  "type": "badge",
                  "parentKey": "metricsRow",
                  "props": {
                    "text": "PRO"
                  }
                },
                "todoTitle": {
                  "type": "text",
                  "parentKey": "root",
                  "props": {
                    "text": "Checklist"
                  },
                  "styles": {
                    "font-size": 18,
                    "font-weight": "bold"
                  }
                },
                "todoList": {
                  "type": "list",
                  "parentKey": "root",
                  "children": {
                    "children": ["item1", "item2", "item3"]
                  }
                },
                "item1": {
                  "type": "text",
                  "parentKey": "todoList",
                  "props": {
                    "text": "Create ticket"
                  }
                },
                "item2": {
                  "type": "text",
                  "parentKey": "todoList",
                  "props": {
                    "text": "Assign agent"
                  }
                },
                "item3": {
                  "type": "text",
                  "parentKey": "todoList",
                  "props": {
                    "text": "Notify customer"
                  }
                }
              }
            }
            """#,
            initialData: .object([:]),
            styleClasses: defaultStyleClasses,
            styleVariables: defaultStyleVariables
        ),
        RenderCatalogScenario(
            id: "styled-actions",
            title: "Styled Actions",
            description: "Buttons fire open_url and log_event actions. Diagnostics appear below the render.",
            specJSON: #"""
            {
              "root": "root",
              "elements": {
                "root": {
                  "type": "root",
                  "children": {
                    "children": ["heroCard", "openButton", "logButton"]
                  }
                },
                "heroCard": {
                  "type": "card",
                  "parentKey": "root",
                  "children": {
                    "children": ["heroTitle", "heroSubtitle"]
                  },
                  "classNames": ["surface"]
                },
                "heroTitle": {
                  "type": "text",
                  "parentKey": "heroCard",
                  "props": {
                    "text": "Automation Ready"
                  },
                  "classNames": ["accent"],
                  "styles": {
                    "font-size": 20
                  }
                },
                "heroSubtitle": {
                  "type": "text",
                  "parentKey": "heroCard",
                  "props": {
                    "text": "Catalog-defined actions keep behavior guardrailed."
                  },
                  "classNames": ["muted"]
                },
                "openButton": {
                  "type": "button",
                  "parentKey": "root",
                  "props": {
                    "text": "Open Docs",
                    "action": {
                      "name": "open_url",
                      "params": {
                        "url": "https://json-render.dev"
                      }
                    }
                  }
                },
                "logButton": {
                  "type": "button",
                  "parentKey": "root",
                  "props": {
                    "text": "Log Event",
                    "action": {
                      "name": "log_event",
                      "params": {
                        "name": "catalog_preview_tapped",
                        "payload": {
                          "source": "render_catalog_preview"
                        }
                      }
                    }
                  }
                }
              }
            }
            """#,
            initialData: .object([:]),
            styleClasses: defaultStyleClasses,
            styleVariables: defaultStyleVariables
        ),
        RenderCatalogScenario(
            id: "guardrail",
            title: "Guardrail Example",
            description: "Includes an unsupported component type so guardrail surfaces are visible.",
            specJSON: #"""
            {
              "root": "root",
              "elements": {
                "root": {
                  "type": "root",
                  "children": {
                    "children": ["badNode", "hint"]
                  }
                },
                "badNode": {
                  "type": "unknown-widget",
                  "parentKey": "root",
                  "props": {
                    "text": "Unsupported"
                  }
                },
                "hint": {
                  "type": "text",
                  "parentKey": "root",
                  "props": {
                    "text": "Guardrails should report this component as unsupported."
                  },
                  "classNames": ["muted"]
                }
              }
            }
            """#,
            initialData: .object([:]),
            styleClasses: defaultStyleClasses,
            styleVariables: defaultStyleVariables
        ),
    ]
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
    .frame(minWidth: 420, minHeight: 900)
}
