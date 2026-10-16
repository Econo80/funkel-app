import UIKit

/// Picks one font size for a group of answers so they all look the same.
///
/// SwiftUI's `minimumScaleFactor` shrinks each view on its own, so a grid
/// ends up with mixed sizes. Instead we measure the longest *word* (lines may
/// wrap between words, never inside one) and take the largest size at which
/// it fits the column.
enum TextFitting {

    static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func width(of text: String, size: CGFloat, weight: UIFont.Weight) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: roundedFont(size: size, weight: weight)]).width)
    }

    /// The largest size in `minSize...maxSize` (1 pt steps) at which every word
    /// of every text fits into `width`. Returns `minSize` if even that doesn't fit;
    /// the view's own `minimumScaleFactor` is the last resort.
    static func fittingSize(
        for texts: [String],
        width: CGFloat,
        maxSize: CGFloat,
        minSize: CGFloat,
        weight: UIFont.Weight
    ) -> CGFloat {
        guard width > 0 else { return maxSize }
        let words = texts.flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
        guard let longest = words.max(by: { Self.width(of: $0, size: maxSize, weight: weight) < Self.width(of: $1, size: maxSize, weight: weight) }) else {
            return maxSize
        }
        var size = maxSize.rounded(.down)
        while size > minSize && Self.width(of: longest, size: size, weight: weight) > width {
            size -= 1
        }
        return max(size, minSize)
    }
}
