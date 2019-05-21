
require("nnetwork")
require("anim")
require("object")

apples = {}
snakes = {}

local body_colors = {}
local apple_colors = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
local drk = {[0]=0, 0, 1, 2, 3, 4, 7, 8, 9, 0, 15, 10, 13, 14, 10, 0}
local shkx, shky = 0, 0

-- CORE

function _init()
  init_object_mgr(
    "apples",
    "snakes"
  )

  load_anims()
  
  init_network()

  if not IS_SERVER then
    load_colors()
  end
  
  init_game()
end

function _update()
  update_game()
  
  update_network()
end

function _draw()
  draw_game()
end


-- GAME

function init_game()
  if IS_SERVER then
    --create_snake(nil, 64, 64, 32)
  else
    init_board()
  end
  
--  create_apple(64,64)
end

function update_game()
  update_shake()
  
  if IS_SERVER and group_size("snakes") == 0 then
    new_wave()
  end

  update_objects()
end

function draw_game()
  palt(0, false)
  palt(11, false)
  
  camera()
  
  cls()
--  for id, apple in pairs(apples) do
--    
--  end
  
  camera(shkx, shky)
  
  draw_board()
  
  palt(11, true)
  
  draw_objects()
  
  camera()
  
  draw_cursor()
end



-- UPDATES

function update_apple(s)
  s.animt = s.animt + dt()
  
  local acc = dt() * 15 * 30
  
  if s.id == my_id then
    if btn(4) or btn(5) then
      s.vx = s.vx + btnv(4) * acc
      s.vy = s.vy + btnv(5) * acc
    end
    
    if btn(8) then
      local mx, my = btnv(6), btnv(7)
      local a = atan2(mx - s.x, my - s.y)
      
      s.vx = s.vx + cos(a) * acc
      s.vy = s.vy + sin(a) * acc
    end
    
    if btn(0) then s.vx = s.vx - acc end
    if btn(1) then s.vx = s.vx + acc end
    if btn(2) then s.vy = s.vy - acc end
    if btn(3) then s.vy = s.vy + acc end
  end
  
  s.x = s.x + s.vx * dt()
  s.y = s.y + s.vy * dt()
  
  s.vx = lerp(s.vx, 0, dt() * 15)
  s.vy = lerp(s.vy, 0, dt() * 15)
  
  collide_borders(s)
  
  local nstate
  if abs(s.vx) + abs(s.vy) > 0.1 then
    nstate = "run"
  else
    nstate = "idle"
  end
  
  if nstate ~= s.state then
    s.state = nstate
    s.animt = 0
  end
end

function update_snake(s)
  if s.dead then
    s.animt = s.animt + dt()
    
    local k = flr(s.animt/0.15)
    local n = 0
    for i,p in pairs(s.parts) do
      if i < k then
        s.parts[i] = nil
        local a = s.animt
        local k = 3
        for i = 1,k do
          create_star(p.x, p.y, a+i/k)
        end
      else
        n = n + 1
      end
    end
    
    if n == 0 then
      add_shake(4)
      deregister_object(s)
    end
    
    return
  end

  local md, target = 99999
  for a in group("apples") do
    local nd = sqrdist(a.x - s.x, a.y - s.y)
    if nd < md then
      target = a
      md = nd
    end
  end
  
  if not target then
    return
  end
  
  local target_a = atan2(target.x - s.x, target.y - s.y)
  local diff_a = angle_diff(s.a, target_a)
  
  s.a = s.a + dt() * diff_a
  
  local wave = 0.1 * cos(t()/2)
  s.x = s.x + s.spd * cos(s.a + wave) * dt()
  s.y = s.y + s.spd * sin(s.a + wave) * dt()
  
  if collide_borders(s) then
    -- snek dies
    s.dead = true
    s.animt = 0
    add_shake(8)
  end
  
  s.parts[1].x = s.x
  s.parts[1].y = s.y
  
  for i = 2, #s.parts do
    local part = s.parts[i]
    local prev = s.parts[i-1]
    
    local d = dist(prev.x, prev.y, part.x, part.y)
    local md = 2
    if d > md then
      part.x = lerp(part.x, prev.x, 1-md/d)
      part.y = lerp(part.y, prev.y, 1-md/d)
    end
  end
end

function collide_borders(s)
  local bw = 256
  local bh = 160

  local col
  if s.x-s.w/2 < 8 then
    s.x = 8+s.w/2
    col = true
  end
  
  if s.y-s.h/2 < 22 then
    s.y = 22 + s.h/2
    col = true
  end
  
  if s.x+s.w/2 >= bw-8 then
    s.x = bw-8-s.w/2-0.1
    col = true
  end
  
  if s.y+s.h/2 >= bh-6 then
    s.y = bh-6-s.h/2-0.1
    col = true
  end
  
  return col
end

function update_star(s)
  s.animt = s.animt + dt()
  
  local a,b,c = anim_step("star", s.anim, s.animt)
  if c > 0 then
    deregister_object(s)
    return
  end
  
  s.x = s.x + s.vx * dt()
  s.y = s.y + s.vy * dt()
  
  s.vx = lerp(s.vx, 0, 7*dt())
  s.vy = lerp(s.vy, 0, 7*dt())
end


-- DRAWS

function draw_apple(s)
  local plt = body_colors[s.color]
  
--  plt = {}
  
  pal(1, plt[1])
  pal(2, plt[2])
  pal(3, plt[3])
  draw_self(s)
  pal(1, 1)
  pal(2, 2)
  pal(3, 3)
end

function draw_snake(s)
  if s.dead then
    pal(0, 5)
    for _,p in pairs(s.parts) do
      spr(p.s + 8, p.x - 8 + irnd(2), p.y - 8 + irnd(2), 2, 2)
    end
    pal(0, 0)
    return
  end
  
  local ti = t()
  
  if ti%4 < 0.25 or ti%7 < 0.25 or ti%13 < 0.25 then
    local v = cos(0.75 + t() * 2)
    aspr(96, s.x, s.y, s.a, 1, 1, 0.5-v, 3.5/8)
    
    if t()%1 < dt() then
      --sfx("snek")
    end
  end
  
  local plta = body_colors[s.ca]
  local pltb = body_colors[s.cb]
  
  pal(14, drk[plta[1]])
  pal(13, plta[1])
  pal(12, plta[2])
  pal(5,  plta[3])
  pal(1,  pltb[1])
  pal(2,  pltb[2])
  pal(3,  pltb[3])
  
  for _,p in pairs(s.parts) do
    spr(p.s + 8, p.x - 8, p.y - 8, 2, 2)
  end
  
  for i = #s.parts, 1, -1 do
    local p = s.parts[i]
    spr(p.s, p.x - 8, p.y - 8, 2, 2)
  end
  
  aspr(97, s.x, s.y, s.a, 1, 1, 0.4)
  
  pal(14, 14)
  pal(13, 13)
  pal(12, 12)
  pal(5,  5)
  pal(1,  1)
  pal(2,  2)
  pal(3,  3)
end

function draw_star(s)
  draw_anim(s.x, s.y, "star", s.anim, s.animt)
end


-- CREATES

function create_apple(id, x, y, color)
  local s  = {
    id     = id,
    x      = x,
    y      = y,
    w      = 6,
    h      = 6,
    vx     = 0,
    vy     = 0,
    name   = "apple",
    state  = "idle",
    animt  = rnd(1),
    update = update_apple,
    draw   = draw_apple,
    regs   = {"to_update", "to_draw1", "apples"}
  }
  
  if color then
    s.color = color
  else
    s.color = pick(apple_colors)
    del(apple_colors, s.color)
  end

  apples[id] = s
  
  register_object(s)
  
  log("Created apple!")
  
  return s
end

local snake_id = 1
function create_snake(id, x, y, n, ca, cb)
  local s = {
    id     = id,
    x      = x,
    y      = y,
    w      = 8,
    h      = 8,
    parts  = {},
    a      = rnd(1),
    spd    = 25,
    animt  = 0,
    ca     = ca or irnd(10)+1,
    cb     = cb or irnd(10)+1,
    update = update_snake,
    draw   = draw_snake,
    regs   = {"to_update", "to_draw2", "snakes"}
  }
  
  if not id then
    for i = 1,n do
      local l = 2+i*0.5
      local a = s.a + 0.5 + i*0.1
      add(s.parts, {
        x = x + l * cos(a),
        y = y + l * sin(a)
      })
    end
  else
    for i = 1,n do
      add(s.parts, {x = x, y = y})
    end
  end
  
  for i,p in pairs(s.parts) do
    if i == 1 then
      p.s = 64
    elseif i >= n-2 then
      p.s = 70
    elseif i >= n-4 then
      p.s = 68
    else
      p.s = 66
    end
  end
  
  if not id then
    s.id = snake_id
    snake_id = snake_id + 1
  else
    snake_id = id + 1
  end
  
  snakes[s.id] = s
  
  register_object(s)
  
  return s
end

function create_star(x,y,a,spd)
  spd = spd or 100+rnd(50)
  
  local s = {
    x      = x,
    y      = y,
    vx     = spd*cos(a),
    vy     = spd*sin(a),
    animt  = rnd(0.2),
    anim   = pick{"a", "b"},
    update = update_star,
    draw   = draw_star,
    regs   = {"to_update", "to_draw4"}
  }
  
  register_object(s)
  
  return s
end

-- DESTROYS

function remove_apple(s)
  add(apple_colors, s.color)

  deregister_object(s)
  apples[s.id] = nil
end


-- BOARD

function init_board()
  -- initializing the board tables with a sprite id for each tile, to draw on draw_table().
  
  board_w = screen_w()/8
  board_h = screen_h()/8-2

  board = {}
  for i = 0, board_h-1 do
    board[i] = {}
  end
  
  for i = 1, board_h-2 do
    for j = 1, board_w-2 do
      if rnd(8) > 1 then
        board[i][j] = irnd(4)
      else
        board[i][j] = irnd(10)
      end
    end
    
    board[i][0] = 18
    board[i][board_w-1] = 19
  end
  
  for i = 1,board_w-2 do
    board[0][i] = 16
    board[board_h-1][i] = 17
  end
  
  board[0][0] = 20
  board[0][board_w-1] = 21
  board[board_h-1][0] = 22
  board[board_h-1][board_w-1] = 23
end

function draw_board()
  for y,l in pairs(board) do
    for x,v in pairs(l) do
      spr(v, x*8, y*8 + 16)
    end
  end
end

function draw_bottomfence()
  for i = 1, 14 do
    spr(24, i*8, 120)
  end
end


-- MISC UPDATE

function new_wave()
  create_snake(nil, 64+rnd(128), 16+36+rnd(72), 24+irnd(16))
end

function add_shake(p)
  local a = rnd(1)
  shkx = shkx + p * cos(a)
  shky = shky + p * sin(a)
end

local shkt = 0
function update_shake()
  shkt = shkt - dt()
  if shkt <= 0 then
    if abs(shkx)+abs(shky) < 0.5 then
      shkx, shky = 0, 0
    else
      shkx = - (0.5 + rnd(0.2)) * shkx
      shky = - (0.5 + rnd(0.2)) * shky
    end
    
    shkt = 0.03
  end
end


-- MISC DRAW

function draw_cursor()
  palt(11, false)
  palt(12, true)
  local mx, my = btnv(6), btnv(7)
  if btn(8) then
    spr(99, mx, my, 1, 2)
  else
    spr(98, mx, my, 1, 2)
  end
  palt(12, false)
end


-- MISC INIT

function load_assets()
  load_png("spritesheet", "assets/sheet.png", nil, true)
  
--  load_sfx("assets/jump.wav", "jump", 1)
--  load_sfx("assets/snake.wav", "snek", 0.5)
end

function load_colors()
--  body_colors = {}
  for i = 1,10 do
    local column = {}
    for j = 1,3 do
      column[j] = sget(i-1, 64+j)
    end
    body_colors[i] = column
  end
end

function define_controls()
  player_assign_ctrlr(0, 0)

  register_btn(0, 0, {input_id("keyboard", "left"),
                      input_id("keyboard", "a"),
                      input_id("controller_button", "dpleft")})
  register_btn(1, 0, {input_id("keyboard", "right"),
                      input_id("keyboard", "d"),
                      input_id("controller_button", "dpright")})
  register_btn(2, 0, {input_id("keyboard", "up"),
                      input_id("keyboard", "w"),
                      input_id("controller_button", "dpup")})
  register_btn(3, 0, {input_id("keyboard", "down"),
                      input_id("keyboard", "s"),
                      input_id("controller_button", "dpdown")})
  
  register_btn(4, 0, input_id("controller_axis", "leftx"))
  register_btn(5, 0, input_id("controller_axis", "lefty"))
  
  register_btn(6, 0, input_id("mouse_position", "x"))
  register_btn(7, 0, input_id("mouse_position", "y"))
  register_btn(8, 0, input_id("mouse_button", "lb"))
end

function load_anims()
  local info = {
    apple = {
      idle = {
--        sheet = "sprites",
        dt = 0.06,
        sprites = {32, 32, 32, 32, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 32, 32, 32, 32},
        w = 2,
        h = 2
      },
      run = {
--        sheet = "sprites",
        dt = 0.06,
        sprites = {34, 36, 38, 40, 42},
        w = 2,
        h = 2
      },
    },
    star = {
      a = {
        dt = 0.07,
        sprites = {100, 100, 100, 100, 100, 100, 100, 100, 101, 102, 103, 104, 105}
      },
      b = {
        dt = 0.07,
        sprites = {100, 100, 100, 100, 100, 100, 100, 100, 101, 102, 107, 108, 109, 110}
      }
    }
  }
  
  init_anims(info)
end