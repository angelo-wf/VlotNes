#  VlotNes

Yet another NES emulator, in Swift.

This is mostly a port of my [Javascript NES emulator](https://github.com/elzo-d/NesJs) except written in Swift as a macOS application.

The CPU has almost all instructions emulated (only the 'unstable' undocumented instructions are not), but it is not cycle-accurate.
The PPU has full sprite and background rendering, but is also not fully cycle accurate and some edge cases are not handled properly.
The APU supports all five channels, but, again, is not fully accurate. There are also some inaccuracies with OAM-DMA and such.
Most games, however, seem to run fine.

It supports mappers 0 (NROM), 1 (MMC1), 2 (UxROM), 3 (CNROM), 4 (MMC3) and 7 (AxROM).

Battery saves are supported, and so are save states.

## Usage

The emulator can load .nes files and .zip files (where it will open the first .nes file it can find from within the root of the zip file).

Controls for controller 1 are as follows:

* D-pad: Arrow keys
* Start: Enter
* Select: Tab
* A: Z
* B: A

Additionally, M makes an save state, and N loads it. Controller 2 does not have controls set up.

Other command found in the 'Emulation'-menu:

* Pause / Continue (command-P)
* Reset (command-R)
* Power Cycle (option-command-R)

'Reload' in the 'File'-menu fully reloads the rom (and battery data) for disk.

Battery saves, save states and temprary files (for .zip support) are saved in the sandbox container's Application Support. This is located at `~/Library/Containers/com.elzod.vlotNes/Data/Library/Application Support/vlotNes`.

## Problems / Todo

* Although most games run fine even with the emulation not being 100% accurate, some games do not run correctly, like Adventures of Lolo 2 and Battletoads. (interestingly, the crash that occurs when starting level 2 in Battletoads looks different than how it looks in my Javascript emulator, even though the emulation should be identical between the two.)
* The way drawing the screen is currently handled is quite CPU-intesive (being about 30% of the CPU usage). It also isn't always smooth.
* The way audio is currently played means that even the slightest lag will cause the audio to start sounding scratchy. Pausing and unpausing seems to fix it.
* The emulator in general is quite resource intensive, using about 70% of the CPU on 5th-gen Core i5. It's only barely better than my Javascript emulator.
* General usability can be better, like being able to rebind controls and better zip support.
* Only supports the 6 most used mappers. Supporting more would be nice.
