//
//  ContentView.swift
//  PixelJingle
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SFXBoardView()
                .tabItem {
                    Label("SFX Board", systemImage: "speaker.wave.2.fill")
                }

            JinglePlayerView()
                .tabItem {
                    Label("Jingle Player", systemImage: "music.note.list")
                }
        }
    }
}
