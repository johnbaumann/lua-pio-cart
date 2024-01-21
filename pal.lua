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

function PIOCart.PAL.init(self)
	self.FlashMemory:init()
	self.m_detachedMemory = ffi.fill(self.m_detachedMemory, 64 * 1024, 0xff)
end

function PIOCart.PAL.read8(address)
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

function PIOCart.PAL.reset()
	PIOCart.PAL.FlashMemory:resetFlash()
	PIOCart.PAL.m_bank = 0
end

function PIOCart.PAL.setLUTFlashBank(self, bank)
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	local exp1 = PCSX.getParPtr()
	
	if(readLUT == nil or writeLUT == nill) then return end
	
	if(bank == 0) then
		readLUT[0x1f04] = ffi.cast('uint8_t*', exp1 + bit.lshift(0,16))
		readLUT[0x1f05] = ffi.cast('uint8_t*', exp1 + bit.lshift(1,16))
	else
		readLUT[0x1f04] = ffi.cast('uint8_t*', self.m_detachedMemory)
		readLUT[0x1f05] = ffi.cast('uint8_t*', self.m_detachedMemory)
	end
	
	readLUT[0x9f04] = readLUT[0x1f04]
	readLUT[0xbf04] = readLUT[0x1f04]
	readLUT[0x9f05] = readLUT[0x1f05]
	readLUT[0xbf05] = readLUT[0x1f05]
	
	self.m_bank = bank
end

function PIOCart.PAL.write8(address, value)
	--print('PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))

	if (between(address, 0x1f000000, 0x1f03ffff)) then
		PIOCart.PAL.FlashMemory:write8(bit.band(address, 0x3ffff), value)
	elseif (between(address, 0x1f040000, 0x1f060000 - 1)) then
		if (PIOCart.PAL.m_bank == 0) then
			--print('PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
			PIOCart.PAL.FlashMemory:write8(bit.band(address, 0x3ffff), value)
		end
	elseif(address == 0x1f060001) then -- Bank Select
		PIOCart.PAL:setLUTFlashBank(value)
		--print('Bank selected: ' .. string.format("%x", value))
	else
		print('Unknown 8-bit write in PIOCart.PAL.write8: ' .. string.format("%x", address) .. ' ' .. string.format("%x", value))
	end
end
