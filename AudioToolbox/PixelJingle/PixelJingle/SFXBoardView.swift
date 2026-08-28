//
//  SFXBoardView.swift
//  PixelJingle
//

import SwiftUI

struct SFXBoardView: View {
    @StateObject private var soundManager = SystemSoundManager()
    @State private var flashingEffect: SystemSoundManager.Effect?

    private let columns = [GridItem(.adaptive(minimum: 140))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(SystemSoundManager.Effect.allCases) { effect in
                        Button {
                            flashingEffect = effect
                            soundManager.play(effect)
                        } label: {
                            Text(effect.label)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(flashingEffect == effect ? .yellow : .indigo)
                    }
                }
                .padding()
            }
            .navigationTitle("SFX Board")
            .onChange(of: soundManager.lastCompletedEffect) { _, completed in
                if completed == flashingEffect {
                    flashingEffect = nil
                }
            }
        }
    }
}

#Preview {
    SFXBoardView()
}
