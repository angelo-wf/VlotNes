//
//  Util.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 27/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

// utulity functions

enum FileError: Error {
    case fileReadError
    case fileWriteError
    case zipLoadError(details: String)
}

func loadFileAsByteArray(path: String) throws -> [Byte] {
    if let data = NSData(contentsOfFile: path) {
        var buffer = [Byte](repeating: 0, count: data.length)
        data.getBytes(&buffer, length: data.length)
        return buffer
    } else {
        throw FileError.fileReadError
    }
}

func loadFileAsStringArray(path: String) throws -> [String] {
    do {
        let text = try String(contentsOfFile: path)
        return text.split(separator: "\n").map(String.init)
    } catch {
        throw FileError.fileReadError
    }
}

func saveByteArrayToFile(url: URL, data: [Byte]) throws {
    do {
        let data = Data(bytes: data, count: data.count)
        try data.write(to: url)
    } catch {
        throw FileError.fileWriteError
    }
}
