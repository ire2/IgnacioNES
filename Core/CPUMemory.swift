//
//  CPUMemory.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 11/25/24.
//

import Foundation

class CPUMemory {
    private var ram: [UInt8] = [UInt8](repeating: 0, count: 0x0800) // 2KB RAM
    let cartridge: Cartridge
    var sram: [UInt8]
    var banks: [UInt8]

    init(cartridge: Cartridge) {
        self.cartridge = cartridge
        self.sram = [UInt8](repeating: 0, count: 0x2000) // 8KB SRAM
        self.banks = cartridge.prgROM // Just mirror it for now
    }

    func read(_ address: UInt16) -> UInt8 {
        switch address {
        case 0x0000..<0x2000:
            return ram[Int(address % 0x0800)]
        case 0x6000..<0x8000:
            return sram[Int(address - 0x6000)]
        case 0x8000...0xFFFF:
            return banks[Int(address - 0x8000) % banks.count]
        default:
            return 0
        }
    }

    func write(_ address: UInt16, value: UInt8) {
        switch address {
        case 0x0000..<0x2000:
            ram[Int(address % 0x0800)] = value
        case 0x6000..<0x8000:
            sram[Int(address - 0x6000)] = value
        // Ignore writes to ROM
        default: break
        }
    }
}
