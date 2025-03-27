//
//  Mapper.swift
//  SwiftNES
//
// Created by Ignacio Estrada on 11/25/24.
//

import Foundation

class Mapper {
    var cpuMemory: CPUMemory!
    var ppuMemory: PPUMemory!
    
    var chrBankCount: UInt8
    var prgBankCount: UInt8
    
    init() {
        cpuMemory = nil
        ppuMemory = nil
        chrBankCount = 0
        prgBankCount = 0
    }
    
    func read(_ address: UInt16) -> UInt8 {
        switch address {
        case 0x6000 ..< 0x8000:
            return cpuMemory.sram[Int(address - 0x6000)]
        case 0x8000 ..< 0xC000:
            return cpuMemory.banks[Int(address - 0x8000)]
        case 0xC000 ... 0xFFFF:
            return cpuMemory.banks[Int(address - 0x8000)]
            default:
                break
        }
        
        return 0
    }
    
    func write(_ address: UInt16, data: UInt8) {
        switch(address) {
        case 0x0000 ..< 0x1000:
            ppuMemory.banks[Int(address)] = data
        case 0x1000 ..< 0x2000:
            ppuMemory.banks[Int(address)] = data
        case 0x6000 ..< 0x8000:
            cpuMemory.sram[Int(address - 0x6000)] = data
        case 0x8000 ..< 0xC000:
            cpuMemory.banks[Int(address - 0x8000)] = data
        case 0xC000 ... 0xFFFF:
            cpuMemory.banks[Int(address - 0x8000)] = data
        default:
                break
        }
    }
    
    func step() {
        
    }
}
