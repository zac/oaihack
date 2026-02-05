import Foundation

public struct EdgeValueSet: Sendable, Equatable {
    public var top: Double?
    public var leading: Double?
    public var bottom: Double?
    public var trailing: Double?

    public init(
        top: Double? = nil,
        leading: Double? = nil,
        bottom: Double? = nil,
        trailing: Double? = nil
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

public struct ResolvedStyle: Sendable, Equatable {
    public var color: String?
    public var fontSize: Double?
    public var fontWeight: String?
    public var lineHeight: Double?
    public var textAlign: String?

    public var padding: EdgeValueSet
    public var margin: EdgeValueSet
    public var gap: Double?

    public var width: Double?
    public var height: Double?
    public var minWidth: Double?
    public var maxWidth: Double?
    public var minHeight: Double?
    public var maxHeight: Double?
    public var opacity: Double?

    public var backgroundColor: String?
    public var borderWidth: Double?
    public var borderColor: String?
    public var borderRadius: Double?

    public init(
        color: String? = nil,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        lineHeight: Double? = nil,
        textAlign: String? = nil,
        padding: EdgeValueSet = EdgeValueSet(),
        margin: EdgeValueSet = EdgeValueSet(),
        gap: Double? = nil,
        width: Double? = nil,
        height: Double? = nil,
        minWidth: Double? = nil,
        maxWidth: Double? = nil,
        minHeight: Double? = nil,
        maxHeight: Double? = nil,
        opacity: Double? = nil,
        backgroundColor: String? = nil,
        borderWidth: Double? = nil,
        borderColor: String? = nil,
        borderRadius: Double? = nil
    ) {
        self.color = color
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.lineHeight = lineHeight
        self.textAlign = textAlign
        self.padding = padding
        self.margin = margin
        self.gap = gap
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.opacity = opacity
        self.backgroundColor = backgroundColor
        self.borderWidth = borderWidth
        self.borderColor = borderColor
        self.borderRadius = borderRadius
    }
}
