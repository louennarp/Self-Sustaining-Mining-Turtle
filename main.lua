local endStragePos = 16
local toolPos = 15


local unloaded = 0
local collected = 0

local depth = 0
local xPos,zPos = 0,0
local xDir,zDir = 1,0

local fuelLowLimit, fuelHightLimit = 1000, 3000

local goTo -- Filled in further down
local refuel -- Filled in further down

local function local_to_global (bX, bY, bZ)
  local x, y, z
  y = depth - bY
  x = xPos + bZ * xDir - bX * zDir
  z = zPos + bZ * zDir + bX *  xDir
  return x, y, z
end

local function scan(n)
  local initSlot = turtle.getSelectedSlot()
  turtle.select(toolPos)
  turtle.equipLeft()

  local geoscanner = peripheral.find("geoScanner")
  local scan = geoscanner.scan(10)
  turtle.equipLeft()
  turtle.select(initSlot)

  for block_data_index in pairs(scan) do
    scan[block_data_index].x, scan[block_data_index].y, scan[block_data_index].z = local_to_global(scan[block_data_index].x, scan[block_data_index].y, scan[block_data_index].z)
  end
  return scan
end

function selectCoal (scan)
  coals = {}
  for block_data in pairs(scan) do
    if block_data.name == "minecraft:coal_ore" or block_data.name == "minecraft:deepslate_coal_ore" then
      print("Coal found at:", block_data.x, block_data.y, block_data.z)
      table.insert(coals, {block_data})
    end
  end
  return coals
end

function elementIndexInArray (array, element)
  for i, e in ipairs(array) do
    if e == element then
      return i
    end
  end
  return nil --element not found
end

function selectOres (scan)
  oreTypes = {}
  ores = {}
  for i, block_data in ipairs(scan) do
    if string.find(block_data.name, "ore") ~= nil then
      local oreType = elementIndexInArray(oreTypes, block_data.name)
      if oreType == nil then
        table.insert(oreTypes, block_data.name)
        table.insert(ores, {})
        print(block_data.name, "found at:", block_data.x, block_data.y, block_data.z)
      else
        table.insert(ores[oreType], block_data)
      end
    end
  end
  return ores
end

local function unload( _bKeepOneFuelStack )
	print( "Unloading items..." )
  turtle.select(endStragePos)
  turtle.placeUp()
	for n=1,14 do
		local nCount = turtle.getItemCount(n)
		if nCount > 0 then
			turtle.select(n)
			local bDrop = true
			if _bKeepOneFuelStack and turtle.refuel(0) then
				bDrop = false
				_bKeepOneFuelStack = false
			end
			if bDrop then
				turtle.dropUp()
				unloaded = unloaded + nCount
			end
		end
	end
	collected = 0
	turtle.select(1)
end

local function returnSupplies()
	print( "Full, Unloading ... " )
	if not refuel(fuelLowLimit) then
		unload(true)
		print("Not enough fuel")
	else
		unload( true )
	end
	print( "Resuming mining..." )
end

local function collect()
	local bFull = true
	local nTotalItems = 0
	for n=1,16 do
		local nCount = turtle.getItemCount(n)
		if nCount == 0 then
			bFull = false
		end
		nTotalItems = nTotalItems + nCount
	end

	if nTotalItems > collected then
		collected = nTotalItems
		if math.fmod(collected + unloaded, 50) == 0 then
			local fuelLevel = turtle.getFuelLevel()
			local fuelLimit = turtle.getFuelLimit()
			if fuelLevel == "unlimited" then
				print( "Mined "..(collected + unloaded).." items.")
      else
        local fuelPercentage = math.floor(fuelLevel/fuelLimit*100+0.5)
  			print( "Mined "..(collected + unloaded).." items. ["..(fuelPercentage).."% fuel]")
			end

		end
	end

	if bFull then
		print( "No empty slots left." )
		return false
	end
	return true
end

function refuel(ammount)
	local fuelLevel = turtle.getFuelLevel()
	if fuelLevel == "unlimited" then
		return true
	end

	local needed = ammount
	if turtle.getFuelLevel() < needed then
		for n=1,16 do
			if turtle.getItemCount(n) > 0 then
				turtle.select(n)
				if turtle.refuel(1) then
					while turtle.getItemCount(n) > 0 and turtle.getFuelLevel() < needed do
						turtle.refuel(1)
					end
					if turtle.getFuelLevel() >= needed then
						turtle.select(1)
						return true
					end
				end
			end
		end
		turtle.select(1)
		return false
	end

	return true
end

local function tryForwards()
	if not refuel() then
		print( "Not enough Fuel" )
		returnSupplies()
	end

	while not turtle.forward() do
		if turtle.detect() then
			if turtle.dig() then
				if not collect() then
					returnSupplies()
				end
			else
				return false
			end
		elseif turtle.attack() then
			if not collect() then
				returnSupplies()
			end
		else
			sleep( 0.5 )
		end
	end

	xPos = xPos + xDir
	zPos = zPos + zDir

	if turtle.digUp() then
		if not collect() then
			returnSupplies()
		end
	end

	if turtle.digDown() then
		if not collect() then
			returnSupplies()
		end
	end
	return true
end

local function turnLeft()
	turtle.turnLeft()
	xDir, zDir = -zDir, xDir
end

local function turnRight()
	turtle.turnRight()
	xDir, zDir = zDir, -xDir
end

function goTo( x, y, z, xd, zd )
	while depth > y do
		if turtle.up() then
			depth = depth - 1
		elseif turtle.digUp() or turtle.attackUp() then
      if not collect() then
				returnSupplies()
			end
		else
			sleep( 0.5 )
		end
	end

	if xPos > x then
		while xDir ~= -1 do
			turnLeft()
		end
		while xPos > x do
			if turtle.forward() then
				xPos = xPos - 1
			elseif turtle.dig() or turtle.attack() then
        if not collect() then
  				returnSupplies()
  			end
			else
				sleep( 0.5 )
			end
		end
	elseif xPos < x then
		while xDir ~= 1 do
			turnLeft()
		end
		while xPos < x do
			if turtle.forward() then
				xPos = xPos + 1
			elseif turtle.dig() or turtle.attack() then
        if not collect() then
  				returnSupplies()
  			end
			else
				sleep( 0.5 )
			end
		end
	end

	if zPos > z then
		while zDir ~= -1 do
			turnLeft()
		end
		while zPos > z do
			if turtle.forward() then
				zPos = zPos - 1
			elseif turtle.dig() or turtle.attack() then
        if not collect() then
  				returnSupplies()
  			end
			else
				sleep( 0.5 )
			end
		end
	elseif zPos < z then
		while zDir ~= 1 do
			turnLeft()
		end
		while zPos < z do
			if turtle.forward() then
				zPos = zPos + 1
			elseif turtle.dig() or turtle.attack() then
        if not collect() then
  				returnSupplies()
  			end
			else
				sleep( 0.5 )
			end
		end
	end

	while depth < y do
		if turtle.down() then
			depth = depth + 1
		elseif turtle.digDown() or turtle.attackDown() then
      if not collect() then
				returnSupplies()
			end
		else
			sleep( 0.5 )
		end
	end
  if zd ~= nil and xd ~= nil then
  	while zDir ~= zd or xDir ~= xd do
  		turnLeft()
  	end
  end
end

function goMineBlocks(blocks)
  for Types in pairs(blocks) do
    for block_data in pairs(Types) do
      print(block_data.name, " >>> ", block_data.x, block_data.y, block_data.z)
      goTo(block_data.x, block_data.y, block_data.z)
    end
  end
end

function main()
  if not refuel(fuelHightLimit) then
  	print( "Out of Fuel" )
  	return
  end

  print( "Excavating..." )
  done = false
  while not done do
    local s = scan(10)
    if not refuel(fuelHightLimit) then
      goMineBlocks(selectCoal(s))
    else
      goMineBlocks(selectOres(s))
    end
  end
end

main()
