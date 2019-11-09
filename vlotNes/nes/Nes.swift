//
//  Nes.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 27/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Nes: MemoryHandler {
    
    // state version
    let stateVersion: Int = 3
    
    // components
    var cpu: Cpu! = nil
    var ppu: Ppu! = nil
    var apu: Apu! = nil
    
    // ram
    var ram: [Byte] = [Byte](repeating: 0, count: 0x800)
    
    // rom
    var mapper: Mapper? = nil
    
    // cycle timer, to sync components
    // explicitly UInt64 because 32-bit values would only allow around 20 minutes of play
    var cycles: UInt64 = 0
    
    // oam dma
    var inDma: Bool = false
    var dmaTimer: Int = 0
    var dmaBase: Word = 0
    var dmaValue: Byte = 0
    
    // controllers
    var pad1state: Byte = 0
    var pad2state: Byte = 0
    var latchedPad1: Byte = 0
    var latchedPad2: Byte = 0
    var controllersLatched: Bool = false
    
    // irq
    var mapperIrqWanted: Bool = false
    var dmcIrqWanted: Bool = false
    var frameIrqWanted: Bool = false
    
    init() {
        cpu = Cpu(memoryHandler: self)
        ppu = Ppu(nes: self)
        apu = Apu(nes: self)
        reset(hard: true)
    }
    
    func reset(hard: Bool = false) {
        if hard {
            cycles = 0
            ram.fill(with: 0)
        }
        mapper?.reset(hard: hard)
        cpu.reset()
        ppu.reset()
        apu.reset()
        inDma = false
        dmaTimer = 0
        dmaBase = 0
        dmaValue = 0
        latchedPad1 = 0
        latchedPad2 = 0
        controllersLatched = false
        mapperIrqWanted = false
        dmcIrqWanted = false
        frameIrqWanted = false
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&inDma, &controllersLatched, &mapperIrqWanted, &dmcIrqWanted)
        s.handleBool(&frameIrqWanted)
        s.handleByte(&dmaValue, &latchedPad1, &latchedPad2)
        s.handleWord(&dmaBase)
        s.handleInt(&dmaTimer)
        s.handleUInt64(&cycles)
        s.handleByteArray(&ram)
        
        cpu.handleState(s)
        ppu.handleState(s)
        apu.handleState(s)
        mapper!.handleState(s)
    }
    
    func loadRom(rom: [Byte]) throws {
        if rom.count < 16 {
            throw EmulatorError.romLoadError(details: "Rom file is too small to be valid")
        }
        if rom[0] != 0x4e || rom[1] != 0x45 || rom[2] != 0x53 || rom[3] != 0x1a {
            throw EmulatorError.romLoadError(details: "Rom file does not have a valid iNES-header")
        }
        let header = Header(rom: rom)
        let neededLength = header.chrBase + (0x2000 * header.chrBanks)
        if rom.count < neededLength {
            throw EmulatorError.romLoadError(details: "Rom file is truncated")
        }
        // create mapper
        if let mapper = getMapperForRom(rom: rom, header: header) {
            self.mapper = mapper
        } else {
            throw EmulatorError.romLoadError(details: "Mapper \(header.mapper) is not supported")
        }
        reset(hard: true)
    }
    
    func unloadRom() {
        mapper = nil
        reset(hard: true)
    }
    
    func cycle() {
        if cycles % 3 == 0 {
            // handle controllers and irq
            if controllersLatched {
                latchedPad1 = pad1state
                latchedPad2 = pad2state
            }
            
            cpu.irqWanted = mapperIrqWanted || frameIrqWanted || dmcIrqWanted
            
            // cycle the cpu (or do dma), mapper and apu
            if !inDma {
                cpu.cycle()
            } else {
                // handle oam dma
                if dmaTimer > 0 {
                    if (dmaTimer & 0x1) == 0 {
                        ppu.write(4, dmaValue)
                    } else {
                        dmaValue = read(dmaBase + Word(dmaTimer / 2))
                    }
                }
                dmaTimer += 1
                if dmaTimer == 513 {
                    dmaTimer = 0
                    inDma = false
                }
            }
            
            mapper?.cycle()
            apu.cycle()
        }
        // cycle the ppu
        ppu.cycle()
        cycles += 1
    }
    
    func runFrame() {
        repeat {
            cycle()
        } while !(ppu.dot == 0 && ppu.line == 240)
    }
    
    func setPixels(inside: inout [Byte]) {
        ppu.setFrame(buffer: &inside)
    }
    
    func setSamples(inside: inout [Float32]) {
        // sample down from the 29780 samples the apu generates per frame to the 735 needed for 44.1 KHz audio
        let runAdd: Float = 29780 / 735
        var inputPos: Int = 0
        var running: Float = 0
        for i in 0..<735 {
            running += runAdd
            var total: Float32 = 0
            let avgCount = floor(running)
            for j in inputPos..<(inputPos + Int(avgCount)) {
                total += apu.output[j]
            }
            inside[i] = total / avgCount
            inputPos += Int(avgCount)
            running -= avgCount
        }
        apu.outputOffset = 0
    }
    
    func setButtonPressed(pad: Int, button: Int) {
        if pad == 1 {
            pad1state |= 1 << button
        } else if pad == 2 {
            pad2state |= 1 << button
        }
    }
    
    func setButtonReleased(pad: Int, button: Int) {
        if pad == 1 {
            pad1state &= (~(1 << button)) & 0xff
        } else if pad == 2 {
            pad2state &= (~(1 << button)) & 0xff
        }
    }
    
    func peak(_ address: Word) -> Byte {
        switch address {
        case 0..<0x2000:
            return ram[address & 0x7ff]
        case 0x2000..<0x4000:
            return ppu.peak(address & 0x7)
        case 0x4000..<0x4020:
            if address == 0x4014 {
                return 0 // not readable
            } else if address == 0x4016 {
                return 0x40 | (latchedPad1 & 0x1)
            } else if address == 0x4017 {
                return 0x40 | (latchedPad2 & 0x1)
            }
            return apu.peak(address)
        default:
            if let mapper = mapper {
                return mapper.peak(address)
            }
            return 0 // no rom loaded
        }
    }
    
    func read(_ address: Word) -> Byte {
        switch address {
        case 0..<0x2000:
            return ram[address & 0x7ff]
        case 0x2000..<0x4000:
            return ppu.read(address & 0x7)
        case 0x4000..<0x4020:
            if address == 0x4014 {
                return 0 // not readable
            } else if address == 0x4016 {
                let value = latchedPad1 & 0x1
                latchedPad1 >>= 1
                latchedPad1 |= 0x80
                return 0x40 | value
            } else if address == 0x4017 {
                let value = latchedPad2 & 0x1
                latchedPad2 >>= 1
                latchedPad2 |= 0x80
                return 0x40 | value
            }
            return apu.read(address)
        default:
            if let mapper = mapper {
                return mapper.read(address)
            }
            return 0 // no rom loaded
        }
    }
    
    func write(_ address: Word, _ value: Byte) {
        switch address {
        case 0..<0x2000:
            ram[address & 0x7ff] = value
        case 0x2000..<0x4000:
            ppu.write(address & 0x7, value)
        case 0x4000..<0x4020:
            if address == 0x4014 {
                inDma = true
                dmaBase = Word(value) << 8
                return
            } else if address == 0x4016 {
                controllersLatched = (value & 0x1) > 0
                return
            }
            apu.write(address, value)
        default:
            if let mapper = mapper {
                mapper.write(address, value)
            }
        }
    }
    
    // MARK: - Battery and state loading and saving
    
    func getBatteryData() -> [Byte]? {
        if !(mapper!.hasBattery) {
            return nil
        }
        return mapper!.saveBattery()
    }
    
    func setBatteryData(data: [Byte]) throws {
        if !(mapper!.hasBattery) {
            // loading battery for a rom without a battery save is always deemed valid
            return
        }
        if !(mapper!.loadBattery(data)) {
            throw EmulatorError.batteryLoadError(details: "Battery data is not valid")
        }
    }
    
    func getState() -> [Byte] {
        let s = StateHandler()
        s.writeInt(value: 0x46545356) // 'VSTF'
        s.writeInt(value: stateVersion)
        s.writeInt(value: 0) // length, will be corrected at end
        s.writeInt(value: getRomHash())
        var header = mapper!.header.getAsArray()
        s.handleIntArray(&header)
        s.writeInt(value: mapper!.version)
        handleState(s)
        s.placeInt(offset: 8, value: s.data.count) // correct length
        return s.data
    }
    
    func setState(state: [Byte]) throws {
        let s = StateHandler(data: state)
        if state.count < 16 {
            throw EmulatorError.stateLoadError(details: "State file is too small to be valid")
        }
        let identifier = s.readInt()
        let version = s.readInt()
        let length = s.readInt()
        let romHash = s.readInt()
        if identifier != 0x46545356 {
            throw EmulatorError.stateLoadError(details: "State file is not valid")
        }
        if version != stateVersion {
            throw EmulatorError.stateLoadError(details: "State file was made with a unsupported emulator version")
        }
        if length != state.count {
            throw EmulatorError.stateLoadError(details: "State file is truncated")
        }
        if romHash != getRomHash() {
            throw EmulatorError.stateLoadError(details: "State file was not made with this rom")
        }
        let realHeader = mapper!.header.getAsArray()
        var stateHeader: [Int] = [Int](repeating: 0, count: realHeader.count)
        s.handleIntArray(&stateHeader)
        if stateHeader != realHeader {
            throw EmulatorError.stateLoadError(details: "State file was made for a different rom-type")
        }
        let mapperVersion = s.readInt()
        if mapperVersion != mapper!.version {
            throw EmulatorError.stateLoadError(details: "State file was made with a unsupported mapper version")
        }
        // everything matches, load state
        handleState(s)
    }
    
    func getRomHash() -> Int {
        var total: UInt32 = 0
        for i in 0..<mapper!.rom.count {
            let value = mapper!.rom[i]
            total = total &+ UInt32(value)
        }
        return Int(total & 0x7fffffff)
    }
    
    // MARK: -  Mapper handling
    
    func getMapperForRom(rom: [Byte], header: Header) -> Mapper? {
        switch header.mapper {
        case 0: return Nrom(nes: self, rom: rom, header: header)
        case 1: return Mmc1(nes: self, rom: rom, header: header)
        case 2: return Uxrom(nes: self, rom: rom, header: header)
        case 3: return Cnrom(nes: self, rom: rom, header: header)
        case 4: return Mmc3(nes: self, rom: rom, header: header)
        case 7: return Axrom(nes: self, rom: rom, header: header)
        default:
            // not supported
            return nil
        }
    }
}
