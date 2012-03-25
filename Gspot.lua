-- This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
-- Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
-- 1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.

local Gspot = {
	load = function(this)
		local def = {
			std = 16, -- set a standard gui unit
			color = { -- define colors
				default = {96, 96, 96, 255},
				hilite = {128, 128, 128, 255},
				focus = {160, 160, 160, 255},
				bg = {32, 32, 32, 255},
				fg = {224, 224, 224, 255},
			},
			font = love.graphics.newFont(10), -- set standard gui font
			dblclickinterval = 0.25, -- double click rate
			-- no messin' past here
			maxid = 0, -- legacy
			mem = {},
			elements = {},
			mousein = nil,
			focus = nil,
			drag = nil,
			mousedt = 0,
			ofont = nil,
			ocolor = {},
			orepeat = {},
		}
		return setmetatable(def, {__index = this, __call = this.load})
	end,
	
	util = {
		loadimage = function(this, img)
			if type(img) == 'string' and love.filesystem.exists(img) then
				return love.graphics.newImage(img)
			else return img end
		end,
		
		addchild = function(this, child)
			table.insert(this.children, child)
			child.parent = this
		end,
		
		remchild = function(this, child)
			table.remove(this.children, this.getindex(this.children, child))
			child.parent = nil
		end,
		
		show = function(this)
			this.display = true
			for i, child in pairs(this.children) do
				child:show()
			end
		end,
		
		hide = function(this)
			this.display = false
			for i, child in pairs(this.children) do
				child:hide()
			end
		end,
		
		getindex = function(tab, val)
			for i, v in pairs(tab) do if v == val then return i end end
		end,
		
		getparent = function(this)
			if this.parent then
				return this.getparent(this.parent)
			else
				return this
			end
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
		
		focus = function(this)
			this.Gspot:setfocus(this)
		end,
		
		newpos = function(t)
			local pos = {}
			if t.x and t.y then
				pos.x = t.x or 16
				pos.y = t.y or 16
				pos.w = t.w or 16
				pos.h = t.h or 16
				pos.r = t.r or nil
			else
				pos.x, pos.y, pos.w, pos.h = t[1], t[2], t[3], t[4]
				if t[5] then -- not sure if radius will have w and h, so this might change
					pos.r = t[5]
				end
			end
			return pos
		end,
		
		getpos = function(this)
			local pos = this.pos
			if this.parent then
				pos = this:addpos(this.parent:getpos())
				if this.parent.type == 'scrollgroup' and this ~= this.parent.scroller then
					pos.y = pos.y - this.parent.scroller.values.current
				end
			end
			return pos
		end,
		
		addpos = function(this, offset)
			this.pos.x = this.orig.x + offset.x
			this.pos.y = this.orig.y + offset.y
			return this.pos
		end,
		
		subpos = function(this, offset)
			this.pos.x = this.orig.x - offset.x
			this.pos.y = this.orig.y - offset.y
			return this.pos
		end,
		
		withinrect = function(pos, rect)
			if pos.x >= rect.x and pos.x <= (rect.x + rect.w) then
				if pos.y >= rect.y and pos.y < (rect.y + rect.h) then
					return true
				end
			end
			return false
		end,
		
		getdist = function(pos, target)
			return math.sqrt((pos.x-target.x) * (pos.x-target.x) + (pos.y-target.y) * (pos.y-target.y))
		end,
		
		withinradius = function(pos, circ)
			if this:dist(pos, {x = circ.x, y = circ.y}) < circ.r then
				return true
			end
			return false
		end,
		
		rect = function(pos, mode)
			local mode = mode or 'fill'
			love.graphics.rectangle(mode, pos.x, pos.y, pos.w, pos.h)
		end,
		
		scrollvalues = function(this, values)
			local n = {}
			for i, v in pairs(values) do
				n[i] = v
			end
			if n.min and n.max and n.current and n.step then
				return n
			else
				local val = {}
				val.min, val.max, val.current, val.step = n[1], n[2], n[3], n[4]
				val.current = val.current or val.min
				val.step = val.step or this.Gspot.std
				return val
			end
		end,
		
	},
	
	-- legacy
	newid = function(this)
		this.maxid = this.maxid + 1
		return this.maxid
	end,
	
	element = function(this, id)
		for i, element in ipairs(this.elements) do
			if element.id == id then
				return element
			end
		end
		return false
	end,
	-- /legacy
	
	add = function(this, element, setscroller)
		element.id = this:newid() -- legacy
		element.label = element.label or ' '
		element.display = true
		element.orig = this.util.newpos(element.pos)
		element.children = {}
		element.color = setmetatable({}, {__index = this.color})
		table.insert(this.elements, element)
		if element.parent then
			element.parent:addchild(element, setscroller)
			if element.parent.type == 'scrollgroup' then
				if element.type == 'scroll' then
					if setscroller then element.parent.scroller = element end
				else
					local maxh = 0
					for i, child in ipairs(element.parent.children) do
						if child.type ~= 'scroll' and child.pos.y + child.pos.h > maxh then
							maxh = child.pos.y + child.pos.h
						end
					end
					element.parent.maxh = maxh
					if element.parent.scroller then
						element.parent.scroller.values.max = math.max(maxh - element.parent.pos.h, 0)
					end
				end
			end
		end
		return setmetatable(element, {__index = this[element.type]})
	end,

	rem = function(this, element)
		if element.parent then
			table.remove(element.parent.children, this.util.getindex(element.parent.children, element))
		end
		while #element.children > 0 do
			for i, child in ipairs(element.children) do
				this:rem(child)
			end
		end
		if element == this.mousein then this.mousein = nil end
		if element == this.drag then this.drag = nil end
		if element == this.focus then this:unfocus() end
		table.remove(this.elements, this.util.getindex(this.elements, element))
	end,
	
	-- interaction
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
							element:drag(mousein)
						else
							element.pos.y = mouse.y - element.offset.y
							element.pos.x = mouse.x - element.offset.x
						end
						if love.mouse.isDown('r') and type(element.rdrag) == 'function' then
							element:rdrag(mousein)
						else
							element.pos.y = mouse.y - element.offset.y
							element.pos.x = mouse.x - element.offset.x
						end
					end
					for i, bucket in ipairs(this.elements) do
						if bucket ~= element then
							if this.util.withinrect(mouse, bucket:getpos()) then
								this.mouseover = bucket
							end
						end
					end
				end
				if element.type == 'input' and element == this.focus then
					if element.cursorlife < 1 then
						element.cursorlife = 0
					else
						element.cursorlife = element.cursorlife + dt
					end
				end
				if element.type == 'scrollgroup' then
					for i, child in pairs(element.children) do
						if child.type ~= 'scroll' then
							child.pos.y = child.orig.y - element.scroller.values.current
						end
					end
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
			if mousein and mousein.enter then
				mousein:enter()
			end
			if this.mousein and this.mousein.leave then
				this.mousein:leave()
			end
		end
		this.mousein = mousein
	end,
	
	mousepress = function(this, x, y, button, dt)
		this:unfocus()
		if this.mousein then
			local element = this.mousein
			if element.type ~= 'hidden' then
				element:getparent():stack()
			end
			if element.drag then
				this.drag = element
				element.offset = {x = x - element.pos.x, y = y - element.pos.y}
			end
			if button == 'l' then
				if this.mousedt < this.dblclickinterval and element.dblclick then
					element:dblclick(x, y, button)
				elseif element.click then
					element:click(x, y, button)
				end
			elseif button == 'r' and element.rclick then
				element:rclick(x, y, button)
			elseif button == 'wu' and element.wheelup then
				element:wheelup(x, y, button)
			elseif button == 'wd' and element.wheeldown then
				element:wheeldown(x, y, button)
			end
		end
		this.mousedt = 0
	end,

	mouserelease = function(this, x, y, button)
		if this.drag then
			local element = this.drag
			if button == 'l' then
				if element.drop then
					element:drop(this.mouseover)
				end
				if this.mouseover and this.mouseover.catch then
					this.mouseover:catch(element)
				end
			elseif button == 'r' then
				if element.rdrop then
					if button == 'r' and element.rdrop then
						element:rdrop(this.mouseover)
					end
				end
				if this.mouseover and this.mouseover.rcatch then
					this.mouseover:rcatch(element.id)
				end
			end
		end
		this.drag = nil
	end,

	keypress = function(this, key, code)
		if this.focus then
			if key == 'return' then
				if this.focus.done then
					this.focus:done()
				end
			end
			if this.focus and this.focus.keypress then
				this.focus:keypress(key, code)
			end
		end
	end,
	
	setfocus = function(this, element)
		if element then
			this.focus = element
			this.orepeat.delay, this.orepeat.interval = love.keyboard.getKeyRepeat()
			if element.keyrepeat and element.keyrepeat > 0 then
				if element.keydelay then
					love.keyboard.setKeyRepeat(element.keydelay, element.keyrepeat)
				else
					love.keyboard.setKeyRepeat(element.keyrepeat, element.keyrepeat)
				end
			end
		end
	end,
	
	unfocus = function(this)
		this.focus = nil
		if this.orepeat then
			love.keyboard.setKeyRepeat(this.orepeat.delay, this.orepeat.interval)
		end
	end,
	
	draw = function(this)
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local ofont = love.graphics.getFont()
		local ocolor = {}
		ocolor.r, ocolor.g, ocolor.b, ocolor.a = love.graphics.getColor()
		for i, element in ipairs(this.elements) do
			if element.display then
				local pos = element:getpos()
				love.graphics.setFont(this.font)
				if element.parent and element.parent.type == 'scrollgroup' and element ~= element.parent.scroller then
					love.graphics.setRenderTarget(element.parent.canvas)
					pos.x = pos.x - element.parent.pos.x
					pos.y = pos.y - element.parent.pos.y
				else
					love.graphics.setRenderTarget()
				end
				this[element.type].draw(element, pos)
			end
		end
		love.graphics.setRenderTarget()
		love.graphics.setColor(this.color.fg)
		for i, element in ipairs(this.elements) do
			if element.display and element == this.mousein and element.tip then
				local pos = element:getpos()
				local tippos = {x = pos.x + (this.std / 2), y = pos.y + (this.std / 2), w = this.font:getWidth(element.tip) + this.std, h = this.std}
				love.graphics.setColor(this.color.bg)
				this.util.rect({x = math.max(0, math.min(tippos.x, love.graphics.getWidth() - (this.font:getWidth(element.tip) + this.std))), y = math.max(0, math.min(tippos.y, love.graphics.getHeight() - this.std)), w = tippos.w, h = tippos.h})
				love.graphics.setColor(this.color.fg)
				love.graphics.print(element.tip, math.max(this.std / 2, math.min(tippos.x + (this.std / 2), love.graphics.getWidth() - (this.font:getWidth(element.tip) + (this.std / 2)))), math.max((this.std - this.font:getHeight(element.tip)) / 2, math.min(tippos.y + ((this.std - this.font:getHeight('dp')) / 2), (love.graphics.getHeight() - this.std) + ((this.std - this.font:getHeight('dp')) / 2))))
			end
		end
		love.graphics.setFont(ofont)
		love.graphics.setColor(ocolor.r, ocolor.g, ocolor.b, ocolor.a)
	end,
	
	group = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'group', label = label, pos = this.newpos(pos), Gspot = Gspot}
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			love.graphics.setColor(this.color.bg)
			this.rect(pos)
			if this.label then
				local color = this.color.fg
				love.graphics.setColor(color)
				love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), pos.y + ((this.Gspot.std - this.Gspot.font:getHeight('dp')) / 2))
			end
		end,
	},
	
	text = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'text', label = label, pos = this.newpos(pos), parent = parent, Gspot = Gspot}
			local width, lines = Gspot.font:getWrap(label, element.pos.w)
			local lines = math.max(lines, 1)
			element.pos.h = (Gspot.font:getHeight('dp') * lines) + (Gspot.std - Gspot.font:getHeight('dp'))
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			love.graphics.setColor(this.color.fg)
			love.graphics.printf(this.label, pos.x + (this.Gspot.std / 4), pos.y + ((this.Gspot.std - this.Gspot.font:getHeight('dp')) / 2), pos.w - (this.Gspot.std / 2), 'left')
		end,
	},
	
	image = {
		load = function(this, Gspot, label, pos, img, parent)
			local element = {type = 'image', label = label, pos = this.newpos(pos), img = this:loadimage(img), parent = parent, Gspot = Gspot}
			if element.img:type() == 'Image' then
				element.pos.w = element.img:getWidth()
				element.pos.h = element.img:getHeight()
			end
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			if this.img then
				local colormode = love.graphics.getColorMode()
				love.graphics.setColorMode('replace')
				love.graphics.draw(this.img, pos.x, pos.y)
				love.graphics.setColorMode(colormode)
			end
			if this.label then
				love.graphics.setColor(this.color.fg)
				love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), (pos.y + pos.h) + ((this.Gspot.std - this.Gspot.font:getHeight('dp')) / 2))
			end
		end,
	},
	
	button = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'button', label = label, pos = this.newpos(pos), parent = parent, Gspot = Gspot}
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			-- option
			if this.parent and this.value == this.parent.value then
				if this == this.Gspot.mousein then
					love.graphics.setColor(this.color.focus)
				else
					love.graphics.setColor(this.color.hilite)
				end
			-- regular button
			else
				if this == this.Gspot.mousein then
					love.graphics.setColor(this.color.hilite)
				else
					love.graphics.setColor(this.color.default)
				end
			end
			this.rect(pos)
			-- image button
			if this.img then
				-- love.graphics.setcolormode('replace')
				love.graphics.draw(this.img, ((pos.x + (pos.w / 2)) - (this.img:getWidth()) / 2), ((pos.y + (pos.h / 2)) - (this.img:getHeight() / 2)))
				if this.label then
					love.graphics.setColor(this.color.fg)
					love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), pos.y + ((this.Gspot.std - this.Gspot.font:getHeight(this.label)) / 2))
				end
			-- regular text button
			else
				if this.label then
					love.graphics.setColor(this.color.fg)
					love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), pos.y + ((this.pos.h - this.Gspot.font:getHeight(this.label)) / 2))
				end
			end
		end,
	},
	
	imgbutton = {
		load = function(this, Gspot, label, pos, img, parent)
			local element = Gspot:button(label, pos, parent)
			element.img = this:loadimg(img)
			return Gspot:add(element)
		end,
	},
	
	option = {
		load = function(this, Gspot, label, pos, value, parent)
			local element = Gspot:button(label, pos, parent)
			element.value = value
			element.click = function(this)
				this.parent.value = this.value
			end
			return element
		end,
		draw = function(this, pos)
			if this == this.Gspot.mousein then
				love.graphics.setColor(this.color.focus)
			else
				love.graphics.setColor(this.color.hilite)
			end
			this.rect(pos)
			if this.label then
				love.graphics.setColor(this.color.fg)
				love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), pos.y + ((this.pos.h - this.Gspot.font:getHeight(this.label)) / 2))
			end
		end,
	},
	
	input = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'input', label = label, pos = this.newpos(pos), parent = parent, value = '', cursor = 0, cursorlife = 0, Gspot = Gspot}
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
			if this == this.Gspot.focus then
				love.graphics.setColor(this.color.bg)
			else
				if this == this.Gspot.mousein then
					love.graphics.setColor(this.color.hilite)
				else
						love.graphics.setColor(this.color.default)
				end
			end
			this.rect(pos)
			love.graphics.setColor(this.color.fg)
			local str = tostring(this.value)
			local offset = 0
			while this.Gspot.font:getWidth(str) > pos.w - (this.Gspot.std / 2) do
				str = str:sub(2)
				offset = offset + 1
			end
			love.graphics.print(str, pos.x + (this.Gspot.std / 4), pos.y + ((pos.h - this.Gspot.font:getHeight('dp')) / 2))
			if this == this.Gspot.focus and this.cursorlife < 0.5 then
				local cursorx = ((pos.x + (this.Gspot.std / 4)) + this.Gspot.font:getWidth(str:sub(1, this.cursor - offset)))
				love.graphics.line(cursorx, pos.y + (this.Gspot.std / 8), cursorx, (pos.y + pos.h) - (this.Gspot.std / 8))
			end
			if this.label then
				love.graphics.setColor(this.color.fg)
				love.graphics.print(this.label, pos.x - ((this.Gspot.std / 2) + this.Gspot.font:getWidth(this.label)), pos.y + ((this.pos.h - this.Gspot.font:getHeight('dp')) / 2))
			end
		end,
	},
	
	scroll = {
		load = function(this, Gspot, label, pos, values, parent, setscoller)
			local element = {type = 'scroll', label = label, drag = true, pos = this.newpos(pos), parent = parent, values = this:scrollvalues(values), Gspot = Gspot}
			element.wheelup = function(this)
				this.values.current = math.max(this.values.current - this.values.step, this.values.min)
			end
			element.wheeldown = function(this)
				this.values.current = math.min(this.values.current + this.values.step, this.values.max)
			end
			element.offset = {x = 0, y = 0}
			element.drag = true
			return Gspot:add(element, setscroller)
		end,
		draw = function(this, pos)
			if this == this.Gspot.mousein then
				love.graphics.setColor(this.color.default)
			else
				love.graphics.setColor(this.color.bg)
			end
			this.rect(pos)
			if this == this.Gspot.mousein then
				love.graphics.setColor(this.color.fg)
			else
				love.graphics.setColor(this.color.hilite)
			end
			this.rect({x = pos.x, y = math.min(pos.y + (pos.h - this.Gspot.std), math.max(pos.y, pos.y + (pos.h * (this.values.current / (this.values.max - this.values.min))) - (this.Gspot.std / 2))), w = this.Gspot.std, h = this.Gspot.std})
		end,
	},
	
	scrollgroup = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'scrollgroup', label = label, pos = this.newpos(pos), parent = parent, maxh = 0, Gspot = Gspot}
			element.canvas = love.graphics.newFramebuffer(element.pos.w, element.pos.h)
			local element = Gspot:add(element)
			element.scroller = Gspot:scroll(nil, {x = element.pos.w, y = 0, w = Gspot.std, h = element.pos.h}, {min = 0, max = 0, current = 0, step = Gspot.std}, element, true)
			return element
		end,
		draw = function(this, pos)
			love.graphics.setColor(this.color.bg)
			this.rect(pos)
			if this.label then
				love.graphics.setColor(this.color.fg)
				love.graphics.print(this.label, pos.x + ((pos.w - this.Gspot.font:getWidth(this.label)) / 2), pos.y + ((this.Gspot.std - this.Gspot.font:getHeight(this.label)) / 2))
			end
			love.graphics.setColor({255, 255, 255, 255})
			love.graphics.draw(this.canvas, pos.x, pos.y, 0, 1, 1, 0, 0)
		end,
	},
	
	hidden = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'hidden', label = label, pos = this.newpos(pos), parent = parent, Gspot = Gspot}
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			--
		end,
	},
	
	radius = {
		load = function(this, Gspot, label, pos, parent)
			local element = {type = 'radius', label = label, pos = this.newpos(pos), parent = parent, display = false, Gspot = Gspot}
			return Gspot:add(element)
		end,
		draw = function(this, pos)
			--
		end,
	},
}
for i, v in pairs(Gspot) do
	if type(v) == 'table' and v ~= Gspot.util then setmetatable(v, {__index = Gspot.util, __call = v.load}) end
end

return Gspot:load()