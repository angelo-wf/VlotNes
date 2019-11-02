//
//  Cnrom.swift
//  VlotNes
//
//  Created by Elzo Doornbos on 07/09/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Cnrom: Mapper {
    
    let nes: Nes
    let rom: [Byte]
    let header: Header
    
    let name: String = "CNROM"
    let hasBattery: Bool = false
    let currentSample: Float32? = nil
    let version: Int = 1
    
    var ppuRam: [Byte] = [Byte](repeating: 0, count: 0x800)
    var chrRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    
    var chrBank: Int = 0
    
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
        chrBank = 0
    }
    
    func handleState(_ s: StateHandler) {
        s.handleInt(&chrBank)
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
        let adr = chrBank * 0x2000 + Int(address & 0x1fff)
        return adr & header.chrAnd
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
        chrBank = Int(value)
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
