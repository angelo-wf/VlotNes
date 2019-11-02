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
