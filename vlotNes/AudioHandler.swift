//
//  AudioHandler.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 09/08/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Foundation
import AVFoundation

class AudioHandler {
    
    let engine: AVAudioEngine
    let playerNode: AVAudioPlayerNode
    let pcmBuffer1: AVAudioPCMBuffer
    let pcmBuffer2: AVAudioPCMBuffer
    let audioFormat: AVAudioFormat
    
    var sampleBuffer: [Float32] = [Float32](repeating: 0, count: 735)
    
    let maxCount: UInt32 = 4
    var count = 0
    var usingSecondBuffer = false
    
    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
        
        pcmBuffer1 = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 735 * maxCount)!
        pcmBuffer2 = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 735 * maxCount)!
        
        pcmBuffer1.frameLength = pcmBuffer1.frameCapacity
        pcmBuffer2.frameLength = pcmBuffer2.frameCapacity
        let data1 = pcmBuffer1.floatChannelData![0]
        let data2 = pcmBuffer2.floatChannelData![0]
        for i in 0..<Int(pcmBuffer1.frameCapacity) {
            data1[i] = 0
            data2[i] = 0
        }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: pcmBuffer1.format)
        do {
            try engine.start()
            print("Audio engine started")
            //print(engine.description)
        } catch {
            print("Error starting audio engine")
        }
    }
    
    func start() {
        print("starting audio")
        // playerNode.scheduleBuffer(pcmBuffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
    }
    
    func stop() {
        print("stopping audio")
        playerNode.stop()
        count = 0
        usingSecondBuffer = false
    }
    
    func nextBuffer() {
        let base = count * 735
        
        let data = usingSecondBuffer ? pcmBuffer2.floatChannelData![0] : pcmBuffer1.floatChannelData![0]
        for i in 0..<735 {
            data[base + i] = sampleBuffer[i]
        }
        
        count += 1
        if count == maxCount {
            playerNode.scheduleBuffer(usingSecondBuffer ? pcmBuffer2 : pcmBuffer1, at: nil, options: [], completionHandler: nil)
            count = 0
            usingSecondBuffer = !usingSecondBuffer
        }
    }
}
