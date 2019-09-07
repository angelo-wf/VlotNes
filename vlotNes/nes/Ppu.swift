//
//  Ppu.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 29/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Ppu: MemoryHandler {
    
    let nes: Nes
    
    // palette, from https://wiki.nesdev.com/w/index.php/PPU_palettes (savtool palette)
    let palette: [[Byte]] = [
        [101, 101, 101], [0, 45, 105], [19, 31, 127], [60, 19, 124], [96, 11, 98], [115, 10, 55], [113, 15, 7], [90, 26, 0], [52, 40, 0], [11, 52, 0], [0, 60, 0], [0, 61, 16], [0, 56, 64], [0, 0, 0], [0, 0, 0], [0, 0, 0],
        [174, 174, 174], [15, 99, 179], [64, 81, 208], [120, 65, 204], [167, 54, 169], [192, 52, 112], [189, 60, 48], [159, 74, 0], [109, 92, 0], [54, 109, 0], [7, 119, 4], [0, 121, 61], [0, 114, 125], [0, 0, 0], [0, 0, 0], [0, 0, 0],
        [254, 254, 255], [93, 179, 255], [143, 161, 255], [200, 144, 255], [247, 133, 250], [255, 131, 192], [255, 139, 127], [239, 154, 73], [189, 172, 44], [133, 188, 47], [85, 199, 83], [60, 201, 140], [62, 194, 205], [78, 78, 78], [0, 0, 0], [0, 0, 0],
        [254, 254, 255], [188, 223, 255], [209, 216, 255], [232, 209, 255], [251, 205, 253], [255, 204, 229], [255, 207, 202], [248, 213, 180], [228, 220, 168], [204, 227, 169], [185, 232, 184], [174, 232, 208], [175, 229, 234], [182, 182, 182], [0, 0, 0], [0, 0, 0]
    ]
    
    // ram
    // ppu ram is stored in the mapper to simplify accessing it
    var paletteRam: [Byte] = [Byte](repeating: 0, count: 0x20)
    var oamRam: [Byte] = [Byte](repeating: 0, count: 0x100)
    
    // output
    var output: [Int] = [Int](repeating: 0, count: 256 * 240)
    
    // scroll registers
    var v: Word = 0
    var t: Word = 0
    var x: Byte = 0
    var w: Bool = false
    
    // dot position
    var line: Int = 0
    var dot: Int = 0
    var evenFrame: Bool = false
    
    // misc
    var readBuffer: Byte = 0
    var oamAddress: Byte = 0
    
    // ppu_status
    var spriteZero: Bool = false
    var spriteOverflow: Bool = false
    var inVblank: Bool = false
    
    // ppu_ctrl
    var vramIncrement: Word = 0
    var spritePatternBase: Word = 0
    var bgPatternBase: Word = 0
    var spriteHeight: Int = 0
    var slave: Bool = false
    var generateNmi: Bool = false
    
    // ppu_mask
    var greyScale: Bool = false
    var bgInLeft: Bool = false
    var spritesInLeft: Bool = false
    var bgRendering: Bool = false
    var spriteRendering: Bool = false
    var emphasis: Byte = 0
    
    // internal operation
    var atl: Byte = 0
    var atr: Byte = 0
    var tl: Word = 0
    var th: Word = 0
    var secondaryOam: [Byte] = [Byte](repeating: 0, count: 0x20)
    var spriteTiles: [Byte] = [Byte](repeating: 0, count: 0x10)
    var spriteZeroInOam: Bool = false
    var spriteCount: Int = 0
    
    init(nes: Nes) {
        self.nes = nes
        reset()
    }
    
    func reset() {
        paletteRam.fill(with: 0)
        oamRam.fill(with: 0)
        t = 0
        v = 0
        w = false
        x = 0
        line = 0
        dot = 0
        evenFrame = true
        oamAddress = 0
        readBuffer = 0
        spriteZero = false
        spriteOverflow = false
        inVblank = false
        vramIncrement = 1
        spritePatternBase = 0
        bgPatternBase = 0
        slave = false
        generateNmi = false
        greyScale = false
        spritesInLeft = false
        bgInLeft = false
        spriteRendering = false
        bgRendering = false
        emphasis = 0
        atl = 0
        atr = 0
        tl = 0
        th = 0
        spriteZeroInOam = false
        spriteCount = 0
        secondaryOam.fill(with: 0)
        spriteTiles.fill(with: 0)
        output.fill(with: 0)
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&w, &evenFrame, &spriteZero, &spriteOverflow)
        s.handleBool(&inVblank, &slave, &generateNmi, &greyScale)
        s.handleBool(&spritesInLeft, &bgInLeft, &spriteRendering, &bgRendering)
        s.handleBool(&spriteZeroInOam)
        s.handleByte(&x, &readBuffer, &oamAddress, &emphasis)
        s.handleByte(&atl, &atr)
        s.handleWord(&v, &t, &vramIncrement, &spritePatternBase)
        s.handleWord(&bgPatternBase, &tl, &th)
        s.handleInt(&line, &dot, &spriteHeight, &spriteCount)
        s.handleByteArray(&paletteRam)
        s.handleByteArray(&oamRam)
        s.handleByteArray(&secondaryOam)
        s.handleByteArray(&spriteTiles)
    }
    
    func cycle() {
        if line < 240 {
            // visible frame
            switch dot {
            case 0..<256:
                generateDot()
                if ((dot + 1) & 0x7) == 0 {
                    // dot 7, 15, 23, 31 etc
                    if bgRendering || spriteRendering {
                        readTileBuffers()
                        incrementVx()
                    }
                }
            case 256:
                if bgRendering || spriteRendering {
                    incrementVy()
                }
            case 257:
                if bgRendering || spriteRendering {
                    // copy x from t to v
                    v &= 0x7be0
                    v |= t & 0x41f
                }
            case 270:
                // clear sprite buffer
                spriteZeroInOam = false
                spriteCount = 0
                if bgRendering || spriteRendering {
                    // evaluate sprites
                    evaluateSprites()
                }
            case 321, 329:
                if bgRendering || spriteRendering {
                    readTileBuffers()
                    incrementVx()
                }
            default:
                break
            }
        } else if line == 241 {
            // start of vblank
            if dot == 1 {
                inVblank = true
                if generateNmi {
                    nes.cpu.nmiWanted = true
                }
                if bgRendering || spriteRendering {
                    evenFrame = !evenFrame
                } else {
                    evenFrame = true
                }
            }
        } else if line == 261 {
            // pre-render line
            switch dot {
            case 1:
                inVblank = false
                spriteZero = false
                spriteOverflow = false
            case 257:
                if bgRendering || spriteRendering {
                    // copy x from t to v
                    v &= 0x7be0
                    v |= t & 0x41f
                }
            case 270:
                // clear sprite buffer
                spriteZeroInOam = false
                spriteCount = 0
                if bgRendering || spriteRendering {
                    // garbage sprite fetch
                    let base = spriteHeight == 16 ? 0x1000 : spritePatternBase
                    _ = readInternal(base + 0xfff)
                }
            case 280:
                // copy y from t to v
                if bgRendering || spriteRendering {
                    v &= 0x41f
                    v |= t & 0x7be0
                }
            case 321, 329:
                if bgRendering || spriteRendering {
                    readTileBuffers()
                    incrementVx()
                }
            default:
                break
            }
        }
        
        dot += 1
        if dot == 341 || (dot == 340 && line == 261 && !evenFrame) {
            dot = 0
            line += 1
            if line == 262 {
                line = 0
            }
        }
    }
    
    private func readTileBuffers() {
        let tileNum = Word(readInternal(0x2000 + (v & 0xfff)))
        
        atl = atr
        var attAdr: Word = 0x23c0
        attAdr |= (v & 0x1c) >> 2
        attAdr |= (v & 0x380) >> 4
        attAdr |= v & 0xc00
        atr = readInternal(attAdr)
        if (v & 0x40) > 0 {
            atr >>= 4
        }
        atr &= 0xf
        if (v & 0x02) > 0 {
            atr >>= 2
        }
        atr &= 0x3
        
        let fineY = (v & 0x7000) >> 12
        tl &= 0xff
        tl <<= 8
        tl |= Word(readInternal(bgPatternBase + (tileNum * 16) + fineY))
        th &= 0xff
        th <<= 8
        th |= Word(readInternal(bgPatternBase + (tileNum * 16) + fineY + 8))
    }
    
    private func evaluateSprites() {
        var i = 0
        while i < 256 {
            let sprY = Int(oamRam[i])
            var sprRow = line - sprY
            if sprRow >= 0 && sprRow < spriteHeight {
                // sprite is on this scanline
                if spriteCount == 8 {
                    // secondary oam is full
                    spriteOverflow = true
                    break
                } else {
                    // place in secondary oam
                    if i == 0 {
                        // this is sprite zero
                        spriteZeroInOam = true
                    }
                    secondaryOam[spriteCount * 4] = oamRam[i]
                    secondaryOam[spriteCount * 4 + 1] = oamRam[i + 1]
                    secondaryOam[spriteCount * 4 + 2] = oamRam[i + 2]
                    secondaryOam[spriteCount * 4 + 3] = oamRam[i + 3]
                    // fetch the tiles
                    if (oamRam[i + 2] & 0x80) > 0 {
                        // vertical flip
                        sprRow = spriteHeight - 1 - sprRow
                    }
                    var base = spritePatternBase
                    var tileNum = Word(oamRam[i + 1])
                    if spriteHeight == 16 {
                        base = Word(tileNum & 0x1) * 0x1000
                        tileNum &= 0xfe
                        tileNum += Word(sprRow >> 3)
                        sprRow &= 0x7
                    }
                    spriteTiles[spriteCount] = readInternal(base + tileNum * 16 + Word(sprRow))
                    spriteTiles[spriteCount + 8] = readInternal(base + tileNum * 16 + Word(sprRow) + 8)
                    spriteCount += 1
                }
            }
            i += 4
        }
        if spriteCount < 8 {
            // garbage fetch
            let base = spriteHeight == 16 ? 0x1000 : spritePatternBase
            _ = readInternal(base + 0xfff)
        }
    }
    
    private func generateDot() {
        let i = dot & 0x7
        var bgPixel: Word = 0
        var sprPixel: Word = 0
        var sprNum = -1
        var sprPriority: Byte = 0
        
        // search through the sprites in secondary oam
        if spriteRendering && (dot > 7 || spritesInLeft) && spriteCount > 0 {
            for j in 0..<spriteCount {
                let xPos = Int(secondaryOam[j * 4 + 3])
                var xCol = dot - xPos
                if xCol >= 0 && xCol < 8 {
                    // sprite is in range
                    if (secondaryOam[j * 4 + 2] & 0x40) > 0 {
                        // horizontal flip
                        xCol = 7 - xCol
                    }
                    let shift = 7 - xCol
                    var pixel = (spriteTiles[j] >> shift) & 0x1
                    pixel |= ((spriteTiles[j + 8] >> shift) & 0x1) << 1
                    if pixel > 0 {
                        // this sprite has a pixel here
                        sprPixel = Word(pixel | ((secondaryOam[j * 4 + 2] & 0x3) << 2))
                        sprPriority = (secondaryOam[j * 4 + 2] & 0x20) >> 5
                        sprNum = j
                        break
                    }
                }
            }
        }
        
        // get the background color
        if bgRendering && (dot > 7 || bgInLeft) {
            let shiftAmount = 15 - i - Int(x)
            bgPixel = (tl >> shiftAmount) & 0x1
            bgPixel |= ((th >> shiftAmount) & 0x1) << 1
            var atrOff: Word = 0
            if Int(x) + i > 7 {
                atrOff = Word(atr * 4)
            } else {
                atrOff = Word(atl * 4)
            }
            if bgPixel > 0 {
                bgPixel += atrOff
            }
        }
        
        // render the pixel
        var finalColor = 0
        if !bgRendering && !spriteRendering {
            if (v & 0x3fff) >= 0x3f00 {
                finalColor = Int(readPalette(v & 0x1f))
            } else {
                finalColor = Int(readPalette(0))
            }
        } else {
            // if bg pixel is 0, render sprite pixel
            if bgPixel == 0 {
                if sprPixel > 0 {
                    finalColor = Int(readPalette(sprPixel + 0x10))
                } else {
                    finalColor = Int(readPalette(0))
                }
            } else {
                // render bg pixel or sprite pixel, depending on priority
                if sprPixel > 0 {
                    // check for sprite zero
                    if sprNum == 0 && spriteZeroInOam && dot != 255 {
                        spriteZero = true
                    }
                }
                if sprPixel > 0 && sprPriority == 0 {
                    finalColor = Int(readPalette(sprPixel + 0x10))
                } else {
                    finalColor = Int(readPalette(bgPixel))
                }
            }
        }
        
        output[line * 256 + dot] = (Int(emphasis) << 6) | (finalColor & 0x3f)
    }
    
    func setFrame(buffer: inout [Byte]) {
        for i in 0..<output.count {
            let color = output[i]
            var r = palette[color & 0x3f][0]
            var g = palette[color & 0x3f][1]
            var b = palette[color & 0x3f][2]
            if (color & 0x40) > 0 {
                r &+= (r >= 224) ? 0 : (r / 8)
                g &-= (g / 8)
                b &-= (b / 8)
            }
            if (color & 0x80) > 0 {
                r &-= (r / 8)
                g &+= (g >= 224) ? 0 : (g / 8)
                b &-= (b / 8)
            }
            if (color & 0x100) > 0 {
                r &-= (r / 8)
                g &-= (g / 8)
                b &+= (b >= 224) ? 0 : (b / 8)
            }
            buffer[i * 3] = r
            buffer[i * 3 + 1] = g
            buffer[i * 3 + 2] = b
        }
    }
    
    // incrementVx and Vy adapted from https://wiki.nesdev.com/w/index.php/PPU_scrolling
    
    private func incrementVx() {
        if (v & 0x1f) == 0x1f {
            v &= 0x7fe0
            v ^= 0x400
        } else {
            v += 1
        }
    }
    
    private func incrementVy() {
        if (v & 0x7000) != 0x7000 {
            v += 0x1000
        } else {
            v &= 0xfff
            var coarseY = (v & 0x3e0) >> 5
            if coarseY == 29 {
                coarseY = 0
                v ^= 0x800
            } else if coarseY == 31 {
                coarseY = 0
            } else {
                coarseY += 1
            }
            v &= 0x7c1f
            v |= coarseY << 5
        }
    }
    
    private func readInternal(_ address: Word) -> Byte {
        return nes.mapper!.ppuRead(address & 0x3fff)
    }
    
    private func writeInternal(_ address: Word, _ value: Byte) {
        nes.mapper!.ppuWrite(address & 0x3fff, value)
    }
    
    private func readPalette(_ address: Word) -> Byte {
        var palAdr = address & 0x1f
        if palAdr >= 0x10 && (palAdr & 0x3) == 0 {
            // 0x10, 0x14, 0x18 and 0x1c are mirrored down to 0x0, 0x4, 0x8 and 0xc
            palAdr -= 0x10
        }
        var ret = paletteRam[palAdr]
        if greyScale {
            ret &= 0x30
        }
        return ret
    }
    
    private func writePalette(_ address: Word, _ value: Byte) {
        var palAdr = address & 0x1f
        if palAdr >= 0x10 && (palAdr & 0x3) == 0 {
            // 0x10, 0x14, 0x18 and 0x1c are mirrored down to 0x0, 0x4, 0x8 and 0xc
            palAdr -= 0x10
        }
        paletteRam[palAdr] = value
    }
    
    func peak(_ address: Word) -> Byte {
        switch address {
        case 2:
            var value: Byte = 0
            value |= inVblank ? 0x80 : 0
            value |= spriteZero ? 0x40 : 0
            value |= spriteOverflow ? 0x20 : 0
            return value
        case 4:
            return oamRam[oamAddress]
        case 7:
            if (v & 0x3fff) >= 0x3f00 {
                // read palette directly
                return readPalette(v)
            }
            return readBuffer
        default:
            return 0
        }
    }
    
    func read(_ address: Word) -> Byte {
        switch address {
        case 2:
            w = false
            var value: Byte = 0
            if inVblank {
                value |= 0x80
                inVblank = false
            }
            value |= spriteZero ? 0x40 : 0
            value |= spriteOverflow ? 0x20 : 0
            return value
        case 4:
            return oamRam[oamAddress]
        case 7:
            let adr = v & 0x3fff
            if (bgRendering || spriteRendering) && (line < 240 || line == 261) {
                // during rendering, v is incremented strangely
                incrementVy()
                incrementVx()
            } else {
                v &+= vramIncrement
                v &= 0x7fff
            }
            var temp = readBuffer
            if adr >= 0x3f00 {
                // read palette directly in temp
                temp = readPalette(adr)
            }
            // read nametable/chr byte in read buffer
            readBuffer = readInternal(adr)
            return temp
        default:
            return 0
        }
    }
    
    func write(_ address: Word, _ value: Byte) {
        switch address {
        case 0:
            t &= 0x73ff
            t |= (Word(value) & 0x3) << 10
            vramIncrement = (value & 0x4) > 0 ? 32 : 1
            spritePatternBase = (value & 0x8) > 0 ? 0x1000 : 0
            bgPatternBase = (value & 0x10) > 0 ? 0x1000 : 0
            spriteHeight = (value & 0x20) > 0 ? 16 : 8
            slave = (value & 0x040) > 0
            let oldNmi = generateNmi
            generateNmi = (value & 0x80) > 0
            if !oldNmi && generateNmi && inVblank {
                // immediate nmi if enabled while in vblank
                nes.cpu.nmiWanted = true
            }
            return
        case 1:
            greyScale = (value & 0x1) > 0
            bgInLeft = (value & 0x2) > 0
            spritesInLeft = (value & 0x4) > 0
            bgRendering = (value & 0x8) > 0
            spriteRendering = (value & 0x10) > 0
            emphasis = (value & 0xe0) >> 5
            return
        case 3:
            oamAddress = value
            return
        case 4:
            oamRam[oamAddress] = value
            oamAddress &+= 1
            return
        case 5:
            if !w {
                t &= 0x7fe0
                t |= (Word(value) & 0xf8) >> 3
                x = value & 0x7
            } else {
                t &= 0x0c1f
                t |= (Word(value) & 0x7) << 12
                t |= (Word(value) & 0xf8) << 2
            }
            w = !w
            return
        case 6:
            if !w {
                t &= 0xff
                t |= (Word(value) & 0x3f) << 8
            } else {
                t &= 0x7f00
                t |= Word(value)
                v = t
            }
            w = !w
            return
        case 7:
            let adr = v & 0x3fff
            if (bgRendering || spriteRendering) && (line < 240 || line == 261) {
                // during rendering, v is incremented strangely
                incrementVy()
                incrementVx()
            } else {
                v &+= vramIncrement
                v &= 0x7fff
            }
            if adr >= 0x3f00 {
                // write the palette
                writePalette(adr, value)
            } else {
                // write to nametables/chr
                writeInternal(adr, value)
            }
            return
        default:
            return
        }
    }
}
