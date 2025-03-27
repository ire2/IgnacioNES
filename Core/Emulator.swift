//
//  Emulator.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 3/26/25.
//

import Foundation

class Emulator {
    var cpu: CPU?
    var ppu: PPU?
    var loop: MainLoop?


    func loadROM(_ url: URL) -> Bool {
            guard let cart = Cartridge(url: url) else {
                print("❌ Failed to parse ROM.")
                return false
            }

            let cpuMemory = CPUMemory(cartridge: cart)
            let ppuMemory = PPUMemory(cartridge: cart)
            let cpu = CPU(memory: cpuMemory)
            self.ppu = PPU(cpuMemory: cpuMemory, ppuMemory: ppuMemory)
            self.cpu = cpu
            self.cpu?.ppu = self.ppu
            cpu.reset()
            
        
        
            self.loop = MainLoop(cpu: cpu)

            print("✅ Emulator loaded and CPU reset.")
            return true
        }

        func toggleRun() {
            loop?.toggle()
        }

        func pause() {
            loop?.pause()
        }

        func stepOnce() {
            cpu?.step()
        }
    }
