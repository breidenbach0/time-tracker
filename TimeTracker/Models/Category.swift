import Foundation

struct Category: Identifiable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var colorHex: String
    var isDefault: Bool
    var sourceCalendarIdentifier: String?
}
