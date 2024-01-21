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

Support.extra.dofile('pio-cart.lua')
Support.extra.dofile('pal.lua')
Support.extra.dofile('flash.lua')

PIOCart.cart_path = 'd:/psx/cart/unirom_standalone.rom'

-- Global callbacks
function DrawImguiFrame()
	local show = imgui.Begin('Lua PIO Cart', true)
	if not show then imgui.End() return end

	local changed

	imgui.TextUnformatted('ROM Path: ' .. PIOCart.cart_path)
	
	imgui.TextUnformatted('On/Off Switch:')
	imgui.SameLine()
	changed, PIOCart.m_switchOn = imgui.Checkbox('##ToggleSwitch', PIOCart.m_switchOn)
	imgui.SameLine()
	if(PIOCart.m_switchOn) then
		imgui.TextUnformatted('On')
	else
		imgui.TextUnformatted('Off')
	end
	
	changed, PIOCart.m_Connected = imgui.Checkbox('Connected', PIOCart.m_Connected)

	imgui.End()
end

function UnknownMemoryRead(address, size)
	local page = bit.band(bit.rshift(address,16),0x1fff)

	if(page >= 0x1f00 and page < 0x1f80 and PIOCart.m_Connected == true) then
		local addr = bit.band(address, 0x1fffffff)

		if size == 1 then
			return PIOCart.read8(addr)
		elseif size == 2 then
			return PIOCart.read16(addr)
		elseif size == 4 then
			return PIOCart.read32(addr)
		end
	end

	return 0xff
end

function UnknownMemoryWrite(address, size, value)
	local page = bit.band(bit.rshift(address,16),0x1fff)

	--print("page = " .. string.format("%x", page))

	if(page >= 0x1f00 and page < 0x1f80 and PIOCart.m_Connected == true) then
		local addr = bit.band(address, 0x1fffffff)

		if size == 1 then
			PIOCart.write8(addr, bit.band(value, 0xff))
		elseif size == 2 then
			PIOCart.write16(addr, bit.band(value, 0xffff))
		elseif size == 4 then
			PIOCart.write32(addr, bit.band(value, 0xffffffff))
		end

		return true
	end
end

function resetCallback(reset_type)
	print('PIO Cart reset')
	PIOCart.LoadCart(PIOCart.cart_path)
	PIOCart.setLuts()
	if(reset_type.hard == true) then

	else
		
	end
end

PIOCart.PAL.FlashMemory.init()
PIOCart.LoadCart(PIOCart.cart_path)

event_reset = PCSX.Events.createEventListener('ExecutionFlow::Reset', resetCallback)