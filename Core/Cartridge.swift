//
//  Cartridge.swift
//  IgnacioNES
//
//  Created by Ignacio Estrada on 11/25/24.
//


import Foundation

class Cartridge {
    var prgROM: [UInt8] = []
    var chrROM: [UInt8] = []

    init?(url: URL) {
        print("🧪 Trying to load file at path: \(url.path)")

        guard url.startAccessingSecurityScopedResource() else {
            print("💥 Failed to access security-scoped resource")
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            print("💥 Could not read ROM file")
            return nil
        }

        guard data.count >= 16,
              data[0] == 0x4E, // 'N'
              data[1] == 0x45, // 'E'
              data[2] == 0x53, // 'S'
              data[3] == 0x1A else {
            print("💥 Invalid iNES header")
            return nil
        }

        let prgSize = Int(data[4]) * 16 * 1024
        let chrSize = Int(data[5]) * 8 * 1024
        let hasTrainer = (data[6] & 0b00000100) != 0
        let trainerSize = hasTrainer ? 512 : 0

        let prgStart = 16 + trainerSize
        let chrStart = prgStart + prgSize

        if data.count < chrStart + chrSize {
            print("💥 File too small for expected PRG+CHR size")
            return nil
        }

        prgROM = Array(data[prgStart..<chrStart])

        if chrSize > 0 {
            chrROM = Array(data[chrStart..<chrStart + chrSize])
        } else {
            chrROM = Array(repeating: 0, count: 8192) // CHR RAM fallback
        }

        print("✅ ROM loaded: PRG = \(prgROM.count), CHR = \(chrROM.count)")
    }
}
