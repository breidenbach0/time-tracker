import Foundation

struct Project: Identifiable, Equatable, Hashable {
    var id: Int64?
    var name: String
    var scope: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: Int64? = nil,
        name: String,
        scope: String = "",
        colorHex: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
