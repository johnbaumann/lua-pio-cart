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
 ]]--

local ffi = require("ffi")

PIOCart.PAL.FlashMemory = {
    m_busCycle = 0,
    m_commandBuffer = ffi.new("uint8_t[6]"),
    m_commandBufferAddress = ffi.new("uint16_t[6]"),
    m_commandLastAddress = 0,
    m_dataProtectEnabled = true,
    m_pageWriteEnabled = false, -- Todo: Need to reset this to false on some timer
    m_softwareIDMode = false,
    m_targetWritePage = -1,
    m_softwareID = ffi.new("uint8_t[64 * 1024]"),
}

function PIOCart.PAL.FlashMemory:init()
    for i=0,(64*1024)-1,2 do
        self.m_softwareID[i] = 0xbf
        self.m_softwareID[i+1] = 0x10
    end

    self:resetFlash()
end

function PIOCart.PAL.FlashMemory:writeCommandBus(address, value)
    --print('write command bus: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))

    self.m_commandBufferAddress[self.m_busCycle] = address
    self.m_commandBuffer[self.m_busCycle] = value

    local masked_addr = bit.band(address, 0xffff)

    if(masked_addr == 0x2aaa or masked_addr == 0x5555) then
        if(not self:checkCommand()) then
            self.m_busCycle = (self.m_busCycle + 1) % 6
        end
    end
end

function PIOCart.PAL.FlashMemory:write8(address, value)
    --print('FlashMemory.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
    local masked_addr = bit.band(address, 0x1ffff)

    if (self.m_pageWriteEnabled) then
        self:resetCommandBuffer()
        if (self.m_targetWritePage == -1) then
            self.m_targetWritePage = math.floor(address / 128)
            --print('page write enabled, target page: ' .. self.m_targetWritePage .. ' ' .. string.format("%x", address))
        end

        if (math.floor(address / 128) == self.m_targetWritePage) then
            PIOCart.m_cartData[address] = value
            --print('write8: ' .. string.format("%x", address) .. ' = ' .. string.format("%x", value) .. ', page: ' .. string.format("%x", self.m_targetWritePage))

            if (math.fmod(bit.band(address, 0xff), 0x80) == 0x7f) then
                --print('page write complete')
                self.m_pageWriteEnabled = false
                self.m_targetWritePage = -1
            end
        else
            --print('page write complete')
            self.m_pageWriteEnabled = false
            self.m_targetWritePage = -1
        end
    elseif (not self.m_dataProtectEnabled) then
        self:resetCommandBuffer()
        PIOCart.m_cartData[address] = value
        --print('write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
    else
        if ((masked_addr == 0x2aaa) or (masked_addr == 0x5555)) then
            self:writeCommandBus(masked_addr, value)
        end
    end
end

function PIOCart.PAL.FlashMemory:softwareDataProtectEnablePageWrite()
    self.m_dataProtectEnabled = true
    self.m_pageWriteEnabled = true
end

function PIOCart.PAL.FlashMemory:softwareDataProtectDisable()
    self.m_dataProtectEnabled = false
end

function PIOCart.PAL.FlashMemory:softwareChipErase()
    ffi.fill(PIOCart.m_cartData, 256 * 1024, 0xff)
end

function PIOCart.PAL.FlashMemory:enterSoftwareIDMode()
    self:setLUTSoftwareID()
    self:resetCommandBuffer()
    m_softwareIDMode = true
end

function PIOCart.PAL.FlashMemory:exitSoftwareIDMode()
    self:setLUTNormal()
    self:resetCommandBuffer()
    m_softwareIDMode = false
end

function PIOCart.PAL.FlashMemory:checkCommand()
    local result = false

    -- Grab last 6 commands issued and addresses written to
    local addressHistory = ffi.new("uint16_t[6]")
    local commandHistory = ffi.new("uint8_t[6]")
    local j = 0

    for i=0,5,1 do
        if(j < 0) then j = 5 end
        addressHistory[i] = self.m_commandBufferAddress[(self.m_busCycle + j) % 6]
        commandHistory[i] = self.m_commandBuffer[(self.m_busCycle + j) % 6]
        j = j - 1
    end



    -- Check 3-cycle commands
    local is3CycleCommand = (
        (addressHistory[2] == 0x5555 and commandHistory[2] == 0xaa)
            and
        (addressHistory[1] == 0x2aaa and commandHistory[1] == 0x55)
    )

    if(is3CycleCommand) then
        if(addressHistory[0] == 0x5555) then
            if(commandHistory[0] == 0xa0) then -- Software Data Protect Enable & Page-Write
                --print('Software Data Protect Enable & Page-Write')
                self:softwareDataProtectEnablePageWrite()
                result = true
            elseif(commandHistory[0] == 0x90) then -- Software ID Entry
                --print('Software ID Entry')
                self:enterSoftwareIDMode()
                result = true
            elseif(commandHistory[0] == 0xf0) then -- Software ID Exit
                --print('Software ID Exit')
                self:exitSoftwareIDMode()
                result = true
            end
        end
    end

    if(not result) then
        local is6CycleComand = (
            (addressHistory[5] == 0x5555 and commandHistory[5] == 0xaa)
                and
            (addressHistory[4] == 0x2aaa and commandHistory[4] == 0x55)
                and
            (addressHistory[3] == 0x5555 and commandHistory[3] == 0x80)
                and
            (addressHistory[2] == 0x5555 and commandHistory[2] == 0xaa)
                and
            (addressHistory[1] == 0x2aaa and commandHistory[1] == 0x55)
        )
        -- Check 6-cycle commands
        if(is6CycleComand) then
            if(addressHistory[0] == 0x5555) then
                if(commandHistory[0] == 0x20) then -- Software Data Protect Disable
                    --print('Software Data Protect Disable')
                    self:softwareDataProtectDisable()
                    result = true
                elseif(commandHistory[0] == 0x10) then -- Software Chip-Erase
                    --print('Software Chip-Erase')
                    self:softwareChipErase()
                    result = true
                elseif(commandHistory[0] == 0x60) then -- Alternate Software ID Entry
                    --print('Alternate Software ID Entry')
                    self:enterSoftwareIDMode()
                    result = true
                end
            end
        end
    end

    return result
end

function PIOCart.PAL.FlashMemory:resetCommandBuffer()
    ffi.fill(self.m_commandBuffer, 6, 0)
    ffi.fill(self.m_commandBufferAddress, 6, 0)
end

function PIOCart.PAL.FlashMemory:resetFlash()
    self:resetCommandBuffer()
    m_dataProtectEnabled = true
    m_pageWriteEnabled = false
    m_softwareIDMode = false
    m_bank = 0
    m_chip = 0
end

function PIOCart.PAL.FlashMemory:setLUTs()
    if(self.m_softwareIDMode) then
        self:setLUTSoftwareID()
    else
        self:setLUTNormal()
    end
end

function PIOCart.PAL.FlashMemory:setLUTNormal()
    local readLUT = PCSX.getReadLUT()

    for i=0,3,1 do
        readLUT[i + 0x1f00] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(i,16))
    end

    ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"))
    ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"))
end

function PIOCart.PAL.FlashMemory:setLUTSoftwareID()
    local readLUT = PCSX.getReadLUT()

    for i=0,5,1 do
        readLUT[0x1f00 + i] = ffi.cast('uint8_t*', self.m_softwareID)
    end

    ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 5 * ffi.sizeof("void *"))
    ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 5 * ffi.sizeof("void *"))
end
