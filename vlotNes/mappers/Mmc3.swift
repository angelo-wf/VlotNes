//
//  Mmc3.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 20/08/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Mmc3: Mapper {
    
    let nes: Nes
    let rom: [Byte]
    let header: Header
    
    let name: String = "MMC3"
    let hasBattery: Bool
    let currentSample: Float32? = nil
    let version: Int = 1
    
    var ppuRam: [Byte] = [Byte](repeating: 0, count: 0x800)
    var chrRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    var prgRam: [Byte] = [Byte](repeating: 0, count: 0x2000)
    
    var bankRegs: [Int] = [0, 0, 0, 0, 0, 0, 0, 0]
    var horizontalMirroring: Bool = false
    var prgStartFixed: Bool = true
    var chrA11Invertion: Bool = true
    var regSelect: Byte = 0
    var reloadIrq: Bool = false
    var irqLatch: Byte = 0
    var irqEnabled: Bool = false
    var irqCounter: Byte = 0
    var lastRead: Word = 0
    
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
        bankRegs.fill(with: 0)
        horizontalMirroring = false
        prgStartFixed = true
        chrA11Invertion = true
        regSelect = 0
        reloadIrq = false
        irqLatch = 0
        irqEnabled = false
        irqCounter = 0
        lastRead = 0
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&horizontalMirroring, &prgStartFixed, &chrA11Invertion, &reloadIrq)
        s.handleBool(&irqEnabled)
        s.handleByte(&regSelect, &irqLatch, &irqCounter)
        s.handleWord(&lastRead)
        s.handleIntArray(&bankRegs)
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
        if prgStartFixed {
            if address < 0xa000 {
                final = (header.banks * 2 - 2) * 0x2000 + Int(address & 0x1fff)
            } else if address < 0xc000 {
                final = bankRegs[7] * 0x2000 + Int(address & 0x1fff)
            } else if address < 0xe000 {
                final = bankRegs[6] * 0x2000 + Int(address & 0x1fff)
            } else {
                final = (header.banks * 2 - 1) * 0x2000 + Int(address & 0x1fff)
            }
        } else {
            if address < 0xa000 {
                final = bankRegs[6] * 0x2000 + Int(address & 0x1fff)
            } else if address < 0xc000 {
                final = bankRegs[7] * 0x2000 + Int(address & 0x1fff)
            } else if address < 0xe000 {
                final = (header.banks * 2 - 2) * 0x2000 + Int(address & 0x1fff)
            } else {
                final = (header.banks * 2 - 1) * 0x2000 + Int(address & 0x1fff)
            }
        }
        return final & header.prgAnd
    }
    
    private func getMirroringAdr(_ address: Word) -> Word {
        if horizontalMirroring {
            return ((address & 0x800) >> 1) | (address & 0x3ff)
        }
        return address & 0x7ff
    }
    
    private func getChrAdr(_ address: Word) -> Int {
        var adr = address
        if chrA11Invertion {
            adr ^= 0x1000
        }
        var final = 0
        if adr < 0x800 {
            final = (bankRegs[0] >> 1) * 0x800 + Int(adr & 0x7ff)
        } else if adr < 0x1000 {
            final = (bankRegs[1] >> 1) * 0x800 + Int(adr & 0x7ff)
        } else if adr < 0x1400 {
            final = bankRegs[2] * 0x400 + Int(adr & 0x3ff)
        } else if adr < 0x1800 {
            final = bankRegs[3] * 0x400 + Int(adr & 0x3ff)
        } else if adr < 0x1c00 {
            final = bankRegs[4] * 0x400 + Int(adr & 0x3ff)
        } else {
            final = bankRegs[5] * 0x400 + Int(adr & 0x3ff)
        }
        return final & header.chrAnd
    }
    
    private func clockIrq() {
        if irqCounter == 0 || reloadIrq {
            irqCounter = irqLatch
            reloadIrq = false
        } else {
            irqCounter -= 1
        }
        if irqCounter == 0 && irqEnabled {
            nes.mapperIrqWanted = true
        }
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
        if address < 0x6000 {
            return
        }
        if address < 0x8000 {
            prgRam[address & 0x1fff] = value
            return
        }
        switch address & 0xe001 {
        case 0x8000:
            regSelect = value & 0x7
            prgStartFixed = (value & 0x40) > 0
            chrA11Invertion = (value & 0x80) > 0
        case 0x8001:
            bankRegs[regSelect] = Int(value)
        case 0xa000:
            horizontalMirroring = (value & 0x01) > 0
        case 0xa001:
            // ram protection not emulated
            break
        case 0xc000:
            irqLatch = value
        case 0xc001:
            reloadIrq = true
        case 0xe000:
            irqEnabled = false
            nes.mapperIrqWanted = false
        default:
            irqEnabled = true
        }
    }
    
    func ppuPeak(_ address: Word) -> Byte {
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
    
    func ppuRead(_ address: Word) -> Byte {
        if address < 0x2000 {
            // clock irq
            // TODO: currently only for chr-reads, but should always happen with a 8-cycle cooldown
            if (lastRead & 0x1000) == 0 && (address & 0x1000) > 0 {
                clockIrq()
            }
            lastRead = address
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
