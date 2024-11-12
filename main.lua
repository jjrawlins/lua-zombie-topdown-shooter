--package.path = package.path .. ";/opt/homebrew/Cellar/luarocks/3.11.1/share/lua/5.4/mobdebug.lua"
--require("mobdebug").start()

function love.load()
	math.randomseed(os.time())  -- Add this line at the start
	local width, height = love.window.getDesktopDimensions()
	love.window.setMode(width, height, {fullscreen = false})

	-- Add these lines to calculate scaling factors
	WINDOW_WIDTH = love.graphics.getWidth()
	WINDOW_HEIGHT = love.graphics.getHeight()

	-- Calculate scaling factors based on background image size
	sprites = {}
	sprites.background = love.graphics.newImage("background.png")
	scaleX = WINDOW_WIDTH / sprites.background:getWidth()
	scaleY = WINDOW_HEIGHT / sprites.background:getHeight()

	sprites.background = love.graphics.newImage("background.png")
	sprites.bullet = love.graphics.newImage("bullet.png")
	sprites.player = love.graphics.newImage("player.png")
	sprites.zombie = love.graphics.newImage("zombie.png")
	sprites.building = love.graphics.newImage("building.png")

	-- Initialize player
	player = {}
	player.x = (love.graphics.getWidth() / 2) - 50
	player.y = (love.graphics.getHeight() / 2) - 50
	player.speed = 180
	player.energy = 10
	player.invulnerable = false
	player.invulnerableTimer = 0

	-- Initialize game objects
	zombies = {}
	bullets = {}
	buildings = {}

	-- Setup buildings
	setupBuildings()

	-- Find valid spawn position for player
	setupPlayerPosition()

	-- Initialize game state
	gameState = "countdown"
	countdown = 3
	timer = countdown
	wave = 1
	zombiesToSpawn = 10
end

function setupBuildings()
	local numBuildings = 4
	local buildingSize = 100
	local attempts = 0
	local maxAttempts = 100
	local margin = 50  -- smaller margin from edges

	while #buildings < numBuildings and attempts < maxAttempts do
		local x = math.random(margin, love.graphics.getWidth() - buildingSize - margin)
		local y = math.random(margin, love.graphics.getHeight() - buildingSize - margin)

		-- Check if new building overlaps with existing buildings
		local canPlace = true
		for _, building in ipairs(buildings) do
			if checkCollision(
					x, y,
					buildingSize, buildingSize,
					building.x, building.y,
					building.width, building.height
			) then
				canPlace = false
				break
			end
		end

		-- Add minimum distance check between buildings
		if canPlace then
			for _, building in ipairs(buildings) do
				local distance = distanceBetween(
						x + buildingSize/2,
						y + buildingSize/2,
						building.x + building.width/2,
						building.y + building.height/2
				)
				if distance < buildingSize * 1.5 then  -- minimum spacing between buildings
					canPlace = false
					break
				end
			end
		end

		if canPlace then
			table.insert(buildings, {
				x = x,
				y = y,
				width = buildingSize,
				height = buildingSize
			})
		end

		attempts = attempts + 1
	end
end

function setupPlayerPosition()
	local validPosition = false
	while not validPosition do
		player.x = (love.graphics.getWidth() / 2) - 50
		player.y = (love.graphics.getHeight() / 2)

		validPosition = true
		for _, building in ipairs(buildings) do
			if checkCollision(
					player.x - sprites.player:getWidth()/2,
					player.y - sprites.player:getHeight()/2,
					sprites.player:getWidth(),
					sprites.player:getHeight(),
					building.x, building.y,
					building.width, building.height) then
				validPosition = false
				player.x = math.random(50, love.graphics.getWidth() - 50)
				player.y = math.random(50, love.graphics.getHeight() - 50)
				break
			end
		end
	end
end

function love.update(dt)
	if gameState == "countdown" then
		updateCountdown(dt)
	elseif gameState == "playing" then
		updatePlaying(dt)
	elseif gameState == "victory" then
		updateVictory(dt)
	end

	updatePlayer(dt)
	updateZombies(dt)
	updateBullets(dt)
	cleanupDeadObjects()
end

function updateCountdown(dt)
	timer = timer - dt
	if timer <= 0 then
		gameState = "playing"
		spawnWave()
	end
end

function updatePlaying(dt)
	if #zombies == 0 then
		gameState = "victory"
		timer = 3
	end

	if player.invulnerableTimer > 0 then
		player.invulnerableTimer = player.invulnerableTimer - dt
		if player.invulnerableTimer <= 0 then
			player.invulnerable = false
		end
	end

	checkPlayerZombieCollisions()
end

function updateVictory(dt)
	timer = timer - dt
	if timer <= 0 then
		wave = wave + 1
		zombiesToSpawn = zombiesToSpawn + 5
		gameState = "countdown"
		timer = countdown
		bullets = {}
	end
end

function updatePlayer(dt)
	-- Right movement
	if love.keyboard.isDown("right") then
		local nextX = player.x + player.speed * dt
		movePlayerIfValid(nextX, player.y)
	end

	-- Left movement
	if love.keyboard.isDown("left") then
		local nextX = player.x - player.speed * dt
		movePlayerIfValid(nextX, player.y)
	end

	-- Up movement
	if love.keyboard.isDown("up") then
		local nextY = player.y - player.speed * dt
		movePlayerIfValid(player.x, nextY)
	end

	-- Down movement
	if love.keyboard.isDown("down") then
		local nextY = player.y + player.speed * dt
		movePlayerIfValid(player.x, nextY)
	end
end

function movePlayerIfValid(nextX, nextY)
	local canMove = true
	for _, building in ipairs(buildings) do
		if checkCollision(
				nextX - sprites.player:getWidth()/2,
				nextY - sprites.player:getHeight()/2,
				sprites.player:getWidth(),
				sprites.player:getHeight(),
				building.x, building.y,
				building.width, building.height) then
			canMove = false
			break
		end
	end

	if canMove then
		player.x = nextX
		player.y = nextY
	end
end

function updateZombies(dt)
	for _, z in ipairs(zombies) do
		local angle = zombiePlayerAngle(z)
		local nextX = z.x + math.cos(angle) * z.speed * dt
		local nextY = z.y + math.sin(angle) * z.speed * dt

		local willCollide = false
		local collidingBuilding = nil

		for _, building in ipairs(buildings) do
			if checkCollision(
					nextX - z.width/2,
					nextY - z.height/2,
					z.width, z.height,
					building.x, building.y,
					building.width, building.height) then
				willCollide = true
				collidingBuilding = building
				break
			end
		end

		if willCollide then
			handleZombieBuildingCollision(z, collidingBuilding, dt)
		else
			handleZombieMovement(z, nextX, nextY)
		end
	end
end

function handleZombieBuildingCollision(zombie, building, dt)
	zombie.circlingBuilding = true
	zombie.currentBuilding = building

	local buildingCenterX = building.x + building.width/2
	local buildingCenterY = building.y + building.height/2
	local currentAngle = math.atan2(zombie.y - buildingCenterY, zombie.x - buildingCenterX)

	local circleSpeed = 2 * dt
	if zombie.circleDirection == "clockwise" then
		currentAngle = currentAngle - circleSpeed
	else
		currentAngle = currentAngle + circleSpeed
	end

	local radius = math.sqrt((building.width/2 + 30)^2 + (building.height/2 + 30)^2)
	zombie.x = buildingCenterX + math.cos(currentAngle) * radius
	zombie.y = buildingCenterY + math.sin(currentAngle) * radius
end

function handleZombieMovement(zombie, nextX, nextY)
	if zombie.circlingBuilding then
		local angleToPlayer = zombiePlayerAngle(zombie)
		local testX = zombie.x + math.cos(angleToPlayer) * 50
		local testY = zombie.y + math.sin(angleToPlayer) * 50

		local pathClear = true
		for _, building in ipairs(buildings) do
			if lineIntersectsBuilding(zombie.x, zombie.y, testX, testY, building) then
				pathClear = false
				break
			end
		end

		if pathClear then
			zombie.circlingBuilding = false
			zombie.currentBuilding = nil
		end
	end

	if not zombie.circlingBuilding then
		zombie.x = nextX
		zombie.y = nextY
	end
end

function updateBullets(dt)
	for _, b in ipairs(bullets) do
		local nextX = b.x + math.cos(b.direction) * b.speed * dt
		local nextY = b.y + math.sin(b.direction) * b.speed * dt

		local hitBuilding = false
		for _, building in ipairs(buildings) do
			if lineIntersectsBuilding(b.x, b.y, nextX, nextY, building) then
				hitBuilding = true
				b.dead = true
				break
			end
		end

		if not hitBuilding then
			b.x = nextX
			b.y = nextY

			for _, z in ipairs(zombies) do
				if distanceBetween(b.x, b.y, z.x, z.y) < (sprites.zombie:getWidth()/3) then
					b.dead = true
					z.dead = true
				end
			end
		end
	end
end

function checkPlayerZombieCollisions()
	for _, z in ipairs(zombies) do
		if not player.invulnerable and distanceBetween(z.x, z.y, player.x, player.y) < 30 then
			player.energy = player.energy - 1
			player.invulnerable = true
			player.invulnerableTimer = 1

			if player.energy <= 0 then
				resetGame()
			end
		end
	end
end

function resetGame()
	player.energy = 10
	gameState = "countdown"
	timer = countdown
	wave = 1
	zombiesToSpawn = 10
	bullets = {}
	zombies = {}
end

function cleanupDeadObjects()
	for i = #bullets, 1, -1 do
		if bullets[i].dead then
			table.remove(bullets, i)
		end
	end

	for i = #zombies, 1, -1 do
		if zombies[i].dead then
			table.remove(zombies, i)
		end
	end
end

function spawnZombie()
	local zombie = {}
	local validPosition = false
	local attempts = 0
	local maxAttempts = 100

	while not validPosition and attempts < maxAttempts do
		local side = math.random(1, 4)

		if side == 1 then -- top
			zombie.x = math.random(0, love.graphics.getWidth())
			zombie.y = -30
		elseif side == 2 then -- right
			zombie.x = love.graphics.getWidth() + 30
			zombie.y = math.random(0, love.graphics.getHeight())
		elseif side == 3 then -- bottom
			zombie.x = math.random(0, love.graphics.getWidth())
			zombie.y = love.graphics.getHeight() + 30
		else -- left
			zombie.x = -30
			zombie.y = math.random(0, love.graphics.getHeight())
		end

		zombie.speed = 100
		zombie.dead = false
		zombie.width = sprites.zombie:getWidth()
		zombie.height = sprites.zombie:getHeight()
		zombie.circlingBuilding = false
		zombie.circleDirection = math.random() < 0.5 and "clockwise" or "counterclockwise"
		zombie.currentBuilding = nil

		validPosition = true
		for _, building in ipairs(buildings) do
			if checkCollision(
					zombie.x - zombie.width/2,
					zombie.y - zombie.height/2,
					zombie.width, zombie.height,
					building.x, building.y,
					building.width, building.height) then
				validPosition = false
				break
			end
		end

		attempts = attempts + 1
	end

	if validPosition then
		table.insert(zombies, zombie)
	else
		spawnZombie()
	end
end

function spawnWave()
	zombies = {}
	for i = 1, zombiesToSpawn do
		spawnZombie()
	end
end

function shoot()
	local bullet = {}
	bullet.x = player.x
	bullet.y = player.y
	bullet.speed = 500
	bullet.direction = playerMouseAngle()
	bullet.dead = false
	table.insert(bullets, bullet)
end

function love.draw()
	drawBackground()
	drawBuildings()
	drawBullets()
	drawPlayer()
	drawZombies()
	drawUI()
end

function drawBackground()
    love.graphics.draw(sprites.background, 0, 0, 0, scaleX, scaleY)
end

function drawBuildings()
	for _, building in ipairs(buildings) do
		if sprites.building then
			local scaleX = 100 / sprites.building:getWidth()
			local scaleY = 100 / sprites.building:getHeight()
			love.graphics.draw(sprites.building, building.x, building.y, 0, scaleX, scaleY)
		else
			love.graphics.setColor(0.5, 0.5, 0.5)
			love.graphics.rectangle("fill", building.x, building.y, building.width, building.height)
			love.graphics.setColor(1, 1, 1)
		end
	end
end

function drawBullets()
	for _, b in ipairs(bullets) do
		love.graphics.draw(sprites.bullet, b.x, b.y, b.direction, 0.5, 0.5,
				sprites.bullet:getWidth()/2, sprites.bullet:getHeight()/2)
	end
end

function drawPlayer()
	love.graphics.draw(sprites.player, player.x, player.y, playerMouseAngle(), nil, nil,
			sprites.player:getWidth()/2, sprites.player:getHeight()/2)
end

function drawZombies()
	for _, z in ipairs(zombies) do
		love.graphics.draw(sprites.zombie, z.x, z.y, zombiePlayerAngle(z), 1, 1,
				sprites.zombie:getWidth()/2, sprites.zombie:getHeight()/2)
	end
end

function drawUI()
	love.graphics.setColor(1, 1, 1)
	if gameState == "countdown" then
		love.graphics.print("Wave " .. wave, 10, 10)
		love.graphics.printf("Starting in: " .. math.ceil(timer), 0,
				love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
	elseif gameState == "playing" then
		love.graphics.print("Wave " .. wave, 10, 10)
		love.graphics.print("Zombies left: " .. #zombies, 10, 30)
		love.graphics.print("Energy: " .. player.energy, 10, 50)
	elseif gameState == "victory" then
		love.graphics.printf("Wave Complete!", 0,
				love.graphics.getHeight()/2, love.graphics.getWidth(), "center")
	end
	love.graphics.setColor(1, 1, 1)
end

function love.mousepressed(x, y, button)
	if button == 1 then
		shoot()
	end
end

function distanceBetween(x1, y1, x2, y2)
	return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function playerMouseAngle()
	return math.atan2(player.y - love.mouse.getY(),
			player.x - love.mouse.getX()) + math.pi
end

function zombiePlayerAngle(zombie)
	return math.atan2(player.y - zombie.y, player.x - zombie.x)
end

function checkCollision(x1, y1, w1, h1, x2, y2, w2, h2)
	return x1 < x2 + w2 and
			x2 < x1 + w1 and
			y1 < y2 + h2 and
			y2 < y1 + h1
end

function lineIntersectsBuilding(x1, y1, x2, y2, building)
	local left = building.x
	local right = building.x + building.width
	local top = building.y
	local bottom = building.y + building.height

	local dx = x2 - x1
	local dy = y2 - y1

	local t1 = (left - x1) / dx
	local t2 = (right - x1) / dx
	local t3 = (top - y1) / dy
	local t4 = (bottom - y1) / dy

	local tMin = math.max(math.min(t1, t2), math.min(t3, t4))
	local tMax = math.min(math.max(t1, t2), math.max(t3, t4))

	return tMax >= 0 and tMin <= 1 and tMax >= tMin
end
