//
//  ViewController.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 24/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSWindowDelegate {
    
    let keyMap: [Int:Int] = [
        6: 0,
        0: 1,
        48: 2,
        36: 3,
        126: 4,
        125: 5,
        123: 6,
        124: 7
    ]
    
    var delegate: AppDelegate?
    
    @IBOutlet weak var pixelView: PixelView!
    
    let nes = Nes()
    var audioHandler: AudioHandler!
    
    var timer: Timer?
    
    var running = false
    var lastOpened: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        delegate = NSApplication.shared.delegate as? AppDelegate
        delegate?.viewController = self
        
        audioHandler = AudioHandler()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            if self.keyPressed($0) {
                return nil
            }
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) {
            if self.keyReleased($0) {
                return nil
            }
            return $0
        }
    }
    
    override func viewWillAppear() {
        self.view.window?.backgroundColor = .black
        self.view.window?.delegate = self
        self.view.window?.contentAspectRatio = NSSize(width: 16, height: 15)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stopWindow()
        return true
    }
    
    func stopWindow() {
        stopLoop()
        if lastOpened != nil {
            // save battery data for the game
            saveBattery(for: lastOpened!)
        }
        pixelView.pixelData.fill(with: 0)
        pixelView.needsDisplay = true
        delegate?.setEmulationState(state: false)
        lastOpened = nil
    }
    
    func keyPressed(_ event: NSEvent) -> Bool {
        if let key = keyMap[Int(event.keyCode)] {
            nes.setButtonPressed(pad: 1, button: key)
            return true
        }
        // shortcuts for save and load state
        if event.keyCode == 45 {
            // load state
            if lastOpened != nil {
                loadState(for: lastOpened!)
            }
            return true
        }
        if event.keyCode == 46 {
            // save state
            if lastOpened != nil {
                saveState(for: lastOpened!)
            }
            return true
        }
        return false
    }
    
    func keyReleased(_ event: NSEvent) -> Bool {
        if let key = keyMap[Int(event.keyCode)] {
            nes.setButtonReleased(pad: 1, button: key)
            return true
        }
        return false
    }
    
    func openRom() {
        let dialog = NSOpenPanel()
        
        dialog.title = "Select rom"
        
        if dialog.runModal() == NSApplication.ModalResponse.OK {
            if let result = dialog.url {
                let path = result.path
                loadRom(path: path)
            }
        }
    }
    
    func loadRom(path: String) {
        var romData: [Byte] = []
        if path.lowercased().suffix(4) == ".zip" {
            // unpack the zip
            if let unzipData = getRomFromZip(path: path) {
                romData = unzipData
            } else {
                print("Failed to find rom in zip")
                return
            }
        } else {
            // read the data normally
            romData = loadFileAsByteArray(path: path)
        }
        if nes.loadRom(rom: romData) {
            // loaded rom succesfully
            if lastOpened != nil {
                // save battery data for previous loaded game
                saveBattery(for: lastOpened!)
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
            lastOpened = path
            // load battery data
            loadBattery(for: lastOpened!)
            delegate?.setEmulationState(state: true)
            startLoop()
        } else {
            print("Failed to load rom")
        }
    }
    
    // MARK: - Menu items
    
    @IBAction func reload(_ sender: Any) {
        // reload menu item
        if let path = lastOpened {
            loadRom(path: path)
        }
    }
    
    @IBAction func pause(_ sender: Any) {
        // pause menu item
        if !running && lastOpened != nil {
            startLoop()
        } else {
            stopLoop()
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        // reset menu item
        nes.reset()
    }
    
    @IBAction func hardReset(_ sender: Any) {
        // power cycle menu item
        nes.reset(hard: true)
    }
    
    @IBAction func saveState(_ sender: Any) {
        // save state menu item
        if lastOpened != nil {
            saveState(for: lastOpened!)
        }
    }
    
    @IBAction func loadState(_ sender: Any) {
        // load state menu item
        if lastOpened != nil {
            loadState(for: lastOpened!)
        }
    }
    
    // MARK: - Main loop
    
    func startLoop() {
        if !running {
            timer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
            delegate?.setPauseText(paused: false)
            running = true
            audioHandler.start()
        }
    }
    
    func stopLoop() {
        if running {
            timer?.invalidate()
            timer = nil
            delegate?.setPauseText(paused: true)
            running = false
            audioHandler.stop()
        }
    }
    
    @objc func update() {
        nes.runFrame()
        draw()
    }
    
    func draw() {
        nes.setPixels(inside: &pixelView.pixelData)
        pixelView.needsDisplay = true
        nes.setSamples(inside: &audioHandler.sampleBuffer)
        audioHandler.nextBuffer()
    }
    
    // MARK: - Battery and state file handling
    
    func getAppSupportDir(subFolder: String) -> URL? {
        let fileManager = FileManager.default
        guard let appSupportFolder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dataLocation = appSupportFolder.appendingPathComponent("vlotNes")
        let folderLoc = dataLocation.appendingPathComponent(subFolder)
        do {
            try fileManager.createDirectory(at: folderLoc, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        return folderLoc
    }
    
    func saveBattery(for path: String) {
        guard let batteryData = nes.getBatteryData() else {
            return
        }
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "battery") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("srm")
        if !saveByteArrayToFile(url: saveLocation, data:batteryData) {
            print("Failed to save battery file to \(saveLocation.path)")
        } else {
            print("Saved battery data to \(saveLocation.path)")
        }
    }
    
    func loadBattery(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "battery") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("srm")
        let saveData = loadFileAsByteArray(path: saveLocation.path)
        if saveData.count == 0 {
            return
        }
        if !nes.setBatteryData(data: saveData) {
            print("Failed to load battery file from \(saveLocation.path)")
        } else {
            print("Loaded battery data from \(saveLocation.path)")
        }
    }
    
    func saveState(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "state") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("vst")
        if !saveByteArrayToFile(url: saveLocation, data:nes.getState()) {
            print("Failed to save state file to \(saveLocation.path)")
        } else {
            print("Saved state data to \(saveLocation.path)")
        }
    }
    
    func loadState(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "state") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("vst")
        let stateData = loadFileAsByteArray(path: saveLocation.path)
        if stateData.count == 0 {
            return
        }
        if !nes.setState(state: stateData) {
            print("Failed to load state file from \(saveLocation.path)")
        } else {
            print("Loaded state data from \(saveLocation.path)")
        }
    }
    
    func getRomFromZip(path: String) -> [Byte]? {
        guard let tempDir = getAppSupportDir(subFolder: "temp") else {
            return nil
        }
        let fileManager = FileManager.default
        // first, clear all files currently in the temp directory
        do {
            let files = try fileManager.contentsOfDirectory(atPath: tempDir.path)
            for file in files {
                try fileManager.removeItem(at: tempDir.appendingPathComponent(file))
            }
        } catch {
            print("Failed to clear temp directory")
            return nil
        }
        // then, unpack the zip to the temp directory
        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = [path, "-d", tempDir.path]
        do {
            try task.run()
        } catch {
            print("Failed to unzip")
            return nil
        }
        task.waitUntilExit()
        // now, search the temp directory for .nes files and use the first one
        var files: [String] = []
        do {
            files = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        } catch {
            print("Failed to get files in temp directory")
            return nil
        }
        for file in files {
            if file.lowercased().suffix(4) == ".nes" {
                // we found an .nes file, read it
                let data = loadFileAsByteArray(path: tempDir.appendingPathComponent(file).path)
                return data
            }
        }
        print("No .nes file found")
        return nil
    }
}

