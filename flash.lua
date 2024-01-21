--[[
/***************************************************************************
 *   Copyright (C) 2024 PCSX-Redux authors                                 *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.           *
 ***************************************************************************/
 ]]

local ffi = require("ffi")

PIOCart.PAL.FlashMemory = {
    m_busCycle = 0,
    m_commandBuffer = ffi.new("uint8_t[6]"),
    m_dataProtectEnabled = true,
    m_pageWriteEnabled = false,
    m_targetWritePage = -1,
    m_softwareID = ffi.new("uint8_t[64 * 1024]"),
}

function PIOCart.PAL.FlashMemory.init()
    for i=0,(64*1024)-1,2 do
        PIOCart.PAL.FlashMemory.m_softwareID[i] = 0xbf
        PIOCart.PAL.FlashMemory.m_softwareID[i+1] = 0x10
    end
end

function PIOCart.PAL.FlashMemory.reset()
    PIOCart.PAL.FlashMemory.resetCommandBuffer()
    PIOCart.PAL.FlashMemory.m_dataProtectEnabled = true
    PIOCart.PAL.FlashMemory.m_pageWriteEnabled = false
end

function PIOCart.PAL.FlashMemory.writeCommandBus(address, value)
    --print('write command bus: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))

    PIOCart.PAL.FlashMemory.m_commandBuffer[PIOCart.PAL.FlashMemory.m_busCycle] = value

    masked_addr = bit.band(address, 0xffff)

    if(masked_addr == 0x2aaa or masked_addr == 0x5555) then
        if(not PIOCart.PAL.FlashMemory.checkCommand()) then
            PIOCart.PAL.FlashMemory.m_busCycle = (PIOCart.PAL.FlashMemory.m_busCycle + 1) % 6
        end
    end
end

function PIOCart.PAL.FlashMemory.write8(address, value)
    local offset = bit.band(address, 0x3ffff)

    --print('write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value) .. ' ' .. string.format("%x", offset))

    if (PIOCart.PAL.FlashMemory.m_pageWriteEnabled == true) then
        if (PIOCart.PAL.FlashMemory.m_targetWritePage == -1) then
            PIOCart.PAL.FlashMemory.m_targetWritePage = address / 128
        end
    end

    if ((address / 128) == PIOCart.PAL.FlashMemory.m_targetWritePage) then
        PCSX.getParPtr()[address] = value

        if (math.fmod(bit.band(address, 0xff), 0x80) == 0x7f) then
            PIOCart.PAL.FlashMemory.m_pageWriteEnabled = false
            PIOCart.PAL.FlashMemory.m_targetWritePage = -1
        end
    elseif (PIOCart.PAL.FlashMemory.m_dataProtectEnabled == false) then
        PCSX.getParPtr()[address] = value
    else
        if ((address == 0x2aaa) or (address == 0x5555)) then
            PIOCart.PAL.FlashMemory.writeCommandBus(address, value)
        end
    end   
end

function PIOCart.PAL.FlashMemory.softwareDataProtectEnablePageWrite()
    PIOCart.PAL.FlashMemory.m_dataProtectEnabled = true
    PIOCart.PAL.FlashMemory.m_pageWriteEnabled = true
end

function PIOCart.PAL.FlashMemory.softwareDataProtectDisable()
    PIOCart.PAL.FlashMemory.m_dataProtectEnabled = false
end

function PIOCart.PAL.FlashMemory.softwareChipErase()
    
end

function PIOCart.PAL.FlashMemory.enterSoftwareIDMode()
    PIOCart.PAL.FlashMemory.setLUTSoftwareID();
    PIOCart.PAL.FlashMemory.resetCommandBuffer();
end

function PIOCart.PAL.FlashMemory.exitSoftwareIDMode()

end

function PIOCart.PAL.FlashMemory.checkCommand()
    result = false

    -- Grab last 6 commands issued
    local commandHistory = ffi.new("uint8_t[6]")   
    local j = 0
    for i=0,5,1 do
        if(j < 0) then j = 5 end
        commandHistory[i] = PIOCart.PAL.FlashMemory.m_commandBuffer[(PIOCart.PAL.FlashMemory.m_busCycle + j) % 6]
        j = j - 1
    end

    -- Check 3-cycle commands
    if(commandHistory[2] == 0xaa and commandHistory[1] == 0x55) then
        if(commandHistory[0] == 0xa0) then -- Software Data Protect Enable & Page - Write
            print('Software Data Protect Enable & Page - Write')
            PIOCart.PAL.FlashMemory.softwareDataProtectEnablePageWrite()
            result = true
        elseif(commandHistory[0] == 0x90) then -- Software ID Entry
            print('Software ID Entry')
            PIOCart.PAL.FlashMemory.enterSoftwareIDMode()
            result = true
        elseif(commandHistory[0] == 0xf0) then -- Software ID Exit
            print('Software ID Exit')
            PIOCart.PAL.FlashMemory.softwareChipErase()
            result = true
        end
    end

    if(not result) then
        -- Check 6-cycle commands
        if(commandHistory[5] == 0xaa and commandHistory[4] == 0x55 and commandHistory[3] == 0x90 and commandHistory[2] == 0xaa and commandHistory[1] == 0x55) then
            if(commandHistory[0] == 0x20) then -- Software Data Protect Disable
                print('Software Data Protect Disable')
                PIOCart.PAL.FlashMemory.softwareDataProtectDisable()
                result = true
            elseif(commandHistory[0] == 0x10) then -- Software Chip-Erase
                print('Software Chip-Erase')
                PIOCart.PAL.FlashMemory.softwareChipErase()
                result = true
            elseif(commandHistory[0] == 0x60) then -- Alternate Software ID Entry
                print('Alternate Software ID Entry')
                PIOCart.PAL.FlashMemory.enterSoftwareIDMode()
                result = true
            end
        end
    end

    return result
end

function PIOCart.PAL.FlashMemory.resetCommandBuffer()
    ffi.fill(PIOCart.PAL.FlashMemory.m_commandBuffer, 6, 0)
end

function PIOCart.PAL.FlashMemory.resetFlash()

end

function PIOCart.PAL.FlashMemory.setLUTNormal()
    local readLUT = PCSX.getReadLUT()
	local exp1 = PCSX.getParPtr()

    for i=0,3,1 do
        readLUT[i + 0x1f00] = ffi.cast('uint8_t*', exp1 + bit.lshift(i,16))
    end

    ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"));
    ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"));
end

function PIOCart.PAL.FlashMemory.setLUTSoftwareID()
    local readLUT = PCSX.getReadLUT()
	local exp1 = PCSX.getParPtr()

    for i=0,3,1 do
        readLUT[0x1f00 + i] = ffi.cast('uint8_t*', PIOCart.PAL.FlashMemory.m_softwareID)
    end

    ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"));
    ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"));
end

PIOCart.PAL.FlashMemory.reset()