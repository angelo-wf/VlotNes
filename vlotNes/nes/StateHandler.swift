//
//  StateHandler.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 20/08/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

class StateHandler {
    
    var data: [Byte] = []
    var offset: Int
    var saving: Bool
    
    init() {
        // for saving the state
        offset = 0
        saving = true
    }
    
    init(data: [Byte]) {
        // for loading the state
        self.data = data
        offset = 0
        saving = false
    }
    
    func handleBool(_ value: inout Bool) {
        if saving {
            data += [0]
            data[offset] = value ? 1 : 0
        } else {
            value = data[offset] > 0
        }
        offset += 1
    }
    
    func handleByte(_ value: inout Byte) {
        if saving {
            data += [0]
            data[offset] = value
        } else {
            value = data[offset]
        }
        offset += 1
    }
    
    func handleWord(_ value: inout Word) {
        if saving {
            data += [0, 0]
            data[offset] = Byte(value & 0xff)
            data[offset + 1] = Byte(value >> 8)
        } else {
            value = Word(data[offset])
            value |= Word(data[offset + 1]) << 8
        }
        offset += 2
    }
    
    func handleInt(_ value: inout Int) {
        if saving {
            data += [0, 0, 0, 0]
            let uint = UInt(bitPattern: value)
            data[offset] = Byte(uint & 0xff)
            data[offset + 1] = Byte((uint & 0xff00) >> 8)
            data[offset + 2] = Byte((uint & 0xff0000) >> 16)
            data[offset + 3] = Byte((uint & 0xff000000) >> 24)
        } else {
            var uint: UInt = 0
            uint = UInt(data[offset])
            uint |= UInt(data[offset + 1]) << 8
            uint |= UInt(data[offset + 2]) << 16
            uint |= UInt(data[offset + 3]) << 24
            value = Int(bitPattern: uint)
        }
        offset += 4
    }
    
    func handleUInt64(_ value: inout UInt64) {
        if saving {
            data += [0, 0, 0, 0, 0, 0, 0, 0]
            data[offset] = Byte(value & 0xff)
            data[offset + 1] = Byte((value & 0xff00) >> 8)
            data[offset + 2] = Byte((value & 0xff0000) >> 16)
            data[offset + 3] = Byte((value & 0xff000000) >> 24)
            data[offset + 4] = Byte((value & 0xff00000000) >> 32)
            data[offset + 5] = Byte((value & 0xff0000000000) >> 40)
            data[offset + 6] = Byte((value & 0xff000000000000) >> 48)
            data[offset + 7] = Byte((value & 0xff00000000000000) >> 56)
        } else {
            value = UInt64(data[offset])
            value |= UInt64(data[offset + 1]) << 8
            value |= UInt64(data[offset + 2]) << 16
            value |= UInt64(data[offset + 3]) << 24
            value |= UInt64(data[offset + 4]) << 32
            value |= UInt64(data[offset + 5]) << 40
            value |= UInt64(data[offset + 6]) << 48
            value |= UInt64(data[offset + 7]) << 56
        }
        offset += 8
    }
    
    func handleByteArray(_ value: inout [Byte]) {
        for i in 0..<value.count {
            handleByte(&value[i])
        }
    }
    
    func handleIntArray(_ value: inout [Int]) {
        for i in 0..<value.count {
            handleInt(&value[i])
        }
    }
    
    // MARK: - Reading and writing directly
    
    func placeInt(offset: Int, value: Int) {
        let uint = UInt(bitPattern: value)
        data[offset] = Byte(uint & 0xff)
        data[offset + 1] = Byte((uint & 0xff00) >> 8)
        data[offset + 2] = Byte((uint & 0xff0000) >> 16)
        data[offset + 3] = Byte((uint & 0xff000000) >> 24)
    }
    
    func writeByte(value: Byte) {
        data += [0]
        data[offset] = value
        offset += 1
    }
    
    func readByte() -> Byte {
        let value = data[offset]
        offset += 1
        return value
    }
    
    func writeWord(value: Word) {
        data += [0, 0]
        data[offset] = Byte(value & 0xff)
        data[offset + 1] = Byte(value >> 8)
        offset += 2
    }
    
    func readWord() -> Word {
        var value = Word(data[offset])
        value |= Word(data[offset + 1]) << 8
        offset += 2
        return value
    }
    
    func writeInt(value: Int) {
        data += [0, 0, 0, 0]
        let uint = UInt(bitPattern: value)
        data[offset] = Byte(uint & 0xff)
        data[offset + 1] = Byte((uint & 0xff00) >> 8)
        data[offset + 2] = Byte((uint & 0xff0000) >> 16)
        data[offset + 3] = Byte((uint & 0xff000000) >> 24)
        offset += 4
    }
    
    func readInt() -> Int {
        var uint: UInt = 0
        uint = UInt(data[offset])
        uint |= UInt(data[offset + 1]) << 8
        uint |= UInt(data[offset + 2]) << 16
        uint |= UInt(data[offset + 3]) << 24
        offset += 4
        return Int(bitPattern: uint)
    }
    
    // MARK: - Functions for multiple at once (up to 4)
    
    func handleBool(_ value1: inout Bool, _ value2: inout Bool) {
        handleBool(&value1)
        handleBool(&value2)
    }
    
    func handleBool(_ value1: inout Bool, _ value2: inout Bool, _ value3: inout Bool) {
        handleBool(&value1)
        handleBool(&value2)
        handleBool(&value3)
    }
    
    func handleBool(_ value1: inout Bool, _ value2: inout Bool, _ value3: inout Bool, _ value4: inout Bool) {
        handleBool(&value1)
        handleBool(&value2)
        handleBool(&value3)
        handleBool(&value4)
    }
    
    func handleByte(_ value1: inout Byte, _ value2: inout Byte) {
        handleByte(&value1)
        handleByte(&value2)
    }
    
    func handleByte(_ value1: inout Byte, _ value2: inout Byte, _ value3: inout Byte) {
        handleByte(&value1)
        handleByte(&value2)
        handleByte(&value3)
    }
    
    func handleByte(_ value1: inout Byte, _ value2: inout Byte, _ value3: inout Byte, _ value4: inout Byte) {
        handleByte(&value1)
        handleByte(&value2)
        handleByte(&value3)
        handleByte(&value4)
    }
    
    func handleWord(_ value1: inout Word, _ value2: inout Word) {
        handleWord(&value1)
        handleWord(&value2)
    }
    
    func handleWord(_ value1: inout Word, _ value2: inout Word, _ value3: inout Word) {
        handleWord(&value1)
        handleWord(&value2)
        handleWord(&value3)
    }
    
    func handleWord(_ value1: inout Word, _ value2: inout Word, _ value3: inout Word, _ value4: inout Word) {
        handleWord(&value1)
        handleWord(&value2)
        handleWord(&value3)
        handleWord(&value4)
    }
    
    func handleInt(_ value1: inout Int, _ value2: inout Int) {
        handleInt(&value1)
        handleInt(&value2)
    }
    
    func handleInt(_ value1: inout Int, _ value2: inout Int, _ value3: inout Int) {
        handleInt(&value1)
        handleInt(&value2)
        handleInt(&value3)
    }
    
    func handleInt(_ value1: inout Int, _ value2: inout Int, _ value3: inout Int, _ value4: inout Int) {
        handleInt(&value1)
        handleInt(&value2)
        handleInt(&value3)
        handleInt(&value4)
    }
}
