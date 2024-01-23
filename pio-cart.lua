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

 PIOCart = {
    m_Connected = true,
    m_switchOn = true,
	m_cartData = ffi.new("uint8_t[512 * 1024]")
}

function PIOCart.setLuts()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	
	if(readLUT == nil or writeLUT == nil) then return end
	
	if(PIOCart.m_Connected) then
		for i=0,3,1 do
			readLUT[i + 0x1f00] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(i,16))
		end
		
		PIOCart.PAL:setLUTFlashBank(PIOCart.PAL.m_bank)

		ffi.fill(writeLUT + 0x1f00, 6 * ffi.sizeof("void *"), 0)
		ffi.fill(writeLUT + 0x9f00, 6 * ffi.sizeof("void *"), 0)
		ffi.fill(writeLUT + 0xbf00, 6 * ffi.sizeof("void *"), 0)

		ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 6 * ffi.sizeof("void *"))
		ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 6 * ffi.sizeof("void *"))
	end
end

function PIOCart.read8(address) 
	return PIOCart.PAL:read8(address)
end

function PIOCart.read16(address)
	local byte2 = bit.lshift(PIOCart.read8(address + 1), 8)
	local byte1 = PIOCart.read8(address)
	return bit.bor(byte2, byte1)
end

function PIOCart.read32(address)
	local byte4 = bit.lshift(PIOCart.read8(address), 24)
	local byte3 = bit.lshift(PIOCart.read8(address + 1), 16)
	local byte2 = bit.lshift(PIOCart.read8(address + 2), 8)
	local byte1 = PIOCart.read8(address + 3)
	return bit.bor(byte4, byte3, byte2, byte1)
end

function PIOCart.write8(address, value)
	--print('PIOCart.write8 ' .. string.format("%x", address) .. ' = ' .. string.format("%x", value))
	PIOCart.PAL:write8(address, value)
end

function PIOCart.write16(address, value)
	print('PIOCart.write16 not implemented')
end

function PIOCart.write32(address, value)
	print('PIOCart.write32 not implemented')
end