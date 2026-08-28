//
//  JinglePreset.swift
//  PixelJingle
//
//  Pure data describing each jingle as a list of MIDI notes.
//  Holds no AudioToolbox calls — JingleSequenceManager turns this into a real MusicSequence.
//

import Foundation

struct JingleNote {
    let pitch: UInt8
    let beats: Double

    var name: String { Self.name(forPitch: pitch) }

    static func name(forPitch pitch: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(pitch) / 12 - 1
        return "\(noteNames[Int(pitch) % 12])\(octave)"
    }
}

enum JinglePreset: String, CaseIterable, Identifiable, Hashable {
    case victory = "Victory"
    case levelUp = "Level Up"
    case gameOver = "Game Over Jingle"

    var id: String { rawValue }

    var notes: [JingleNote] {
        switch self {
        case .victory:
            return [
                JingleNote(pitch: 60, beats: 0.5),  // C4
                JingleNote(pitch: 64, beats: 0.5),  // E4
                JingleNote(pitch: 67, beats: 0.5),  // G4
                JingleNote(pitch: 72, beats: 1.0),  // C5
            ]
        case .levelUp:
            return [
                JingleNote(pitch: 67, beats: 0.25),  // G4
                JingleNote(pitch: 71, beats: 0.25),  // B4
                JingleNote(pitch: 74, beats: 0.25),  // D5
                JingleNote(pitch: 79, beats: 0.75),  // G5
            ]
        case .gameOver:
            return [
                JingleNote(pitch: 65, beats: 0.5),  // F4
                JingleNote(pitch: 62, beats: 0.5),  // D4
                JingleNote(pitch: 58, beats: 0.5),  // A#3
                JingleNote(pitch: 53, beats: 1.0),  // F3
            ]
        }
    }
}
