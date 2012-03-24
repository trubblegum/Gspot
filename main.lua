-- elements defined :
-- gui:group(label, pos, optional parent) -- a box with a label, great for arranging gui elements in
-- gui:text(text, pos, optional parent) -- a text object, alighned left and wrapped to pos.w
-- gui:image(label, pos, img, optional parent) -- an image, with label as a caption, centered below. if img is not nil, sets the dimensions of the element to match the image else nothing will be rendered
-- gui:button(label, pos, optional parent) -- a box with a label, great for clicking on
-- gui:imgbutton(label, pos, img, optional parent) -- a button with an image, which will be centered on the button. a transparent image will show the gui's hilighting underneath. does not alter element dimensions
-- gui:option(label, pos, value, optional parent) -- a button which remembers if it was clicked
-- gui:scroll(label, pos, values, optional parent) -- a vertical scrollbar
-- gui:scrollgroup(label, pos, optional parent) -- a vertical scrolling window, with its own scrollbar
-- gui:hidden(label, pos, optional parent) -- an invisible element, which is never drawn, but its tooltip is, and is not brought to the front. it only has a label so it doesn't feel left out.

-- element format :
-- element = {id = gui.maxid(), label = string or nil, pos = gui.pos(position), display = true}
-- + optionally :
-- parent = number -- must be an element id, positions the element relative to its parent
-- display = false -- don't draw or register events
-- tip = string -- a tooltip to display near the top left when the mouse is inside the element
-- font = fontData as used by love. sets a font other than the default, to print the label with
-- color = RGBA as used by love. element colour overrides
-- keyrepeat = number -- sets the repeat interval for this element's key events
-- keydelay = number -- sets a delay before repeating key events for this element (defaults to element.keyrepeat)
-- updateinterval = number -- sets the repeat interval for this element's update events

-- element-specific variables :
-- button.img = imageData or path -- optionally displays the image centered on the button, and moves the label to the top
-- image.img = imageData or path -- in both cases, the element will so img = assert(love.graphics.newImage(img)) if img is a string
-- scroll.offset
-- scroll.values = {min, max, current, step}
-- scrollgroup.maxh -- the overall height (lowest pixel) of the scrollgroup's contents. updated when a child element is added
-- scrollgroup.child -- id of the scrollgroup's scrollbar
-- option.value -- a value stored in a button. it will be copied into parent.value when clicked
-- input.value -- string entered into the box - default ''
-- input.cursor -- cursor position - default 0

-- reserved element variables :
-- don't override these
-- element.id, orig

-- predefined element behaviours :
-- check with Gspot.lua when overriding these
-- option.click
-- input.click, keypress
-- scroll.wheelup, wheeldown, drag
-- scrollgroup.child

-- events :
-- enter = function(this) -- register a mouseenter behaviour
-- leave = function(this) -- register a mouseleave behaviour
-- click = function(this) -- register a click behaviour
-- dblclick = function(this) -- registers a behaviour which will be called if the mouse is clicked within .25s of the last click. only the first click will trigger the click behaviour
-- rclick = function(this) -- register a right-click behaviour
-- drag = true -- registers for the defualt drag behaviour, which follows the mouse, or scrolls the scrollbar if element is a scrollbar
-- drag = function(this) -- registers for the defualt drag behaviour, followed by an additional custom drag behaviour
-- rdrag = true -- registers for the default right-drag behaviour, which follows the mouse
-- rdrag = function(this) -- registers for the defualt right-drag behaviour, followed by an additional custom right-drag behaviour
-- drop = function(this, bucket) -- register a drop behaviour, which will trigger bucket's catch(). bucket is the object which is dropped onto, or nil if none -- for some reason I can't fathom, scrollbars don't respond
-- rdrop = function(this, bucket) -- register a right-drop behaviour, which will trigger bucket's catch()
-- catch = function(this, ball) -- register a catch behaviour. ball is the object which was dragged
-- rcatch = function(this, ball) -- register a right-catch behaviour. element.rcatch = element.catch is usual, but not default
-- wheelup = function(this) -- register a mousewheel up behaviour
-- wheeldown = function(this) -- register a mousewheel down behaviour
-- keypress = function(this, key, code) -- registers a keypress behaviour
-- update = function(this) -- register a function which will be called every frame. suggest use with caution, and include conditions like if this.id == this.Gspot.mousein then

-- gui types :
-- element.pos = {x = number, y = number, w = number, h = number} or gui.pos(position) -- positioning coordinates
-- scroll.values = {min = number, max = number, current = number, step = number} or gui.scrollvalues(values) -- holds information about a scrollbar's state
-- tables need not be indexed if values are in the correct order, gui will take care of this
-- note that these tables are processed by gui.pos() and gui.scrollvalues() which create new tables, so get your references post-creation

-- not in this demo :
-- scroll(label, position, values, optional parent) -- an independent scrollbar, see also scroll.values above

gui = require('Gspot') -- import the library
--gui = Gspot() -- create a gui instance. don't have to do this, but you will probably want a gui for each gamestate, so you don't have to recontsruct the gui every time you enter a state

font = love.graphics.newFont(192)

love.load = function()
	
	love.keyboard.setKeyRepeat(500, 250)
	
	love.graphics.setFont(font) -- our font, not the gui's
	love.graphics.setColor(24, 16, 8, 128) -- just setting these so we know the gui isn't stealing our thunder
	
	-- button
	-- element constructor returns the element's id
	local button = gui:button('button', {x = gui.std, y = gui.std, w = 128, h = gui.std}) -- create a button(label, position, optional parent) gui.std is a standard gui unit (default 16), used to keep the interface tidy
	button.click = function(this) -- set element:click() to make it respond to gui's click event
		print('clicky')
	end
	
	-- image
	button = gui:image('An Image', {160, 32, 0, 0}, 'img.png') -- an image(label, pos, img, optional parent) img is imageData or path
	button.click = function(this) -- works for any element
		print('clicky clicky')
	end
	button.enter = function(this) print("I'm In!") end
	button.leave = function(this) print("I'm Out!") end
	
	-- hidden element
	--local hidden = gui:hidden(nil, {128, 128, 128, 128}) -- creating a hidden element, to see it at work
	--hidden.tip = "can't see me, but I still respond"
	
	-- group will carry its children with it, positioned relatively
	group1 = gui:group('group', {gui.std, gui.std * 3, 128, gui.std}) -- create a group(label, position, optional parent), like a simple window
	group1.color.fg = {255, 192, 0, 255}
	group1.tip = 'drag and drop' -- add a tooltip
	group1.drag = true -- respond to gui's drag behaviour. note that children will not respond to parent's events
	group1.drop = function(this, bucket) -- respond to drop event (this, receiving element)
		if bucket then
			print('dropped on '..bucket.type)
		else
			print('dropped on nothing')
		end
	end
	-- option (must have a parent)
	for i = 1, 3 do
		option = gui:option('option '..i, {0, gui.std * i, 128, gui.std}, i, group1) -- create an option(label, position, value, optional parent) option is just a button with a default click function which stores this.value in this.parent.value, and is selected if this.value == this.parent.value
		option.tip = 'select '..option.value
		-- if you want to add a click() to an option element and retain its default functionality, start its click() with the following line
		-- this.Gspot:element(this.parent).value = this.value
	end
	
	-- another group, with various behaviours
	group2 = gui:group('group', {gui.std, 128, 128, 256})
	group2.drag = true
	group2.tip = 'drag, right-click, and catch'
	group2.rclick = function(this) -- respond to gui's right-click event by creating a button.
		print('right click')
		local button = gui:button('click', {love.mouse.getX() - this.pos.x, love.mouse.getY() - this.pos.y, 128, gui.std}, this) -- this new button's parent will be the calling element
		button.click = function(this) -- temp button responds to click before being removed
			print('I\'ll be back!')
			gui:rem(this)
		end
	end
	group2.catch = function(this, ball) -- respond when an element is dragged and then dropped on the element by telling us what you caught
		print('caught '..ball.type)
	end
	-- scrollgroup within group (a scrollgroup's children will all scroll)
	scrollgroup = gui:scrollgroup(nil, {0, gui.std, 128, 256}, group2) -- create a scrollgroup(label, position, optional parent). will create its own scrollbar, although you can create independent scrollbars
	scrollgroup.scroller.tip = 'scroll (mouse or wheel)' -- scrollgroup.scroller is the scrollbar
	scrollgroup.scroller.drop = function(this)
		print('scroll '..this.values.current..' / '..this.values.min..' - '..this.values.max) -- a scrollbar's values are min, max, current, step
	end
	-- text within scrollgroup
	str = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'
	for i = 1, 8 do
		gui:text(str, {0, scrollgroup.maxh, 128, 0}, scrollgroup) -- adding these to scrollgroup, Gspot will take care of setting height
	end
	
	-- additional scroll controls
	button = gui:button('up', {128, 0, gui.std, gui.std}, group2) -- a small button attached to the scrollgroup's group
	button.click = function(this) -- gui click event will decrement scrollbar.value.current by values.step, and the slider will go up a notch
		local scroll = scrollgroup.scroller -- using our global scrollgroup reference to find its scrollbar
		scroll.values.current = math.max(scroll.values.min, scroll.values.current - scroll.values.step)
		print('scrolling outside gui '..scroll.values.current..' / '..scroll.values.min..' - '..scroll.values.max)
	end
	button = gui:button('dn', {128, scrollgroup.pos.h + gui.std, gui.std, gui.std}, group2)
	button.click = function(this) -- this one increment's scrollbar's values.current, moving the slider down a notch
		local scroll = scrollgroup.scroller
		scroll.values.current = math.min(scroll.values.max, scroll.values.current + scroll.values.step)
		print('scrolling outside gui '..scroll.values.current..' / '..scroll.values.min..' - '..scroll.values.max)
	end
	
	-- input
	input = gui:input('chat', {64, love.graphics.getHeight() - 32, 256, gui.std}) -- create an input(label, position, optional parent)
	input.keydelay = 500 -- these two are set by default for input elements, same as doing love.setKeyRepeat(element.keydelay, element.keyrepeat) gui will of course return you to your defined keyrepeat state when it loses focus
	input.keyrepeat = 200 -- gui uses this as default keydelay value if not assigned as above. use element.keyrepeat = false disable repeating
	input.done = function(this) -- input:done() is called when you hit enter while input has focus
		print('I say '..this.value)
		this.value = '' -- clear input
		this.Gspot:unfocus() -- every element has a reference to the gui instance which created it, and since we are overriding imput.done we need it to clear focus
	end
	-- Note : you probably don't want to override input's default keypress()
	-- if you want to override input's default click(), be sure to include the following default focus behaviour, or the gui won't pass it any keyboard events
	-- this.Gspot:focus(this.id)
	button = gui:button('Speak', {input.pos.w + gui.std, 0, 64, gui.std}, input) -- attach a button
	button.click = function(this) -- use click event
		this.parent:done() --  to trigger the input's done() behaviour
	end
	
	-- custom gui element
	gui.window = function(this, label, pos, parent) -- careful not to override existing element types, and remember we're inside the gui's scope now
		local pos = gui.util.newpos(pos) -- this formats our pos argument by returning a new pos table with our values
		local group = this:group(label, pos, parent) -- our window is based on a group
		group.tip = 'drag, and right-click to create'
		group.drag = true
		local x = this:button('X', {x = pos.w - this.std, y = 0, w = this.std, h = this.std}, group) -- with an added control
		x.click = function(this) -- which responds to click
			this.Gspot:rem(this.parent) -- and removes the window
		end
		group.rclick = function(this)
			this.Gspot:window('more custom goodness', {love.mouse.getX(), love.mouse.getY(), 128, 64})
		end
		return group -- return the element
	end
	window = gui:window('custom goodness', {256, 256, 128, 64}) -- create a window
	
	-- or if you feel so inclined
	gui.mostbasic = function(this, label, pos, parent)
		local element = {type = 'group', label = label, pos = this.newpos(pos), parent = parent, Gspot = this} -- the element must contain at least this much. type must be one of the drawable types, or it won't be drawn
		return this:add(element) -- gui.add() gives the element an id, adds it to the collection of elements, and returns the new element's id
	end
	
	--show, hide, and update
	text = gui:text('Hit F1 to show/hide', {love.graphics.getWidth() - 128, gui.std, 128, gui.std}) -- a hint (see love.keypressed() below)
	showhider = gui:group('Mouse Below', {love.graphics.getWidth() - 128, gui.std * 2, 128, 64}) -- remember this
	counter = gui:text('0', {0, gui.std, 128, 0}, showhider) -- some contents
	counter.count = 0 -- careful not to override element values
	counter.update = function(this, dt) -- set an update function, which will be called every frame
		if this.id == gui.mousein then -- this is how we know the mouse is over
			this.label = this.count -- set the element's text to the counter value
		end
		this.count = this.count + dt -- do stuff
		if this.count > 1 then this.count = 0 end
	end
	showhider:hide() -- display state will be propagated to children as long as they already exist
end

love.update = function(dt)
	gui:update(dt) -- triggers everything - very important
end

love.draw = function()
	local bg = 'ÖBEY'
	love.graphics.print(bg, 0, 240, math.pi / 4, 1, 1)-- draw some stuff under the gui
	
	gui:draw() -- draw the gui, or another one, or several, but they will all need mouse events etc, and if they overlap they will all respond, disregarding draw order
	
	love.graphics.print(bg, 320, 240, math.pi / 4, 1, 1)-- or on top
end

love.keypressed = function(key, code)
	if key == 'return' and gui.focus ~= input then -- binding enter key to input focus
		input:focus() -- set focus to input
	elseif key == 'f1' then -- toggle show-hider
		if showhider.display then
			showhider:hide()
		else
			showhider:show()
		end
	else
		gui:keypress(key, code) -- if you don't want text input, you don't need this
	end
end

love.mousepressed = function(x, y, button)
	gui:mousepress(x, y, button) -- pretty sure you want to register mouse events
end
love.mousereleased = function(x, y, button)
	gui:mouserelease(x, y, button) -- only need this if you're dragging or dropping
end