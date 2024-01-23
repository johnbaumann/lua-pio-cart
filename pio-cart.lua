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
    m_switchOn = true
}

function PIOCart.setLuts()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	local exp1 = PCSX.getParPtr()
	
	if(readLUT == nil or writeLUT == nil or exp1 == nil) then return end
	
	if(PIOCart.m_Connected) then
		for i=0,3,1 do
			readLUT[i + 0x1f00] = ffi.cast('uint8_t*', exp1 + bit.lshift(i,16))
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
	byte2 = bit.lshift(PIOCart.read8(address + 1), 8)
	byte1 = PIOCart.read8(address)
	result = bit.bor(byte1, byte2)
	return result
end

function PIOCart.read32(address)
	byte4 = bit.lshift(PIOCart.read8(address), 24)
	byte3 = bit.lshift(PIOCart.read8(address + 1), 16)
	byte2 = bit.lshift(PIOCart.read8(address + 2), 8)
	byte1 = PIOCart.read8(address + 3)
	result = bit.bor(byte1, byte2, byte3, byte4)
	return result
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