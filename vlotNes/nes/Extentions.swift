//
//  Extentions.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 25/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

typealias Byte = UInt8
typealias Word = UInt16

extension Array {
    subscript(place: Word) -> Element {
        get {
            return self[Int(place)]
        }
        set(newValue) {
            self[Int(place)] = newValue
        }
    }
    
    subscript(place: Byte) -> Element {
        get {
            return self[Int(place)]
        }
        set(newValue) {
            self[Int(place)] = newValue
        }
    }
    
    mutating func fill(with value: Element) {
        for i in 0..<self.count {
            self[i] = value
        }
    }
}

extension Byte {
    static func &+=(left: inout Byte, right: Byte) {
        left = left &+ right
    }
    
    static func &-=(left: inout Byte, right: Byte) {
        left = left &- right
    }
}

extension Word {
    static func &+=(left: inout Word, right: Word) {
        left = left &+ right
    }
    
    static func &-=(left: inout Word, right: Word) {
        left = left &- right
    }
}
