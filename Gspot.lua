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
				default = {96, 96, 96, 255},
				hilite = {128, 128, 128, 255},
				focus = {160, 160, 160, 255},
				bg = {32, 32, 32, 255},
				fg = {224, 224, 224, 255},
			},
			dblclickinterval = 0.25,
			rendertarget = nil,
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
		this.mouseover = nil
		local mousein = nil
		for i, element in ipairs(this.elements) do
			if element.display then
				local pos = element:getpos()
				if this.util.withinrect(mouse, pos) then
					if element.parent and element.parent.type == 'scrollgroup' and element ~= element.parent.scroller then
						if this.util.withinrect(mouse, element.parent:getpos()) then mousein = element end
					else
						mousein = element
					end
				end
				if element == this.drag then
					if element.type == 'scroll' then
						element.values.current = element.values.min + ((element.values.max - element.values.min) * ((math.min(math.max(pos.y, mouse.y), (pos.y + pos.h)) - pos.y) / pos.h))
					else
						if love.mouse.isDown('l') and type(element.drag) == 'function' then
							element:drag()
						else
							element.pos.y = mouse.y - element.offset.y
							element.pos.x = mouse.x - element.offset.x
						end
						if love.mouse.isDown('r') and type(element.rdrag) == 'function' then
							element:rdrag()
						else
							element.pos.y = mouse.y - element.offset.y
							element.pos.x = mouse.x - element.offset.x
						end
					end
					for i, bucket in ipairs(this.elements) do
						if bucket ~= element then
							if this.util.withinrect(mouse, bucket:getpos()) then this.mouseover = bucket end
						end
					end
				end
				if element.type == 'input' and element == this.focus then
					if element.cursorlife < 1 then element.cursorlife = 0
					else element.cursorlife = element.cursorlife + dt end
				end
			end
			if element.update then -- element.update or Gspot[element.type].update or Gspot.util.update
				if element.updateinterval then
					element.dt = element.dt or 0
					element.dt = element.dt + dt
					if element.dt >= element.updateinterval then
						element.dt = 0
						element:update(dt)
					end
				else
					element:update(dt)
				end
			end
		end
		if this.mousein ~= mousein then
			if mousein and mousein.enter then mousein:enter() end
			if this.mousein and this.mousein.leave then this.mousein:leave() end
		end
		this.mousein = mousein
	end,
	
	draw = function(this)
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local ostyle = {}
		ostyle.colormode = love.graphics.getColorMode()
		ostyle.font = love.graphics.getFont()
		ostyle.r, ostyle.g, ostyle.b, ostyle.a = love.graphics.getColor()
		love.graphics.setColorMode('replace')
		for i, element in ipairs(this.elements) do
			if element.display then
				local pos = element:getpos()
				love.graphics.setFont(element.style.font)
				if element.parent and element.parent.type == 'scrollgroup' and element ~= element.parent.scroller then
					love.graphics.setRenderTarget(element.parent.canvas)
					pos = pos - element.parent:getpos()
				else
					love.graphics.setRenderTarget(this.rendertarget)
				end
				element:draw(pos)
			end
		end
		love.graphics.setRenderTarget(this.rendertarget)
		love.graphics.setColor(this.style.fg)
		for i, element in ipairs(this.elements) do
			if element.display and element == this.mousein and element.tip then
				local pos = element:getpos()
				local tippos = {x = pos.x + (this.style.unit / 2), y = pos.y + (this.style.unit / 2), w = element.style.font:getWidth(element.tip) + this.style.unit, h = this.style.unit}
				love.graphics.setColor(this.style.bg)
				this.util.rect({x = math.max(0, math.min(tippos.x, love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + this.style.unit))), y = math.max(0, math.min(tippos.y, love.graphics.getHeight() - this.style.unit)), w = tippos.w, h = tippos.h})
				love.graphics.setColor(this.style.fg)
				love.graphics.print(element.tip, math.max(this.style.unit / 2, math.min(tippos.x + (this.style.unit / 2), love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + (this.style.unit / 2)))), math.max((this.style.unit - element.style.font:getHeight(element.tip)) / 2, math.min(tippos.y + ((this.style.unit - element.style.font:getHeight('dp')) / 2), (love.graphics.getHeight() - this.style.unit) + ((this.style.unit - element.style.font:getHeight('dp')) / 2))))
			end
		end
		love.graphics.setFont(ostyle.font)
		love.graphics.setColor(ostyle.r, ostyle.g, ostyle.b, ostyle.a)
		love.graphics.setColorMode(ostyle.colormode)
		love.graphics.setRenderTarget()
	end,
	
	mousepress = function(this, x, y, button, dt)
		this:unfocus()
		if this.mousein then
			local element = this.mousein
			if element.type ~= 'hidden' then element:getparent():stack() end
			if element.drag then
				this.drag = element
				element.offset = {x = x - element:getpos().x, y = y - element:getpos().y}
			end
			if button == 'l' then
				if this.mousedt < this.dblclickinterval and element.dblclick then element:dblclick(x, y, button)
				elseif element.click then element:click(x, y, button)
				end
			elseif button == 'r' and element.rclick then element:rclick(x, y, button)
			elseif button == 'wu' and element.wheelup then element:wheelup(x, y, button)
			elseif button == 'wd' and element.wheeldown then element:wheeldown(x, y, button)
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
				if element.rdrop then
					if button == 'r' and element.rdrop then element:rdrop(this.mouseover) end
				end
				if this.mouseover and this.mouseover.rcatch then this.mouseover:rcatch(element.id) end
			end
		end
		this.drag = nil
	end,

	keypress = function(this, key, code)
		if this.focus then
			if key == 'return' then
				if this.focus.done then this.focus:done() end
			end
			if this.focus and this.focus.keypress then this.focus:keypress(key, code) end
		end
	end,
	
	-- legacy
	newid = function(this)
		this.maxid = this.maxid + 1
		return this.maxid
	end,
	-- /legacy
	
	pos_mt = {
		__unm = function(a) a.x = 0 - a.x; a.y = 0 - a.y; return a end,
		__add = function(a, b) a.x = a.x + b.x; a.y = a.y + b.y; return a end,
		__sub = function(a, b) a.x = a.x - b.x; a.y = a.y - b.y; return a end,
		__mul = function(a, b) a.x = a.x * b.x; a.y = a.y * b.y; return a end,
		__div = function(a, b) a.x = a.x / b.x; a.y = a.y / b.y; return a end,
		__pow = function(a, b) a.x = a.x ^ b.x; a.y = a.y ^ b.y; return a end,
	},
	
	pos = function(this, t)
		if t then t = t.pos or t else t = {} end
		local pos = {}
		pos.x = t.x or t[1] or this.style.unit
		pos.y = t.y or t[2] or this.style.unit
		pos.w = t.w or t[3] or this.style.unit * 4
		pos.h = t.h or t[4] or this.style.unit
		pos.r = t.r or t[5] or nil
		return setmetatable(pos, this.pos_mt)
	end,
	
	element = function(this, type, label, pos, parent)
		return setmetatable({type = type, label = label, pos = this:pos(pos), parent = parent}, {__index = this[type]})
	end,
	
	add = function(this, element, setscroller) -- need a more elegant solution
		element.Gspot = this
		element.id = this:newid() -- legacy
		element.label = element.label or ' '
		element.display = true
		element.children = {}
		table.insert(this.elements, element)
		if element.parent and element.parent.style then
			element.style = setmetatable({}, {__index = element.parent.style})
			element.parent:addchild(element, setscroller)
			if element.parent.type == 'scrollgroup' then
				if element.type == 'scroll' then
					if setscroller then element.parent.scroller = element end
				else
					local maxh = 0
					for i, child in ipairs(element.parent.children) do
						if child.type ~= 'scroll' and child.pos.y + child.pos.h > maxh then maxh = child.pos.y + child.pos.h end
					end
					element.parent.maxh = maxh
					if element.parent.scroller then element.parent.scroller.values.max = math.max(maxh - element.parent.pos.h, 0) end
				end
			end
		else
			element.style = setmetatable({}, {__index = this.style})
		end
		return element
	end,

	rem = function(this, element)
		if element.parent then table.remove(element.parent.children, this.util.getindex(element.parent.children, element)) end
		while #element.children > 0 do
			for i, child in ipairs(element.children) do this:rem(child) end
		end
		if element == this.mousein then this.mousein = nil end
		if element == this.drag then this.drag = nil end
		if element == this.focus then this:unfocus() end
		table.remove(this.elements, this.util.getindex(this.elements, element))
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

Gspot.util = {
	getpos = function(this)
		local pos = this.Gspot:pos(this)
		if this.parent then
			pos = pos + this.parent:getpos()
			if this.parent.type == 'scrollgroup' and this ~= this.parent.scroller then pos.y = pos.y - this.parent.scroller.values.current end
		end
		return pos
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
		if this:dist(pos, {x = circ.x, y = circ.y}) < circ.r then return true end
		return false
	end,
	
	loadimage = function(this, img)
		if type(img) == 'string' and love.filesystem.exists(img) then return love.graphics.newImage(img)
		else return img end
	end,
	
	getindex = function(tab, val)
		for i, v in pairs(tab) do if v == val then return i end end
	end,
	
	getparent = function(this)
		if this.parent then return this.getparent(this.parent)
		else return this end
	end,
	
	addchild = function(this, child)
		table.insert(this.children, child)
		child.parent = this
	end,
	
	remchild = function(this, child)
		child.pos = child:getpos()
		table.remove(this.children, this.getindex(this.children, child))
		child.parent = nil
	end,
	
	stack = function(this, limit)
		local elements = this.Gspot.elements
		i = 1
		l = limit or #elements
		while i <= l do
			if elements[i] == this then
				table.insert(elements, table.remove(elements, i))
				l = l - 1
				break
			end
			i = i + 1
		end
		i = 1
		while i <= l do
			if elements[i].parent == this then
				l = elements[i]:stack(l)
				i = 1
			end
			i = i + 1
		end
		return l
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
	
	rect = function(pos, mode)
		pos = pos.pos or pos
		mode = mode or 'fill'
		love.graphics.rectangle(mode, pos.x, pos.y, pos.w, pos.h)
	end,
	
	scrollvalues = function(this, values)
		local sv = {}
		for i, v in pairs(values) do sv[i] = v end
		if sv.min and sv.max and sv.current and sv.step then return sv
		else
			local val = {}
			val.min, val.max, val.current, val.step = sv[1], sv[2], sv[3], sv[4]
			val.current = val.current or val.min
			val.step = val.step or this.Gspot.style.unit
			return val
		end
	end,
}

Gspot.group = {
	load = function(this, Gspot, label, pos, parent)
		return Gspot:add(Gspot:element('group', label, pos, parent))
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.bg)
		this.rect(pos)
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.Gspot.style.unit - this.style.font:getHeight('dp')) / 2))
		end
	end,
}
setmetatable(Gspot.group, {__index = Gspot.util, __call = Gspot.group.load})

Gspot.text = {
	load = function(this, Gspot, label, pos, parent)
		local element = Gspot:element('text', label, pos, parent)
		local width, lines = Gspot.style.font:getWrap(label, element.pos.w)
		local lines = math.max(lines, 1)
		element.pos.h = (Gspot.style.font:getHeight('dp') * lines) + (Gspot.style.unit - Gspot.style.font:getHeight('dp'))
		return Gspot:add(element)
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.fg)
		love.graphics.printf(this.label, pos.x + (this.Gspot.style.unit / 4), pos.y + ((this.Gspot.style.unit - this.style.font:getHeight('dp')) / 2), pos.w - (this.style.unit / 2), 'left')
	end,
}
setmetatable(Gspot.text, {__index = Gspot.util, __call = Gspot.text.load})

Gspot.image = {
	load = function(this, Gspot, label, pos, img, parent)
		local element = Gspot:element('image', label, pos, parent)
		element.img = this:loadimage(img)
		if element.img:type() == 'Image' then
			element.pos.w = element.img:getWidth()
			element.pos.h = element.img:getHeight()
		end
		return Gspot:add(element)
	end,
	draw = function(this, pos)
		if this.img then love.graphics.draw(this.img, pos.x, pos.y) end
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
		-- option
		if this.parent and this.value == this.parent.value then
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.focus)
			else love.graphics.setColor(this.style.hilite) end
		-- regular button
		else
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
			else love.graphics.setColor(this.style.default) end
		end
		this.rect(pos)
		love.graphics.setColor(this.style.fg)
		-- image button
		if this.img then
			love.graphics.draw(this.img, ((pos.x + (pos.w / 2)) - (this.img:getWidth()) / 2), ((pos.y + (pos.h / 2)) - (this.img:getHeight() / 2)))
			if this.label then love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.style.unit - this.style.font:getHeight(this.label)) / 2)) end
		-- regular text button
		else
			if this.label then love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.pos.h - this.style.font:getHeight(this.label)) / 2)) end
		end
	end,
}
setmetatable(Gspot.button, {__index = Gspot.util, __call = Gspot.button.load})

Gspot.imgbutton = {
	load = function(this, Gspot, label, pos, img, parent)
		local element = Gspot:button(label, pos, parent)
		element.img = this:loadimg(img)
		return Gspot:add(element)
	end,
}
setmetatable(Gspot.imgbutton, {__index = Gspot.util, __call = Gspot.imgbutton.load})

Gspot.option = {
	load = function(this, Gspot, label, pos, value, parent)
		local element = Gspot:button(label, pos, parent)
		element.value = value
		element.click = function(this) this.parent.value = this.value end
		return element
	end,
}
setmetatable(Gspot.option, {__index = Gspot.util, __call = Gspot.option.load})

Gspot.checkbox = {
	load = function(this, Gspot, label, pos, value, parent)
		local element = Gspot:element('checkbox', label, pos, parent)
		element.value = value
		element.click = function(this) this.value = not this.value end
		return Gspot:add(element)
	end,
	draw = function(this, pos)
		if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
		else love.graphics.setColor(this.style.default) end
		this.rect(pos)
		if this.value then
			love.graphics.setColor(this.style.fg)
			this.rect({x = pos.x + (pos.w / 4), y = pos.y + (pos.h / 4), w = pos.w / 2, h = pos.h / 2})
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
		element.click = function(this) this.Gspot:setfocus(this) end
		element.done = function(this) this.Gspot:unfocus() end
		element.keypress = function(this, key, code)
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
		end
		return Gspot:add(element)
	end,
	draw = function(this, pos)
		if this == this.Gspot.focus then love.graphics.setColor(this.style.bg)
		else
			if this == this.Gspot.mousein then love.graphics.setColor(this.style.hilite)
			else love.graphics.setColor(this.style.default) end
		end
		this.rect(pos)
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
}
setmetatable(Gspot.input, {__index = Gspot.util, __call = Gspot.input.load})

Gspot.scroll = {
	load = function(this, Gspot, label, pos, values, parent, setscoller)
		local element = Gspot:element('scroll', label, pos, parent)
		element.drag = true
		element.values = this:scrollvalues(values)
		element.wheelup = function(this) this.values.current = math.max(this.values.current - this.values.step, this.values.min) end
		element.wheeldown = function(this) this.values.current = math.min(this.values.current + this.values.step, this.values.max) end
		element.offset = {x = 0, y = 0}
		element.drag = true
		return Gspot:add(element, setscroller)
	end,
	draw = function(this, pos)
		if this == this.Gspot.mousein then love.graphics.setColor(this.style.default)
		else love.graphics.setColor(this.style.bg) end
		this.rect(pos)
		if this == this.Gspot.mousein then love.graphics.setColor(this.style.fg)
		else love.graphics.setColor(this.style.hilite) end
		this.rect({x = pos.x, y = math.min(pos.y + (pos.h - this.style.unit), math.max(pos.y, pos.y + (pos.h * (this.values.current / (this.values.max - this.values.min))) - (this.style.unit / 2))), w = this.style.unit, h = this.Gspot.style.unit})
	end,
}
setmetatable(Gspot.scroll, {__index = Gspot.util, __call = Gspot.scroll.load})

Gspot.scrollgroup = {
	load = function(this, Gspot, label, pos, parent)
		local element = Gspot:element('scrollgroup', label, pos, parent)
		element.maxh = 0
		element.canvas = love.graphics.newFramebuffer(element.pos.w, element.pos.h)
		local element = Gspot:add(element)
		element.scroller = Gspot:scroll(nil, {x = element.pos.w, y = 0, w = element.style.unit, h = element.pos.h}, {min = 0, max = 0, current = 0, step = element.style.unit}, element, true)
		return element
	end,
	draw = function(this, pos)
		love.graphics.setColor(this.style.bg)
		this.rect(pos)
		if this.label then
			love.graphics.setColor(this.style.fg)
			love.graphics.print(this.label, pos.x + ((pos.w - this.style.font:getWidth(this.label)) / 2), pos.y + ((this.style.unit - this.style.font:getHeight(this.label)) / 2))
		end
		love.graphics.setColor({255, 255, 255, 255})
		love.graphics.draw(this.canvas, pos.x, pos.y, 0, 1, 1, 0, 0)
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

return Gspot:load()