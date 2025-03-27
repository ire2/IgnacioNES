
//
//  ContentView.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 11/25/24.
//



import SwiftUI

struct ContentView: View {
    @State private var emulator = Emulator()
    @State private var romName: String = "No ROM loaded"
    @State private var showFileImporter = false
    @State private var isLoaded = false
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("🎮 IgnacioNES")
                .font(.largeTitle)
                .bold()

            Text(romName)
                .foregroundColor(isLoaded ? .green : .red)

            HStack(spacing: 20) {
                Button("Load ROM") {
                    showFileImporter = true
                }

                Button(isRunning ? "⏸ Pause" : "▶️ Play") {
                    emulator.toggleRun()
                    isRunning.toggle()
                }
                .disabled(!isLoaded)

                Button("Step") {
                    emulator.stepOnce()
                }
                .disabled(!isLoaded || isRunning)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedFile = try result.get().first else { return }

                if emulator.loadROM(selectedFile) {
                    romName = selectedFile.lastPathComponent
                    isLoaded = true
                    isRunning = false
                } else {
                    romName = "❌ Failed to load ROM"
                    isLoaded = false
                    isRunning = false
                }

            } catch {
                romName = "❌ Error: \(error.localizedDescription)"
                isLoaded = false
                isRunning = false
            }
        }
        .frame(width: 420, height: 300)
        .padding()
    }
}

#Preview {
    ContentView()
}
