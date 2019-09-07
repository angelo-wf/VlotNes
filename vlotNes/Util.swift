//
//  Util.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 27/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

// utulity functions

func loadFileAsByteArray(path: String) -> [Byte] {
    var bytes: [Byte] = []
    if let data = NSData(contentsOfFile: path) {
        var buffer = [Byte](repeating: 0, count: data.length)
        data.getBytes(&buffer, length: data.length)
        bytes = buffer
    }
    return bytes
}

func loadFileAsStringArray(path: String) -> [String] {
    do {
        let text = try String(contentsOfFile: path)
        return text.split(separator: "\n").map(String.init)
    } catch {
        return []
    }
}

func saveByteArrayToFile(url: URL, data: [Byte]) -> Bool {
    do {
        let data = Data(bytes: data, count: data.count)
        try data.write(to: url)
    } catch {
        return false
    }
    return true
}

// used for nestest log checking

//func getCpuStateAsString(cpu: Cpu, cycles: UInt64) -> String {
//    return "\(getWordRep(cpu.pc))                                            A:\(getByteRep(cpu.a)) X:\(getByteRep(cpu.x)) Y:\(getByteRep(cpu.y)) P:\(getByteRep(cpu.getP(b: false))) SP:\(getByteRep(cpu.sp))             CYC:\(cycles)"
//}
//
//func compareStateString(checked: String, correct: String) -> Bool {
//    if getStringRange(checked, start: 0, end: 4) != getStringRange(correct, start: 0, end: 4) {
//        return false
//    }
//    if getStringRange(checked, start: 48, end: 73) != getStringRange(correct, start: 48, end: 73) {
//        return false
//    }
//    if getStringRange(checked, start: 86, end: -1) != getStringRange(correct, start: 86, end: -1) {
//        return false
//    }
//    return true
//}
//
//func getStringRange(_ str: String, start: Int, end: Int) -> Substring {
//    let start = str.index(str.startIndex, offsetBy: start)
//    if end < 0 {
//        return str[start...]
//    }
//    let end = str.index(str.startIndex, offsetBy: end)
//    return str[start..<end]
//}
//
//func getByteRep(_ value: Byte) -> String {
//    return String(format: "%02X", value)
//}
//
//func getWordRep(_ value: Word) -> String {
//    return String(format: "%04X", value)
//}
