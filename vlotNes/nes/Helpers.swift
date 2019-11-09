//
//  MemoryHandler.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 25/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

// a bunch of smaller structs and protocols 

protocol MemoryHandler: AnyObject {
    
    func peak(_ address: Word) -> Byte
    func read(_ address: Word) -> Byte
    func write(_ address: Word, _ value: Byte)
    
}

protocol Mapper: AnyObject {
    
    var rom: [Byte] { get }
    var header: Header { get }
    
    var name: String { get }
    var currentSample: Float32? { get }
    var hasBattery: Bool { get }
    var version: Int { get }
    
    func reset(hard: Bool)
    func handleState(_ s: StateHandler)
    
    func cycle()
    func saveBattery() -> [Byte]
    func loadBattery(_ data: [Byte]) -> Bool
    
    func peak(_ address: Word) -> Byte
    func read(_ address: Word) -> Byte
    func write(_ address: Word, _ value: Byte)
    
    func ppuPeak(_ address: Word) -> Byte
    func ppuRead(_ address: Word) -> Byte
    func ppuWrite(_ address: Word, _ value: Byte)
    
}

struct Header {
    let banks: Int
    let chrBanks: Int
    let mapper: Int
    let verticalMirroring: Bool
    let battery: Bool
    let trainer: Bool
    let fourScreen: Bool
    
    // base offsets in rom file, mirroring and-value for chr and prg
    let base: Int
    let chrBase: Int
    let prgAnd: Int
    let chrAnd: Int
    
    init(rom: [Byte]) {
        banks = Int(rom[4])
        chrBanks = Int(rom[5])
        mapper = Int((rom[6] >> 4) | (rom[7] & 0xf0))
        verticalMirroring = (rom[6] & 0x1) > 0
        battery = (rom[6] & 0x2) > 0
        trainer = (rom[6] & 0x4) > 0
        fourScreen = (rom[6] & 0x8) > 0
        
        base = 0x10 + (trainer ? 512 : 0)
        chrBase = base + (banks * 0x4000)
        prgAnd = (banks * 0x4000) - 1
        chrAnd = chrBanks == 0 ? 0x1fff : (chrBanks * 0x2000) - 1
    }
    
    func getAsArray() -> [Int] {
        var result: [Int] = [0, 0, 0, 0]
        result[0] = banks
        result[1] = chrBanks
        result[2] = mapper
        result[3] |= verticalMirroring ? 1 : 0
        result[3] |= battery ? 0x100 : 0
        result[3] |= trainer ? 0x10000 : 0
        result[3] |= fourScreen ? 0x1000000 : 0
        return result
    }
}

enum EmulatorError: Error {
    case romLoadError(details: String)
    case stateLoadError(details: String)
    case batteryLoadError(details: String)
}
