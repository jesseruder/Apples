
require("object")

-- CORE

function init_game()
  init_object_mgr(
    "apples",
    "snakes"
  )

  init_network()

  init_board()
  
  apple = create_apple()
  snake = create_snake()
  
  log("Game initialized.")
end

function update_game()
  if IS_SERVER then return end

--  update_objects()
  update_apple(apple)
  update_snake(snake)
  
  update_network()
end

function draw_game()
--  camera(0,0)

  palt(0, false) -- 0 is not the transparent color here
  
  cls(0)
  
  palt(11, false) -- the board tiles use that color
  
  draw_board()
  
  palt(11, true) -- the other sprites use that color for transparency
  
  --draw_objects()
  draw_apple(apple)
  --draw_snake(snake)
  
  draw_bottomfence()

  
  rectfill(0, 0, 127, 15, 0)
  
  local str = "chillin' with snek"
--  print(str, 1, 2, 11)
--  print(str, 1, 1, 5)

  local x, y = 1, 0
  for i = 1, #str do
    local ch = str:sub(i, i)
    local yy = y + 3 * cos(i/24.5 - t() * 0.25)
    
    print(ch, x-1, yy+1, 10)
    print(ch, x, yy+1, 11)
    print(ch, x-1, yy, 11)
    print(ch, x, yy, 5)
    
    x = x + str_px_width(ch)
  end
  
  -- drawing mouse cursor
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


-- UPDATES

function update_apple(s)
  local acc = dt() * 15 * 30
  
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
  
  s.x = s.x + s.vx * dt()
  s.y = s.y + s.vy * dt()
  
  s.vx = lerp(s.vx, 0, dt() * 15)
  s.vy = lerp(s.vy, 0, dt() * 15)
  
  -- controlling game space borders
  local hw, hh = 4, 1
  if s.x - hw < 8   then s.x = 8 + hw   end
  if s.x + hw > 120 then s.x = 120 - hw end
  if s.y - hh < 24  then s.y = 24 + hh  end
  if s.y + hh > 120 then s.y = 120 - hh end
  
  s.t = s.t + dt()
end

function update_snake(s)
  -- getting the closest apple
  local apple
  local sd = 99999
  for a in group("apples") do
    local nd = sqrdist(a.x - s.x, a.y - s.y)
    if nd < sd then
      apple = a
      sd = nd
    end
  end
  
  if not apple then
    apple = { x = 64, y = 64 }
  end

  -- moving towards apple
  local target_a = atan2(apple.x - s.x, apple.y - s.y)
  local diff_a = angle_diff(s.a, target_a)
  
  s.a = s.a + 1 * dt() * diff_a
  
  local wave = 0.1 * cos(t()/2)
  s.x = s.x + s.spd * cos(s.a + wave) * dt()
  s.y = s.y + s.spd * sin(s.a + wave) * dt()
  
  -- controlling game space borders
  local hw, hh = 3, 0
  if s.x - hw < 8   then s.x = 8 + hw   end
  if s.x + hw > 120 then s.x = 120 - hw end
  if s.y - hh < 24  then s.y = 24 + hh  end
  if s.y + hh > 120 then s.y = 120 - hh end

  s.parts[1] = { x = s.x, y = s.y}
  
  for i = 2, #s.parts do
    local part = s.parts[i]
    local prev = s.parts[i-1]
    
    local d = dist(prev.x, prev.y, part.x, part.y)
    local md = prev.r + part.r
    if d > md then
      part.x = lerp(part.x, prev.x, (d-md)/d)
      part.y = lerp(part.y, prev.y, (d-md)/d)
    end
  end
end


-- DRAWS

function draw_apple(s)
  local anim
  local flipx
  if abs(s.vx) + abs(s.vy) > 0.1 then
    -- run animation
    anim = {34, 36, 38, 40, 42}
    flipx = (s.vx < 0)
  else
    -- idle animation
    anim = {32, 32, 32, 32, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 32, 32, 32, 32}
  end
  
  local sp = anim[flr(s.t / 0.06) % #anim + 1]
  
  if sp == 34 and s.t % 0.06 < dt() then
    sfx("jump", nil, nil, 0.9+rnd(0.2))
  end
  
  spr(sp, s.x - 8, s.y - 8, 2, 2)
end

function draw_snake(s)
  if t()%4 < 0.25 or t()%7 < 0.25 or t()%13 < 0.25 then
    local v = cos(0.75 + t() * 2)
    aspr(96, s.x, s.y, s.a, 1, 1, 0.5-v, 3.5/8)
    
    if t()%1 < dt() then
      sfx("snek")
    end
  end

  for i = #snake, 1, -1 do
    local part = s.parts[i]
    spr(part.s + 8, part.x-8, part.y-8, 2, 2)
  end
  
  for i = #snake, 1, -1 do
    local part = s.parts[i]
    spr(part.s, part.x-8, part.y-8, 2, 2)
  end
  
  aspr(97, s.x, s.y, s.a, 1, 1, 0.4)
end


-- CREATES

function create_apple(x, y)
  local s = {
    x      = x or 64,
    y      = y or 72,
    vx     = 0,
    vy     = 0,
    t      = 0,
    update = update_apple,
    draw   = draw_apple,
    regs   = {"to_update", "to_draw1", "apples"}
  }
  
  register_object(s)
  
  log("Created an apple at "..s.x..";"..s.y)
  
  return s
end

function create_snake(positions, x, y, n)
  if not positions then
    positions = {{ 64, 32 }}
  end

  local s = {
    x      = positions[1][1],
    y      = positions[1][2],
    parts  = {},
    a      = rnd(1),
    spd    = 25,
    update = update_snake,
    draw   = draw_snake,
    regs   = {"to_update", "to_draw2", "snakes"}
  }
  
  local n = 32
  local x, y = 64, 32
  
  for i = 1, n do
    local part = {
      x = x,
      y = y
    }
    
    if i == 1 then -- defining sprite + ball radius
      part.s = 64
      part.r = 1
    elseif i > n - 4 then
      local v = (i - (n - 4))/2
      part.s = 66 + ceil(v) * 2
      part.r = 1--2 - v/2
    else
      part.s = 66
      part.r = 1
    end
  
    add(s.parts, part)
  end
  
  register_object(s)
  
  log("Created a snake at "..s.x..";"..s.y)
  
  return s
end


-- TITLESCREEN

function update_titlescreen()

end

function draw_titlescreen()

end


-- BOARD

function init_board()
  -- initializing the board tables with a sprite id for each tile, to draw on draw_table().

  board = {}
  for i = 0, 13 do
    board[i] = {}
  end
  
  for i = 1, 12 do
    for j = 1, 14 do
      if rnd(8) > 1 then
        --board[i][j] = flr(rnd(4))
        board[i][j] = irnd(4)
      else
        --board[i][j] = flr(rnd(9))
        board[i][j] = irnd(10)
      end
    end
    
    board[i][0] = 18
    board[i][15] = 19
  end
  
  for i = 1,14 do
    board[0][i] = 16
    board[13][i] = 17
  end
  
  board[0][0] = 20
  board[0][15] = 21
  board[13][0] = 22
  board[13][15] = 23
end

function draw_board()
  local y = 16
  for i = 0, 13 do
    local x = 0
    local line = board[i]
    
    for j = 0, 15 do
      spr(line[j], x, y)
    
      x = x + 8
    end
    
    y = y + 8
  end
end

function draw_bottomfence()
  for i = 1, 14 do
    spr(24, i*8, 120)
  end
end


-- MISC INIT

function load_assets()
  load_png("spritesheet", "assets/sheet.png", nil, true)
  
  load_sfx("assets/jump.wav", "jump", 1)
  load_sfx("assets/snake.wav", "snek", 0.5)
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