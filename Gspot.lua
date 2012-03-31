-- This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
-- Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
-- 1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.

local Gspot = {
	load = function(this)
		local def = {
			style = {
				unit = 16,
				font = love.graphics.newFont(10),
				imagemode = 'replace',
				fg = {224, 224, 224, 255},
				bg = {32, 32, 32, 255},
				default = {96, 96, 96, 255},
				hilite = {128, 128, 128, 255},
				focus = {160, 160, 160, 255},
			},
			dblclickinterval = 0.25,
			-- no messin' past here
			maxid = 0, -- legacy
			mem = {},
			elements = {},
			mousein = nil,
			focus = nil,
			drag = nil,
			mousedt = 0,
			orepeat = {},
		}
		return setmetatable(def, {__index = this, __call = this.load})
	end,
	
	update = function(this, dt)
		this.mousedt = this.mousedt + dt
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local mousein = this.mousein
		this.mousein = false
		this.mouseover = false
		if this.drag then
			local element = this.drag
			if love.mouse.isDown('l') then
				if type(element.drag) == 'function' then element:drag(mouse.x, mouse.y)
				else
					element.pos.y = mouse.y - element.offset.y
					element.pos.x = mouse.x - element.offset.x
				end
			elseif love.mouse.isDown('r') then
				if type(element.rdrag) == 'function' then element:rdrag(mouse.x, mouse.y)
				else
					element.pos.y = mouse.y - element.offset.y
					element.pos.x = mouse.x - element.offset.x
				end
			end
			for i, bucket in ipairs(this.elements) do
				if bucket ~= element then
					if bucket:containspoint(mouse) then this.mouseover = bucket end
				end
			end
		end
		for i, element in ipairs(this.elements) do
			if element.display then
				if element.update then
					if element.updateinterval then
						element.dt = element.dt or 0
						element.dt = element.dt + dt
						if element.dt >= element.updateinterval then
							element.dt = 0
							element:update(dt)
						end
					else element:update(dt) end
				end
				if element:containspoint(mouse) then
					if element.parent and element.parent.elementtype == 'scrollgroup' and element ~= element.parent.scroller then
						if this.util.withinrect(mouse, element.parent:getpos()) then this.mousein = element end
					else this.mousein = element end
				end
			end
		end
		if this.mousein ~= mousein then
			if this.mousein and this.mousein.enter then this.mousein:enter() end
			if mousein and mousein.leave then mousein:leave() end
		end
	end,
	
	draw = function(this)
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local ostyle = {}
		ostyle.colormode = love.graphics.getColorMode()
		ostyle.font = love.graphics.getFont()
		ostyle.r, ostyle.g, ostyle.b, ostyle.a = love.graphics.getColor()
		ostyle.scissor = {}
		ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h = love.graphics.getScissor()
		love.graphics.setColorMode('modulate')
		for i, element in ipairs(this.elements) do
			if element.display then
				local pos, scissor = element:getpos()
				if scissor then love.graphics.setScissor(scissor.x, scissor.y, scissor.w, scissor.h) end
				love.graphics.setFont(element.style.font)
				element:draw(pos)
				if ostyle.scissor.x then love.graphics.setScissor(ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h)
				else love.graphics.setScissor() end
			end
		end
		if this.mousein and this.mousein.tip then
			local element = this.mousein
			local pos = element:getpos()
			local tippos = {x = pos.x + (this.style.unit / 2), y = pos.y + (this.style.unit / 2), w = element.style.font:getWidth(element.tip) + this.style.unit, h = this.style.unit}
			love.graphics.setColor(this.style.bg)
			this.mousein:rect({x = math.max(0, math.min(tippos.x, love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + this.style.unit))), y = math.max(0, math.min(tippos.y, love.graphics.getHeight() - this.style.unit)), w = tippos.w, h = tippos.h})
			love.graphics.setColor(this.style.fg)
			love.graphics.print(element.tip, math.max(this.style.unit / 2, math.min(tippos.x + (this.style.unit / 2), love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + (this.style.unit / 2)))), math.max((this.style.unit - element.style.font:getHeight(element.tip)) / 2, math.min(tippos.y + ((this.style.unit - element.style.font:getHeight('dp')) / 2), (love.graphics.getHeight() - this.style.unit) + ((this.style.unit - element.style.font:getHeight('dp')) / 2))))
		end
		love.graphics.setFont(ostyle.font)
		love.graphics.setColor(ostyle.r, ostyle.g, ostyle.b, ostyle.a)
		love.graphics.setColorMode(ostyle.colormode)
		if ostyle.scissor.x then love.graphics.setScissor(ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h)
		else love.graphics.setScissor() end
	end,
	
	mousepress = function(this, x, y, button, dt)
		this:unfocus()
		if this.mousein then
			local element = this.mousein
			if element.elementtype ~= 'hidden' then element:getparent():setlevel() end
			if element.drag then
				this.drag = element
				element.offset = {x = x - element:getpos().x, y = y - element:getpos().y}
			end
			if button == 'l' then
				if this.mousedt < this.dblclickinterval and element.dblclick then element:dblclick(x, y, button)
				elseif element.click then element:click(x, y)end
			elseif button == 'r' and element.rclick then element:rclick(x, y)
			elseif button == 'wu' and element.wheelup then element:wheelup(x, y)
			elseif button == 'wd' and element.wheeldown then element:wheeldown(x, y)
			end
		end
		this.mousedt = 0
	end,

	mouserelease = function(this, x, y, button)
		if this.drag then
			local element = this.drag
			if button == 'l' then
				if element.drop then element:drop(this.mouseover) end
				if this.mouseover and this.mouseover.catch then this.mouseover:catch(element) end
			elseif button == 'r' then
				if element.rdrop then element:rdrop(this.mouseover) end
				if this.mouseover and this.mouseover.rcatch then this.mouseover:rcatch(element.id) end
			end
		end
		this.drag = nil
	end,

	keypress = function(this, key, code)
		if this.focus then
			if key == 'return' and this.focus.done then this.focus:done() end
			if this.focus and this.focus.keypress then this.focus:keypress(key, code) end
		end
	end,
	
	-- legacy
	newid = function(this)
		this.maxid = this.maxid + 1
		return this.maxid
	end,
	-- /legacy
	
	clone = function(this, t)
		local c = {}
		for i, v in pairs(t) do
			if v then
				if type(v) == 'table' then c[i] = this:clone(v) else c[i] = v end
			end
		end
		return setmetatable(c, getmetatable(t))
	end,
	
	getindex = function(tab, val)
		for i, v in pairs(tab) do if v == val then return i end end
	end,
	
	add = function(this, element)
		element.id = this:newid() -- legacy
		table.insert(this.elements, element)
		if element.parent then element.parent:addchild(element) end
		return element
	end,

	rem = function(this, element)
		if element.parent then element.parent:remchild(element) end
		while #element.children > 0 do
			for i, child in ipairs(element.children) do this:rem(child) end
		end
		if element == this.mousein then this.mousein = nil end
		if element == this.drag then this.drag = nil end
		if element == this.focus then this:unfocus() end
		return table.remove(this.elements, this.getindex(this.elements, element))
	end,
	
	setfocus = function(this, element)
		if element then
			this.focus = element
			if element.keyrepeat and element.keyrepeat > 0 then
				this.orepeat.delay, this.orepeat.interval = love.keyboard.getKeyRepeat()
				if element.keydelay then love.keyboard.setKeyRepeat(element.keydelay, element.keyrepeat)
				else love.keyboard.setKeyRepeat(element.keyrepeat, element.keyrepeat) end
			end
		end
	end,
	
	unfocus = function(this)
		this.focus = nil
		if this.orepeat then love.keyboard.setKeyRepeat(this.orepeat.delay, this.orepeat.interval) end
	end,
}

Gspot.pos = {
	load = function(this, Gspot, t)
		assert(type(t) == 'table' or not t, 'invalid pos constructor argument : must be of type table or nil')
		t = t or {}
		t = t.pos or t
		local circ = false
		local pos = {}
		if t.r or t[5] or (#t == 3 and not t.w) then
			pos.r = t.r or t[5] or t[3]
			circ = true
			pos.w = t.w or t[3] or pos.r * 2
			pos.h = t.h or t[4] or pos.r * 2
		else
			pos.w = t.w or t[3] or Gspot.style.unit
			pos.h = t.h or t[4] or Gspot.style.unit
		end
		pos.x = t.x or t[1] or 0
		pos.y = t.y or t[2] or 0
		return setmetatable(pos, this), circ
	end,
	__unm = function(a)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		c.x = 0 - a.x
		c.y = 0 - a.y
		return setmetatable(c, getmetatable(a))
	end,
	__add = function(a, b)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		local d
		local success, e = pcall(function(b) return b.x end, b)
		if success then d = e else d = b end
		c.x = a.x + d
		local success, e = pcall(function(b) return b.y end, b)
		if success then d = e else d = b end
		c.y = a.y + d
		return setmetatable(c, getmetatable(a))
	end,
	__sub = function(a, b)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		local d
		local success, e = pcall(function(b) return b.x end, b)
		if success then d = e else d = b end
		c.x = a.x - d
		local success, e = pcall(function(b) return b.y end, b)
		if success then d = e else d = b end
		c.y = a.y - d
		return setmetatable(c, getmetatable(a))
	end,
	__mul = function(a, b)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		local d
		local success, e = pcall(function(b) return b.x end, b)
		if success then d = e else d = b end
		c.x = a.x * d
		local success, e = pcall(function(b) return b.y end, b)
		if success then d = e else d = b end
		c.y = c.y * d
		return setmetatable(c, getmetatable(a))
	end,
	__div = function(a, b)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		local d
		local success, e = pcall(function(b) return b.x end, b)
		if success then d = e else d = b end
		c.x = a.x / d
		local success, e = pcall(function(b) return b.y end, b)
		if success then d = e else d = b end
		c.y = a.y / d
		return setmetatable(c, getmetatable(a))
	end,
	__pow = function(a, b)
		local c = {x = a.x, y = a.y, w = a.w, h = a.h, r = a.r}
		local d
		local success, e = pcall(function(b) return b.x end, b)
		if success then d = e else d = b end
		c.x = a.x ^ d
		local success, e = pcall(function(b) return b.y end, b)
		if success then d = e else d = b end
		c.y = a.y ^ d
		return setmetatable(c, getmetatable(a))
	end,
	__tostring = function(this) return this:type() .. ' : x = ' .. tostring(this.x) .. ', y = ' .. tostring(this.y) .. ', w = ' .. tostring(this.w) .. ', h = ' .. tostring(this.h) .. ', r = ' .. tostring(this.r) end,
	__index = {
		type = function(this) return 'Gspot.pos' end,
	},
}
setmetatable(Gspot.pos, {__call = Gspot.pos.load})

Gspot.util = {
	setshape = function(this, shape)
		assert(shape == 'circle' or shape == 'rect' or not shape, 'shape must be "rect" or "circle" or nil')
		this.shape = shape
		if this.shape == 'circle' and not this.pos.r then this.pos.r = this.pos.w / 2 end
	end,
	
	drawshape = function(this, pos)
		pos = pos or this:getpos()
		if this.shape == 'circle' then
			local segments = this.segments or math.max(pos.r, 8)
			love.graphics.circle('fill', pos.x + pos.r, pos.y + pos.r, pos.r, segments)
		else
			this:rect(pos)
		end
	end,
	
	rect = function(this, pos, mode)
		pos = this.Gspot:pos(pos.pos or pos or this.pos)
		assert(pos:type() == 'Gspot.pos')
		mode = mode or 'fill'
		love.graphics.rectangle(mode, pos.x, pos.y, pos.w, pos.h)
	end,
	
	setimage = function(this, img)
		if type(img) == 'string' and love.filesystem.exists(img) then img = love.graphics.newImage(img) end
		if pcall(function(img) return img:type() == 'Image' end, img) then this.img = img
		else this.img = nil end
	end,
	
	drawimg = function(this, pos)
		love.graphics.setColor({255, 255, 255, 255})
		love.graphics.setColorMode(this.style.imagemode)
		love.graphics.draw(this.img, (pos.x + (pos.w / 2)) - (this.img:getWidth()) / 2, (pos.y + (pos.h / 2)) - (this.img:getHeight() / 2))
		love.graphics.setColorMode('modulate')
	end,
	
	setfont = function(this, font, size)
		if type(font) == 'string' and love.filesystem.exists(font) then
			font = love.graphics.newFont(font, size)
		elseif type(font) == 'number' then
			font = love.graphics.newFont(font)
		end
		if pcall(function(font) return font:type() == 'Font' end, font) then
			this.style.font = font
		else
			this.style.font = nil
			this.style = this.Gspot:clone(this.style)
		end
	end,
	
	getpos = function(this, scissor)
		local pos = this.Gspot:pos(this)
		if this.parent then
			ppos, scissor = this.parent:getpos()
			pos = pos + ppos
			if this.parent:type() == 'Gspot.element.scrollgroup' and this ~= this.parent.scroller then
				scissor = this.Gspot:clone(this.parent:getpos())
				pos.y = pos.y - this.parent.scroller.values.current
			end
		end
		return pos, scissor
	end,
	
	containspoint = function(this, point)
		local pos = point.pos or point
		if this.shape == 'circle' then
			if this.withinradius(pos, this:getpos() + this.pos.r) then return true end
		elseif this.withinrect(pos, this:getpos()) then return true end
		return false
	end,
	
	withinrect = function(pos, rect)
		pos = pos.pos or pos
		rect = rect.pos or rect
		if pos.x >= rect.x and pos.x <= (rect.x + rect.w) and pos.y >= rect.y and pos.y < (rect.y + rect.h) then return true end
		return false
	end,
	
	getdist = function(pos, target)
		pos = pos.pos or pos
		target = target.pos or target
		return math.sqrt((pos.x-target.x) * (pos.x-target.x) + (pos.y-target.y) * (pos.y-target.y))
	end,
	
	withinradius = function(pos, circ)
		pos = pos.pos or pos
		circ = circ.pos or circ
		if math.sqrt((pos.x - circ.x) * (pos.x - circ.x) + (pos.y - circ.y) * (pos.y - circ.y)) < circ.r then return true end
		return false
	end,
	
	getparent = function(this)
		if this.parent then return this.parent:getparent()
		else return this end
	end,
	
	getmaxh = function(this)
		local maxh = 0
		for i, child in ipairs(this.children) do
			if child ~= this.scroller and child.pos.y + child.pos.h > maxh then maxh = child.pos.y + child.pos.h end
		end
		return maxh
	end,
	
	addchild = function(this, child, autostack)
		if autostack then
			local maxh = this:getmaxh()
			child.pos.y = maxh
			if this.scroller then this.scroller.values.max = math.max(maxh - this.pos.h, 0) end
		end
		table.insert(this.children, child)
		child.parent = this
		child.style = this.Gspot:clone(child.style)
		setmetatable(child.style, {__index = this.style})
		return child
	end,
	
	remchild = function(this, child)
		child.pos = child:getpos()
		table.remove(this.children, this.Gspot.getindex(this.children, child))
		child.parent = nil
		setmetatable(child.style, {__index = this.Gspot.style})
	end,
	
	getlevel = function(this)
		for i, element in pairs(this.Gspot.elements) do
			if element == this then return i end
		end
	end,
	
	setlevel = function(this, level)
		if level then
			table.insert(this.Gspot.elements, level, table.remove(this.Gspot.elements, this.Gspot.getindex(this.Gspot.elements, this)))
			for i, child in ipairs(this.children) do child:setlevel(level + i) end
		else
			table.insert(this.Gspot.elements, table.remove(this.Gspot.elements, this.Gspot.getindex(this.Gspot.elements, this)))
			for i, child in ipairs(this.children) do child:setlevel() end
		end
	end,
	
	show = function(this)
		this.display = true
		for i, child in pairs(this.children) do child:show() end
	end,
	
	hide = function(this)
		this.display = false
		for i, child in pairs(this.children) do child:hide() end
	end,
	
	focus = function(this)
		this.Gspot:setfocus(this)
	end,
	
	type = function(this)
		return 'Gspot.element.'..this.elementtype
	end,
}

Gspot.element = {
	load = function(this, Gspot, elementtype, label, pos, parent)
		assert(Gspot[elementtype], 'invalid element constructor argument : element.elementtype must be an existing element type')
		assert(type(label) == 'string' or type(label) == 'number' or not label, 'invalid element constructor argument : element.label must be of type string or number')
		assert(type(pos) == 'table' or not pos, 'invalid element constructor argument : element.pos must be of type table or nil')
		assert((type(parent) == 'table' and parent:type():sub(1, 13) == 'Gspot.element') or not parent, 'invalid element constructor argument : element.parent must be of type element or nil')
		local pos, circ = Gspot:pos(pos)
		local element = {elementtype = elementtype, label = label, pos = pos, display = true, parent = parent, children = {}, Gspot = Gspot}
		if element.label == '' then element.label = element.label or ' ' end
		if circ then element.shape = 'circle' else element.shape = 'box' end
		if parent then element.style = setmetatable({}, {__index = parent.style})
		else element.style = setmetatable({}, {__index = Gspot.style}) end
		return setmetatable(element, {__index = Gspot[elementtype], __tostring = function(this) return this:type() .. ' (' .. this:getlevel() .. ')' end})
	end,
}
setmetatable(Gspot.element, {__call = Gspot.element.load})
	
Gspot.scrollvalues = function(this, values)
	local val = {}
	val.min = values.min or values[1] or 0
	val.max = values.max or values[2] or 0
	val.current = values.current or values[3] or val.min
	val.step = values.step or values[4] or this.style.unit
	return val
end

-- elements

Gspot.group = {
	load = function(this, Gspot, label, pos, parent)
		return Gspot:add(Gspot:element('group', label, pos, parent))
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.bg)
		this:drawshape(pos)
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.style.unit - this.style.font:getHeight('dp')) / 2))
		end
	end,
}
setmetatable(Gspot.group, {__index = Gspot.util, __call = Gspot.group.load})

Gspot.text = {
	load = function(this, Gspot, label, pos, parent, autosize)
		local element = Gspot:element('text', label, pos, parent)
		if autosize then
			element.pos.w = element.style.font:getWidth(label) + (element.style.unit / 2)
			element.autosize = autosize
		end
		element:setfont(element.style.font)
		return Gspot:add(element)
	end,
	setfont = function(this, font, size)
		this.Gspot.util.setfont(this, font, size)
		local width, lines = this.style.font:getWrap(this.label, this.pos.w)
		lines = math.max(lines, 1)
		this.pos.h = (this.style.font:getHeight('dp') * lines) + (this.style.unit - this.style.font:getHeight('dp'))
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.fg)
		if this.autosize then love.graphics.print(this.label, pos.x + (this.style.unit / 4), pos.y + ((this.style.unit - this.style.font:getHeight('dp')) / 2))
		else love.graphics.printf(this.label, pos.x + (this.style.unit / 4), pos.y + ((this.style.unit - this.style.font:getHeight('dp')) / 2), (this.autosize and pos.w) or  pos.w - (this.style.unit / 2), 'left') end
	end,
}
setmetatable(Gspot.text, {__index = Gspot.util, __call = Gspot.text.load})

Gspot.image = {
	load = function(this, Gspot, label, pos, parent, img)
		local element = Gspot:element('image', label, pos, parent)
		element:setimage(img)
		return Gspot:add(element)
	end,
	setimage = function(this, img)
		this.Gspot.util.setimage(this, img)
		if this.img then
			this.pos.w = this.img:getWidth()
			this.pos.h = this.img:getHeight()
		end
	end,
	draw = function(this, pos)
		if this.img then
			this:drawimg(pos)
		end
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), (pos.y + pos.h) + ((this.style.unit - this.style.font:getHeight('dp')) / 2))
		end
	end,
}
setmetatable(Gspot.image, {__index = Gspot.util, __call = Gspot.image.load})

Gspot.button = {
	load = function(this, Gspot, label, pos, parent)
		return Gspot:add(Gspot:element('button', label, pos, parent))
	end,
	draw = function(this, pos)
		if this.parent and this.value == this.parent.value then
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.focus)
			else love.graphics.setColor(this.style.hilite) end
		else
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
			else love.graphics.setColor(this.style.default) end
		end
		this:drawshape(pos)
		love.graphics.setColor(this.style.fg)
		if this.shape == 'circle' then
			if this.img then this:drawimg(pos) end
			if this.label then love.graphics.print(this.label, (pos.x + pos.r) - (this.style.font:getWidth(this.label) / 2), (this.img and (pos.y + (pos.r * 2)) + ((this.style.unit - this.style.font:getHeight(this.label)) / 2)) or (pos.y + pos.r) - (this.style.font:getHeight(this.label) / 2)) end
		else
			if this.img then this:drawimg(pos) end
			if this.label then love.graphics.print(this.label, (pos.x + (pos.w / 2)) - (this.style.font:getWidth(this.label) / 2), (this.img and pos.y + ((this.style.unit - this.style.font:getHeight(this.label)) / 2)) or (pos.y + (pos.h / 2)) - (this.style.font:getHeight(this.label) / 2)) end
		end
	end,
}
setmetatable(Gspot.button, {__index = Gspot.util, __call = Gspot.button.load})

Gspot.imgbutton = {
	load = function(this, Gspot, label, pos, parent, img)
		local element = Gspot:button(label, pos, parent)
		element:setimage(img)
		return Gspot:add(element)
	end,
}
setmetatable(Gspot.imgbutton, {__index = Gspot.util, __call = Gspot.imgbutton.load})

Gspot.option = {
	load = function(this, Gspot, label, pos, parent, value)
		local element = Gspot:button(label, pos, parent)
		element.value = value
		element.click = function(this) this.parent.value = this.value end
		return element
	end,
}
setmetatable(Gspot.option, {__index = Gspot.util, __call = Gspot.option.load})

Gspot.checkbox = {
	load = function(this, Gspot, label, pos, parent, value)
		local element = Gspot:element('checkbox', label, pos, parent)
		element.value = value
		return Gspot:add(element)
	end,
	click = function(this) this.value = not this.value end,
	draw = function(this, pos)
		if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
		else love.graphics.setColor(this.style.default) end
		this:drawshape(pos)
		if this.value then
			love.graphics.setColor(this.style.fg)
			this:drawshape(this.Gspot:pos({x = pos.x + (pos.w / 4), y = pos.y + (pos.h / 4), w = pos.w / 2, h = pos.h / 2, r = pos.r and pos.r / 2}))
		end
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + pos.w + (this.style.unit / 2), pos.y + ((this.pos.h - this.style.font:getHeight(this.label)) / 2))
		end
	end,
}
setmetatable(Gspot.checkbox, {__index = Gspot.util, __call = Gspot.checkbox.load})

Gspot.input = {
	load = function(this, Gspot, label, pos, parent)
		local element = Gspot:element('input', label, pos, parent)
		element.value = ''
		element.cursor = 0
		element.cursorlife = 0
		element.keyrepeat = 200
		element.keydelay = 500
		return Gspot:add(element)
	end,
	update = function(this)
		if this.Gspot.focus == this then
			if this.cursorlife < 1 then this.cursorlife = 0
			else this.cursorlife = this.cursorlife + dt end
		end
	end,
	draw = function(this, pos)
		if this == this.Gspot.focus then love.graphics.setColor(this.style.bg)
		else
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
			else love.graphics.setColor(this.style.default) end
		end
		this:drawshape(pos)
		love.graphics.setColor(this.style.fg)
		local str = tostring(this.value)
		local offset = 0
		while this.style.font:getWidth(str) > pos.w - (this.style.unit / 2) do
			str = str:sub(2)
			offset = offset + 1
		end
		love.graphics.print(str, pos.x + (this.style.unit / 4), pos.y + ((pos.h - this.style.font:getHeight('dp')) / 2))
		if this == this.Gspot.focus and this.cursorlife < 0.5 then
			local cursorx = ((pos.x + (this.style.unit / 4)) + this.style.font:getWidth(str:sub(1, this.cursor - offset)))
			love.graphics.line(cursorx, pos.y + (this.style.unit / 8), cursorx, (pos.y + pos.h) - (this.style.unit / 8))
		end
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x - ((this.style.unit / 2) + this.style.font:getWidth(this.label)), pos.y + ((this.pos.h - this.style.font:getHeight('dp')) / 2))
		end
	end,
	click = function(this) this:focus() end,
	done = function(this) this.Gspot:unfocus() end,
	keypress = function(this, key, code)
		-- fragments attributed to vrld's Quickie : https://github.com/vrld/Quickie
		if key == 'backspace' then
			this.value = this.value:sub(1, this.cursor - 1)..this.value:sub(this.cursor + 1)
			this.cursor = math.max(0, this.cursor - 1)
		elseif key == 'delete' then
			this.value = this.value:sub(1, this.cursor)..this.value:sub(this.cursor + 2)
			this.cursor = math.min(this.value:len(), this.cursor)
		elseif key == 'left' then
			this.cursor = math.max(0, this.cursor - 1)
		elseif key == 'right' then
			this.cursor = math.min(this.value:len(), this.cursor + 1)
		elseif key == 'home' then
			this.cursor = 0
		elseif key == 'end' then
			this.cursor = this.value:len()
		elseif code >= 32 and code < 127 then
			this.value = this.value:sub(1, this.cursor)..string.char(code)..this.value:sub(this.cursor + 1)
			this.cursor = this.cursor + 1
		end
		-- /fragments
	end,
}
setmetatable(Gspot.input, {__index = Gspot.util, __call = Gspot.input.load})

Gspot.scroll = {
	load = function(this, Gspot, label, pos, parent, values, setscoller)
		local element = Gspot:element('scroll', label, pos, parent)
		element.values = Gspot:scrollvalues(values)
		element.wheelup = function(this) this.values.current = math.max(this.values.current - this.values.step, this.values.min) end
		element.wheeldown = function(this) this.values.current = math.min(this.values.current + this.values.step, this.values.max) end
		return Gspot:add(element, setscroller)
	end,
	update = function(this, dt)
		if this.withinrect({x = love.mouse.getX(), y = love.mouse.getY()}, this:getpos()) then this.Gspot.mousein = this end
	end,
	drag = function(this, x, y)
		local pos = this:getpos()
		this.values.current = this.values.min + ((this.values.max - this.values.min) * ((math.min(math.max(pos.y, y), (pos.y + pos.h)) - pos.y) / pos.h))
	end,
	draw = function(this, pos)
		if this == this.Gspot.mousein or this == this.Gspot.drag then love.graphics.setColor(this.style.default)
		else love.graphics.setColor(this.style.bg) end
		this:rect(pos)
		if this == this.Gspot.mousein or this == this.Gspot.drag then love.graphics.setColor(this.style.fg)
		else love.graphics.setColor(this.style.hilite) end
		handlepos = this.Gspot:pos({x = pos.x, y = math.min(pos.y + (pos.h - this.style.unit), math.max(pos.y, pos.y + (pos.h * (this.values.current / (this.values.max - this.values.min))) - (this.style.unit / 2))), r = pos.r})
		this:drawshape(handlepos)
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), (pos.y + pos.h) + ((this.style.unit - this.style.font:getHeight('dp')) / 2))
		end
	end,
}
setmetatable(Gspot.scroll, {__index = Gspot.util, __call = Gspot.scroll.load})

Gspot.scrollgroup = {
	load = function(this, Gspot, label, pos, parent)
		local element = Gspot:element('scrollgroup', label, pos, parent)
		element.maxh = 0
		element = Gspot:add(element)
		this.scroller = Gspot:scroll(nil, {x = element.pos.w, y = 0, w = element.style.unit, h = element.pos.h}, element, {min = 0, max = 0, current = 0, step = element.style.unit})
		return element
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.bg)
		this:drawshape(pos)
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.style.unit - this.style.font:getHeight(this.label)) / 2))
		end
	end,
}
setmetatable(Gspot.scrollgroup, {__index = Gspot.util, __call = Gspot.scrollgroup.load})

Gspot.hidden = {
	load = function(this, Gspot, label, pos, parent)
		return Gspot:add(Gspot:element('hidden', label, pos, parent))
	end,
	draw = function(this, pos)
		--
	end,
}
setmetatable(Gspot.hidden, {__index = Gspot.util, __call = Gspot.hidden.load})

Gspot.radius = {
	load = function(this, Gspot, label, pos, parent)
		return Gspot:add(Gspot:element('radius', label, pos, parent))
	end,
	draw = function(this, pos)
		--
	end,
}
setmetatable(Gspot.radius, {__index = Gspot.util, __call = Gspot.radius.load})

Gspot.feedback = {
	load = function(this, Gspot, label, pos, parent, autopos)
		pos = pos or {}
		if (autopos == false and false) or true then
			for i, element in ipairs(Gspot.elements) do
				if element.elementtype == 'feedback' and element.autopos then element.pos.y = element.pos.y + element.style.unit end
			end
		end
		pos.x = pos.x or pos[1] or 0
		pos.y = pos.y or pos[2] or 0
		pos.w = 0
		pos.h = 0
		local element = Gspot:add(Gspot:element('feedback', label, pos, parent))
		element.style.fg = {255, 255, 255, 255}
		element.alpha = 255
		element.life = 3
		element.autopos = autopos
		return element
	end,
	update = function(this, dt)
		this.alpha = this.alpha - ((255 * dt) / this.life)
		if this.alpha < 0 then
			this.Gspot:rem(this)
			return
		end
		local color = this.style.fg
		this.style.fg = {color[1], color[2], color[3], this.alpha}
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.fg)
		love.graphics.print(this.label, pos.x + (this.style.unit / 4), pos.y + ((this.style.unit - this.style.font:getHeight('dp')) / 2))
	end,
}
setmetatable(Gspot.feedback, {__index = Gspot.util, __call = Gspot.feedback.load})

return Gspot:load()