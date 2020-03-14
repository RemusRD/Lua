local component = require('component')
local computer = require('computer')
local quads = {{-7, -7}, {-7, 1}, {1, -7}, {1, 1}}

local function add_component(name)
    name = component.list(name)()
    if name then
        return component.proxy(name)
    end
end

local controller = add_component('inventory_controller')
local chunkloader = add_component('chunkloader')
local geolyzer = add_component('geolyzer')
local robot = add_component('robot')
local inventory = robot.inventorySize()

local min, max = 2.2, 40
local WORLD = {x = {}, y = {}, z = {}}
local X, Y, Z, D, border = 0, 0, 0, 0
local E_C, W_R = 0, 0 -- energy consumption and tool durability
local quads = {{-7, -7}, {-7, 1}, {1, -7}, {1, 1}}
local workbench = {1,2,3,5,6,7,9,10,11}
local wlist = {'enderstorage:ender_storage'}
local fragments = {'redstone','coal','dye','diamond','emerald'}
local tails = {'cobblestone','granite','diorite','andesite','marble','limestone','dirt','gravel','sand','stained_hardened_clay','sandstone','stone','grass','end_stone','hardened_clay','mossy_cobblestone','planks','fence','torch','nether_brick','nether_brick_fence','nether_brick_stairs','netherrack','soul_sand'}

scan = function(xx, zz)
    local raw = geolyzer.scan(xx, zz, -1, 8, 8, 1)
    local index = 1
    for z = zz, zz + 7 do
        for x = xx, xx + 7 do
            if isMinable(raw, index) then
                table.insert(WORLD.x, X + x)
                table.insert(WORLD.y, Y - 1)
                table.insert(WORLD.z, Z + z)
            elseif raw[index] < -0.31 then
                border = Y
            end
            index = index + 1
        end
    end
end

function isMinable(table, index)
    return table[index] >= min and table[index] <= max
end

main = function()
    border = nil
    while not border do
        step(0)
        for q = 1, 4 do scan(table.unpack(quads[q])) end -- size instead of hardcoded?
        check(true)
    end
    while #WORLD.x ~= 0 do
        local n_delta, c_delta, current = math.huge, math.huge
        for index = 1, #WORLD.x do
            n_delta = math.abs(X - WORLD.x[index]) +
                          math.abs(Y - WORLD.y[index]) +
                          math.abs(Z - WORLD.z[index]) - border + WORLD.y[index]
            if (WORLD.x[index] > X and D ~= 3) or
                (WORLD.x[index] < X and D ~= 1) or
                (WORLD.z[index] > Z and D ~= 0) or
                (WORLD.z[index] < Z and D ~= 2) then
                n_delta = n_delta + 1
            end
            if n_delta < c_delta then
                c_delta, current = n_delta, index
            end
        end
        if WORLD.x[current] == X and WORLD.y[current] == Y and WORLD.z[current] ==
            Z then
            remove_point(current)
        else
            local yc = WORLD.y[current]
            if yc - 1 > Y then
                yc = yc - 1
            elseif yc + 1 < Y then
                yc = yc + 1
            end
            go(WORLD.x[current], yc, WORLD.z[current])
        end
    end
    sorter()
end


step = function(side, ignore) 
    local result, obstacle = robot.swing(side) 
    if not result and obstacle ~= 'air' and robot.detect(side) then 
      home(true) 
    else
      while robot.swing(side) do end
    end
    if robot.move(side) then 
      steps = steps + 1 
      if side == 0 then
        Y = Y-1
      elseif side == 1 then
        Y = Y+1
      elseif side == 3 then
        if D == 0 then
          Z = Z+1
        elseif D == 1 then
          X = X-1
        elseif D == 2 then
          Z = Z-1
        else
          X = X+1
        end
      end
    end
    if not ignore then
      check()
    end
  end
  turn = function(side)
    side = side or false
    if robot.turn(side) and D then 
      turns = turns+1 
      if side then
        D = (D+1)%4
      else
        D = (D-1)%4
      end
      check()
    end
  end


  check = function(force) 
    if not ignore_check and (steps%32 == 0 or force) then 
      inv_check()
    end 
    if #WORLD.x ~= 0 then 
      for i = 1, #WORLD.x do
        if WORLD.y[i] == Y and ((WORLD.x[i] == X and ((WORLD.z[i] == Z+1 and D == 0) or (WORLD.z[i] == Z-1 and D == 2))) or (WORLD.z[i] == Z and ((WORLD.x[i] == X+1 and D == 3) or (WORLD.x[i] == X-1 and D == 1)))) then
          robot.swing(3)
          remove_point(i)
        end
        if X == WORLD.x[i] and (Y-1 <= WORLD.y[i] and Y+1 >= WORLD.y[i]) and Z == WORLD.z[i] then
          if WORLD.y[i] == Y+1 then 
            robot.swing(1)
          elseif WORLD.y[i] == Y-1 then 
            robot.swing(0)
          end
          remove_point(i)
        end
      end
    end
  end

  remove_point = function(point) 
    table.remove(WORLD.x, point)
    table.remove(WORLD.y, point)
    table.remove(WORLD.z, point)
  end

  inv_check = function() 
    local items = 0
    for slot = 1, inventory do
      if robot.count(slot) > 0 then
        items = items + 1
      end
    end
    if inventory-items < 10 or items/inventory > 0.9 then
      while robot.suck(1) do end
      -- leave items in ender chest
    end
  end

  home = function(forcibly, interrupt)
    local x, y, z, d
    print('ore unloading')
    ignore_check = true
    local enderchest 
    for slot = 1, inventory do 
      local item = controller.getStackInInternalSlot(slot)
      if item then 
        if item.name == 'enderstorage:ender_storage' then
          enderchest = slot 
          break --
        end
      end
    end
    if enderchest and not forcibly then 
      robot.swing(3) 
      robot.select(enderchest) 
      robot.place(3) 
    else
      x, y, z, d = X, Y, Z, D
      go(0, -2, 0)
      go(0, 0, 0)
    end
    sorter() 
    local size = nil
    while true do 
      for side = 1, 4 do
        size = controller.getInventorySize(3)
        if size and size>26 then
          break 
        end
        turn()
      end
      if not size or size<26 then 
        print('container not found') 
        sleep(30)
      else
        break
      end
    end
    for slot = 1, inventory do
      local item = controller.getStackInInternalSlot(slot)
      if item then
        if not wlist[item.name] then 
          robot.select(slot) 
          local a, b = robot.drop(3)
          if not a and b == 'inventory full' then
            while not robot.drop(3) do 
              print(b) 
              sleep(30) 
            end
          end
        end
      end
    end
      sorter(true) 
      for slot = 1, inventory do
        local item = controller.getStackInInternalSlot(slot)
        if item then 
          if not wlist[item.name] then 
            robot.select(slot)
            robot.drop(3)
          end
        end
      end
    end
  
    if enderchest and not forcibly then
      robot.swing(3) 
    else
      if energy_level() < 0.98 then
        print('need charging')
        sleep(30)
      end
    end
    ignore_check = nil
    if not interrupt then
      print('return to work')
      go(0, -2, 0)
      go(x, y, z)
      smart_turn(d)
    end
  
  main = function()
    border = nil
    while not border do
      step(0)
      for q = 1, 4 do
        scan(table.unpack(quads[q]))
      end
      check(true)
    end
    while #WORLD.x ~= 0 do
      local n_delta, c_delta, current = math.huge, math.huge
      for index = 1, #WORLD.x do
        n_delta = math.abs(X-WORLD.x[index])+math.abs(Y-WORLD.y[index])+math.abs(Z-WORLD.z[index])-border+WORLD.y[index]
        if (WORLD.x[index] > X and D ~= 3) or
        (WORLD.x[index] < X and D ~= 1) or
        (WORLD.z[index] > Z and D ~= 0) or
        (WORLD.z[index] < Z and D ~= 2) then
          n_delta = n_delta + 1
        end
        if n_delta < c_delta then
          c_delta, current = n_delta, index
        end
      end
      if WORLD.x[current] == X and WORLD.y[current] == Y and WORLD.z[current] == Z then
        remove_point(current)
      else
        local yc = WORLD.y[current]
        if yc-1 > Y then
          yc = yc-1
        elseif yc+1 < Y then
          yc = yc+1
        end
        go(WORLD.x[current], yc, WORLD.z[current])
      end
    end
    sorter()
  end

  smart_turn = function(side) 
    while D ~= side do
      turn((side-D)%4==1)
    end
  end

go = function(x, y, z)
  if border and y < border then
    y = border
  end
  while Y ~= y do
    if Y < y then
      step(1)
    elseif Y > y then
      step(0)
    end
  end
  if X < x then
    smart_turn(3)
  elseif X > x then
    smart_turn(1)
  end
  while X ~= x do
    step(3)
  end
  if Z < z then
    smart_turn(0)
  elseif Z > z then
    smart_turn(2)
  end
  while Z ~= z do
    step(3)
  end
end
sleep = function(timeout)
  local deadline = computer.uptime()+timeout
  repeat
    computer.pullSignal(deadline-computer.uptime())
  until computer.uptime() >= deadline
end

energy_level = function()
  return computer.energy()/computer.maxEnergy()
end

sorter = function(pack)
  robot.swing(0)
  robot.swing(1)
  local empty, available = 0, {}
  for slot = 1, inventory do 
    local item = controller.getStackInInternalSlot(slot)
    if item then
      local name = item.name:gsub('%g+:', '')
      if tails[name] then 
        robot.select(slot) 
        robot.drop(0)
        empty = empty + 1
      elseif fragments[name] then 
        if available[name] then
          available[name] = available[name] + item.size
        else
          available[name] = item.size
        end
      end
    else
      empty = empty + 1
    end
  end
  while robot.suck(1) do end
  inv_check()
end
