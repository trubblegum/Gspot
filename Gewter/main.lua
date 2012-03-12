Gspot = require('Gspot')
gui = Gspot:new()

bgtext = 'ÖBEY'
ground = love.graphics.getHeight() - 256
bg = nil
player = nil
target = nil
gibbage = {'Ouch!', 'Hey!', 'Pow!', 'Oof!'}
help = nil

normal = function(v)
	length = math.sqrt(v.x * v.x + v.y * v.y)
	v.x = v.x / length
	v.y = v.y / length
	return v
end

love.load = function()
	
	love.graphics.setFont(love.graphics.newFont(192))
	love.graphics.setColor(24, 16, 8, 255)
	
	bg = gui:element(gui:hidden('', {0, 0, love.graphics.getWidth(), love.graphics.getWidth()}))
	bg.click = function(this)
		bullet = gui:image('', {player.pos.x + (player.img:getWidth() / 2), player.pos.y + (player.img:getHeight() / 2), 0, 0}, 'bullet.png')
		bullet = gui:element(bullet)
		bullet.v = normal({x = love.mouse.getX() - (player.pos.x + (player.img:getWidth() / 2)), y = love.mouse.getY() - (player.pos.y + (player.img:getWidth() / 2))})
		bullet.update = function(this, dt)
			this.pos.x = this.pos.x + (this.v.x * (256 * dt))
			this.pos.y = this.pos.y + (this.v.y * (256 * dt))
			for i, target in pairs(this.Gspot.elements) do
				if target.type == 'group' and this.Gspot.withinrect(this.pos, target.pos) then
					if target.hit then
						target:hit()
					end
					this.Gspot:rem(this.id)
					break
				end
			end
		end
	end
	
	player = gui:element(gui:image('', {0, 0, 0, 0}, 'player.png'))
	player.v = {x = 0, y = 0}
	player.jump = false
	player.update = function(this, dt)
		if love.keyboard.isDown('w') and this.jump then
			this.jump = false
			this.v.y = -512
		end
		this.pos.y = this.pos.y + (this.v.y * dt)
		if this.pos.y > ground then
			this.pos.y = ground
			this.v.y = 0
			this.jump = true
		elseif this.pos.y == ground then
			--
		else
			if this.v.y > 0 then
				for i, target in pairs(gui.elements) do
					if target.type == 'group' then
						for x = this.pos.x, this.pos.x + this.pos.w, 16 do
							if gui.withinrect({x = x, y = this.pos.y + this.pos.h}, target.pos) and (this.pos.y + this.pos.h) - this.v.y < target.pos.y then
								this.pos.y = target.pos.y - this.pos.h
								this.v.y = 0
								this.jump = true
							end
						end
					end
				end
			end
			this.v.y = this.v.y + (1024 * dt)
		end
		
		if love.keyboard.isDown('a') and this.v.x > -256 then
			this.v.x = this.v.x - (1024 * dt)
		else
			if this.v.x < 0 then
				this.v.x = math.min(this.v.x + (512 * dt), 0)
			end
		end
		if love.keyboard.isDown('d') and this.v.x  < 256 then
			this.v.x = this.v.x + (1024 * dt)
		else
			if this.v.x > 0 then
				this.v.x = math.max(this.v.x - (512 * dt), 0)
			end
		end
		this.pos.x = this.pos.x + (this.v.x * dt)
		if this.pos.x < 0 - this.pos.w then
			this.pos.x = this.pos.x + love.graphics.getWidth()
		elseif this.pos.x > love.graphics.getWidth() then
			this.pos.x = this.pos.x - love.graphics.getWidth()
		end
	end
	
	gui.speech = function(this, label, pos, parent)
		local group = this:group(label, pos, parent)
		group = this:element(group)
		group.alpha = 255
		group.update = function(this, dt)
			this.alpha = this.alpha - (128 * dt)
			if this.alpha < 0 then
				this.Gspot:rem(this.id)
			end
			this.color = {255, 255, 255, math.floor(this.alpha)}
			this.pos.y = this.pos.y - (128 * dt)
		end
		return group.id
	end
	
	target = gui:element(gui:group(nil, {love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 32, 32}))
	target.click = function(this)
		this.Gspot:speech('Hey! No cheating!', {target.pos.x + (target.pos.w / 2), target.pos.y, 1, 1})
	end
	target.hit = function(this)
		local label = gibbage[math.ceil(math.random() * 4)]
		this.Gspot:speech(label, {target.pos.x + (target.pos.w / 2), target.pos.y, 1, 1})
	end
	
	id = gui:text('Hit F1 for help', {love.graphics.getWidth() - 128, gui.std, 128, gui.std})
	help = gui:group('Controls', {love.graphics.getWidth() - 128, gui.std, 128, 64})
	help = gui:element(help)
	gui:text('A and D to move, W to jump, Mouse to fire', {0, gui.std, 128, 0}, help.id) -- some contents
	gui:hide(help.id)
	
	for i = 1, 3 do
		local element = gui:element(gui:group(nil, {gui.std, gui.std, 256, 32}))
		element.drag = true
	end
end

love.update = function(dt)
	gui:update(dt)
end

love.draw = function()
	love.graphics.print(bgtext, 0, 240, math.pi / 4, 1, 1)
	
	gui:draw()
end

love.keypressed = function(key, code)
	gui:keypress(key, code)
	if key == 'f1' then -- toggle show-hider
		if help.display then
			gui:hide(help.id)
		else
			gui:show(help.id)
		end
	end
end

love.mousepressed = function(x, y, button)
	gui:mousepress(x, y, button)
end
love.mousereleased = function(x, y, button)
	gui:mouserelease(x, y, button)
end