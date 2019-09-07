//
//  Apu.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 14/08/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation

final class Apu : MemoryHandler {
    
    let nes: Nes
    
    // tables
    let dutyCycles: [[Int]] = [
        [0, 1, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 0, 0, 0],
        [1, 0, 0, 1, 1, 1, 1, 1]
    ]
    let lengthLoadValues: [Int] = [
        10, 254, 20, 2,  40, 4,  80, 6,  160, 8,  60, 10, 14, 12, 26, 14,
        12, 16,  24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
    ]
    let triangleSteps: [Int] = [
        15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5,  4,  3,  2,  1,  0,
        0,  1,  2,  3,  4,  5,  6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    ]
    let noiseLoadValues: [Word] = [
        4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
    ]
    let dmcLoadValues: [Word] = [
        428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54
    ]
    
    
    // output
    var output: [Float32] = [Float32](repeating: 0, count: 29781)
    var outputOffset: Int = 0
    
    // general
    var frameCounter: Int = 0
    var interruptInhibit: Bool = false
    var step5mode: Bool = false
    var enablePulse1: Bool = false
    var enablePulse2: Bool = false
    var enableTriangle: Bool = false
    var enableNoise: Bool = false
    
    // pulse 1
    var p1Timer: Word = 0
    var p1TimerValue: Word = 0
    var p1Duty: Byte = 0
    var p1DutyIndex: Int = 0
    var p1Output: Byte = 0
    var p1CounterHalt: Bool = false
    var p1Counter: Int = 0
    var p1Volume: Byte = 0
    var p1ConstantVolume: Bool = false
    var p1Decay: Byte = 0
    var p1EnvelopeCounter: Byte = 0
    var p1EnvelopeStart: Bool = false
    var p1SweepEnabled: Bool = false
    var p1SweepPeriod: Byte = 0
    var p1SweepNegate: Bool = false
    var p1SweepShift: Byte = 0
    var p1SweepTimer: Byte = 0
    var p1SweepTarget: Word = 0
    var p1SweepMuting: Bool = true
    var p1SweepReload: Bool = false
    
    // pulse 2
    var p2Timer: Word = 0
    var p2TimerValue: Word = 0
    var p2Duty: Byte = 0
    var p2DutyIndex: Int = 0
    var p2Output: Byte = 0
    var p2CounterHalt: Bool = false
    var p2Counter: Int = 0
    var p2Volume: Byte = 0
    var p2ConstantVolume: Bool = false
    var p2Decay: Byte = 0
    var p2EnvelopeCounter: Byte = 0
    var p2EnvelopeStart: Bool = false
    var p2SweepEnabled: Bool = false
    var p2SweepPeriod: Byte = 0
    var p2SweepNegate: Bool = false
    var p2SweepShift: Byte = 0
    var p2SweepTimer: Byte = 0
    var p2SweepTarget: Word = 0
    var p2SweepMuting: Bool = true
    var p2SweepReload: Bool = false
    
    // triangle
    var triTimer: Word = 0
    var triTimerValue: Word = 0
    var triStepIndex: Int = 0
    var triOutput: Int = 0
    var triCounterHalt: Bool = false
    var triCounter: Int = 0
    var triLinearCounter: Byte = 0
    var triReloadLinear: Bool = false
    var triLinearReload: Byte = 0
    
    // noise
    var noiseTimer: Word = 0
    var noiseTimerValue: Word = 0
    var noiseShift: Int = 1
    var noiseTonal: Bool = false
    var noiseOutput: Byte = 0
    var noiseCounterHalt: Bool = false
    var noiseCounter: Int = 0
    var noiseVolume: Byte = 0
    var noiseConstantVolume: Bool = false
    var noiseDecay: Byte = 0
    var noiseEnvelopeCounter: Byte = 0
    var noiseEnvelopeStart: Bool = false
    
    // dmc
    var dmcInterrupt: Bool = false
    var dmcLoop: Bool = false
    var dmcTimer: Word = 0
    var dmcTimerValue: Word = 0
    var dmcOutput: Byte = 0
    var dmcSampleAddress: Word = 0xc000
    var dmcAddress: Word = 0xc000
    var dmcSample: Byte = 0
    var dmcSampleLength: Int = 0
    var dmcSampleEmpty: Bool = true
    var dmcBytesLeft: Int = 0
    var dmcShifter: Byte = 0
    var dmcBitsLeft: Int = 8
    var dmcSilent: Bool = true
    
    
    init(nes: Nes) {
        self.nes = nes
        reset()
    }
    
    func reset() {
        output.fill(with: 0)
        outputOffset = 0
        
        frameCounter = 0
        interruptInhibit = false
        step5mode = false
        enablePulse1 = false
        enablePulse2 = false
        enableTriangle = false
        enableNoise = false
        
        p1Timer = 0
        p1TimerValue = 0
        p1Duty = 0
        p1DutyIndex = 0
        p1Output = 0
        p1CounterHalt = false
        p1Counter = 0
        p1Volume = 0
        p1ConstantVolume = false
        p1Decay = 0
        p1EnvelopeCounter = 0
        p1EnvelopeStart = false
        p1SweepEnabled = false
        p1SweepPeriod = 0
        p1SweepNegate = false
        p1SweepShift = 0
        p1SweepTimer = 0
        p1SweepTarget = 0
        p1SweepMuting = true
        p1SweepReload = false
        
        p2Timer = 0
        p2TimerValue = 0
        p2Duty = 0
        p2DutyIndex = 0
        p2Output = 0
        p2CounterHalt = false
        p2Counter = 0
        p2Volume = 0
        p2ConstantVolume = false
        p2Decay = 0
        p2EnvelopeCounter = 0
        p2EnvelopeStart = false
        p2SweepEnabled = false
        p2SweepPeriod = 0
        p2SweepNegate = false
        p2SweepShift = 0
        p2SweepTimer = 0
        p2SweepTarget = 0
        p2SweepMuting = true
        p2SweepReload = false
        
        triTimer = 0
        triTimerValue = 0
        triStepIndex = 0
        triOutput = 0
        triCounterHalt = false
        triCounter = 0
        triLinearCounter = 0
        triReloadLinear = false
        triLinearReload = 0
        
        noiseTimer = 0
        noiseTimerValue = 0
        noiseShift = 1
        noiseTonal = false
        noiseOutput = 0
        noiseCounterHalt = false
        noiseCounter = 0
        noiseVolume = 0
        noiseConstantVolume = false
        noiseDecay = 0
        noiseEnvelopeCounter = 0
        noiseEnvelopeStart = false
        
        dmcInterrupt = false
        dmcLoop = false
        dmcTimer = 0
        dmcTimerValue = 0
        dmcOutput = 0
        dmcSampleAddress = 0xc000
        dmcAddress = 0xc000
        dmcSample = 0
        dmcSampleLength = 0
        dmcSampleEmpty = true
        dmcBytesLeft = 0
        dmcShifter = 0
        dmcBitsLeft = 8
        dmcSilent = true
    }
    
    func handleState(_ s: StateHandler) {
        s.handleBool(&interruptInhibit, &step5mode, &enablePulse1, &enablePulse2)
        s.handleBool(&enableTriangle, &enableNoise, &p1CounterHalt, &p1ConstantVolume)
        s.handleBool(&p1EnvelopeStart, &p1SweepEnabled, &p1SweepNegate, &p1SweepMuting)
        s.handleBool(&p1SweepReload, &p2CounterHalt, &p2ConstantVolume, &p2EnvelopeStart)
        s.handleBool(&p2SweepEnabled, &p2SweepNegate, &p2SweepMuting, &p2SweepReload)
        s.handleBool(&triCounterHalt, &triReloadLinear, &noiseTonal, &noiseCounterHalt)
        s.handleBool(&noiseConstantVolume, &noiseEnvelopeStart, &dmcInterrupt, &dmcLoop)
        s.handleBool(&dmcSampleEmpty, &dmcSilent)
        s.handleByte(&p1Duty, &p1Output, &p1Volume, &p1Decay)
        s.handleByte(&p1EnvelopeCounter, &p1SweepPeriod, &p1SweepShift, &p1SweepTimer)
        s.handleByte(&p2Duty, &p2Output, &p2Volume, &p2Decay)
        s.handleByte(&p2EnvelopeCounter, &p2SweepPeriod, &p2SweepShift, &p2SweepTimer)
        s.handleByte(&triLinearCounter, &triLinearReload, &noiseOutput, &noiseVolume)
        s.handleByte(&noiseDecay, &noiseEnvelopeCounter, &dmcOutput, &dmcSample)
        s.handleByte(&dmcShifter)
        s.handleWord(&p1Timer, &p1TimerValue, &p1SweepTarget, &p2Timer)
        s.handleWord(&p2TimerValue, &p2SweepTarget, &triTimer, &triTimerValue)
        s.handleWord(&noiseTimer, &noiseTimerValue, &dmcTimer, &dmcTimerValue)
        s.handleWord(&dmcSampleAddress, &dmcAddress)
        s.handleInt(&frameCounter, &p1DutyIndex, &p1Counter, &p2DutyIndex)
        s.handleInt(&p2Counter, &triStepIndex, &triOutput, &triCounter)
        s.handleInt(&noiseShift, &noiseCounter, &dmcSampleLength, &dmcBytesLeft)
        s.handleInt(&dmcBitsLeft)
    }
    
    func cycle() {
        if (frameCounter == 29830 && !step5mode) || frameCounter == 37282 {
            frameCounter = 0
        }
        frameCounter += 1
        handleFrameCounter()
        
        cyclePulse1()
        cyclePulse2()
        cycleTriangle()
        cycleNoise()
        cycleDmc()
        
        output[outputOffset] = mix()
        outputOffset += (outputOffset == 29780) ? 0 : 1
    }
    
    // linear approximation from https://wiki.nesdev.com/w/index.php/APU_Mixer
    private func mix() -> Float32 {
        let tnd: Float32 = (0.00851 * Float32(triOutput)) + (0.00494 * Float32(noiseOutput)) + (0.00335 * Float32(dmcOutput))
        let pulse: Float32 = 0.00752 * (Float32(p1Output) + Float32(p2Output))
        // TODO: mix in mapper audio
        return tnd + pulse
    }
    
    private func cyclePulse1() {
        if p1TimerValue > 0 {
            p1TimerValue -= 1
        } else {
            p1TimerValue = (p1Timer * 2) + 1
            p1DutyIndex += 1
            p1DutyIndex &= 0x7
        }
        let output = dutyCycles[p1Duty][p1DutyIndex]
        if output == 0 || p1SweepMuting || p1Counter == 0 {
            p1Output = 0
        } else {
            p1Output = p1ConstantVolume ? p1Volume : p1Decay
        }
    }
    
    private func updateSweepP1() {
        let change = p1Timer >> p1SweepShift
        if p1SweepNegate {
            p1SweepTarget = p1Timer - change
            p1SweepTarget -= p1SweepTarget == 0 ? 0 : 1
        } else {
            p1SweepTarget = p1Timer + change
        }
        p1SweepMuting = p1SweepTarget > 0x7ff || p1Timer < 8
    }
    
    private func cyclePulse2() {
        if p2TimerValue > 0 {
            p2TimerValue -= 1
        } else {
            p2TimerValue = (p2Timer * 2) + 1
            p2DutyIndex += 1
            p2DutyIndex &= 0x7
        }
        let output = dutyCycles[p2Duty][p2DutyIndex]
        if output == 0 || p2SweepMuting || p2Counter == 0 {
            p2Output = 0
        } else {
            p2Output = p2ConstantVolume ? p2Volume : p2Decay
        }
    }
    
    private func updateSweepP2() {
        let change = p2Timer >> p2SweepShift
        if p2SweepNegate {
            p2SweepTarget = p2Timer - change
        } else {
            p2SweepTarget = p2Timer + change
        }
        p2SweepMuting = p2SweepTarget > 0x7ff || p2Timer < 8
    }
    
    private func cycleTriangle() {
        if triTimerValue > 0 {
            triTimerValue -= 1
        } else {
            triTimerValue = triTimer
            if triCounter != 0 && triLinearCounter != 0 {
                triOutput = triangleSteps[triStepIndex]
                triStepIndex += 1
                if triTimer < 2 {
                    // ultrasonic sound
                    triOutput = 7
                }
                triStepIndex &= 0x1f
            }
        }
    }
    
    private func cycleNoise() {
        if noiseTimerValue > 0 {
            noiseTimerValue -= 1
        } else {
            noiseTimerValue = noiseTimer
            var feedback = noiseShift & 1
            if noiseTonal {
                feedback ^= (noiseShift & 0x40) >> 6
            } else {
                feedback ^= (noiseShift & 0x2) >> 1
            }
            noiseShift >>= 1
            noiseShift |= feedback << 14
        }
        if noiseCounter == 0 || (noiseShift & 0x1) == 1 {
            noiseOutput = 0
        } else {
            noiseOutput = noiseConstantVolume ? noiseVolume : noiseDecay
        }
    }
    
    private func cycleDmc() {
        if dmcTimerValue > 0 {
            dmcTimerValue -= 1
        } else {
            dmcTimerValue = dmcTimer
            if !dmcSilent {
                if (dmcShifter & 0x1) == 0 && dmcOutput >= 2 {
                    dmcOutput -= 2
                } else if dmcOutput <= 125 {
                    dmcOutput += 2
                }
            }
            dmcShifter >>= 1
            dmcBitsLeft -= 1
            if dmcBitsLeft == 0 {
                dmcBitsLeft = 8
                if dmcSampleEmpty {
                    dmcSilent = true
                } else {
                    dmcSilent = false
                    dmcShifter = dmcSample
                    dmcSampleEmpty = true
                }
            }
        }
        if dmcBytesLeft > 0 && dmcSampleEmpty {
            dmcSampleEmpty = false
            dmcSample = nes.read(dmcAddress)
            dmcAddress &+= 1
            if dmcAddress == 0 {
                dmcAddress = 0x8000
            }
            dmcBytesLeft -= 1
            if dmcBytesLeft == 0 && dmcLoop {
                dmcBytesLeft = dmcSampleLength
                dmcAddress = dmcSampleAddress
            } else if dmcBytesLeft == 0 && dmcInterrupt {
                nes.dmcIrqWanted = true
            }
        }
    }
    
    private func clockQuarter() {
        // handle triangle linear counter
        if triReloadLinear {
            triLinearCounter = triLinearReload
        } else if triLinearCounter > 0 {
            triLinearCounter -= 1
        }
        if !triCounterHalt {
            triReloadLinear = false
        }
        
        // handle envelopes
        if !p1EnvelopeStart {
            if p1EnvelopeCounter > 0 {
                p1EnvelopeCounter -= 1
            } else {
                p1EnvelopeCounter = p1Volume
                if p1Decay > 0 {
                    p1Decay -= 1
                } else {
                    if p1CounterHalt {
                        p1Decay = 15
                    }
                }
            }
        } else {
            p1EnvelopeStart = false
            p1Decay = 15
            p1EnvelopeCounter = p1Volume
        }
        
        if !p2EnvelopeStart {
            if p2EnvelopeCounter > 0 {
                p2EnvelopeCounter -= 1
            } else {
                p2EnvelopeCounter = p2Volume
                if p2Decay > 0 {
                    p2Decay -= 1
                } else {
                    if p2CounterHalt {
                        p2Decay = 15
                    }
                }
            }
        } else {
            p2EnvelopeStart = false
            p2Decay = 15
            p2EnvelopeCounter = p2Volume
        }
        
        if !noiseEnvelopeStart {
            if noiseEnvelopeCounter > 0 {
                noiseEnvelopeCounter -= 1
            } else {
                noiseEnvelopeCounter = noiseVolume
                if noiseDecay > 0 {
                    noiseDecay -= 1
                } else {
                    if noiseCounterHalt {
                        noiseDecay = 15
                    }
                }
            }
        } else {
            noiseEnvelopeStart = false
            noiseDecay = 15
            noiseEnvelopeCounter = noiseVolume
        }
    }
    
    private func clockHalf() {
        // decrement length counters
        if !p1CounterHalt && p1Counter > 0 {
            p1Counter -= 1
        }
        if !p2CounterHalt && p2Counter > 0 {
            p2Counter -= 1
        }
        if !triCounterHalt && triCounter > 0 {
            triCounter -= 1
        }
        if !noiseCounterHalt && noiseCounter > 0 {
            noiseCounter -= 1
        }
        
        // handle sweeps
        if p1SweepTimer == 0 && p1SweepEnabled && !p1SweepMuting && p1SweepShift > 0 {
            p1Timer = p1SweepTarget
            updateSweepP1()
        }
        if p1SweepTimer == 0 || p1SweepReload {
            p1SweepTimer = p1SweepPeriod
            p1SweepReload = false
        } else {
            p1SweepTimer -= 1
        }
        
        if p2SweepTimer == 0 && p2SweepEnabled && !p2SweepMuting && p2SweepShift > 0 {
            p2Timer = p2SweepTarget
            updateSweepP2()
        }
        if p2SweepTimer == 0 || p2SweepReload {
            p2SweepTimer = p2SweepPeriod
            p2SweepReload = false
        } else {
            p2SweepTimer -= 1
        }
    }
    
    private func handleFrameCounter() {
        if frameCounter == 7457 {
            clockQuarter()
        } else if frameCounter == 14913 {
            clockQuarter()
            clockHalf()
        } else if frameCounter == 22371 {
            clockQuarter()
        } else if frameCounter == 29829 && !step5mode {
            clockQuarter()
            clockHalf()
            if !interruptInhibit {
                nes.frameIrqWanted = true
            }
        } else if frameCounter == 37281 {
            clockQuarter()
            clockHalf()
        }
    }
    
    func peak(_ address: Word) -> Byte {
        if address == 0x4015 {
            var ret: Byte = 0
            ret |= (p1Counter > 0) ? 0x01 : 0
            ret |= (p2Counter > 0) ? 0x02 : 0
            ret |= (triCounter > 0) ? 0x04 : 0
            ret |= (noiseCounter > 0) ? 0x08 : 0
            ret |= (dmcBytesLeft > 0) ? 0x10 : 0
            ret |= nes.frameIrqWanted ? 0x40 : 0
            ret |= nes.dmcIrqWanted ? 0x80 : 0
            return ret
        }
        return 0
    }
    
    func read(_ address: Word) -> Byte {
        if address == 0x4015 {
            var ret: Byte = 0
            ret |= (p1Counter > 0) ? 0x01 : 0
            ret |= (p2Counter > 0) ? 0x02 : 0
            ret |= (triCounter > 0) ? 0x04 : 0
            ret |= (noiseCounter > 0) ? 0x08 : 0
            ret |= (dmcBytesLeft > 0) ? 0x10 : 0
            ret |= nes.frameIrqWanted ? 0x40 : 0
            ret |= nes.dmcIrqWanted ? 0x80 : 0
            nes.frameIrqWanted = false
            return ret
        }
        return 0
    }
    
    func write(_ address: Word, _ value: Byte) {
        switch address {
        case 0x4000:
            p1Duty = (value & 0xc0) >> 6
            p1Volume = value & 0xf
            p1CounterHalt = (value & 0x20) > 0
            p1ConstantVolume = (value & 0x10) > 0
        case 0x4001:
            p1SweepEnabled = (value & 0x80) > 0
            p1SweepPeriod = (value & 0x70) >> 4
            p1SweepNegate = (value & 0x8) > 0
            p1SweepShift = value & 0x7
            p1SweepReload = true
            updateSweepP1()
        case 0x4002:
            p1Timer &= 0x700
            p1Timer |= Word(value)
            updateSweepP1()
        case 0x4003:
            p1Timer &= 0xff
            p1Timer |= Word(value & 0x7) << 8
            p1DutyIndex = 0
            if enablePulse1 {
                p1Counter = lengthLoadValues[(value & 0xf8) >> 3]
            }
            p1EnvelopeStart = true
            updateSweepP1()
        case 0x4004:
            p2Duty = (value & 0xc0) >> 6
            p2Volume = value & 0xf
            p2CounterHalt = (value & 0x20) > 0
            p2ConstantVolume = (value & 0x10) > 0
        case 0x4005:
            p2SweepEnabled = (value & 0x80) > 0
            p2SweepPeriod = (value & 0x70) >> 4
            p2SweepNegate = (value & 0x8) > 0
            p2SweepShift = value & 0x7
            p2SweepReload = true
            updateSweepP2()
        case 0x4006:
            p2Timer &= 0x700
            p2Timer |= Word(value)
            updateSweepP2()
        case 0x4007:
            p2Timer &= 0xff
            p2Timer |= Word(value & 0x7) << 8
            p2DutyIndex = 0
            if enablePulse2 {
                p2Counter = lengthLoadValues[(value & 0xf8) >> 3]
            }
            p2EnvelopeStart = true
            updateSweepP2()
        case 0x4008:
            triCounterHalt = (value & 0x80) > 0
            triLinearReload = value & 0x7f
        case 0x400a:
            triTimer &= 0x700
            triTimer |= Word(value)
        case 0x400b:
            triTimer &= 0xff
            triTimer |= Word(value & 0x7) << 8
            if enableTriangle {
                triCounter = lengthLoadValues[(value & 0xf8) >> 3]
            }
            triReloadLinear = true
        case 0x400c:
            noiseCounterHalt = (value & 0x20) > 0
            noiseConstantVolume = (value & 0x10) > 0
            noiseVolume = value & 0xf
        case 0x400e:
            noiseTonal = (value & 0x80) > 0
            noiseTimer = noiseLoadValues[value & 0xf] - 1
        case 0x400f:
            if enableNoise {
                noiseCounter = lengthLoadValues[(value & 0xf8) >> 3]
            }
            noiseEnvelopeStart = true
        case 0x4010:
            dmcInterrupt = (value & 0x80) > 0
            dmcLoop = (value & 0x40) > 0
            dmcTimer = dmcLoadValues[value & 0xf] - 1
            if !dmcInterrupt {
                nes.dmcIrqWanted = false
            }
        case 0x4011:
            dmcOutput = value & 0x7f
        case 0x4012:
            dmcSampleAddress = 0xc000 | (Word(value) << 6)
        case 0x4013:
            dmcSampleLength = (Int(value) << 4) + 1
        case 0x4015:
            enablePulse1 = (value & 0x1) > 0
            enablePulse2 = (value & 0x2) > 0
            enableTriangle = (value & 0x4) > 0
            enableNoise = (value & 0x8) > 0
            if !enablePulse1 {
                p1Counter = 0
            }
            if !enablePulse2 {
                p2Counter = 0
            }
            if !enableTriangle {
                triCounter = 0
            }
            if !enableNoise {
                noiseCounter = 0
            }
            if (value & 0x10) > 0 {
                if dmcBytesLeft == 0 {
                    dmcBytesLeft = dmcSampleLength
                    dmcAddress = dmcSampleAddress
                }
            } else {
                dmcBytesLeft = 0
            }
            nes.dmcIrqWanted = false
        case 0x4017:
            step5mode = (value & 0x80) > 0
            interruptInhibit = (value & 0x40) > 0
            if interruptInhibit {
                nes.frameIrqWanted = false
            }
            frameCounter = 0
            if step5mode {
                clockQuarter()
                clockHalf()
            }
        default:
            return
        }
    }
}
