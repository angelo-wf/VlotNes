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
    var romLoaded: Bool = false
    
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
        unloadRom()
        lastOpened = nil
    }
    
    func unloadRom() {
        stopLoop()
        if romLoaded {
            // save battery data for the game
            saveBattery(for: lastOpened!)
        }
        nes.unloadRom()
        pixelView.pixelData.fill(with: 0)
        pixelView.needsDisplay = true
        delegate?.setEmulationState(state: false)
        romLoaded = false;
    }
    
    func showWarning(text: String, details: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.informativeText = details
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func keyPressed(_ event: NSEvent) -> Bool {
        if let key = keyMap[Int(event.keyCode)] {
            nes.setButtonPressed(pad: 1, button: key)
            return true
        }
        // shortcuts for save and load state
        if event.keyCode == 45 {
            // load state
            if romLoaded {
                loadState(for: lastOpened!)
            }
            return true
        }
        if event.keyCode == 46 {
            // save state
            if romLoaded {
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
        unloadRom()
        var romData: [Byte] = []
        if path.lowercased().suffix(4) == ".zip" {
            // unpack the zip
            do {
                let unzipData = try getRomFromZip(path: path)
                romData = unzipData
            } catch FileError.zipLoadError(let details) {
                showWarning(text: "Failed to load rom from zip", details: details)
            } catch {
                showWarning(text: "Failed to load rom from zip", details: "An unknown error occured")
            }
        } else {
            // read the data normally
            do {
                let fileData = try loadFileAsByteArray(path: path)
                romData = fileData
            } catch {
                showWarning(text: "Failed to load rom", details: "Failed to read rom file")
            }
        }
        do {
            try nes.loadRom(rom: romData)
            // loaded rom succesfully
            NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
            lastOpened = path
            romLoaded = true
            // load battery data
            loadBattery(for: lastOpened!)
            delegate?.setEmulationState(state: true)
            startLoop()
        } catch EmulatorError.romLoadError(let details) {
            showWarning(text: "Failed to load rom", details: details)
        } catch {
            showWarning(text: "Failed to load rom", details: "An unknown error occured")
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
        if !running && romLoaded {
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
        if romLoaded {
            saveState(for: lastOpened!)
        }
    }
    
    @IBAction func loadState(_ sender: Any) {
        // load state menu item
        if romLoaded {
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
            // this game doesn't have battery saves
            return
        }
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "battery") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("srm")
        do {
            try saveByteArrayToFile(url: saveLocation, data: batteryData)
            print("Saved battery data to \(saveLocation.path)")
        } catch {
            showWarning(text: "Failed to save battery data", details: "Failed to write file")
        }
    }
    
    func loadBattery(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "battery") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("srm")
        let saveData = try? loadFileAsByteArray(path: saveLocation.path)
        if saveData == nil {
            // no battery save has been saved for this rom yet
            return
        }
        do {
            try nes.setBatteryData(data: saveData!)
            print("Loaded battery data from \(saveLocation.path)");
        } catch EmulatorError.batteryLoadError(let details) {
            showWarning(text: "Failed to load battery data", details: details)
        } catch {
            showWarning(text: "Failed to load battery data", details: "An unknown error occured")
        }
    }
    
    func saveState(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "state") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("vst")
        do {
            try saveByteArrayToFile(url: saveLocation, data: nes.getState())
            print("Saved state data to \(saveLocation.path)")
        } catch {
            showWarning(text: "Failed to save state", details: "Failed to write file")
        }
    }
    
    func loadState(for path: String) {
        let saveName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        guard let saveFolderLoc = getAppSupportDir(subFolder: "state") else {
            return
        }
        let saveLocation = saveFolderLoc.appendingPathComponent(saveName).appendingPathExtension("vst")
        let stateData = try? loadFileAsByteArray(path: saveLocation.path)
        if stateData == nil {
            // no state has been made yet
            return
        }
        do {
            try nes.setState(state: stateData!)
            print("Loaded state data from \(saveLocation.path)")
        } catch EmulatorError.stateLoadError(let details) {
            showWarning(text: "Failed to load state", details: details)
        } catch {
            showWarning(text: "Failed to load state", details: "An unknown error occured")
        }
    }
    
    func getRomFromZip(path: String) throws -> [Byte] {
        guard let tempDir = getAppSupportDir(subFolder: "temp") else {
            return []
        }
        let fileManager = FileManager.default
        // first, clear all files currently in the temp directory
        do {
            let files = try fileManager.contentsOfDirectory(atPath: tempDir.path)
            for file in files {
                try fileManager.removeItem(at: tempDir.appendingPathComponent(file))
            }
        } catch {
            throw FileError.zipLoadError(details: "Failed to clear temporary directory")
        }
        // then, unpack the zip to the temp directory
        let task = Process()
        task.launchPath = "/usr/bin/unzip"
        task.arguments = [path, "-d", tempDir.path]
        do {
            try task.run()
        } catch {
            throw FileError.zipLoadError(details: "Failed to unzip this zip file")
        }
        task.waitUntilExit()
        // now, search the temp directory for .nes files and use the first one
        var files: [String] = []
        do {
            files = try fileManager.contentsOfDirectory(atPath: tempDir.path)
        } catch {
            throw FileError.zipLoadError(details: "Failed to access the unzipped files")
        }
        for file in files {
            if file.lowercased().suffix(4) == ".nes" {
                // we found an .nes file, read it
                do {
                    let data = try loadFileAsByteArray(path: tempDir.appendingPathComponent(file).path)
                    return data
                } catch {
                    throw FileError.zipLoadError(details: "Failed to read unzipped rom file")
                }
            }
        }
        throw FileError.zipLoadError(details: "Failed to find rom in this zip file")
    }
}

