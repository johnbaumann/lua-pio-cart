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
	m_detachedMemory = ffi.new("uint8_t[64 * 1024]")
}

function between(val, low, high)
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
		addr_mask = bit.band(address, 7)
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
	
	print('Unknown read in EXP1/PIO: ' .. string.format("%x", address))
	return 0xff
end

function PIOCart.PAL:reset()
	self.FlashMemory:resetFlash()
	self.m_bank = 0
end

function PIOCart.PAL:setLUTFlashBank(bank)
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	
	if(readLUT == nil or writeLUT == nill) then return end
	
	if(bank == 0) then
		readLUT[0x1f04] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(0,16))
		readLUT[0x1f05] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(1,16))
	else--if(bank == 1) then
		readLUT[0x1f04] = ffi.cast('uint8_t*', self.m_detachedMemory)
		readLUT[0x1f05] = ffi.cast('uint8_t*', self.m_detachedMemory)
	end
	--[[elseif(bank == 2) then
		readLUT[0x1f04] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(2,16))
		readLUT[0x1f05] = ffi.cast('uint8_t*', PIOCart.m_cartData + bit.lshift(3,16))
	end]]--
	
	ffi.copy(readLUT + 0x9f04, readLUT + 0x1f04, 2 * ffi.sizeof("void *"))
	ffi.copy(readLUT + 0xbf04, readLUT + 0x1f04, 2 * ffi.sizeof("void *"))
	
	self.m_bank = bank
end

function PIOCart.PAL:write8(address, value)
	--print('PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))

	if (between(address, 0x1f000000, 0x1f03ffff)) then
		self.FlashMemory:write8(bit.band(address, 0x3ffff), value)
	elseif (between(address, 0x1f040000, 0x1f060000 - 1)) then
		if (self.m_bank == 0) then
			--print('PIOCart.PAL.write8: FLASH2 ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
			self.FlashMemory:write8(bit.band(address, 0x3ffff), value)
		end
	elseif(address == 0x1f060001) then -- Bank Select
		local bank = bit.band(bit.rshift(value, 4), 0x3)
		--print('Bank selected: ' .. string.format("%x", value) .. ' masked: ' .. string.format("%x", bank))
		PIOCart.PAL:setLUTFlashBank(bank)
	else
		--print('Unknown 8-bit write in PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
	end
end
