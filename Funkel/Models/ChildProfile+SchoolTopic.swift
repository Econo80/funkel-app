import Foundation

/// The school topic shown as an extra subject (e.g. "topic-pilze"), kept as
/// the web field "schoolTopic" (web/src/domain/profile.ts). None by default.
extension ChildProfile {
    var schoolTopic: String? {
        get { webField("schoolTopic", as: String.self).flatMap { $0.isEmpty ? nil : $0 } }
        set { setWebField("schoolTopic", newValue) }
    }
}
