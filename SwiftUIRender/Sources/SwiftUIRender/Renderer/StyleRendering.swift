import SwiftUI

enum StyleColorParser {
    static func color(from raw: String?) -> Color? {
        guard let raw else { return nil }

        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "gray", "grey": return .gray
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "primary": return .primary
        case "secondary": return .secondary
        default:
            break
        }

        guard normalized.hasPrefix("#") else {
            return nil
        }

        let hex = String(normalized.dropFirst())
        guard hex.count == 6 || hex.count == 8, let value = UInt64(hex, radix: 16) else {
            return nil
        }

        let r, g, b, a: Double
        if hex.count == 8 {
            r = Double((value & 0xFF00_0000) >> 24) / 255.0
            g = Double((value & 0x00FF_0000) >> 16) / 255.0
            b = Double((value & 0x0000_FF00) >> 8) / 255.0
            a = Double(value & 0x0000_00FF) / 255.0
        } else {
            r = Double((value & 0xFF00_00) >> 16) / 255.0
            g = Double((value & 0x00FF_00) >> 8) / 255.0
            b = Double(value & 0x0000_FF) / 255.0
            a = 1.0
        }

        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

private struct NodeLayoutModifier: ViewModifier {
    let style: ResolvedStyle

    func body(content: Content) -> some View {
        content
            .padding(.top, CGFloat(style.padding.top ?? 0))
            .padding(.leading, CGFloat(style.padding.leading ?? 0))
            .padding(.bottom, CGFloat(style.padding.bottom ?? 0))
            .padding(.trailing, CGFloat(style.padding.trailing ?? 0))
            .frame(
                minWidth: cg(style.minWidth),
                idealWidth: nil,
                maxWidth: cg(style.maxWidth),
                minHeight: cg(style.minHeight),
                idealHeight: nil,
                maxHeight: cg(style.maxHeight)
            )
            .frame(width: cg(style.width), height: cg(style.height))
            .opacity(style.opacity ?? 1)
            .background {
                if let color = StyleColorParser.color(from: style.backgroundColor) {
                    RoundedRectangle(cornerRadius: style.borderRadius ?? 0, style: .continuous)
                        .fill(color)
                }
            }
            .overlay {
                if let borderWidth = style.borderWidth,
                   borderWidth > 0,
                   let borderColor = StyleColorParser.color(from: style.borderColor) {
                    RoundedRectangle(cornerRadius: style.borderRadius ?? 0, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: style.borderRadius ?? 0, style: .continuous))
            .padding(.top, CGFloat(style.margin.top ?? 0))
            .padding(.leading, CGFloat(style.margin.leading ?? 0))
            .padding(.bottom, CGFloat(style.margin.bottom ?? 0))
            .padding(.trailing, CGFloat(style.margin.trailing ?? 0))
    }

    private func cg(_ value: Double?) -> CGFloat? {
        guard let value else { return nil }
        return CGFloat(value)
    }
}

private struct ForegroundStyleModifier: ViewModifier {
    let style: ResolvedStyle

    func body(content: Content) -> some View {
        if let color = StyleColorParser.color(from: style.color) {
            content.foregroundStyle(color)
        } else {
            content
        }
    }
}

private struct FontStyleModifier: ViewModifier {
    let style: ResolvedStyle

    func body(content: Content) -> some View {
        if let fontSize = style.fontSize {
            content.font(.system(size: fontSize, weight: fontWeight(style.fontWeight)))
        } else {
            content.fontWeight(fontWeight(style.fontWeight))
        }
    }

    private func fontWeight(_ raw: String?) -> Font.Weight {
        guard let raw else { return .regular }

        switch raw.lowercased() {
        case "thin": return .thin
        case "ultralight": return .ultraLight
        case "light": return .light
        case "medium": return .medium
        case "semibold", "600": return .semibold
        case "bold", "700": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default:
            return .regular
        }
    }
}

extension View {
    func applyNodeLayout(_ style: ResolvedStyle) -> some View {
        modifier(NodeLayoutModifier(style: style))
    }

    func applyTextStyle(_ style: ResolvedStyle) -> some View {
        modifier(FontStyleModifier(style: style))
            .modifier(ForegroundStyleModifier(style: style))
    }

    func applyForegroundStyle(_ style: ResolvedStyle) -> some View {
        modifier(ForegroundStyleModifier(style: style))
    }
}
