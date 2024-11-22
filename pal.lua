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

PIOCart.PAL = {
	m_bank = 0,
	m_chip = 0,
	m_detachedMemory = ffi.new("uint8_t[64 * 1024]")
}

function PIOCart.PAL:between(val, low, high)
	if(low > high) then return false end
	return (val >= low and val <= high)
end

function PIOCart.PAL:init()
	self.FlashMemory:init()
	ffi.fill(self.m_detachedMemory, 64 * 1024, 0xFF)
end

function PIOCart.PAL:read8(address)
	local page = bit.rshift(address,16)
	local switch_bit = 0
	if PIOCart.m_switchOn then switch_bit = 1 end
	
	if(page == 0x1f06) then
		local addr_mask = bit.band(address, 7)
		if(addr_mask == 0) then
			return bit.bor(0xfe, switch_bit) --Switch Status
		elseif(addr_mask == 1) then
			return 0x00
		elseif(addr_mask == 2) then
			return 0xfe
		elseif(addr_mask >= 3 and addr_mask <= 7) then
			return 0xff
		end
	end
	
	--print('Unknown read in EXP1/PIO: ' .. string.format("%x", address))
	return 0xff
end

function PIOCart.PAL:reset()
	self.FlashMemory:resetFlash()
	self.m_bank = 0
end

function PIOCart.PAL:setLUTs()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()

	for i=0,3,1 do
		readLUT[i + 0x1f00] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(i,16))
	end

	ffi.copy(readLUT + 0x9f00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"))
	ffi.copy(readLUT+ 0xbf00, readLUT + 0x1f00, 4 * ffi.sizeof("void *"))

	PIOCart.PAL:setLUTFlashBank()
end

function PIOCart.PAL:setLUTFlashBank()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	
	if(readLUT == nil or writeLUT == nill) then return end

	if(self.m_chip == 0) then
		self.FlashMemory:setLUTs()
		
		if(self.m_bank == 0) then
			ffi.copy(readLUT + 0x1f04, readLUT + 0x1f00, 2 * ffi.sizeof("void *"))
		else--if(bank == 1) then
			ffi.copy(readLUT + 0x1f04, readLUT + 0x1f02, 2 * ffi.sizeof("void *"))
		end
	else
		readLUT[0x1f04] = ffi.cast('uint8_t*', self.m_detachedMemory)
		readLUT[0x1f05] = ffi.cast('uint8_t*', self.m_detachedMemory)
	end
	
	ffi.copy(readLUT + 0x9f04, readLUT + 0x1f04, 2 * ffi.sizeof("void *"))
	ffi.copy(readLUT + 0xbf04, readLUT + 0x1f04, 2 * ffi.sizeof("void *"))
end

function PIOCart.PAL:write8(address, value)
	--print('PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))

	if (self:between(address, 0x1f000000, 0x1f03ffff)) then
		if (self.m_chip == 0) then
			self.FlashMemory:write8(bit.band(address, 0x3ffff), value)
		end
	elseif (self:between(address, 0x1f040000, 0x1f060000 - 1)) then
		if (self.m_chip == 0) then
			--print('Flash2 write to ' .. string.format("%x", bit.band(address, 0x1ffff) + (self.m_bank * (128 * 1024))))
			self.FlashMemory:write8(bit.band(address, 0x1ffff) + (self.m_bank * (128 * 1024)) , value)
		end
	elseif(address == 0x1f060001) then -- Bank Select
		self.m_bank = bit.band(bit.rshift(value, 5), 0x1) -- Flash Bank Select
		self.m_chip = bit.band(bit.rshift(value, 4), 0x1) -- SRAM/EEPROM Switching
		--print('Bank select( ' .. string.format("%x", value) .. '), bank: ' .. string.format("%x", self.m_bank) .. ' chip: ' .. string.format("%x", self.m_chip))
		PIOCart.PAL:setLUTFlashBank()
	else
		--print('Unknown 8-bit write in PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
	end
end
