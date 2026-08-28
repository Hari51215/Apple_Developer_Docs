//
//  SystemSoundManager.swift
//  PixelJingle
//
//  Wraps Audio Services: register each bundled .caf once, play on demand.
//

import AudioToolbox
import Combine

final class SystemSoundManager: ObservableObject {
    enum Effect: String, CaseIterable, Identifiable, Equatable {
        case coin, jump, powerUp, error, gameOver

        var id: String { rawValue }

        var label: String {
            switch self {
            case .coin: return "Coin"
            case .jump: return "Jump"
            case .powerUp: return "Power-Up"
            case .error: return "Error"
            case .gameOver: return "Game Over"
            }
        }
    }

    @Published var lastCompletedEffect: Effect?

    private var soundIDs: [Effect: SystemSoundID] = [:]

    init() {
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "caf") else {
                continue
            }
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
            soundIDs[effect] = soundID
        }
    }

    func play(_ effect: Effect) {
        guard let soundID = soundIDs[effect] else { return }

        AudioServicesPlaySystemSoundWithCompletion(soundID) { [weak self] in
            DispatchQueue.main.async {
                self?.lastCompletedEffect = effect
            }
        }

        if effect == .gameOver {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    deinit {
        for soundID in soundIDs.values {
            AudioServicesDisposeSystemSoundID(soundID)
        }
    }
}
