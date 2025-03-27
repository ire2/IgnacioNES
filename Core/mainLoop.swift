//
//  mainLoop.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 11/25/24.
//

import Foundation

class MainLoop {
    private var timer: Timer?
    private(set) var isRunning = false
    private let cpu: CPU
    let ticksPerSecond: Double = 60.0 // aiming for ~ 60hz

    init(cpu: CPU) {
        self.cpu = cpu
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / ticksPerSecond, repeats: true) { _ in
            self.cpu.step()
            
        }
        print("▶️ Main loop started")
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        print("⏸️ Main loop paused")
    }

    func toggle() {
        isRunning ? pause() : start()
    }
}
