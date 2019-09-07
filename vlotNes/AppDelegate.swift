//
//  AppDelegate.swift
//  vlotNes
//
//  Created by Elzo Doornbos on 24/07/2019.
//  Copyright © 2019 Elzo Doornbos. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var viewController: ViewController?
    
    @IBOutlet weak var pauseMenuItem: NSMenuItem!
    @IBOutlet weak var resetMenuItem: NSMenuItem!
    @IBOutlet weak var powerMenuItem: NSMenuItem!
    @IBOutlet weak var saveStateMenuItem: NSMenuItem!
    @IBOutlet weak var loadStateMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        if let viewController = viewController {
            setEmulationState(state: viewController.lastOpened != nil)
        } else {
            setEmulationState(state: false)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        viewController?.stopWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            viewController?.view.window?.makeKeyAndOrderFront(self)
        }
        return true
    }
    
    func application(_ sender: NSApplication, openFile fileName: String) -> Bool {
        viewController?.loadRom(path: fileName)
        viewController?.view.window?.makeKeyAndOrderFront(self)
        return true
    }
    
    @IBAction func openFile(_ sender: Any) {
        viewController?.openRom()
        viewController?.view.window?.makeKeyAndOrderFront(self)
    }
    
    func setPauseText(paused: Bool) {
        pauseMenuItem.title = paused ? "Continue" : "Pause"
    }
    
    func setEmulationState(state: Bool) {
        pauseMenuItem.isEnabled = state
        resetMenuItem.isEnabled = state
        powerMenuItem.isEnabled = state
        saveStateMenuItem.isEnabled = state
        loadStateMenuItem.isEnabled = state
    }


}

