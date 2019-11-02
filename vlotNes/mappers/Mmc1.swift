//
//  Mmc1.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 18/08/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Mmc1: Mapper {
    
    let nes: Nes
    let rom: [Byte]
    let header: Header
    
    let name: String = "MMC1"
    let hasBattery: Bool
    let currentSample: Float32? = nil
    let version: Int = 1
    
    var ppuRam: [Byte] = [Byte](repeating: 0, count: 0x800)
    var chrRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    var prgRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    
    var shiftReg: Byte = 0
    var shiftCount: Int = 0
    
    var mirroring: Byte = 0
    var prgMode: Byte = 3
    var chrMode: Byte = 1
    var chrBank0: Int = 0
    var chrBank1: Int = 0
    var prgBank: Int = 0
    var ramDisabled: Bool = false
    
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
            if !hasBattery {
                // only reset prg-ram if it is not battery-backed
                prgRam.fill(with: 0)
            }
        }
        ppuRam.fill(with: 0)
        shiftReg = 0
        shiftCount = 0
        mirroring = 0
        prgMode = 3
        chrMode = 1
        chrBank0 = 0
        chrBank1 = 0
        prgBank = 0
        ramDisabled = false
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&ramDisabled)
        s.handleByte(&shiftReg, &prgMode, &chrMode, &mirroring)
        s.handleInt(&shiftCount, &chrBank0, &chrBank1, &prgBank)
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
        var final = 0
        switch prgMode {
        case 2:
            if address < 0xc000 {
                final = Int(address & 0x3fff)
            } else {
                final = prgBank * 0x4000 + Int(address & 0x3fff)
            }
        case 3:
            if address < 0xc000 {
                final = prgBank * 0x4000 + Int(address & 0x3fff)
            } else {
                final = (header.banks - 1) * 0x4000 + Int(address & 0x3fff)
            }
        default:
            final = 0x8000 * (prgBank >> 1) + Int(address & 0x7fff)
        }
        return final & header.prgAnd
    }
    
    private func getMirroringAdr(_ address: Word) -> Word {
        switch mirroring {
        case 0:
            // 1-screeen A
            return address & 0x3ff
        case 1:
            // 1-screen B
            return 0x400 | (address & 0x3ff)
        case 2:
            // vertical
            return address & 0x7ff
        default:
            // horizontal
            return ((address & 0x800) >> 1) | (address & 0x3ff)
        }
    }
    
    private func getChrAdr(_ address: Word) -> Int {
        var final = 0
        if chrMode == 1 {
            if address < 0x1000 {
                final = chrBank0 * 0x1000 + Int(address & 0xfff)
            } else {
                final = chrBank1 * 0x1000 + Int(address & 0xfff)
            }
        } else {
            final = (chrBank0 >> 1) * 0x2000 + Int(address)
        }
        return final & header.chrAnd
    }
    
    func peak(_ address: Word) -> Byte {
        return read(address)
    }
    
    func read(_ address: Word) -> Byte {
        if address < 0x6000 {
            return 0 // not readable
        }
        if address < 0x8000 {
            if ramDisabled {
                return 0 // ram not enabled
            }
            return prgRam[address & 0x1fff]
        }
        return rom[header.base + getRomAdr(address)]
    }
    
    func write(_ address: Word, _ value: Byte) {
        if address < 0x6000 {
            return
        }
        if address < 0x8000 {
            if ramDisabled {
                return // ram disabled
            }
            prgRam[address & 0x1fff] = value
            return
        }
        if (value & 0x80) > 0 {
            shiftCount = 0
            shiftReg = 0
        } else {
            shiftReg |= (value & 0x1) << shiftCount
            shiftCount += 1
            if shiftCount == 5 {
                switch address & 0xe000 {
                case 0x8000:
                    mirroring = shiftReg & 0x3
                    prgMode = (shiftReg & 0xc) >> 2
                    chrMode = (shiftReg & 0x10) >> 4
                case 0xa000:
                    chrBank0 = Int(shiftReg)
                case 0xc000:
                    chrBank1 = Int(shiftReg)
                default:
                    prgBank = Int(shiftReg & 0xf)
                    ramDisabled = (shiftReg & 0x10) > 0
                }
                shiftCount = 0
                shiftReg = 0
            }
        }
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
