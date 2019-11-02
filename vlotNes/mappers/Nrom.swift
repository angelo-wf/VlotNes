//
//  Nrom.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 30/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Nrom: Mapper {
    
    let nes: Nes
    let rom: [Byte]
    let header: Header
    
    let name: String = "NROM"
    let hasBattery: Bool
    let currentSample: Float32? = nil
    let version: Int = 1
    
    var ppuRam: [Byte] = [Byte](repeating: 0, count: 0x800)
    var chrRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    var prgRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    
    init(nes: Nes, rom: [Byte], header: Header) {
        self.nes = nes
        self.rom = rom
        self.header = header
        hasBattery = header.battery
        reset(hard: true)
    }
    
    func reset(hard: Bool = false) {
        if hard {
            chrRam.fill(with: 0)
            prgRam.fill(with: 0)
        }
        ppuRam.fill(with: 0)
    }
    
    func handleState(_ s: StateHandler) {
        s.handleByteArray(&ppuRam)
        if header.chrBanks == 0 {
            s.handleByteArray(&chrRam)
        }
        s.handleByteArray(&prgRam)
    }
    
    func cycle() {
        return
    }
    
    func saveBattery() -> [Byte] {
        var data: [Byte] = [Byte](repeating: 0, count: 0x2000)
        for i in 0..<data.count {
            data[i] = prgRam[i]
        }
        return data
    }
    
    func loadBattery(_ data: [Byte]) -> Bool {
        if data.count != 0x2000 {
            return false
        }
        for i in 0..<data.count {
            prgRam[i] = data[i]
        }
        return true
    }
    
    private func getRomAdr(_ address: Word) -> Int {
        if header.banks == 2 {
            return Int(address & 0x7fff)
        }
        return Int(address & 0x3fff)
    }
    
    private func getMirroringAdr(_ address: Word) -> Word {
        if header.verticalMirroring {
            return address & 0x7ff
        }
        return ((address & 0x800) >> 1) | (address & 0x3ff)
    }
    
    private func getChrAdr(_ address: Word) -> Int {
        return Int(address)
    }
    
    func peak(_ address: Word) -> Byte {
        return read(address)
    }
    
    func read(_ address: Word) -> Byte {
        if address < 0x6000 {
            return 0 // not readable
        }
        if address < 0x8000 {
            return prgRam[address & 0x1fff]
        }
        return rom[header.base + getRomAdr(address)]
    }
    
    func write(_ address: Word, _ value: Byte) {
        if address < 0x6000 || address >= 0x8000 {
            return
        }
        prgRam[address & 0x1fff] = value
    }
    
    func ppuPeak(_ address: Word) -> Byte {
        return ppuRead(address)
    }
    
    func ppuRead(_ address: Word) -> Byte {
        if address < 0x2000 {
            if header.chrBanks == 0 {
                return chrRam[getChrAdr(address)]
            } else {
                return rom[header.chrBase + getChrAdr(address)]
            }
        } else {
            return ppuRam[getMirroringAdr(address)]
        }
    }
    
    func ppuWrite(_ address: Word, _ value: Byte) {
        if address < 0x2000 {
            if header.chrBanks == 0 {
                chrRam[getChrAdr(address)] = value
                return
            } else {
                return // not writable
            }
        } else {
            ppuRam[getMirroringAdr(address)] = value
        }
    }
}
