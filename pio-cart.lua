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

 PIOCart = {
    m_Connected = true,
    m_switchOn = true,
    PAL = {FlashMemory = {}}
}

function PIOCart.LoadCart(filename)
	local exp1 = PCSX.getParPtr()
	
	if(string.len(filename) == 0) then
		print('cart filename cannot be blank')
	else
		local CartBinary = Support.extra.open(filename)
		if(CartBinary == nil) then
			print('Failed to open file: ' .. filename)
			return
		end

		print('Opened file: ' .. filename .. ' file size: ' .. CartBinary:size())

		cart_buff = Support.NewLuaBuffer(CartBinary:size())
		cart_buff = CartBinary:read(CartBinary:size())

		for i=0,CartBinary:size()-1,1 do
			exp1[i] = cart_buff[i]
		end
		
		print('Loaded ' .. CartBinary:size() .. ' bytes to EXP1 from file: ' .. filename)
		CartBinary:close()
		event_lutsset = PCSX.Events.createEventListener('Memory::SetLuts', PIOCart.setLuts)
	end
end

function PIOCart.setLuts()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	local exp1 = PCSX.getParPtr()
	
	if(readLUT == nil or writeLUT == nil or exp1 == nil) then return end
	
	if(PIOCart.m_Connected) then
		for i=0,3,1 do
			readLUT[i + 0x1f00] = ffi.cast('uint8_t*', exp1 + bit.lshift(i,16))
		end
		
		readLUT[0x1f04] = ffi.cast('uint8_t*', exp1)
		readLUT[0x1f05] = ffi.cast('uint8_t*', exp1 + bit.lshift(1,16))
	end
end

function PIOCart.read8(address)
	if PIOCart.m_Connected then
		return PIOCart.PAL.read8(address)
	else
		return 0xff
	end
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
	if PIOCart.m_Connected then
		return PAL.write8(addr, value)
	else
		return 0xff
	end
end

function PIOCart.write16(address, value)

end

function PIOCart.write32(address, value)

end