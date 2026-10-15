import SwiftUI

/// Rounded system fonts, all built on Dynamic Type text styles so they scale.
extension Font {
    static let funkelTitle = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let funkelHeadline = Font.system(.title2, design: .rounded).weight(.bold)
    static let funkelQuestion = Font.system(.title, design: .rounded).weight(.bold)
    static let funkelBody = Font.system(.body, design: .rounded)
    static let funkelCaption = Font.system(.callout, design: .rounded).weight(.medium)
}
