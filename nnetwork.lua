if castle then
  cs = require("https://raw.githubusercontent.com/castle-games/share.lua/master/cs.lua")
else
  cs = require("cs")
end

network_t = 0
delay = 0
my_id = nil
connected = false

function init_network()
  if IS_SERVER then
    server.share[1] = {} -- timestamps
    
    server.share[2] = {} -- apples
    server.share[3] = {} -- snakes
  else

  end
end

function update_network()
  network_t = network_t - dt()
  if network_t > 0 then
    return
  end
  
  if IS_SERVER then
    server_output()
  else
    client_output()
  end
  
  network_t = 0.05
end



function client_input(diff)
  my_id = client.id
  
  if client.share[1] then
    local timestamp = client.share[1][client.id]
    if timestamp then
      delay = (t() - timestamp) / 2
      connected = true
    else
      return
    end
  else
    return
  end

  
  local apple_data = client.share[2]
  for id, apple in pairs(apples) do
    if not apple_data[id] then
      deregister_object(apple)
      apples[id] = nil
      
      if apple.pic then
        delete_surface(apple.pic)
      end
    end
  end
  
  for id, data in pairs(apple_data) do
    local apple = apples[id]
    if not apple then
      apple = create_apple(id, data[1], data[2], data[5])
    end
    
    if id ~= my_id then
      local nx = data[1] + delay * data[3]
      local ny = data[2] + delay * data[4]
    
      apple.diffx = apple.diffx + nx - apple.x
      apple.diffy = apple.diffy + ny - apple.y
    
      apple.x = nx
      apple.y = ny
      apple.vx = data[3]
      apple.vy = data[4]
      
      if not apple.dead and data[6] then
        apple_die(apple)
      elseif apple.dead and not data[6] then
        apple_resurrect(apple)
      end
    end
    
    if not apple.username then
      apple.username = data[7]
      if data[8] then
        network.async(function()
          apple.pic = load_png("avi"..id, data[8])
          love.graphics.setCanvas()
        end)
      end
    end
  end
  
  local snake_data = client.share[3]
  for id, data in pairs(snake_data) do
    local snake = snakes[id]
    if not snake then
      if data[6] then goto snek_done end
      snake = create_snake(id, data[1][1][1], data[1][1][2], data[8], data[4], data[5], data[7])
    end
    
--    for i,p_d in pairs(data[1]) do
--      local p = snake.parts[i]
--      if p then
--        p.x = p_d[1]
--        p.y = p_d[2]
--      end
--    end
    
--    if data[1][1] and snake.parts[1] then
--      snake.parts[1].x = data[1][1][1]
--      snake.parts[1].y = data[1][1][2]
--    end

    if data[1][1] then
      snake.diffx = snake.diffx + (data[1][1][1] - snake.x - snake.diffx)
      snake.diffy = snake.diffy + (data[1][1][2] - snake.y - snake.diffy)
    end
    
    if not snake.dead then
--      snake.x = snake.parts[1].x
--      snake.y = snake.parts[1].y
      snake.animt = data[3]
      
      local tid = tonumber(data[10])
      if tid then
        if apples[tid] then
          snake.target = apples[tid]
        end
      else
        snake.target = copy_table(data[10])
      end
      snake.target_t = data[9]
      snake.steer = data[11]
    end
    
    snake.a = data[2]
    
    if data[6] and not snake.dead then
      snake.dead = true
      snake.animt = 0
      add_shake(8)
    end
    
    ::snek_done::
  end
  
  local nlevel = client.share[4]
  if nlevel and nlevel > level then
    local my_apple = apples[my_id]
    if my_apple and my_apple.dead then
      apple_resurrect(my_apple)
    end
    level = nlevel
  end
end

function client_output()
--  if not (client and client.connected) then
--    return
--  end

  client.home[1] = t()
  
  local my_player = apples[client.id]

  if my_player then
    client.home[2] = my_player.x
    client.home[3] = my_player.y
    client.home[4] = my_player.vx
    client.home[5] = my_player.vy
    client.home[6] = my_player.dead
  else
    client.home[2] = nil
    client.home[3] = nil
    client.home[4] = nil
    client.home[5] = nil
    client.home[6] = nil
  end
  
  if not client.home[7] and castle and castle.user.isLoggedIn then
    local info = castle.user.getMe()
    if info then
      client.home[7] = info.name or info.username
      client.home[8] = info.photoUrl
    end
  end
end

function client_connect()
  log("Connected to server!")
  
  my_id = client.id
end

function client_disconnect()
  disconnected = true
  log("Disconnected from server!")
end


function server_input()
  for id,ho in pairs(server.homes) do
    local apple = apples[id]
    if not apple then
      apple = create_apple(id, 64, 64)
    end
    
    if ho[2] then
      apple.x = ho[2] + ho[4] * dt()
      apple.y = ho[3] + ho[5] * dt()
      apple.vx = ho[4]
      apple.vy = ho[5]
      apple.dead = ho[6]
      
      apple.username = ho[7]
      apple.pic = ho[8]
    end
  end
end

function server_output()
  for id,ho in pairs(server.homes) do
    server.share[1][id] = ho[1]
  
    local apple = apples[id]
    if apple then
      server.share[2][id] = {
        apple.x,
        apple.y,
        apple.vx,
        apple.vy,
        apple.color,
        apple.dead,
        apple.username,
        apple.pic
      }
    end
  end
  
  for id,s in pairs(server.share[3]) do
    if dead_snakes[id] then
      server.share[3][id] = nil
    end
  end
  
  for id,s in pairs(snakes) do
    server.share[3][id] = {
      {}, s.a, s.animt, s.ca, s.cb, s.dead, s.spd, #s.parts, s.target_t, s.target.id or s.target, s.steer
    }
    
    local p_d = server.share[3][id][1]
    for i = 1, #s.parts, 4 do
      local p = s.parts[i]
      if p then
        p_d[i] = { p.x, p.y }
      end
    end
    
    --for i,p in pairs(s.parts) do
    --  p_d[i] = {p.x, p.y}
    --end
  end
  
  server.share[4] = level
end

function server_new_client(id)
  log("New client: #"..id)

end

function server_lost_client(id)
  log("Client #"..id.." disconnected.")

  local apple = apples[id]
  if apple then
    remove_apple(apple)
    server.share[2][id] = nil
  end
end



-- look-up table

-- client.home = {
--   [1] = timestamp,
--   [2] = pos_x,
--   [3] = pos_y,
--   [4] = vx,
--   [5] = vy,
--   [6] = dead,
--   [7] = username,
--   [8] = pic_url
-- }


-- server.share = {
--   [1] = {
--     [user_id] = timestamp,
--     ...
--   }
--   [2] = { -- apples
--     [user_id] = {
--       [1] = x,
--       [2] = y,
--       [3] = vx,
--       [4] = vy,
--       [5] = color,
--       [6] = dead,
--       [7] = username,
--       [8] = pic
--     },
--     ...
--   }
--   [3] = { -- sneks
--     [snek_id] = {
--       [1] = { parts coordinates },
--       [2] = a,
--       [3] = animt,
--       [4] = ca,
--       [5] = cb,
--       [6] = dead,
--       [7] = spd,
--       [8] = part_count,
--       [9] = target_t,
--       [10] = target,
--       [11] = steer
--     },
--     ...
--   },
--   [4] = current_level
-- }



function start_client()
  client = cs.client
  
  if castle then
    client.useCastleConfig()
  else
    start_client = function()
      client.enabled = true
      client.start('127.0.0.1:22122') -- IP address ('127.0.0.1' is same computer) and port of server
      
      love.update, love.draw = client.update, client.draw
      client.load()
      
      ROLE = client
    end
  end
  
  client.changed = client_input
  client.connect = client_connect
  client.disconnect = client_disconnect
end

function start_server(max_clients)
  server = cs.server
  server.maxClients = max_clients
  
  if castle then
    server.useCastleConfig()
  else
    start_server = function()
      server.enabled = true
      server.start('22122') -- Port of server
      
      love.update = server.update
      server.load()
      
      ROLE = server
    end
  end
  
  server.changed = server_input
  server.connect = server_new_client
  server.disconnect = server_lost_client
end