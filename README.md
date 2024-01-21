# Lua PIO Cart for PCSX-Redux

## What is it?

A PIO cart written in Lua for use with PCSX-Redux.
This serves as a fairly loose emulation of the PAL and flash memory found inside of a common cheat cartridge, such as the Xploder/Xplorer. Specifically, the flash chip emulation is based around the SST29EE020.
The primary rom target during development was Unirom, so some features may be unimplemented, or implemented wrongly.

## Known issues/limitations

Bank switching is not fully implemented. For this reason, most AR/GS/Xplorer roms will fail to boot. Caetla "works", but freezes in several menu options.

## Usage

This project is intended to be self-contained within a zip archive. The primary methods to load this file are:

### Drag and drop

Drag the zip archive onto PCSX-Redux's main window, you will see a message in the log window stating that the zip was added to the list of loaded archives.

### File menu

From the main menu, click File, Add Lua archive, and navigate to the zip archive.

### From the Lua Editor or Lua Console window

Use the following command format Support.extra.dofile('DirectPathToZip'), i.e.
```Support.extra.dofile('E:/ps1/lua/pio-cart.zip')```

### Command Line Flag

Pass the ``-archive`` parameter when launching PCSX-Redux, followed by the filename of the zip archive, i.e.
```
.\pcsx-redux.exe -archive .\pio-cart.zip
```
