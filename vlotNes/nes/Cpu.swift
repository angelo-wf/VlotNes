//
//  cpu.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 25/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Cpu {
    
    // registers
    var a: Byte = 0
    var x: Byte = 0
    var y: Byte = 0
    
    var pc: Word = 0
    var sp: Byte = 0
    
    // processor flags
    var z: Bool = false
    var n: Bool = false
    var c: Bool = false
    var v: Bool = false
    var d: Bool = false
    var i: Bool = false
    
    // interrupts
    var irqWanted: Bool = false
    var nmiWanted: Bool = false
    
    // cycles
    var cyclesLeft: Int = 0
    
    // memory handler
    let mem: MemoryHandler
    
    // tables for cycle counts per instruction
    let cycleCounts: [Int] = [
        7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
        2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
        2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
        2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
        2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
        2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
        2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7
    ]
    
    init(memoryHandler: MemoryHandler) {
        mem = memoryHandler
        reset()
    }
    
    func reset() {
        a = 0
        x = 0
        y = 0
        sp = 0xfd
        z = false
        n = false
        c = false
        v = false
        d = false
        i = true
        pc = Word(mem.read(0xfffc)) | (Word(mem.read(0xfffd)) << 8)
        irqWanted = false
        nmiWanted = false
        cyclesLeft = 7 // reset takes 7 cycles
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&z, &n, &c, &v)
        s.handleBool(&d, &i, &irqWanted, &nmiWanted)
        s.handleByte(&a, &x, &y, &sp)
        s.handleWord(&pc)
        s.handleInt(&cyclesLeft)
    }
    
    func cycle() {
        if cyclesLeft == 0 {
            // read the opcode byte
            let opcode = readOpcode()
            // test for interrupts
            if nmiWanted || (irqWanted && !i) {
                pc &-= 1
                cyclesLeft = 7
                if nmiWanted {
                    nmiWanted = false
                    nmi(adrImp())
                } else {
                    irq(adrImp())
                }
            } else {
                // execute the opcode
                cyclesLeft = cycleCounts[opcode]
                executeOpcode(opcode: opcode)
            }
        }
        cyclesLeft -= 1
    }
    
    private func getP(b: Bool) -> Byte {
        var value: Byte = 0;
        
        value |= n ? 0x80 : 0
        value |= v ? 0x40 : 0
        value |= d ? 0x08 : 0
        value |= i ? 0x04 : 0
        value |= z ? 0x02 : 0
        value |= c ? 0x01 : 0
        
        value |= 0x20 // bit 5 always set
        value |= b ? 0x10 : 0
        
        return value
    }
    
    private func setP(_ value: Byte) {
        n = (value & 0x80) > 0
        v = (value & 0x40) > 0
        d = (value & 0x08) > 0
        i = (value & 0x04) > 0
        z = (value & 0x02) > 0
        c = (value & 0x01) > 0
    }
    
    private func setZandN(_ value: Byte) {
        z = value == 0
        n = value > 127
    }
    
    private func changePcRelative(_ value: Word) -> Bool {
        let oldPc = pc
        if(value > 127) {
            pc &-= 256 - value
        } else {
            pc &+= value
        }
        if (pc & 0xff00) != (oldPc & 0xff00) {
            return true
        }
        return false
    }
    
    private func doBranch(test: Bool, rel: Word) {
        if test {
            // taken branch: 1 extra cycle
            cyclesLeft += 1
            if changePcRelative(rel) {
                // taken branch across page, another extra cycle
                cyclesLeft += 1
            }
        }
    }
    
    private func readOpcode() -> Byte {
        let value = mem.read(pc)
        pc &+= 1
        return value
    }
    
    private func pushByte(_ value: Byte) {
        mem.write(0x100 | Word(sp), value)
        sp &-= 1
    }
    
    private func pullByte() -> Byte {
        sp &+= 1
        return mem.read(0x100 | Word(sp))
    }
    
    private func executeOpcode(opcode: Byte) {
        switch(opcode) {
        case 0x00: brk(adrImp())
        case 0x01: ora(adrIzx())
        case 0x02: kil(adrImp())
        case 0x03: slo(adrIzx())
        case 0x04: nop(adrZp())
        case 0x05: ora(adrZp())
        case 0x06: asl(adrZp())
        case 0x07: slo(adrZp())
        case 0x08: php(adrImp())
        case 0x09: ora(adrImm())
        case 0x0a: asla(adrImp())
        case 0x0b: anc(adrImm())
        case 0x0c: nop(adrAbs())
        case 0x0d: ora(adrAbs())
        case 0x0e: asl(adrAbs())
        case 0x0f: slo(adrAbs())
        case 0x10: bpl(adrRel())
        case 0x11: ora(adrIzyr())
        case 0x12: kil(adrImp())
        case 0x13: slo(adrIzy())
        case 0x14: nop(adrZpx())
        case 0x15: ora(adrZpx())
        case 0x16: asl(adrZpx())
        case 0x17: slo(adrZpx())
        case 0x18: clc(adrImp())
        case 0x19: ora(adrAbyr())
        case 0x1a: nop(adrImp())
        case 0x1b: slo(adrAby())
        case 0x1c: nop(adrAbxr())
        case 0x1d: ora(adrAbxr())
        case 0x1e: asl(adrAbx())
        case 0x1f: slo(adrAbx())
        case 0x20: jsr(adrAbs())
        case 0x21: and(adrIzx())
        case 0x22: kil(adrImp())
        case 0x23: rla(adrIzx())
        case 0x24: bit(adrZp())
        case 0x25: and(adrZp())
        case 0x26: rol(adrZp())
        case 0x27: rla(adrZp())
        case 0x28: plp(adrImp())
        case 0x29: and(adrImm())
        case 0x2a: rola(adrImp())
        case 0x2b: anc(adrImm())
        case 0x2c: bit(adrAbs())
        case 0x2d: and(adrAbs())
        case 0x2e: rol(adrAbs())
        case 0x2f: rla(adrAbs())
        case 0x30: bmi(adrRel())
        case 0x31: and(adrIzyr())
        case 0x32: kil(adrImp())
        case 0x33: rla(adrIzy())
        case 0x34: nop(adrZpx())
        case 0x35: and(adrZpx())
        case 0x36: rol(adrZpx())
        case 0x37: rla(adrZpx())
        case 0x38: sec(adrImp())
        case 0x39: and(adrAbyr())
        case 0x3a: nop(adrImp())
        case 0x3b: rla(adrAby())
        case 0x3c: nop(adrAbxr())
        case 0x3d: and(adrAbxr())
        case 0x3e: rol(adrAbx())
        case 0x3f: rla(adrAbx())
        case 0x40: rti(adrImp())
        case 0x41: eor(adrIzx())
        case 0x42: kil(adrImp())
        case 0x43: sre(adrIzx())
        case 0x44: nop(adrZp())
        case 0x45: eor(adrZp())
        case 0x46: lsr(adrZp())
        case 0x47: sre(adrZp())
        case 0x48: pha(adrImp())
        case 0x49: eor(adrImm())
        case 0x4a: lsra(adrImp())
        case 0x4b: alr(adrImm())
        case 0x4c: jmp(adrAbs())
        case 0x4d: eor(adrAbs())
        case 0x4e: lsr(adrAbs())
        case 0x4f: sre(adrAbs())
        case 0x50: bvc(adrRel())
        case 0x51: eor(adrIzyr())
        case 0x52: kil(adrImp())
        case 0x53: sre(adrIzy())
        case 0x54: nop(adrZpx())
        case 0x55: eor(adrZpx())
        case 0x56: lsr(adrZpx())
        case 0x57: sre(adrZpx())
        case 0x58: cli(adrImp())
        case 0x59: eor(adrAbyr())
        case 0x5a: nop(adrImp())
        case 0x5b: sre(adrAby())
        case 0x5c: nop(adrAbxr())
        case 0x5d: eor(adrAbxr())
        case 0x5e: lsr(adrAbx())
        case 0x5f: sre(adrAbx())
        case 0x60: rts(adrImp())
        case 0x61: adc(adrIzx())
        case 0x62: kil(adrImp())
        case 0x63: rra(adrIzx())
        case 0x64: nop(adrZp())
        case 0x65: adc(adrZp())
        case 0x66: ror(adrZp())
        case 0x67: rra(adrZp())
        case 0x68: pla(adrImp())
        case 0x69: adc(adrImm())
        case 0x6a: rora(adrImp())
        case 0x6b: arr(adrImm())
        case 0x6c: jmp(adrInd())
        case 0x6d: adc(adrAbs())
        case 0x6e: ror(adrAbs())
        case 0x6f: rra(adrAbs())
        case 0x70: bvs(adrRel())
        case 0x71: adc(adrIzyr())
        case 0x72: kil(adrImp())
        case 0x73: rra(adrIzy())
        case 0x74: nop(adrZpx())
        case 0x75: adc(adrZpx())
        case 0x76: ror(adrZpx())
        case 0x77: rra(adrZpx())
        case 0x78: sei(adrImp())
        case 0x79: adc(adrAbyr())
        case 0x7a: nop(adrImp())
        case 0x7b: rra(adrAby())
        case 0x7c: nop(adrAbxr())
        case 0x7d: adc(adrAbxr())
        case 0x7e: ror(adrAbx())
        case 0x7f: rra(adrAbx())
        case 0x80: nop(adrImm())
        case 0x81: sta(adrIzx())
        case 0x82: nop(adrImm())
        case 0x83: sax(adrIzx())
        case 0x84: sty(adrZp())
        case 0x85: sta(adrZp())
        case 0x86: stx(adrZp())
        case 0x87: sax(adrZp())
        case 0x88: dey(adrImp())
        case 0x89: nop(adrImm())
        case 0x8a: txa(adrImp())
        case 0x8b: uni(adrImm())
        case 0x8c: sty(adrAbs())
        case 0x8d: sta(adrAbs())
        case 0x8e: stx(adrAbs())
        case 0x8f: sax(adrAbs())
        case 0x90: bcc(adrRel())
        case 0x91: sta(adrIzy())
        case 0x92: kil(adrImp())
        case 0x93: uni(adrIzy())
        case 0x94: sty(adrZpx())
        case 0x95: sta(adrZpx())
        case 0x96: stx(adrZpy())
        case 0x97: sax(adrZpy())
        case 0x98: tya(adrImp())
        case 0x99: sta(adrAby())
        case 0x9a: txs(adrImp())
        case 0x9b: uni(adrAby())
        case 0x9c: uni(adrAbx())
        case 0x9d: sta(adrAbx())
        case 0x9e: uni(adrAby())
        case 0x9f: uni(adrAby())
        case 0xa0: ldy(adrImm())
        case 0xa1: lda(adrIzx())
        case 0xa2: ldx(adrImm())
        case 0xa3: lax(adrIzx())
        case 0xa4: ldy(adrZp())
        case 0xa5: lda(adrZp())
        case 0xa6: ldx(adrZp())
        case 0xa7: lax(adrZp())
        case 0xa8: tay(adrImp())
        case 0xa9: lda(adrImm())
        case 0xaa: tax(adrImp())
        case 0xab: uni(adrImm())
        case 0xac: ldy(adrAbs())
        case 0xad: lda(adrAbs())
        case 0xae: ldx(adrAbs())
        case 0xaf: lax(adrAbs())
        case 0xb0: bcs(adrRel())
        case 0xb1: lda(adrIzyr())
        case 0xb2: kil(adrImp())
        case 0xb3: lax(adrIzyr())
        case 0xb4: ldy(adrZpx())
        case 0xb5: lda(adrZpx())
        case 0xb6: ldx(adrZpy())
        case 0xb7: lax(adrZpy())
        case 0xb8: clv(adrImp())
        case 0xb9: lda(adrAbyr())
        case 0xba: tsx(adrImp())
        case 0xbb: uni(adrAbyr())
        case 0xbc: ldy(adrAbxr())
        case 0xbd: lda(adrAbxr())
        case 0xbe: ldx(adrAbyr())
        case 0xbf: lax(adrAbyr())
        case 0xc0: cpy(adrImm())
        case 0xc1: cmp(adrIzx())
        case 0xc2: nop(adrImm())
        case 0xc3: dcp(adrIzx())
        case 0xc4: cpy(adrZp())
        case 0xc5: cmp(adrZp())
        case 0xc6: dec(adrZp())
        case 0xc7: dcp(adrZp())
        case 0xc8: iny(adrImp())
        case 0xc9: cmp(adrImm())
        case 0xca: dex(adrImp())
        case 0xcb: axs(adrImm())
        case 0xcc: cpy(adrAbs())
        case 0xcd: cmp(adrAbs())
        case 0xce: dec(adrAbs())
        case 0xcf: dcp(adrAbs())
        case 0xd0: bne(adrRel())
        case 0xd1: cmp(adrIzyr())
        case 0xd2: kil(adrImp())
        case 0xd3: dcp(adrIzy())
        case 0xd4: nop(adrZpx())
        case 0xd5: cmp(adrZpx())
        case 0xd6: dec(adrZpx())
        case 0xd7: dcp(adrZpx())
        case 0xd8: cld(adrImp())
        case 0xd9: cmp(adrAbyr())
        case 0xda: nop(adrImp())
        case 0xdb: dcp(adrAby())
        case 0xdc: nop(adrAbxr())
        case 0xdd: cmp(adrAbxr())
        case 0xde: dec(adrAbx())
        case 0xdf: dcp(adrAbx())
        case 0xe0: cpx(adrImm())
        case 0xe1: sbc(adrIzx())
        case 0xe2: nop(adrImm())
        case 0xe3: isc(adrIzx())
        case 0xe4: cpx(adrZp())
        case 0xe5: sbc(adrZp())
        case 0xe6: inc(adrZp())
        case 0xe7: isc(adrZp())
        case 0xe8: inx(adrImp())
        case 0xe9: sbc(adrImm())
        case 0xea: nop(adrImp())
        case 0xeb: sbc(adrImm())
        case 0xec: cpx(adrAbs())
        case 0xed: sbc(adrAbs())
        case 0xee: inc(adrAbs())
        case 0xef: isc(adrAbs())
        case 0xf0: beq(adrRel())
        case 0xf1: sbc(adrIzyr())
        case 0xf2: kil(adrImp())
        case 0xf3: isc(adrIzy())
        case 0xf4: nop(adrZpx())
        case 0xf5: sbc(adrZpx())
        case 0xf6: inc(adrZpx())
        case 0xf7: isc(adrZpx())
        case 0xf8: sed(adrImp())
        case 0xf9: sbc(adrAbyr())
        case 0xfa: nop(adrImp())
        case 0xfb: isc(adrAby())
        case 0xfc: nop(adrAbxr())
        case 0xfd: sbc(adrAbxr())
        case 0xfe: inc(adrAbx())
        case 0xff: isc(adrAbx())
        default: break
        }
    }
    
    // MARK: - Adressing modes
    
    private func adrImp() -> Word {
        // implied, won't need an address
        return 0
    }
    
    private func adrImm() -> Word {
        // immediate, returns address of next byte after opcode
        let adr = pc
        pc &+= 1
        return adr
    }
    
    private func adrZp() -> Word {
        // zero page
        return Word(readOpcode())
    }
    
    private func adrZpx() -> Word {
        // zero page, indexed on X
        return Word(readOpcode() &+ x)
    }
    
    private func adrZpy() -> Word {
        // zero page, indexed on Y
        return Word(readOpcode() &+ y)
    }
    
    private func adrIzx() -> Word {
        // zero page indexed indirect on X
        let adrl = Word(readOpcode() &+ x)
        let adrh = (adrl + 1) & 0xff
        return Word(mem.read(adrl)) | (Word(mem.read(adrh)) << 8)
    }
    
    private func adrIzy() -> Word {
        // zero page indirect indexed on y
        let adrl = Word(readOpcode())
        let adrh = (adrl + 1) & 0xff
        let radr = Word(mem.read(adrl)) | (Word(mem.read(adrh)) << 8)
        return radr &+ Word(y)
    }
    
    private func adrIzyr() -> Word {
        // zero page indirect indexed on y (for reads, with optional cycle)
        let adrl = Word(readOpcode())
        let adrh = (adrl + 1) & 0xff
        let radr = Word(mem.read(adrl)) | (Word(mem.read(adrh)) << 8)
        if (radr & 0xff00) != ((radr &+ Word(y)) & 0xff00) {
            // page cross, 1 extra cycle
            cyclesLeft += 1
        }
        return radr &+ Word(y)
    }
    
    private func adrAbs() -> Word {
        // absolute
        let low = Word(readOpcode())
        return low | (Word(readOpcode()) << 8)
    }
    
    private func adrAbx() -> Word {
        // absolute, indexed on x
        let low = Word(readOpcode())
        return (low | (Word(readOpcode()) << 8)) &+ Word(x)
    }
    
    private func adrAbxr() -> Word {
        // absolute, indexed on x (for reads, with optional cycle)
        let low = Word(readOpcode())
        let adr = low | (Word(readOpcode()) << 8)
        if (adr & 0xff00) != ((adr &+ Word(x)) & 0xff00) {
            // page cross, 1 extra cycle
            cyclesLeft += 1
        }
        return adr &+ Word(x)
    }
    
    private func adrAby() -> Word {
        // absolute, indexed on y
        let low = Word(readOpcode())
        return (low | (Word(readOpcode()) << 8)) &+ Word(y)
    }
    
    private func adrAbyr() -> Word {
        // absolute, indexed on y (for reads, with optional cycle)
        let low = Word(readOpcode())
        let adr = low | (Word(readOpcode()) << 8)
        if (adr & 0xff00) != ((adr &+ Word(y)) & 0xff00) {
            // page cross, 1 extra cycle
            cyclesLeft += 1
        }
        return adr &+ Word(y)
    }
    
    private func adrInd() -> Word {
        // indirect, doesn't loop pages properly
        let adrl = Word(readOpcode())
        let adrh = Word(readOpcode())
        let radr = Word(mem.read(adrl | (adrh << 8)))
        return radr | (Word(mem.read(((adrl + 1) & 0xff) | (adrh << 8))) << 8)
    }
    
    private func adrRel() -> Word {
        // relative, for branches (acts like zeropage)
        return Word(readOpcode())
    }
    
    // MARK: - Instructions
    
    private func uni(_ adr: Word) {
        let prevPc = pc &- 1
        let opcode = mem.read(prevPc)
        print("Uninplemented instuction at \(prevPc): \(opcode)")
    }
    
    private func ora(_ adr: Word) {
        a |= mem.read(adr)
        setZandN(a)
    }
    
    private func and(_ adr: Word) {
        a &= mem.read(adr)
        setZandN(a)
    }
    
    private func eor(_ adr: Word) {
        a ^= mem.read(adr)
        setZandN(a)
    }
    
    private func adc(_ adr: Word) {
        let value = mem.read(adr)
        let result = Word(a) + Word(value) + (c ? 1 : 0)
        c = result > 0xff
        v = ((a & 0x80) == (value & 0x80)) && ((value & 0x80) != (result & 0x80))
        a = Byte(result & 0xff)
        setZandN(a)
    }
    
    private func sbc(_ adr: Word) {
        let value = mem.read(adr) ^ 0xff
        let result = Word(a) + Word(value) + (c ? 1 : 0)
        c = result > 0xff
        v = ((a & 0x80) == (value & 0x80)) && ((value & 0x80) != (result & 0x80))
        a = Byte(result & 0xff)
        setZandN(a)
    }
    
    private func cmp(_ adr: Word) {
        let value = mem.read(adr) ^ 0xff
        let result = Word(a) + Word(value) + 1
        c = result > 0xff
        setZandN(Byte(result & 0xff))
    }
    
    private func cpx(_ adr: Word) {
        let value = mem.read(adr) ^ 0xff
        let result = Word(x) + Word(value) + 1
        c = result > 0xff
        setZandN(Byte(result & 0xff))
    }
    
    private func cpy(_ adr: Word) {
        let value = mem.read(adr) ^ 0xff
        let result = Word(y) + Word(value) + 1
        c = result > 0xff
        setZandN(Byte(result & 0xff))
    }
    
    private func dec(_ adr: Word) {
        let result = mem.read(adr) &- 1
        setZandN(result)
        mem.write(adr, result)
    }
    
    private func dex(_ adr: Word) {
        x &-= 1
        setZandN(x)
    }
    
    private func dey(_ adr: Word) {
        y &-= 1
        setZandN(y)
    }
    
    private func inc(_ adr: Word) {
        let result = mem.read(adr) &+ 1
        setZandN(result)
        mem.write(adr, result)
    }
    
    private func inx(_ adr: Word) {
        x &+= 1
        setZandN(x)
    }
    
    private func iny(_ adr: Word) {
        y &+= 1
        setZandN(y)
    }
    
    private func asla(_ adr: Word) {
        let result = Word(a) << 1
        c = result > 0xff
        a = Byte(result & 0xff)
        setZandN(a)
    }
    
    private func asl(_ adr: Word) {
        let result = Word(mem.read(adr)) << 1
        c = result > 0xff
        let res = Byte(result & 0xff)
        setZandN(res)
        mem.write(adr, res)
    }
    
    private func rola(_ adr: Word) {
        let result = (Word(a) << 1) | (c ? 1 : 0)
        c = result > 0xff
        a = Byte(result & 0xff)
        setZandN(a)
    }
    
    private func rol(_ adr: Word) {
        let result = (Word(mem.read(adr)) << 1) | (c ? 1 : 0)
        c = result > 0xff
        let res = Byte(result & 0xff)
        setZandN(res)
        mem.write(adr, res)
    }
    
    private func lsra(_ adr: Word) {
        let carry = a & 0x1
        let result = a >> 1
        c = carry > 0
        a = result
        setZandN(a)
    }
    
    private func lsr(_ adr: Word) {
        let value = mem.read(adr)
        let carry = value & 0x1
        let result = value >> 1
        c = carry > 0
        setZandN(result)
        mem.write(adr, result)
    }
    
    private func rora(_ adr: Word) {
        let carry = a & 0x1
        let result = (a >> 1) | (c ? 0x80 : 0)
        c = carry > 0
        a = result
        setZandN(a)
    }
    
    private func ror(_ adr: Word) {
        let value = mem.read(adr)
        let carry = value & 0x1
        let result = (value >> 1) | (c ? 0x80 : 0)
        c = carry > 0
        setZandN(result)
        mem.write(adr, result)
    }
    
    private func lda(_ adr: Word) {
        a = mem.read(adr)
        setZandN(a)
    }
    
    private func sta(_ adr: Word) {
        mem.write(adr, a)
    }
    
    private func ldx(_ adr: Word) {
        x = mem.read(adr)
        setZandN(x)
    }
    
    private func stx(_ adr: Word) {
        mem.write(adr, x)
    }
    
    private func ldy(_ adr: Word) {
        y = mem.read(adr)
        setZandN(y)
    }
    
    private func sty(_ adr: Word) {
        mem.write(adr, y)
    }
    
    private func tax(_ adr: Word) {
        x = a
        setZandN(x)
    }
    
    private func txa(_ adr: Word) {
        a = x
        setZandN(a)
    }
    
    private func tay(_ adr: Word) {
        y = a
        setZandN(y)
    }
    
    private func tya(_ adr: Word) {
        a = y
        setZandN(a)
    }
    
    private func tsx(_ adr: Word) {
        x = sp
        setZandN(x)
    }
    
    private func txs(_ adr: Word) {
        sp = x
    }
    
    private func pla(_ adr: Word) {
        a = pullByte()
        setZandN(a)
    }
    
    private func pha(_ adr: Word) {
        pushByte(a)
    }
    
    private func plp(_ adr: Word) {
        setP(pullByte())
    }
    
    private func php(_ adr: Word) {
        pushByte(getP(b: true))
    }
    
    private func bpl(_ adr: Word) {
        doBranch(test: !n, rel: adr)
    }
    
    private func bmi(_ adr: Word) {
        doBranch(test: n, rel: adr)
    }
    
    private func bvc(_ adr: Word) {
        doBranch(test: !v, rel: adr)
    }
    
    private func bvs(_ adr: Word) {
        doBranch(test: v, rel: adr)
    }
    
    private func bcc(_ adr: Word) {
        doBranch(test: !c, rel: adr)
    }
    
    private func bcs(_ adr: Word) {
        doBranch(test: c, rel: adr)
    }
    
    private func bne(_ adr: Word) {
        doBranch(test: !z, rel: adr)
    }
    
    private func beq(_ adr: Word) {
        doBranch(test: z, rel: adr)
    }
    
    private func brk(_ adr: Word) {
        let pushPc = pc &+ 1
        pushByte(Byte(pushPc >> 8))
        pushByte(Byte(pushPc & 0xff))
        pushByte(getP(b: true))
        i = true
        pc = Word(mem.read(0xfffe)) | (Word(mem.read(0xffff)) << 8)
    }
    
    private func rti(_ adr: Word) {
        setP(pullByte())
        let pullPc = Word(pullByte())
        pc = pullPc | (Word(pullByte()) << 8)
    }
    
    private func jsr(_ adr: Word) {
        let pushPc = pc &- 1
        pushByte(Byte(pushPc >> 8))
        pushByte(Byte(pushPc & 0xff))
        pc = adr
    }
    
    private func rts(_ adr: Word) {
        let pullPc = Word(pullByte())
        pc = (pullPc | (Word(pullByte()) << 8)) &+ 1
    }
    
    private func jmp(_ adr: Word) {
        pc = adr
    }
    
    private func bit(_ adr: Word) {
        let value = mem.read(adr)
        n = (value & 0x80) > 0
        v = (value & 0x40) > 0
        let result = a & value
        z = result == 0
    }
    
    private func clc(_ adr: Word) {
        c = false
    }
    
    private func sec(_ adr: Word) {
        c = true
    }
    
    private func cld(_ adr: Word) {
        d = false
    }
    
    private func sed(_ adr: Word) {
        d = true
    }
    
    private func cli(_ adr: Word) {
        i = false
    }
    
    private func sei(_ adr: Word) {
        i = true
    }
    
    private func clv(_ adr: Word) {
        v = false
    }
    
    private func nop(_ adr: Word) {
        // no operation
    }
    
    // interrupts
    
    private func irq(_ adr: Word) {
        pushByte(Byte(pc >> 8))
        pushByte(Byte(pc & 0xff))
        pushByte(getP(b: false))
        i = true
        pc = Word(mem.read(0xfffe)) | (Word(mem.read(0xffff)) << 8)
    }
    
    private func nmi(_ adr: Word) {
        pushByte(Byte(pc >> 8))
        pushByte(Byte(pc & 0xff))
        pushByte(getP(b: false))
        i = true
        pc = Word(mem.read(0xfffa)) | (Word(mem.read(0xfffb)) << 8)
    }
    
    // unofficial instructions
    
    private func kil(_ adr: Word) {
        pc &-= 1 // kills the cpu
    }
    
    private func slo(_ adr: Word) {
        let result = Word(mem.read(adr)) << 1
        c = result > 0xff
        let res = Byte(result & 0xff)
        mem.write(adr, res)
        a |= res
        setZandN(a)
    }
    
    private func rla(_ adr: Word) {
        let result = (Word(mem.read(adr)) << 1) | (c ? 1 : 0)
        c = result > 0xff
        let res = Byte(result & 0xff)
        mem.write(adr, res)
        a &= res
        setZandN(a)
    }
    
    private func sre(_ adr: Word) {
        let value = mem.read(adr)
        let carry = value & 0x1
        let result = value >> 1
        c = carry > 0
        mem.write(adr, result)
        a ^= result
        setZandN(a)
    }
    
    private func rra(_ adr: Word) {
        let value = mem.read(adr)
        let carry = value & 0x1
        let result = (value >> 1) | (c ? 0x80 : 0)
        mem.write(adr, result)
        let addResult = Word(a) + Word(result) + Word(carry)
        c = addResult > 0xff
        v = ((a & 0x80) == (result & 0x80)) && ((result & 0x80) != (addResult & 0x80))
        a = Byte(addResult & 0xff)
        setZandN(a)
    }
    
    private func sax(_ adr: Word) {
        mem.write(adr, a & x)
    }
    
    private func lax(_ adr: Word) {
        a = mem.read(adr)
        x = a
        setZandN(x)
    }
    
    private func dcp(_ adr: Word) {
        let value = mem.read(adr) &- 1
        mem.write(adr, value)
        let result = Word(a) + Word(value ^ 0xff) + 1
        c = result > 0xff
        setZandN(Byte(result & 0xff))
    }
    
    private func isc(_ adr: Word) {
        let value = mem.read(adr) &+ 1
        mem.write(adr, value)
        let subValue = value ^ 0xff
        let result = Word(a) + Word(subValue) + (c ? 1 : 0)
        c = result > 0xff
        v = ((a & 0x80) == (subValue & 0x80)) && ((subValue & 0x80) != (result & 0x80))
        a = Byte(result & 0xff)
        setZandN(a)
    }
    
    private func anc(_ adr: Word) {
        a &= mem.read(adr)
        setZandN(a)
        c = n
    }
    
    private func alr(_ adr: Word) {
        a &= mem.read(adr)
        let carry = a & 0x1
        let result = a >> 1
        c = carry > 0
        a = result
        setZandN(a)
    }
    
    private func arr(_ adr: Word) {
        a &= mem.read(adr)
        let result = (a >> 1) | (c ? 0x80 : 0)
        setZandN(result)
        c = (result & 0x40) > 0
        v = ((result & 0x40) ^ ((result & 0x20) << 1)) > 0
        a = result
    }
    
    private func axs(_ adr: Word) {
        let value = mem.read(adr) ^ 0xff
        let result = Word(a & x) + Word(value) + 1
        c = result > 0xff
        x = Byte(result & 0xff)
        setZandN(x)
    }
}
