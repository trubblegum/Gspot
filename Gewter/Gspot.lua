-- Copyright (c) 2012 Vince Fryer
-- This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
-- Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
-- 1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.

local Gspot = {
	new = function(this)
		local gui = {
			maxid = 0,
			std = 16, -- set a standard gui unit
			color = { -- define colors
				default = {96, 96, 96, 255},
				hilite = {128, 128, 128, 255},
				focus = {160, 160, 160, 255},
				bg = {32, 32, 32, 255},
				fg = {224, 224, 224, 255},
			},
			font = love.graphics.newFont(10), -- set standard gui font
			mem = {},
			elements = {},
			mousein = nil,
			focus = nil,
			drag = nil,
			mousedt = 0,
			dblclickinterval = 0.25,
			ofont = nil,
			ocolor = {},
			orepeat = {},
		}
		return setmetatable(gui, {__index = this})
	end,
	
	-- helpers
	newid = function(this)
		this.maxid = this.maxid + 1
		return this.maxid
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
	
	newimage = function(this)
		if type(this.img) == 'string' and love.filesystem.exists(this.img) then
			this.img = assert(love.graphics.newImage(this.img))
		end
		if this.img:type() == 'Image' then
			this.pos.w = this.img:getWidth()
			this.pos.h = this.img:getHeight()
		end
	end,
	
	element = function(this, id)
		for i, element in ipairs(this.elements) do
			if element.id == id then
				return element
			end
		end
		return false
	end,
	
	getpos = function(this, element)
		local pos = element.pos
		if this:element(element.parent) then
			pos = this.addpos(element, this:getpos(this:element(element.parent)))
			if this:element(element.parent).type == 'scrollgroup' and element.id ~= this:element(element.parent).child then
				pos.y = pos.y - this:element(this:element(element.parent).child).values.current
			end
		end
		return pos
	end,
	
	addpos = function(element, offset)
		element.pos.x = element.orig.x + offset.x
		element.pos.y = element.orig.y + offset.y
		return element.pos
	end,
	
	subpos = function(element, offset)
		element.pos.x = element.orig.x - offset.x
		element.pos.y = element.orig.y - offset.y
		return element.pos
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
	
	show = function(this, id)
		this:element(id).display = true
		children = this:getchildren(id)
		for i, child in pairs(children) do
			this:show(child.id)
		end
	end,
	
	hide = function(this, id)
		this:element(id).display = false
		children = this:getchildren(id)
		for i, child in pairs(children) do
			this:hide(child.id)
		end
	end,
	
	getchildren = function(this, id)
		local children = {}
		for i, element in ipairs(this.elements) do
			if element.parent == id then
				table.insert(children, element)
			end
		end
		return children
	end,
	
	getparent = function(this, id)
		if this:element(this:element(id).parent) then
			return this:getparent(this:element(id).parent)
		else
			return this:element(id)
		end
	end,
	
	stackchildren = function(this, id, limit)
		i = 1
		l = limit or #this.elements
		while i <= l do
			if this.elements[i].id == id then
				local parent = table.remove(this.elements, i)
				table.insert(this.elements, parent)
				l = l - 1
				break
			end
			i = i + 1
		end
		i = 1
		while i <= l do
			if this.elements[i].parent == id then
				l = this:stackchildren(this.elements[i].id, l)
				i = 1
			end
			i = i + 1
		end
		return l
	end,
	
	add = function(this, element, display)
		local id = this:newid()
		element.id = id
		element.label = element.label or ' '
		element.display = true
		element.orig = this.newpos(element.pos)
		table.insert(this.elements, element)
		if this:element(element.parent) and this:element(element.parent).type == 'scrollgroup' then
			if element.type ~= 'scroll' then
				local scrollgroup = this:element(element.parent)
				local scroll = this:element(scrollgroup.child)
				local maxh = 0
				local items = this:getchildren(scrollgroup.id)
				for i, item in pairs(items) do
					if item.pos.y + item.pos.h > maxh then
						maxh = item.pos.y + item.pos.h
					end
				end
				scrollgroup.maxh = maxh
				scroll.values.max = math.max(maxh - scrollgroup.pos.h, 0)
			end
		end
		return id
	end,

	rem = function(this, id, l)
		if this:element(id).parent and this:element(this:element(id).parent) then
			this:element(this:element(id).parent).child = nil
		end
		i = 1
		l = #this.elements
		while i <= l do
			if this.elements[i].id == id then
				local element = this.elements[i]
				if element.id == this.mousein then
					this.mousein = nil
				end
				if element.id == this.focus then
					this:unfocus()
				end
				table.remove(this.elements, i)
				l = l - 1
				break
			end
			i = i + 1
		end
		i = 1
		while i <= l do
			if this.elements[i].parent == id then
				l = this:rem(this.elements[i].id, l)
				i = 1
			end
			i = i + 1
		end
		return l
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
				element.pos = this:getpos(element)
				if this.withinrect(mouse, element.pos) then
					if this:element(element.parent) and this:element(element.parent).type == 'scrollgroup' and element.id ~= this:element(element.parent).child then
						local scrollgroup = this:element(element.parent)
						if this.withinrect(mouse, scrollgroup.pos) then
							mousein = element.id
						end
					else
						mousein = element.id
					end
				end
				if element.id == this.drag then
					for i, bucket in ipairs(this.elements) do
						if bucket.id ~= element.id then
							if this.withinrect(mouse, bucket.pos) then
								if this:element(bucket.parent) and this:element(bucket.parent).type == 'scrollgroup' and element.id ~= this:element(bucket.parent).child then
									local scrollgroup = this:element(bucket.parent)
									if this.withinrect(mouse, scrollgroup.pos) then
										this.mouseover = bucket.id
									end
								else
									this.mouseover = bucket.id
								end
							end
						end
					end
					if element.type == 'scroll' then
						local pos = this:getpos(element)
						element.values.current = element.values.min + ((element.values.max - element.values.min) * ((math.min(math.max(pos.y, mouse.y), (pos.y + pos.h)) - pos.y) / pos.h))
					else
						if (love.mouse.isDown('l') and element.drag) or (love.mouse.isDown('r') and element.rdrag) then
							element.pos.y = mouse.y - element.offset.y
							element.pos.x = mouse.x - element.offset.x
						end
					end
					if love.mouse.isDown('l') and type(element.drag) == 'function' then
						element:drag(this.mousein)
					end
					if love.mouse.isDown('r') and type(element.rdrag) == 'function' then
						element:rdrag(this.mousein)
					end
				end
				if element.type == 'input' and element.id == this.focus then
					if element.cursorlife < 1 then
						element.cursorlife = 0
					else
						element.cursorlife = element.cursorlife + dt
					end
				end
				if element.type == 'scrollgroup' then
					local scroll = this:element(element.child)
					local children = this:getchildren(element.id)
					for i, child in pairs(children) do
						if child.type ~= 'scroll' then
							child.pos.y = child.orig.y - scroll.values.current
						end
					end
				end
			end
			if element.update then
				if element.updateinterval then
					element.updatetime = element.updatetime or 0
					element.updatetime = element.updatetime + dt
					if element.updatetime >= element.updateinterval then
						element.updatetime = 0
						element:update(dt)
					end
				else
					element:update(dt)
				end
			end
		end
		if this.mousein ~= mousein then
			if this:element(mousein) and this:element(mousein).enter then
				this:element(mousein):enter()
			end
			if this:element(this.mousein) and this:element(this.mousein).leave then
				this:element(this.mousein):leave()
			end
		end
		this.mousein = mousein
	end,
	
	mousepress = function(this, x, y, button, dt)
		this:unfocus()
		for i, element in pairs(this.elements) do
			if element.temp and element.id ~= this.mousein then
				this:rem(element.id)
			end
		end
		if this.mousein then
			local element = this:element(this.mousein)
			if element.type ~= 'hidden' then
				local parentid = this:getparent(element.id).id
				this:stackchildren(parentid)
			end
			if element.drag then
				this.drag = element.id
				element.offset = {x = x - element.pos.x, y = y - element.pos.y}
			end
			if button == 'l' then
				if this.mousedt < this.dblclickinterval and element.dblclick then
					element:dblclick()
				elseif element.click then
					element:click()
				end
			end
			if button == 'r' and element.rclick then
				element:rclick()
			elseif button == 'wu' and element.wheelup then
				element:wheelup()
			elseif button == 'wd' and element.wheeldown then
				element:wheeldown()
			end
			if element.temp then
				this:rem(element.id)
			end
		end
		this.mousedt = 0
	end,

	mouserelease = function(this, x, y, button)
		if this.drag then
			local element = this:element(this.drag)
			if button == 'l' then
				if element.drop then
					element:drop(this.mouseover)
				end
				if this.mouseover and this:element(this.mouseover).catch then
					this:element(this.mouseover):catch(element.id)
				end
			elseif button == 'r' then
				if element.rdrop then
					if button == 'r' and element.rdrop then
						element:rdrop(this.mouseover)
					end
				end
				if this.mouseover and this:element(this.mouseover).rcatch then
					this:element(this.mouseover):rcatch(element.id)
				end
			end
		end
		this.drag = nil
	end,

	keypress = function(this, key, code)
		if this.focus and this:element(this.focus) then
			local element = this:element(this.focus)
			-- enter
			if key == 'return' then
				if element.done then
					element:done() -- default enter key behaviour
				end
			end
			if element.keypress then
				element:keypress(key, code)
			end
		end
	end,
	
	setfocus = function(this, id)
		local element = this:element(id)
		if element then
			this.focus = id
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
	-- draw
	rect = function(pos, mode)
		local mode = mode or 'fill'
		love.graphics.rectangle(mode, pos.x, pos.y, pos.w, pos.h)
	end,
	
	draw = function(this)
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local ofont = love.graphics.getFont()
		local ocolor = {}--love.graphics.getColor()
		ocolor.r, ocolor.g, ocolor.b, ocolor.a = love.graphics.getColor()
		for i, element in ipairs(this.elements) do
			if element.display then
				if element.font then
					love.graphics.setFont(element.font)
				else
					love.graphics.setFont(this.font)
				end
				local pos = this.newpos(this:getpos(element))
				-- scrollgroup exception
				if this:element(element.parent) and this:element(element.parent).type == 'scrollgroup' and this:element(element.parent).child ~= element.id then
					love.graphics.setRenderTarget(this:element(element.parent).canvas)
					pos.x = pos.x - this:element(element.parent).pos.x
					pos.y = pos.y - this:element(element.parent).pos.y
				else
					love.graphics.setRenderTarget()
				end
				-- draw group
				if element.type == 'group' then
					love.graphics.setColor(this.color.bg)
					this.rect(pos)
					if element.label then
						if element.color then
							love.graphics.setColor(element.color)
						else
							love.graphics.setColor(this.color.fg)
						end
						love.graphics.print(element.label, pos.x + ((pos.w - this.font:getWidth(element.label)) / 2), pos.y + ((this.std - this.font:getHeight('dp')) / 2))
					end
				-- draw text
				elseif element.type == 'text' then
						if element.color then
							love.graphics.setColor(element.color)
						else
							love.graphics.setColor(this.color.fg)
						end
					love.graphics.printf(element.label, pos.x + (this.std / 4), pos.y + ((this.std - this.font:getHeight('dp')) / 2), pos.w - (this.std / 2), 'left')
				-- draw image
				elseif element.type == 'image' then
					if element.img then
						local colormode = love.graphics.getColorMode()
						love.graphics.setColorMode('replace')
						love.graphics.draw(element.img, pos.x, pos.y)
						love.graphics.setColorMode(colormode)
					end
					if element.label then
						if element.color then
							love.graphics.setColor(element.color)
						else
							love.graphics.setColor(this.color.fg)
						end
						love.graphics.print(element.label, pos.x + ((pos.w - this.font:getWidth(element.label)) / 2), (pos.y + element.pos.h) + ((this.std - this.font:getHeight('dp')) / 2))
					end
				-- draw button
				elseif element.type == 'button' then
					-- option
					if this:element(element.parent) and this:element(element.parent).value and element.value == this:element(element.parent).value then
						if element.id == this.mousein then
							love.graphics.setColor(this.color.focus)
						else
							love.graphics.setColor(this.color.hilite)
						end
					-- regular button
					else
						if element.id == this.mousein then
							love.graphics.setColor(this.color.hilite)
						else
							love.graphics.setColor(this.color.default)
						end
					end
					this.rect(pos)
					-- image button
					if element.img then
						-- love.graphics.setcolormode('replace')
						love.graphics.draw(element.img, ((pos.x + (pos.w / 2)) - (element.img:getWidth()) / 2), ((pos.y + (pos.h / 2)) - (element.img:getHeight() / 2)))
						if element.label then
							if element.color then
								love.graphics.setColor(element.color)
							else
								love.graphics.setColor(this.color.fg)
							end
							love.graphics.print(element.label, pos.x + ((pos.w - this.font:getWidth(element.label)) / 2), pos.y + ((this.std - this.font:getHeight(element.label)) / 2))
						end
					-- regular text button
					else
						if element.label then
							if element.color then
								love.graphics.setColor(element.color)
							else
								love.graphics.setColor(this.color.fg)
							end
							love.graphics.print(element.label, pos.x + ((pos.w - this.font:getWidth(element.label)) / 2), pos.y + ((element.pos.h - this.font:getHeight(element.label)) / 2))
						end
					end
				-- draw scrollgroup
				elseif element.type == 'scrollgroup' then
					love.graphics.setColor(this.color.bg)
					this.rect(pos)
					if element.label then
						if element.color then
							love.graphics.setColor(element.color)
						else
							love.graphics.setColor(this.color.fg)
						end
						love.graphics.setColor(this.color.fg)
						love.graphics.print(element.label, pos.x + ((pos.w - this.font:getWidth(element.label)) / 2), pos.y + ((this.std - this.font:getHeight(element.label)) / 2))
					end
					love.graphics.setColor({255, 255, 255, 255})
					love.graphics.draw(element.canvas, pos.x, pos.y, 0, 1, 1, 0, 0)
				-- draw scroll
				elseif element.type == 'scroll' then
					if element.id == this.mousein then
						love.graphics.setColor(this.color.default)
					else
						love.graphics.setColor(this.color.bg)
					end
					this.rect(pos)
					if element.id == this.mousein then
						love.graphics.setColor(this.color.fg)
					else
						love.graphics.setColor(this.color.hilite)
					end
					this.rect({x = pos.x, y = math.min(pos.y + (pos.h - this.std), math.max(pos.y, pos.y + (pos.h * (element.values.current / (element.values.max - element.values.min))))), w = this.std, h = this.std})
				-- draw input
				elseif element.type == 'input' then
					if element.id == this.mousein then
						love.graphics.setColor(this.color.hilite)
					else
						if element.id == this.focus then
							love.graphics.setColor(this.color.bg)
						else
							love.graphics.setColor(this.color.default)
						end
					end
					this.rect(pos)
					love.graphics.setColor(this.color.fg)
					local str = tostring(element.value)
					local offset = 0
					while this.font:getWidth(str) > pos.w - (this.std / 2) do
						str = str:sub(2)
						offset = offset + 1
					end
					love.graphics.print(str, pos.x + (this.std / 4), pos.y + ((pos.h - this.font:getHeight('dp')) / 2))
					if element.id == this.focus and element.cursorlife < 0.5 then
						local cursorx = ((pos.x + (this.std / 4)) + this.font:getWidth(str:sub(1, element.cursor - offset)))
						love.graphics.line(cursorx, pos.y + (this.std / 8), cursorx, (pos.y + pos.h) - (this.std / 8))
					end
					if element.label then
						if element.color then
							love.graphics.setColor(element.color)
						else
							love.graphics.setColor(this.color.fg)
						end
						love.graphics.print(element.label, pos.x - ((this.std / 2) + this.font:getWidth(element.label)), pos.y + ((element.pos.h - this.font:getHeight('dp')) / 2))
					end
				end
			end
		end
		love.graphics.setRenderTarget()
		love.graphics.setColor(this.color.fg)
		for i, element in ipairs(this.elements) do
			if element.display then
				local pos = this:getpos(element)
				if element.tip and element.id == this.mousein then
					love.graphics.setColor(this.color.bg)
					tippos = {x = pos.x + (this.std / 2), y = pos.y + (this.std / 2), w = this.font:getWidth(element.tip) + this.std, h = this.std}
					this.rect({x = math.max(0, math.min(tippos.x, love.graphics.getWidth() - (this.font:getWidth(element.tip) + this.std))), y = math.max(0, math.min(tippos.y, love.graphics.getHeight() - this.std)), w = tippos.w, h = tippos.h})
					love.graphics.setColor(this.color.fg)
					love.graphics.print(element.tip, math.max(this.std / 2, math.min(tippos.x + (this.std / 2), love.graphics.getWidth() - (this.font:getWidth(element.tip) + (this.std / 2)))), math.max((this.std - this.font:getHeight(element.tip)) / 2, math.min(tippos.y + ((this.std - this.font:getHeight('dp')) / 2), (love.graphics.getHeight() - this.std) + ((this.std - this.font:getHeight('dp')) / 2))))
				end
			end
		end
		love.graphics.setFont(ofont)
		love.graphics.setColor(ocolor.r, ocolor.g, ocolor.b, ocolor.a)
	end,
	
	-- group
	group = function(this, label, pos, parent)
		local element = {type = 'group', label = label, pos = this.newpos(pos), Gspot = this}
		return this:add(element)
	end,
	
	-- text
	text = function(this, label, pos, parent)
		local element = {type = 'text', label = label, pos = this.newpos(pos), parent = parent, Gspot = this}
		local width, lines = this.font:getWrap(label, element.pos.w)
		local lines = math.max(lines, 1)
		element.pos.h = (this.font:getHeight('dp') * lines) + (this.std - this.font:getHeight('dp'))
		return this:add(element)
	end,
	
	-- image
	image = function(this, label, pos, img, parent)
		local element = {type = 'image', label = label, pos = this.newpos(pos), img = img, parent = parent, Gspot = this}
		if img then
			this.newimage(element)
		end
		return this:add(element)
	end,
	
	-- buttons
	button = function(this, label, pos, parent)
		local element = {type = 'button', label = label, pos = this.newpos(pos), parent = parent, Gspot = this}
		return this:add(element)
	end,
	imgbutton = function(this, label, pos, img, parent)
		local element = {type = 'button', label = label, pos = this.newpos(pos), img = img, parent = parent, Gspot = this}
		if img then
			this.newimage(element)
		end
		return this:add(element)
	end,
	option = function(this, label, pos, value, parent)
		local element = this:element(this:button(label, pos, parent))
		element.value = value
		element.click = function(this)
			this.Gspot:element(this.parent).value = this.value
		end
		return element.id
	end,
	
	-- input
	input = function(this, label, pos, parent)
		local element = {type = 'input', label = label, pos = this.newpos(pos), parent = parent, value = '', cursor = 0, cursorlife = 0, Gspot = this}
		element.keyrepeat = 200
		element.keydelay = 500
		element.click = function(this)
			this.Gspot:setfocus(this.id)
		end
		element.done = function(this)
			this.Gspot:unfocus()
		end
		element.keypress = function(this, key, code)
			-- delete
			if key == 'backspace' then
				this.value = this.value:sub(1, this.cursor - 1)..this.value:sub(this.cursor + 1)
				this.cursor = math.max(0, this.cursor - 1)
			elseif key == 'delete' then
				this.value = this.value:sub(1, this.cursor)..this.value:sub(this.cursor + 2)
				this.cursor = math.min(this.value:len(), this.cursor)
			-- navigate
			elseif key == 'left' then
				this.cursor = math.max(0, this.cursor - 1)
			elseif key == 'right' then
				this.cursor = math.min(this.value:len(), this.cursor + 1)
			elseif key == 'home' then
				this.cursor = 0
			elseif key == 'end' then
				this.cursor = this.value:len()
			-- input
			elseif code >= 32 and code < 127 then
				local left = this.value:sub(1, this.cursor)
				local right =  this.value:sub(this.cursor + 1)
				this.value = table.concat{left, string.char(code), right}
				this.cursor = this.cursor + 1
			end
		end
		return this:add(element)
	end,
	
	-- scroll
	scroll = function(this, label, pos, values, parent)
		local element = {type = 'scroll', label = label, drag = true, pos = this.newpos(pos), parent = parent, values = this:scrollvalues(values), Gspot=this}
		element.wheelup = function(this)
			this.values.current = math.max(this.values.current - this.values.step, this.values.min)
		end
		element.wheeldown = function(this)
			this.values.current = math.min(this.values.current + this.values.step, this.values.max)
		end
		element.offset = {x = 0, y = 0}
		element.drag = true
		return this:add(element)
	end,
	
	scrollvalues = function(this, values) -- scroll helper
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
			val.step = val.step or this.std
			return val
		end
	end,
	
	-- scrollgroup
	scrollgroup = function(this, label, pos, parent)
		local element = {type = 'scrollgroup', label = label, pos = this.newpos(pos), parent = parent, maxh = 0, Gspot = this}
		element.canvas = love.graphics.newFramebuffer(element.pos.w, element.pos.h)
		local element = this:element(this:add(element))
		element.child = this:scroll(nil, {x = element.pos.w, y = 0, w = this.std, h = element.pos.h}, {min = 0, max = 0, current = 0, step = this.std}, element.id)
		return element.id
	end,
	
	hidden = function(this, label, pos, parent)
		local element = {type = 'hidden', label = label, pos = this.newpos(pos), parent = parent, Gspot = this}
		return this:add(element)
	end,
	
	radius = function(this, label, pos, parent)
		local element = {type = 'radius', label = label, pos = this.newpos(pos), parent = parent, display = false, Gspot = this}
		return this:add(element)
	end,
}
return Gspot:new()