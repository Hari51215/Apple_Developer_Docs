import Foundation

struct Call: Identifiable, Equatable {
    enum Direction {
        case incoming
        case outgoing
    }

    enum State: Equatable {
        case ringing
        case connecting
        case connected
        case held
        case ended
    }

    let id: UUID
    let handle: String
    let direction: Direction
    var state: State = .ringing
    var isMuted: Bool = false
    var connectedAt: Date?
}
