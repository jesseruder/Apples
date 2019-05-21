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
    end
  end
  
  for id, data in pairs(apple_data) do
    local apple = apples[id]
    if not apple then
      apple = create_apple(id, data[1], data[2], data[5])
    end
    
    if id ~= my_id then
      apple.x = data[1] + delay * data[3]
      apple.y = data[2] + delay * data[4]
      apple.vx = data[3]
      apple.vy = data[4]
    end
  end
  
  local snake_data = client.share[3]
  for id, data in pairs(snake_data) do
    local snake = snakes[id]
    if not snake then
      snake = create_snake(id, data[1][1][1], data[1][1][2], #data[1], data[4], data[5])
    end
    
    for i,p_d in pairs(data[1]) do
      local p = snake.parts[i]
      if p then
        p.x = p_d[1]
        p.y = p_d[2]
      end
    end
    
    snake.a = data[2]
    snake.animt = data[3]
    
    if data[6] and not snake.dead then
      snake.dead = true
      add_shake(8)
    end
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
  else
    client.home[2] = nil
    client.home[3] = nil
    client.home[4] = nil
    client.home[5] = nil
  end
end

function client_connect()
  log("Connected to server!")
  
  my_id = client.id
end

function client_disconnect()
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
        apple.color
      }
    end
  end
  
  for id,s in pairs(snakes) do
    server.share[3][id] = {
      {}, s.a, s.animt, s.ca, s.cb, s.dead
    }
    
    local p_d = server.share[3][id][1]
    for i,p in pairs(s.parts) do
      p_d[i] = {p.x, p.y}
    end
  end
end

function server_new_client(id)
  log("New client: #"..id)

end

function server_lost_client(id)
  log("Client #"..id.." disconnected.")

  local apple = apples[id]
  if apple then
    deregister_object(apple)
    apples[id] = nil
    server.share[2][id] = nil
  end
end



-- look-up table

-- client.home = {
--   
-- }


-- server.share = {
--
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
  
  if USE_CASTLE_CONFIG then
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