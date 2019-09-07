//
//  PixelView.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 24/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Cocoa

class PixelView: NSView {
    
    var pixelData: [UInt8] = []
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let width = 256
    let height = 240
    
    override func awakeFromNib() {
        pixelData = [UInt8](repeating: 0, count: width * height * 3)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Drawing code here.
        let data = CFDataCreate(nil, pixelData, width * height * 3)!
        let provider = CGDataProvider(data: data)!
        let image = CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: width * 3,
            space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil,
            shouldInterpolate: false, intent: CGColorRenderingIntent.defaultIntent
        )!
        let context = NSGraphicsContext.current?.cgContext
        context?.draw(image, in: bounds)
        
    }
    
}
