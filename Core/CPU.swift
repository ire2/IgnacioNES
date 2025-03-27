//
//  CPU.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 3/26/25.
//

import Foundation


class CPU {
    // MARK: - Registers
    var A: UInt8 = 0      // Accumulator
    var X: UInt8 = 0      // Index X
    var Y: UInt8 = 0      // Index Y
    var SP: UInt8 = 0xFD  // Stack Pointer (starts here by convention)
    var PC: UInt16 = 0    // Program Counter
    var status: UInt8 = 0x24 // Processor Status: unused bits set
    var unsupportedOpcodeCount = 0 //Since I havent fully implemented every opcode it keeps this
    var nmiRequested: Bool = false
    var ppu: PPU?

    let memory: CPUMemory
    var running = true

    init(memory: CPUMemory) {
        self.memory = memory
    }

    func reset() {
        // Read reset vector at 0xFFFC-FFFD
        let lo = UInt16(memory.read(0xFFFC))
        let hi = UInt16(memory.read(0xFFFD))
        PC = (hi << 8) | lo
        print("\u{1F501} CPU Reset: PC set to \(String(format: "0x%04X", PC)))")
    }

    func step() {
        if nmiRequested {
            handleNMI()
            nmiRequested = false
        }

        if !running {
                   return // Stop execution if the CPU has been halted
               }
        let opcode = memory.read(PC)
        print("\u{1F539} Executing opcode \(String(format: "0x%02X", opcode)) at PC: \(String(format: "0x%04X", PC)))")
        PC &+= 1
        decodeAndExecute(opcode)
    }

    func decodeAndExecute(_ opcode: UInt8) {
        switch opcode {
        case 0xD8: // CLD - Clear Decimal Mode
            unsupportedOpcodeCount = 0
            status &= 0b11110111
            print("   → CLD: Clear Decimal Flag")

        case 0xA9: // LDA Immediate
            unsupportedOpcodeCount = 0
            let value = memory.read(PC)
            PC &+= 1
            A = value
            updateZeroAndNegativeFlags(for: A)
            print("   → LDA #\(String(format: "0x%02X", value)) → A = \(A)")

        case 0xA2: // LDX Immediate
            unsupportedOpcodeCount = 0
            let value = memory.read(PC)
            PC &+= 1
            X = value
            updateZeroAndNegativeFlags(for: X)
            print("   → LDX #\(String(format: "0x%02X", value)) → X = \(X)")

        case 0xA0: // LDY Immediate
            unsupportedOpcodeCount = 0
            let value = memory.read(PC)
            PC &+= 1
            Y = value
            updateZeroAndNegativeFlags(for: Y)
            print("   → LDY #\(String(format: "0x%02X", value)) → Y = \(Y)")

        case 0x8D: // STA Absolute
            unsupportedOpcodeCount = 0
            let lo = UInt16(memory.read(PC))
            let hi = UInt16(memory.read(PC + 1))
            let addr = (hi << 8) | lo
            PC &+= 2
            memory.write(addr, value: A)
            print("   → STA $\(String(format: "%04X", addr)) ← A = \(A)")

        case 0xE8: // INX
            unsupportedOpcodeCount = 0
            X &+= 1
            updateZeroAndNegativeFlags(for: X)
            print("   → INX → X = \(X)")

        case 0x00: // BRK - break (halt execution)
            unsupportedOpcodeCount = 0
            print("   → BRK (Interrupt — halting emulator loop if running)")
            running = false

        case 0xEA: // NOP
            unsupportedOpcodeCount = 0
            print("   → NOP (No Operation)")

        case 0x4C: // JMP Absolute
            unsupportedOpcodeCount = 0
            let lo = UInt16(memory.read(PC))
            let hi = UInt16(memory.read(PC + 1))
            let addr = (hi << 8) | lo
            PC = addr
            print("   → JMP $\(String(format: "%04X", addr))")
            
        case 0x78: // SEI - Set Interrupt Disable
            unsupportedOpcodeCount = 0
            status |= 0b00000100
            print("   → SEI: Set Interrupt Disable Flag")

        case 0x8E: // STX Absolute
            unsupportedOpcodeCount = 0
            let lo = UInt16(memory.read(PC))
            let hi = UInt16(memory.read(PC + 1))
            let addr = (hi << 8) | lo
            PC &+= 2
            memory.write(addr, value: X)
            print("   → STX $\(String(format: "%04X", addr)) ← X = \(X)")
        case 0xAD:
            unsupportedOpcodeCount = 0
            let lo = UInt16(memory.read(PC))
            let hi = UInt16(memory.read(PC + 1))
            let addr = (hi << 8) | lo
            PC &+= 2
            A = memory.read(addr)
            updateZeroAndNegativeFlags(for: A)
            print("   → LDA $\(String(format: "%04X", addr)) → A = \(A)")
        case 0xCA:
            unsupportedOpcodeCount = 0
            X &-= 1
            updateZeroAndNegativeFlags(for: X)
            print("   → DEX → X = \(X)")
        case 0x9A:
            unsupportedOpcodeCount = 0
            SP = X
            print("   → TXS: Transfer X to Stack Pointer → SP = \(SP)")
        case 0xEE:
            unsupportedOpcodeCount = 0
            let lo = UInt16(memory.read(PC))
            let hi = UInt16(memory.read(PC + 1))
            let addr = (hi << 8) | lo
            PC &+= 2
            var value = memory.read(addr)
            value &+= 1
            memory.write(addr, value: value)
            updateZeroAndNegativeFlags(for: value)
            print("   → INC $\(String(format: "%04X", addr)) → \(value)")

        default:
            unsupportedOpcodeCount += 1
            if unsupportedOpcodeCount >= 50 {
                print("💥 Too many unsupported opcodes in a row. Halting CPU.")
                fatalError("🚫 Emulator halted due to opcode storm.")
            }
        }
    }

    private func updateZeroAndNegativeFlags(for value: UInt8) {
        // Z flag
        if value == 0 {
            status |= 0b00000010
        } else {
            status &= 0b11111101
        }

        // N flag
        if value & 0x80 != 0 {
            status |= 0b10000000
        } else {
            status &= 0b01111111
        }
    }
    func handleNMI() {
        print("🚨 Handling NMI interrupt")
        pushStack(UInt8((PC >> 8) & 0xFF)) // high byte
        pushStack(UInt8(PC & 0xFF))        // low byte
        pushStack(status)

        // Fetch NMI vector from 0xFFFA-0xFFFB
        let lo = UInt16(memory.read(0xFFFA))
        let hi = UInt16(memory.read(0xFFFB))
        PC = (hi << 8) | lo
    }
    
    func queueNMI() {
        nmiRequested = true
        print("⚡️ NMI Queued")
    }

    func clearNMI() {
        nmiRequested = false
        print("🔕 NMI Cleared")
    }
    func pushStack(_ value: UInt8) {
        memory.write(0x0100 + UInt16(SP), value: value)
        SP &-= 1
    }
    func startOAMTransfer() {
        guard let ppu = ppu else {
            print("❌ PPU not connected to CPU.")
            return
        }

        let baseAddress = UInt16(ppu.OAMDMA) << 8
        for i in 0..<256 {
            let byte = memory.read(baseAddress + UInt16(i))
            ppu.writeDMA(UInt16(i), data: byte)
        }

        print("🚚 OAM DMA transfer complete from \(String(format: "0x%04X", baseAddress))")
    }
}
