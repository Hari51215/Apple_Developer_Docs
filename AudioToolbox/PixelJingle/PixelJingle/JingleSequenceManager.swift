//
//  JingleSequenceManager.swift
//  PixelJingle
//
//  Builds a MusicSequence/MusicTrack from a JinglePreset, plays it with MusicPlayer,
//  and reads the note list back with MusicEventIterator instead of trusting the preset data.
//

import AudioToolbox
import Combine

final class JingleSequenceManager: ObservableObject {
    @Published var isPlaying = false
    @Published var noteDescriptions: [String] = []

    private var sequence: MusicSequence?
    private var player: MusicPlayer?

    func load(_ preset: JinglePreset) {
        stop()
        disposeCurrentSequence()

        var newSequence: MusicSequence?
        NewMusicSequence(&newSequence)
        guard let newSequence else { return }

        var track: MusicTrack?
        MusicSequenceNewTrack(newSequence, &track)
        guard let track else { return }

        var beat: MusicTimeStamp = 0
        for note in preset.notes {
            var message = MIDINoteMessage(
                channel: 0,
                note: note.pitch,
                velocity: 100,
                releaseVelocity: 0,
                duration: Float32(note.beats)
            )
            MusicTrackNewMIDINoteEvent(track, beat, &message)
            beat += note.beats
        }

        sequence = newSequence
        noteDescriptions = readNoteDescriptions(from: track)

        if player == nil {
            var newPlayer: MusicPlayer?
            NewMusicPlayer(&newPlayer)
            player = newPlayer
        }

        if let player {
            MusicPlayerSetSequence(player, newSequence)
            MusicPlayerPreroll(player)
        }
    }

    func play() {
        guard let player else { return }
        MusicPlayerStart(player)
        isPlaying = true
    }

    func stop() {
        guard let player else { return }
        MusicPlayerStop(player)
        MusicPlayerSetTime(player, 0)
        isPlaying = false
    }

    private func readNoteDescriptions(from track: MusicTrack) -> [String] {
        var iterator: MusicEventIterator?
        NewMusicEventIterator(track, &iterator)
        guard let iterator else { return [] }
        defer { DisposeMusicEventIterator(iterator) }

        var descriptions: [String] = []
        var hasEvent: DarwinBoolean = false
        MusicEventIteratorHasCurrentEvent(iterator, &hasEvent)

        while hasEvent.boolValue {
            var timeStamp: MusicTimeStamp = 0
            var eventType: MusicEventType = 0
            var eventData: UnsafeRawPointer?
            var eventDataSize: UInt32 = 0

            MusicEventIteratorGetEventInfo(iterator, &timeStamp, &eventType, &eventData, &eventDataSize)

            if eventType == kMusicEventType_MIDINoteMessage, let eventData {
                let message = eventData.load(as: MIDINoteMessage.self)
                descriptions.append(JingleNote.name(forPitch: message.note))
            }

            MusicEventIteratorNextEvent(iterator)
            MusicEventIteratorHasCurrentEvent(iterator, &hasEvent)
        }

        return descriptions
    }

    private func disposeCurrentSequence() {
        if let sequence {
            DisposeMusicSequence(sequence)
        }
        sequence = nil
    }

    deinit {
        disposeCurrentSequence()
        if let player {
            DisposeMusicPlayer(player)
        }
    }
}
