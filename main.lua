gui = require('Gspot') -- import the library
--mainmenu = gui() -- create a gui instance. don't have to do this, but you may want a gui for each gamestate so they can talk to each other, and you won't have to recontsruct the gui every time you enter a state

font = love.graphics.newFont(192)

love.load = function()
	
	love.keyboard.setKeyRepeat(500, 250)
	love.graphics.setFont(font)
	--love.graphics.setColor(64, 32, 0, 128) -- just setting these so we know the gui isn't stealing our thunder
	love.graphics.setColor(0, 32, 32, 128)
	-- button
	local button = gui:button('button', {x = 128, y = gui.style.unit, w = 128, h = gui.style.unit}) -- a button(label, pos, optional parent) gui.style.unit is a standard gui unit (default 16), used to keep the interface tidy
	button.click = function(this) -- set element:click() to make it respond to gui's click event
		gui:feedback('clicky')
	end
	
	-- image
	local image = gui:image('An Image', {160, 32, 0, 0}, nil, 'img.png') -- an image(label, pos, parent, love.image or path)
	image.click = function(this)
		gui:feedback('clicky clicky')
	end
	image.enter = function(this) this.Gspot:feedback("I'm In!") end -- every element has a reference to the gui instance which created it
	image.leave = function(this) this.Gspot:feedback("I'm Out!") end
	
	-- hidden element
	local hidden = gui:hidden('', {128, 128, 128, 128}) -- creating a hidden element, to see it at work
	hidden.tip = "can't see me, but I still respond"
	
	-- elements' children will be positioned relative to their parent's position
	group1 = gui:group('group', {gui.style.unit, gui.style.unit * 3, 128, gui.style.unit}) -- group(label, pos, optional parent)
	group1.style.fg = {255, 192, 0, 255}
	group1.tip = 'drag and drop' -- add a tooltip
	group1.drag = true -- respond to default drag behaviour
	group1.drop = function(this, bucket) -- respond to drop event
		if bucket then gui:feedback('dropped on '..tostring(bucket))
		else gui:feedback('dropped on nothing') end
	end
	-- option (must have a parent)
	for i = 1, 3 do
		option = gui:option('option '..i, {0, gui.style.unit * i, 128, gui.style.unit}, group1, i) -- option(label, pos, parent, value) option stores this.value in this.parent.value when clicked, and is selected if this.value == this.parent.value
		option.tip = 'select '..option.value
	end
	
	-- another group, with various behaviours
	group2 = gui:group('group', {gui.style.unit, 128, 128, 256})
	group2.drag = true
	group2.tip = 'drag, right-click, and catch'
	group2.rclick = function(this) -- respond to right-click event by creating a button.
		gui:feedback('right-click')
		local button = gui:button('click', {love.mouse.getX(), love.mouse.getY(), 128, gui.style.unit}) -- button's parent will be the calling element
		button.click = function(this) -- temp button to click before removed itself
			gui:feedback('I\'ll be back!')
			gui:rem(this)
		end
	end
	group2.catch = function(this, ball) -- respond when an element is dragged and then dropped on this element
		gui:feedback('Caught '..ball:type())
	end
	-- scrollgroup's children, excepting its scrollbar, will scroll
	scrollgroup = gui:scrollgroup(nil, {0, gui.style.unit, 128, 256}, group2) -- scrollgroup will create its own scrollbar
	scrollgroup.scroller.tip = 'scroll (mouse or wheel)' -- scrollgroup.scroller is the scrollbar
	scrollgroup.scroller:setshape('circle') -- to set a round handle
	scrollgroup.scroller.drop = function(this) gui:feedback('Scrolled to : '..this.values.current..' / '..this.values.min..' - '..this.values.max) end
	
	-- initialize element.shape to 'circle' by specifying pos.r -- pos.w and pos.h will be set accordingly
	local checkbox = gui:checkbox(nil, {r = 8}, scrollgroup) -- scrollgroup.scroller.values.max will be updated when a child is added to scrollgroup
	checkbox.click = function(this)
		gui[this.elementtype].click(this) -- calling option's base click() to preserve default functionality, as we're overriding a reserved behaviour
		if this.value then this.style.fg = {255, 128, 0, 255}
		else this.style.fg = {255, 255, 255, 255} end
	end
	local checkboxlabel = gui:text('check', {x = 16}, checkbox, true) -- using the autosize flag to resize the element's width to fit the text
	checkboxlabel.click = function(this, x, y)
		gui:feedback(tostring(this.pos)) -- Gspot.pos type has some andy features
		this.parent:click()
	end
	
	local str = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'
	for i = 1, 8 do
		local text = gui:text(str, {w = 128}) -- if not autosize, Gspot wraps text to element.pos.w and adjusts element.pos.h to fit it in
		scrollgroup:addchild(text, true) -- using the autostack flag to reposition below existing child elements
		-- the two lines above accomplish the same as gui:text(str, {y = scrollgroup:getmaxh(), w = 128}, scrollgroup)
	end
	
	-- additional scroll controls
	button = gui:button('up', {group2.pos.w, 0}, group2) -- a small button attached to the scrollgroup's group, because all of a scrollgroup's children scroll
	button.click = function(this)
		local scroll = scrollgroup.scroller
		scroll.values.current = math.max(scroll.values.min, scroll.values.current - scroll.values.step) -- decrement scrollgroup.scroller.values.current by scrollgroup.scroller.values.step, and the slider will go up a notch
		scroll:drop()
	end
	button = gui:button('dn', {group2.pos.w, group2.pos.h + gui.style.unit}, group2)
	button.click = function(this)
		local scroll = scrollgroup.scroller
		scroll.values.current = math.min(scroll.values.max, scroll.values.current + scroll.values.step) -- this one increment's scrollbar's values.current, moving the slider down a notch
		scroll:drop()
	end
	
	-- text input
	input = gui:input('chat', {64, love.graphics.getHeight() - 32, 256, gui.style.unit})
	input.keydelay = 500 -- these two are set by default for input elements, same as doing love.setKeyRepeat(element.keydelay, element.keyrepeat) but Gspot will return to current keyrepeat state when it loses focus
	input.keyrepeat = 200 -- keyrepeat is used as default keydelay value if not assigned as above. use element.keyrepeat = false to disable repeating
	input.done = function(this) -- Gspot calls element:done() when you hit enter while element has focus. override this behaviour with element.done = false
		gui:feedback('I say '..this.value)
		this.value = ''
		this.Gspot:unfocus()
	end
	button = gui:button('Speak', {input.pos.w + gui.style.unit, 0, 64, gui.style.unit}, input) -- attach a button
	button.click = function(this)
		this.parent:done()
	end
	
	-- easy custom gui element
	gui.boxy = function(this, label, pos, parent) -- careful not to override existing element types, and remember we're inside the gui's scope now
		local group = this:group(label, pos, parent) -- using the easy  method, our custom element should be based on an existing element type
		group.tip = 'drag, and right-click to spawn'
		group.drag = true
		group.rclick = function(this) gui:boxy('more custom goodness', {love.mouse.getX(), love.mouse.getY(), 128, 64}) end -- boxy will spawn more windows
		
		local x = this:button('X', {x = group.pos.w - this.style.unit, y = 0, w = this.style.unit, h = this.style.unit}, group) -- adding a control
		x.click = function(this) this.Gspot:rem(this.parent) end -- which removes this boxy
		
		return group -- return the element
	end
	boxy = gui:boxy('custom goodness', {256, 256, 128, 64}) -- now make one of our windows
	
	-- or if you feel so inclined
	gui.mostbasic = function(this, label, pos, parent)
		local element = gui:element('group', label, pos, parent) -- Gspot:element(elementtype, label, pos, parent) gives the element its required values and inheritance. elementtype must be an existing type, or it won't work
		return this:add(element) -- Gspot:add() adds it to Gspot.elements, and returns the new element
	end
	
	--show, hide, and update
	text = gui:text('Hit F1 to show/hide', {love.graphics.getWidth() - 128, gui.style.unit, 128, gui.style.unit}) -- a hint (see love.keypressed() below)
	showhider = gui:group('Mouse Below', {love.graphics.getWidth() - 128, gui.style.unit * 2, 128, 64})
	counter = gui:text('0', {0, gui.style.unit, 128, 0}, showhider)
	counter.count = 0
	counter.update = function(this, dt) -- set an update function, which will be called every frame, unless we also specify element.updateinterval
		if this.parent == gui.mousein then
			this.count = this.count + dt
			if this.count > 1 then this.count = 0 end
			this.label = this.count
		end
	end
	showhider:hide() -- display state will be propagated to children
end

love.update = function(dt)
	gui:update(dt)
end

love.draw = function()
	local bg = 'ÖBEY'
	love.graphics.print(bg, 0, 240, math.pi / 4, 1, 1)
	
	gui:draw()
	
	love.graphics.print(bg, 320, 240, math.pi / 4, 1, 1)
end

love.keypressed = function(key, code)
	if gui.focus then
		gui:keypress(key, code) -- only sending input to the gui if we're not using it for something else
	else
		if key == 'return'then -- binding enter key to input focus
			input:focus()
		elseif key == 'f1' then -- toggle show-hider
			if showhider.display then showhider:hide() else showhider:show() end
		else
			gui:feedback(key) -- why not
		end
	end
end

love.mousepressed = function(x, y, button)
	gui:mousepress(x, y, button) -- pretty sure you want to register mouse events
end
love.mousereleased = function(x, y, button)
	gui:mouserelease(x, y, button)
end