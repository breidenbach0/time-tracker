import Foundation

/// A recording that's still running, saved so it survives quitting, crashes and updates.
struct RunningTimerState: Equatable {
    var name: String
    var notes: String
    var projectId: Int64
    var startDate: Date
}
