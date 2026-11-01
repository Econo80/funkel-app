import Foundation

/// Where the child lives: general knowledge asks about this country (capital,
/// emergency numbers, mountains, festivals). Kept as the web field `country`.
enum Country: String, CaseIterable, Identifiable {
    case switzerland = "CH"
    case germany = "DE"
    case austria = "AT"

    var id: String { rawValue }
    var nameKey: String { "editor.country." + rawValue }

    /// From the device's region (Germany, Austria); Switzerland otherwise.
    static func fromDevice(_ locale: Locale = .current) -> Country {
        switch locale.region?.identifier {
        case "DE": .germany
        case "AT": .austria
        default: .switzerland
        }
    }
}

extension ChildProfile {
    var country: Country {
        get { webField("country", as: String.self).flatMap(Country.init(rawValue:)) ?? Country.fromDevice() }
        set { setWebField("country", newValue.rawValue) }
    }
}
