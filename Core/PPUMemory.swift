//
//  PPUMemoy.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 3/26/25.
//

import Foundation

class PPUMemory {
    var banks: [UInt8]
    var paletteRAM: [UInt8] = [UInt8](repeating: 0, count: 0x20)
    var nametables: [UInt8] = [UInt8](repeating: 0, count: 0x1000)
    var a12Timer: Int = 0
    var mapper: Mapper! // set after init

    init(cartridge: Cartridge) {
        // If cartridge has CHR ROM, use it; else allocate CHR RAM (common in some mappers)
        if cartridge.chrROM.isEmpty {
            self.banks = [UInt8](repeating: 0, count: 0x2000) // 8KB CHR RAM
        } else {
            self.banks = cartridge.chrROM
        }
    }

    func readMemory(_ address: UInt16) -> UInt8 {
        let addr = address % 0x4000
        switch addr {
        case 0x0000..<0x2000:
            return banks[Int(addr)]
        case 0x2000..<0x3000:
            return nametables[Int(addr % 0x1000)]
        case 0x3F00..<0x3F20:
            return paletteRAM[Int(addr % 0x20)]
        default:
            return 0
        }
    }

    func writeMemory(_ address: UInt16, data: UInt8) {
        let addr = address % 0x4000
        switch addr {
        case 0x0000..<0x2000:
            banks[Int(addr)] = data
        case 0x2000..<0x3000:
            nametables[Int(addr % 0x1000)] = data
        case 0x3F00..<0x3F20:
            paletteRAM[Int(addr % 0x20)] = data
        default:
            break
        }
    }

    func readPaletteMemory(_ address: UInt16) -> UInt8 {
        return paletteRAM[Int(address % 0x20)]
    }

    func dumpMemory() {
//        TODO
    }
}
class Memory {
    /* Main Memory
    -- $10000 --
     PRG-ROM Upper Bank
    -- $C000 --
     PRG-ROM Lower Bank
    -- $8000 --
     SRAM
    -- $6000 --
     Expansion ROM
    -- $4020 --
     I/O Registers
    -- $4000 --
     Mirrors $2000 - $2007
    -- $2008 --
     I/O Registers
    -- $2000 --
     Mirrors $0000 - $07FF
    -- $0800 --
     RAM
    -- $0200 --
     Stack
    -- $0100 --
     Zero Page
    -- $0000 --
    */
    
    enum NametableMirroringType {
        case vertical
        
        case horizontal
        
        case oneScreen
        
        case fourScreen
    }
    
    var mapper: Mapper
    
    var banks: [UInt8]
    
    var mirrorPRGROM = false
    
    init(mapper: Mapper) {
        // Dummy initialization
        banks = [UInt8](repeating: 0, count: 1)
        self.mapper = mapper
        setMapper(mapper)
    }
    
    func readMemory(_ address: UInt16) -> UInt8 {
        return 0
    }
    
    final func readTwoBytesMemory(_ address: UInt16) -> UInt16 {
        return UInt16(readMemory(address + 1)) << 8 | UInt16(readMemory(address))
    }
    
    func writeMemory(_ address: UInt16, data: UInt8) {
        fatalError("writeMemory function not overriden")
    }
    
    final func writeTwoBytesMemory(_ address: UInt16, data: UInt16) {
        writeMemory(address, data: UInt8(data & 0xFF))
        writeMemory(address + 1, data: UInt8((data & 0xFF00) >> 8))
    }
    
    func setMapper(_ mapper: Mapper) {
        fatalError("setMapper function not overriden")
    }
}
