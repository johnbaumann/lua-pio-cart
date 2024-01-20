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

PIOCart.PAL.FlashMemory = {
    m_dataProtectEnabled = true,
    m_pageWriteEnabled = false,
    m_targetWritePage = -1
}

function PIOCart.PAL.FlashMemory.reset()
    PIOCart.PAL.FlashMemory.resetCommandBuffer()
    PIOCart.PAL.FlashMemory.m_dataProtectEnabled = true
    PIOCart.PAL.FlashMemory.m_pageWriteEnabled = false
end

function PIOCart.PAL.FlashMemory.writeCommandBus(address, value)
    print('write command bus: ' .. address .. ' ' .. value)
end

function PIOCart.PAL.FlashMemory.write8(address, value)
    local offset = bit.band(address, 0x3ffff)

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

end

function PIOCart.PAL.FlashMemory.softwareDataProtectDisable()

end

function PIOCart.PAL.FlashMemory.enterSoftwareIDMode()

end

function PIOCart.PAL.FlashMemory.exitSoftwareIDMode()

end

function PIOCart.PAL.FlashMemory.checkCommand()

end

function PIOCart.PAL.FlashMemory.resetCommandBuffer()

end

function PIOCart.PAL.FlashMemory.resetFlash()

end

function PIOCart.PAL.FlashMemory.setLUTNormal()
    
end

function PIOCart.PAL.FlashMemory.setLUTSoftwareID()

end

PIOCart.PAL.FlashMemory.reset()