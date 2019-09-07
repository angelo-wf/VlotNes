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
    let pcmBuffer: AVAudioPCMBuffer
    let audioFormat: AVAudioFormat
    
    var sampleBuffer: [Float32] = [Float32](repeating: 0, count: 735)
    
    var count = 0
    
    init() {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
        
        pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: 735 * 4)!
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let data = pcmBuffer.floatChannelData![0]
        for i in 0..<Int(pcmBuffer.frameCapacity) {
            data[i] = 0
        }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: pcmBuffer.format)
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
        playerNode.scheduleBuffer(pcmBuffer, at: nil, options: .loops, completionHandler: nil)
        playerNode.play()
    }
    
    func stop() {
        print("stopping audio")
        playerNode.stop()
        count = 0
    }
    
    func nextBuffer() {
        let base = count * 735
        
        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        let data = pcmBuffer.floatChannelData![0]
        for i in 0..<735 {
            data[base + i] = sampleBuffer[i]
        }
        
        count += 1
        if count == 4 {
            //playerNode.scheduleBuffer(pcmBuffer, at: nil, options: [], completionHandler: nil)
            count = 0
        }
    }
}
