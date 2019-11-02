//
//  Uxrom.swift
//  VlotNes
//
//  Created by Elzo Doornbos on 07/09/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Uxrom: Mapper {
    
    let nes: Nes
    let rom: [Byte]
    let header: Header
    
    let name: String = "UxROM"
    let hasBattery: Bool = false
    let currentSample: Float32? = nil
    let version: Int = 1
    
    var ppuRam: [Byte] = [Byte](repeating: 0, count: 0x800)
    var chrRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    
    var prgBank: Int = 0
    
    init(nes: Nes, rom: [Byte], header: Header) {
        self.nes = nes
        self.rom = rom
        self.header = header
        reset(hard: true)
    }
    
    func reset(hard: Bool = false) {
        if hard {
            chrRam.fill(with: 0)
        }
        ppuRam.fill(with: 0)
        prgBank = 0
    }
    
    func handleState(_ s: StateHandler) {
        s.handleInt(&prgBank)
        s.handleByteArray(&ppuRam)
        if header.chrBanks == 0 {
            s.handleByteArray(&chrRam)
        }
    }
    
    func cycle() {
        return
    }
    
    func saveBattery() -> [Byte] {
        return []
    }
    
    func loadBattery(_ data: [Byte]) -> Bool {
        return true
    }
    
    private func getRomAdr(_ address: Word) -> Int {
        var final = 0
        if address < 0xc000 {
            final = prgBank * 0x4000 + Int(address & 0x3fff)
        } else {
            final = (header.banks - 1) * 0x4000 + Int(address & 0x3fff)
        }
        return final & header.prgAnd
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
        if address < 0x8000 {
            return 0 // not readable
        }
        return rom[header.base + getRomAdr(address)]
    }
    
    func write(_ address: Word, _ value: Byte) {
        if address < 0x8000 {
            return
        }
        prgBank = Int(value)
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
