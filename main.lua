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

Support.extra.dofile('flash.lua')
Support.extra.dofile('pal.lua')

-- EXP1
local base_addr = 0x1f000000
-- EXP1

-- Cart
local cart_attached = true
local switch_on = true
local cart_buff
local cart_path = 'E:\\ps1\\cart\\unirom_standalone.rom'
-- Cart

function LoadCart(filename)
	local exp1 = PCSX.getParPtr()
	
	if(string.len(filename) == 0) then
		print('cart filename cannot be blank')
	else
		local CartBinary = assert(Support.File.open(filename, "READ"))
		print('Opened file: ' .. filename .. ' file size: ' .. CartBinary:size())

		cart_buff = Support.NewLuaBuffer(CartBinary:size())
		cart_buff = CartBinary:read(CartBinary:size())
		CartBinary:close()		

		for i=0,CartBinary:size()-1,1 do
			exp1[i] = cart_buff[i]
			
		end
		
		print('Loaded ' .. CartBinary:size() .. ' bytes to EXP1 from file: ' .. filename)
	end
end

function SetLuts()
	local readLUT = PCSX.getReadLUT()
	local writeLUT = PCSX.getWriteLUT()
	local exp1 = PCSX.getParPtr()
	
	if(readLUT == nil or writeLUT == nil or exp1 == nil) then return end
	
	if(cart_attached) then
		for i=0,3,1 do
			readLUT[i + 0x1f00] = ffi.cast('uint8_t*', exp1 + bit.lshift(i,16))
		end
		
		readLUT[0x1f04] = ffi.cast('uint8_t*', exp1)
		readLUT[0x1f05] = ffi.cast('uint8_t*', exp1 + bit.lshift(1,16))
	end
end

-- EXP1
function read8(address)
	if cart_attached then
		return pal_read8(address)
	else
		return 0xff
	end
end

function read16(address)
	byte2 = bit.lshift(read8(address + 1), 8)
	byte1 = read8(address)
	result = bit.bor(byte1, byte2)
	return result
end

function read32(address)
	byte4 = bit.lshift(read8(address), 24)
	byte3 = bit.lshift(read8(address + 1), 16)
	byte2 = bit.lshift(read8(address + 2), 8)
	byte1 = read8(address + 3)
	result = bit.bor(byte1, byte2, byte3, byte4)
	return result
end

function write8(address, value)
	if cart_attached then
		return pal_write8(addr, value)
	else
		return 0xff
	end
end

function write16(address, value)

end

function write32(address, value)

end
-- EXP1


-- Global callbacks
function DrawImguiFrame()
	local show = imgui.Begin('Lua PIO Cart', true)
	if not show then imgui.End() return end

	local changed --disposed return data

	imgui.TextUnformatted('ROM Path: ' .. cart_path)
	
	imgui.TextUnformatted('On/Off Switch:')
	imgui.SameLine()
	changed, switch_on = imgui.Checkbox('##ToggleSwitch', switch_on)
	imgui.SameLine()
	if(switch_on) then
		imgui.TextUnformatted('On')
	else
		imgui.TextUnformatted('Off')
	end
	
	changed, cart_attached = imgui.Checkbox('Connected', cart_attached)

	imgui.End()
end

function UnknownMemoryRead(address, size)
	local page = bit.band(bit.rshift(address,16),0x1fff)

	if(page >= 0x1f00 and page < 0x1f80 and cart_attached == true) then
		local addr = bit.band(address, 0x1fffffff)
			
		if size == 1 then
			return read8(addr)
		elseif size == 2 then
			return read16(addr)
		elseif size == 4 then
			return read32(addr)
		end
	end
	
	return 0xff
end

LoadCart(cart_path)
event_lutsset = PCSX.Events.createEventListener('Memory::SetLuts', SetLuts)
