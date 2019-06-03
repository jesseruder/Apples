
require("nnetwork")
require("anim")
require("object")

-- NOTES:

--- post with shot of before death, with everyone's names
--- title-screen -> don't start game directly, can let people join first


--? difficulty progression


--- display countdown
--- trigger game over from server
--- display gameover
--- credits on the gameover

--- post screenshot button


--- anim for apple mouthful going through snek body

--- sfx
---- apple bounce  ^
---- snake ssss    ^
---- snake dies    .
---- snake dies 2  .
---- apple dies    .
---- apple rebirth .
---- select button .
---- press button  .
---- release button.

--- music???


BOARD_WN = 32
BOARD_HN = 18

apples = {}
snakes = {}
bombs = {}
dead_snakes = {}
dead_bombs = {}

level = 0

bomb_t = 1

in_game = false
countdown = 60
game_over = false

local body_colors = {}
local apple_colors = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
local drk = {[0]=0, 0, 1, 2, 3, 4, 7, 8, 9, 0, 15, 10, 13, 14, 10, 0}
local lit = {[0]=15, 2, 3, 4, 5, 5, 5, 6, 7, 8, 11, 5, 5, 12, 13, 14}
local nrm = {[0]=0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
local shkx, shky = 0, 0

local title_surf

-- CORE

function _init()
  if castle then
    local info = castle.game.getInitialParams()
    if info then
      for k,v in pairs(info) do
        log(k.." : "..v)
      end
    end
  end

  init_object_mgr(
    "apples",
    "snakes",
    "bombs",
    "ui_button"
  )
  
  in_game = false
  
  load_anims()
  
  init_network()

  if not IS_SERVER then
    title_surf = new_surface(9*8, 16, "title")
    load_colors()
    
    init_board()
  end
  
--  define_ui()
  
--  init_game()
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
    bomb_t = 1
  end
  
  in_game = true
  level = 0
  
  log("Starting game.")
  
  if not IS_SERVER then
    remove_all_buttons()
  end
end

function update_game()
  update_shake()
  
  if in_game then
    if IS_SERVER and group_size("snakes") == 0 then
      new_wave()
      bomb_t = 5
    end
    
    bomb_t = bomb_t - dt()
    if IS_SERVER and bomb_t <= 0 then
      local w = BOARD_WN*8
      local h = BOARD_HN*8
      local x = w/4+rnd(w/2)
      local y = h/4+rnd(h/2)
      
      create_bomb(nil, x, y)
      
      bomb_t = 3.5+rnd(1)
    end
  elseif IS_SERVER then
    local ready, total = 0, 0
    for a in group("apples") do
      if a.ready then
        ready = ready + 1
      end
      total = total + 1
    end
    
    if ready == total and ready > 0 then
      countdown = min(countdown - dt(), 10)
    elseif ready > 0 then
      countdown = countdown - dt()
    else
      countdown = 60
    end
    
    if countdown <= 0 then
      init_game()
    end
  else
    if apples[my_id] and not ui_defined then
      define_ui()
    end
  end

  update_objects()
  
  if not IS_SERVER then
    update_topbar()
  end
end

function draw_game()
  palt(0, false)
  
  camera()
  apply_shake()
  
  cls()
--  for id, apple in pairs(apples) do
--    
--  end

  camera(0, -16)
  apply_shake()
  palt(0, false)
  palt(11, false)
  
  draw_board()
  
  palt(11, true)
  
  draw_objects()
  
  draw_bottomfence()
  
  camera()
  
  draw_topbar()
  
  if not in_game then
    --printp(0x3120, 0x0, 0x0, 0x0)
    printp(0x0330, 0x3123, 0x0330, 0x0, 0x0)
    local y
    if game_over then
      y = 32
      local str = "GAME OVER"
      local x = screen_w()/2 - (str_px_width(str) + #str)/2
      --printp_color(5, 7, 2)
      printp_color(5, 7, 0)
      
      for i = 1,#str do
        local ch = str:sub(i, i)
        pprint(ch, x, y + 4*cos(i/8-t()))
        x = x + str_px_width(ch) + 1
      end
      
      y = 112 + 16
    else
      y = 112
    end
    
    if countdown < 60 then
      --printp_color(5, 11, 10)
      printp_color(5, 11, 0)
      local str = (game_over and "Restarting in " or "Starting in ")..ceil(countdown)..'"'
      local x = screen_w()/2 - str_px_width(str)/2
      
      pprint(str, x, y)
    end
    
    
  end
  
  palt(11, false)
  draw_cursor()
end



-- UPDATES

function update_apple(s)
  s.animt = s.animt + dt()
  
  local acc = dt() * 15 * 30
  
  if s.id == my_id then
    local movx, movy = 0,0
  
    if btn(4) or btn(5) then
      movx = movx + btnv(4)
      movy = movy + btnv(5)
    end
    
    if btn(8) then
      local mx, my = btnv(6), btnv(7)-16
      
      local d = dist(mx, my, s.x, s.y)
      movx = movx + (mx - s.x) / d
      movy = movy + (my - s.y) / d
    end
    
    if btn(0) then movx = movx - 1 end
    if btn(1) then movx = movx + 1 end
    if btn(2) then movy = movy - 1 end
    if btn(3) then movy = movy + 1 end
    
    if abs(movx)+abs(movy) > 0 then
      local d = dist(movx, movy)
      s.vx = s.vx + movx/d * acc
      s.vy = s.vy + movy/d * acc
    end
  end
  
  s.x = s.x + s.vx * dt()
  s.y = s.y + s.vy * dt()
  
  s.vx = lerp(s.vx, 0, dt() * 15)
  s.vy = lerp(s.vy, 0, dt() * 15)
  
  collide_borders(s)
  
  for snek in group("snakes") do
    if s.id == my_id then
      if not (s.dead) and collide_objobj(s, snek) then
        apple_die(s, snek)
        break
      end
    end
    
    for _,p in pairs(snek.parts) do
      if collide_objobj(s, p) then
        -- push back
        local d = dist(s.x, s.y, p.x, p.y)
        local dx = (s.x-p.x)/d
        local dy = (s.y-p.y)/d
        
        s.vx = lerp(s.vx, 45*dx, 10*dt())
        s.vy = lerp(s.vy, 45*dy, 10*dt())
      end
    end
  end
  
  if not IS_SERVER then
    s.diffx = sgn(s.diffx) * max(abs(s.diffx) - 30 * dt(), 0)
    s.diffy = sgn(s.diffy) * max(abs(s.diffy) - 30 * dt(), 0)
  end
  
  local col = collide_objgroup(s, "apples")
  if col then
    -- push back
    local d = dist(s.x, s.y, col.x, col.y)
    local dx = (s.x-col.x)/d
    local dy = (s.y-col.y)/d
    
    s.vx = lerp(s.vx, 60*dx, 10*dt())
    s.vy = lerp(s.vy, 60*dy, 10*dt())
    col.vx = lerp(s.vx, -60*dx, 10*dt())
    col.vy = lerp(s.vy, -60*dy, 10*dt())
  end
  
  local nstate
  if s.state == "res" or s.state == "hurt" then
    local a,b,c = anim_step(s.name, s.state, s.animt)
    if c >= 1 then
      nstate = "idle"
    else
      nstate = s.state
    end
  elseif abs(s.vx) + abs(s.vy) > 0.1 or abs(s.diffx) + abs(s.diffy) > 2 then
    nstate = "run"
  else
    nstate = "idle"
  end
  
  if nstate ~= s.state then
    s.state = nstate
    s.animt = 0
  end
  
  if abs(s.vx) > 0.1 then
    s.faceleft = s.vx < 0 
  end
end

function apple_die(s, snek)
  s.dead = true
  s.name = "dead_apple"
  s.state = "hurt"
  s.animt = 0
  
  if snek then
    local d = dist(snek.x, snek.y, s.x, s.y)
    local dx = (snek.x - s.x) / d
    local dy = (snek.y - s.y) / d
    
    s.vx = dx * 120
    s.vy = dy * 120
  end
  
  local a = rnd(1)
  for i = 1,6 do
    create_star(s.x, s.y, a+i/6)
  end
  
  add_shake(4)
  local all_dead = true
  for a in group("apples") do
    all_dead = all_dead and a.dead
  end
  if all_dead then
    game_over = true
  end
end

function apple_resurrect(s)
  s.dead = false
  s.name = "apple"
  s.state = "res"
  s.animt = 0
  
  local a = rnd(1)
  for i = 1,6 do
    create_star(s.x, s.y, a+i/6)
  end
  
  if s.id == my_id then
    add_shake(4)
  end
end

function update_snake(s)
  s.animt = s.animt + dt()
  
  if s.dead then
    local k = flr(s.animt/0.15*6)
    local n = 0
    for i,p in pairs(s.parts) do
      if i < k then
        s.parts[i] = nil
        if i%2==1 then
          local a = s.animt * 1.25
          local k = 3
          for i = 1,k do
            create_star(p.x, p.y, a+i/k)
          end
        end
      else
        n = n + 1
      end
    end
    
    if n == 0 then
      remove_snake(s)
    end
    
    return
  end

  s.target_t = s.target_t - dt()
  if s.target_t < 0 then-- or s.target.dead then
    local md, target = 99999
    for a in group("apples") do
      local nd = sqrdist(a.x - s.x, a.y - s.y)
      if nd < md and not a.dead then
        target = a
        md = nd
      end
    end
    
    if not target then
      local w = BOARD_WN * 8
      local h = BOARD_HN * 8
      target = {
        x = w/4+rnd(w/2),
        y = h/4+rnd(h/2)
      }
    end
    
    s.target_t = 1+rnd(3)
    s.target = target
  end
  
  local diff_a
  if s.steer then
    diff_a = 0.5 * sgn(s.steer)
    
    s.steer = sgn(s.steer) * (abs(s.steer) - dt())
    if s.steer <= 0 then
      s.steer = nil
    end
  else
    local target_a = atan2(s.target.x - s.x, s.target.y - s.y)
    diff_a = angle_diff(s.a, target_a)
  end
  
  s.a = s.a + s.va * dt() * diff_a
  
  local wave = 0.1 * cos(s.animt/2)
  s.x = s.x + s.spd * cos(s.a + wave) * dt()
  s.y = s.y + s.spd * sin(s.a + wave) * dt()
  
  if not s.steer then
    local dprev = 48
    local prev = {
      x = s.x + dprev * cos(s.a),
      y = s.y + dprev * sin(s.a)
    }
    if collide_borders(prev) then
      local na = atan2(prev.x - s.x, prev.y - s.y)
      s.steer = (0.5 + rnd(0.5)) * sgn(angle_diff(s.a, na))
    else
      prev.w, prev.h = 0,0
      -- todo collide with snek bodies
      for snek in group("snakes") do
        if snek ~= s then
          for i = 1,#snek.parts,4 do
            local p = snek.parts[i]
            if p and collide_objobj(prev, p) then
              s.steer = (0.5 + rnd(0.5)) * sgn(rnd(2)-1)
              break
            end
          end
        end
      end
      
    end
  end
  
  local die = false
  if collide_borders(s) then
    -- snek dies
    die = true
  end
  
  for snek in group("snakes") do
    if snek ~= s then
      for _,p in pairs(snek.parts) do
        die = die or collide_objobj(s, p)
      end
    end
  end
  
  if not IS_SERVER then
    local dx = sgn(s.diffx) * max(abs(s.diffx), 6 * dt())
    local dy = sgn(s.diffy) * max(abs(s.diffy), 6 * dt())
    
    s.x = s.x + dx
    s.y = s.y + dy
    
    s.diffx = s.diffx - dx
    s.diffy = s.diffy - dy
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
  
  
  if die and IS_SERVER then
    snake_die(s)
  end
end

function snake_die(s)
  s.dead = true
  s.animt = 0
  add_shake(8)
end

function collide_borders(s)
  local bw = BOARD_WN*8
  local bh = BOARD_HN*8

  local col
  if not s.w then
    if s.x < 8 then
      s.x = 8
      col = true
    end
    
    if s.y < 6 then
      s.y = 6
      col = true
    end
    
    if s.x >= bw-8 then
      s.x = bw-8-0.1
      col = true
    end
    
    if s.y >= bh-6 then
      s.y = bh-6-0.1
      col = true
    end
  
    return col
  end
  
  if s.x-s.w/2 < 8 then
    s.x = 8+s.w/2
    col = true
  end
  
  if s.y-s.h/2 < 6 then
    s.y = 6 + s.h/2
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

function update_bomb(s)
  if s.boom > 0 then
    local collide = function(o)
      local d = dist(s.x, s.y, o.x, o.y)
      local dx = (s.x - o.x) / d
      local dy = (s.y - o.y) / d
      
      s.vx = s.vx + dx * 60 * dt()
      s.vy = s.vy + dy * 60 * dt()
      
      if not o.dead then
        s.trigger = true
      end
    end
  
    for o in group("apples") do
      if collide_objobj(s, o) then
        collide(o)
      end
    end
    
    for o in group("snakes") do
      if collide_objobj(s, o) then
        collide(o)
      end
    end
  
    s.x = s.x + s.vx * dt()
    s.y = s.y + s.vy * dt()
    
    s.a = s.a + sgn(s.vx) * dist(s.vx, s.vy) * dt() * 0.05
    
    s.vx = lerp(s.vx, 0, dt())
    s.vy = lerp(s.vy, 0, dt())
    
    local ox,oy = s.x, s.y
    if collide_borders(s) then
      if ox ~= s.x then
        s.vx = -s.vx
      end
      
      if oy ~= s.y then
        s.vy = -s.vy
      end
    end
    
    if not IS_SERVER then
      local dx = sgn(s.diffx) * max(abs(s.diffx), 0.2)
      local dy = sgn(s.diffy) * max(abs(s.diffy), 0.2)
      
      s.x = s.x + dx
      s.y = s.y + dy
      
      s.a = s.a + sgn(dx) * dist(dx, dy) * 0.05
      
      s.diffx = s.diffx - dx
      s.diffy = s.diffy - dy
    end
  end
  
  if s.trigger then
    local not_boom = (s.boom > 0)
    
    s.boom = s.boom - dt()
    
    if s.boom < -0.5 then
      remove_bomb(s)
    elseif s.boom <= 0 and not_boom then
      if IS_SERVER then
        --kill sneks
        for snek in group("snakes") do
          if not snek.dead and dist(s.x, s.y, snek.x, snek.y) <= 32 then
            snake_die(snek)
          end
        end
        
        for bomb in group("bombs") do
          if not bomb.trigger and dist(s.x, s.y, bomb.x, bomb.y) <= 32 then
            bomb.trigger = true
          end
        end
        
      else
        --kill player apple if close
        local apple = apples[my_id]
        if apple and not apple.dead and dist(s.x, s.y, apple.x, apple.y) < 32 then
          apple_die(apple, s)
        end
        
        -- add stars??
        local a = rnd(1)
        for i = 1,8 do
          create_star(s.x, s.y, a+i/8)
        end
        add_shake(12)
      end
    end
  
  end
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
  
  local ox,oy = s.x, s.y
  
  s.x = s.x - s.diffx
  s.y = s.y - s.diffy
  
  pal(1, plt[1])
  pal(2, plt[2])
  pal(3, plt[3])
  pal(4, lit[plt[3]])
  draw_self(s)
  pal(1, 1)
  pal(2, 2)
  pal(3, 3)
  pal(4, 4)
  
  s.x, s.y = ox, oy
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

function draw_bomb(s)
  palt(12, true)
  palt(11, false)

  local a = round(s.a*20)/20
  local x,y = round(s.x), round(s.y)
  
  if s.white > 0 then
    s.white = s.white - dt()
    aspr(190, x, y - 3, a, 2, 2)
  elseif s.trigger then
    if s.boom < 0 then
      local t = -s.boom/0.5 * 1
      
      local r = 32 * cos(t * 0.35 - 0.08)
      if r > 0 then circfill(s.x, s.y, r, 15) end
      
      local r = 32 * cos(t * 0.35 - 0.07)
      if r > 0 then circfill(s.x, s.y, r, 10) end
      
      local r = 32 * cos(t * 0.35 - 0.06)
      if r > 0 then circfill(s.x, s.y, r, 11) end
      
      local r = 32 * cos(t * 0.35 - 0.05)
      if r > 0 then circfill(s.x, s.y, r, 5) end
    else
      local n = flr(s.boom / 0.1)%2
      aspr(188 + n*2, s.x, s.y - 2, s.a, 2, 2)
    end
  else
    aspr(186, x, y - 2, a, 2, 2)
    spr(185, x-3.5, y-3.5 - 2)
  end
  
  palt(12, false)
  palt(11, true)
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
    w      = 8,
    h      = 8,
    vx     = 0,
    vy     = 0,
    name   = "apple",
    state  = "idle",
    animt  = rnd(1),
    faceleft = false,
    diffx  = 0,
    diffy  = 0,
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
  add_playerui(s)
  
  log("Created apple!")
  
  return s
end

local snake_id = 1
function create_snake(id, x, y, n, ca, cb, spd)
  local s = {
    id       = id,
    x        = x,
    y        = y,
    w        = 8,
    h        = 8,
    parts    = {},
    a        = rnd(1),
    va       = 1,
    spd      = spd or 25,
    animt    = rnd(1),
    target_t = 0,
    target   = {x = x, y = y},
    ca       = ca or irnd(10)+1,
    cb       = cb or irnd(10)+1,
    diffx    = 0,
    diffy    = 0,
    update   = update_snake,
    draw     = draw_snake,
    regs     = {"to_update", "to_draw2", "snakes"}
  }
  
  if spd then
    s.va = spd/25
  end
  
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
      p.w, p.h = 8,8
    elseif i >= n-2 then
      p.s = 70
      p.w, p.h = 2,2
    elseif i >= n-4 then
      p.s = 68
      p.w, p.h = 4,4
    else
      p.s = 66
      p.w, p.h = 6,6
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
  
  log("Created snake!")
  
  return s
end

local bomb_id = 1
function create_bomb(id, x, y)
  local s = {
    x       = x,
    y       = y,
    w       = 6,
    h       = 6,
    vx      = 0,
    vy      = 0,
    a       = 0,
    white   = 0.5,
    boom    = 1.8,
    trigger = false,
    diffx   = 0,
    diffy   = 0,
    update  = update_bomb,
    draw    = draw_bomb,
    regs    = { "to_update", "to_draw1", "bombs" }
  }
  
  if not IS_SERVER then
    local a = rnd(1)
    for i=1,4 do
      create_star(x, y, a+i/4)
    end
  end
  
  if not id then
    s.id = bomb_id
    bomb_id = bomb_id + 1
  else
    s.id = id
    bomb_id = id + 1
  end
  
  bombs[s.id] = s
  
  register_object(s)
  
  log("Created bomb!")
  return s
end

function create_star(x,y,a,spd)
  if IS_SERVER then return end

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
  del_playerui(s)
end

function remove_snake(s)
  add_shake(4)
  deregister_object(s)
  dead_snakes[s.id] = true
end

function remove_bomb(s)
  deregister_object(s)
  bombs[s.id] = nil
  dead_bombs[s.id] = true
end


-- BOARD

function init_board()
  -- initializing the board tables with a sprite id for each tile, to draw on draw_table().
  
  board_w = BOARD_WN
  board_h = BOARD_HN

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
      spr(v, x*8, y*8)
    end
  end
end

function draw_bottomfence()
  local y = (BOARD_HN-1) * 8
  for i = 1, BOARD_WN-2 do
    spr(24, i*8, y)
  end
end


-- UI BUTTONS

function update_button(s)
  local xa, xb = s.x - s.w/2, s.x + s.w/2
  local ya, yb = s.y - s.h/2, s.y + s.h/2
  
  local mx, my = btnv(6), btnv(7)-16
  
  if mx >= xa and mx <= xb and my >= ya and my <= yb then
    s.hover = true
    if btn(8) then
      s.press = true
    else
      s.press = false
    end
    
    if btnp(8) and s.on_press then
      s:on_press()
    end
    
    if btnr(8) and s.on_release then
      s:on_release()
    end
  else
    s.hover = false
    s.press = false
  end
end

function draw_button(s)
  local x, y = s.x, s.y
  local w, h = s.w, s.h
  local c = s.c
  
  if s.hover then
    h = h + 2
    w = w + 2
  end
  
  if s.press then
    y = y + 2
    h = h - 2
    w = w - 2
    c = drk[c]
  elseif s.hold then
    y = y + 1
    if not s.hover then
      c = drk[c]
    end
  elseif s.hover then
    c = lit[c]
  end
  
  local xa, xb = x - w/2, x + w/2
  local ya, yb = y - h/2, y + h/2
  
  pal(3, c)
  pal(2, drk[c])
  pal(4, lit[c])
  pal(5, lit[lit[c]])
  
  sspr(120, 112, 8, 8, xa+8, ya+8, w-16, h-16)
  
  sspr(88, 112, 8, 8, xa+8, ya, w-16, 8)
  sspr(96, 112, 8, 8, xa+8, yb-8, w-16, 8)
  sspr(104, 112, 8, 8, xa, ya+8, 8, h-16)
  sspr(112, 112, 8, 8, xb-8, ya+8, 8, h-16)
  
  spr(251, xa, ya)
  spr(252, xb-8, ya)
  spr(253, xa, yb-8)
  spr(254, xb-8, yb-8)
  
  if s.str then
    printp(0x0, 0x3120, 0x0, 0x0)
    printp_color(lit[lit[c]], lit[c], drk[c])
    pprint(s.str, x - str_px_width(s.str)/2 - 2, y - 9)
  elseif s.spr then
    spr(s.spr, x - 8, y - 8, 2, 2)
  end
  
  pal(5,5)
  pal(4,4)
  pal(3,3)
  pal(2,2)
end

function create_button(info)
  if IS_SERVER then return end

  info.update = update_button
  info.draw   = draw_button

  info.regs = {"to_update", "to_draw4", "ui_button"}
  register_object(info)
  return info
end

function remove_all_buttons()
  eradicate_group("ui_button")
  
  if castle then
    castle.uiupdate = false
  end
  
  ui_defined = false
end

function define_ui()
  if IS_SERVER then return end

  if castle then
    castle.uiupdate = false
  end
  
  local x = screen_w()/2
  local y = screen_h()/2
  
  if game_over then
    y = y - 16
  else
    y = y - 32
  end
  
  create_button({ -- (re)start button
    x   = x,
    y   = y,
    w   = 68,
    h   = 28,
    str = game_over and "RESTART" or "READY",
    c   = 10,
    on_release = function(s)
      if not my_id then return end
      local my_apple = apples[my_id]
      if not my_apple then return end
      
      my_apple.ready = not my_apple.ready
      s.hold = my_apple.ready
    end
  })
  
  create_button({ -- post button
    x   = x - 18,
    y   = y + 30,
    w   = 32,
    h   = 28,
    spr = 122,
    c   = 10,
    on_release = function(s)
      if not castle then return end
      
      
    end
  })
  
  create_button({ -- settings button
    x   = x + 18,
    y   = y + 30,
    w   = 32,
    h   = 28,
    spr = 120,
    c   = 10,
    on_release = function(s)
      if not castle then return end
      castle.uiupdate = not castle.uiupdate and settings_panel
    end
  })
  
  ui_defined = true
end


-- MISC UPDATE

function new_wave()
  for s in group("apples") do
    s.dead = false
    s.name = "apple"
  end

  level = level + 1
  
  log("New wave! Level: "..level)
  
  local w = BOARD_WN*8
  local h = BOARD_HN*8
  local ca, cb = irnd(10)+1, irnd(10)+1
  
  local npts = level * 10
  local pts = npts
  local take_pts = function(n)
    n = min(n/100*npts, pts)
    pts = pts - n
    return n
  end
  
  local spd = 25 + take_pts(rnd(50))/2
  local num = 1 + flr(take_pts(rnd(50))/10)
  local len = 16 + flr(take_pts(rnd(50))/50 * 32)
  
  for i = 1, num do
    local x = w/4+rnd(w/2)
    local y = h/4+rnd(h/2)
    
    create_snake(nil, x, y, len, ca, cb, spd)
  end
  
  
  --create_snake(nil, w/4+rnd(w/2), h/4+rnd(h/2), 24+irnd(16), ca, cb)
  --create_snake(nil, w/4+rnd(w/2), h/4+rnd(h/2), 24+irnd(16), ca, cb)
end

local shkp = 100
function add_shake(p)
  local a = rnd(1)
  shkx = shkx + p * cos(a) * shkp/100
  shky = shky + p * sin(a) * shkp/100
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

function apply_shake()
  camera_move(shkx, shky)
end

local players_ui = {}
function update_topbar()
  for i,u in pairs(players_ui) do
    u.y = lerp(u.y, i*18, 3*dt())
  end
end

function add_playerui(s)
  if IS_SERVER then return end
  add(players_ui, {
    y = screen_h(), s = s
  })
end

function del_playerui(s)
  if IS_SERVER then return end
  for i,u in pairs(players_ui) do
    if u.s == s then
      del_at(players_ui, i)
      return
    end
  end
end

function settings_panel()
  local ui = castle.ui
  
--  ui.slider("sfx volume", )

  local oshkp = shkp
  shkp = ui.slider("screenshake", shkp, 0, 200, {minLabel = "%", maxLabel = "%", step = 1})
  if shkp ~= oshkp then add_shake(4) end
  
  local refresh_shaders = function()
    if shader_chroma and shader_pixels then
      screen_shader(shaders.all)
    elseif shader_chroma then
      screen_shader(shaders.just_chroma)
    elseif shader_pixels then
      screen_shader(shaders.just_pixels)
    else
      screen_shader()
    end
  end
  
  ui.toggle("chroma lines OFF", "chroma lines ON", shader_chroma,
    { onToggle = function()
      shader_chroma = not shader_chroma
      refresh_shaders()
    end})
    
  ui.toggle("super pixels OFF", "super pixels ON", shader_pixels,
    { onToggle = function()
      shader_pixels = not shader_pixels
      refresh_shaders()
    end})
end

-- MISC DRAW

function draw_cursor()
  palt(0, false)
  palt(12, true)
  local mx, my = btnv(6), btnv(7)
  if btn(8) then
    spr(99, mx, my, 1, 2)
  else
    spr(98, mx, my, 1, 2)
  end
  palt(12, false)
end

function draw_topbar()
  --printp(0x0120, 0x0230, 0x0300, 0x0000)
  --printp_color(5, 3, 2)
  --
  --pprint("Apples!", 0, -2)
  
  target(title_surf)
  cls()
  
  palt(0, true)
  
  local x = 84 - (t() * 30) % 84
  spr(224, x, 0, 11, 2)
  spr(224, x-84, 0, 11, 2)
  --spr(224, x+84, 0, 7, 2)
  
  palt(0, false)
  palt(2, true)
  spr(176, 0, 0, 9, 2)
  palt(2, false)
  
  palt(0, true)
  
  target()

  local x = 144-34

  palmap(lit)
  spr_sheet(title_surf, x-1, 0)
  palmap(drk)
  spr_sheet(title_surf, x+1, 0)
  palmap(nrm)
  spr_sheet(title_surf, x, 0)


  
  pal(5,10)
  spr(208, 1, 0, 8, 1)
  spr(216, 1, 7, 6, 1)
  pal(5,15)
  spr(208, 3, 0, 8, 1)
  spr(216, 3, 7, 6, 1)
  pal(5,11)
  spr(208, 2, 0, 8, 1)
  spr(216, 2, 7, 6, 1)
  pal(5,5)
  
  palt(0, false)
  
  if client.connected then
    local str = "Lvl "..level
    local x = screen_w() - 6 - str_px_width(str)
    local y = -1
    
    printp(0x0000, 0x2130, 0x0000, 0x0000)
    printp_color(5, 4, 3)
    pprint(str, x, y)
  
    draw_playerui()
  else
    if castle and not castle.user.isLoggedIn then
      str = "Log-in to play!"
    elseif disconnected then
      str = "Disconnected :("
    else
      str = "Connecting"
      for i = 1,flr(t()/0.25)%4 do
        str = str.."."
      end
    end
    
    printp(0x0000, 0x2130, 0x0000, 0x0000)
    printp_color(5, 11, 10)
    local w = str_px_width(str)
    pprint(str, screen_w() - w - 3, -2)
  end
end

function draw_playerui()
  palt(11, false)
  palt(0, false)
  palt(12, true)
  
  local x = screen_w() - 17
  local y = -1--screen_h() + 1
  for _,u in pairs(players_ui) do
    local y = y + round(u.y)
    
    local pic = u.s.pic
    if pic then
      palt(12, false)
      spr_sheet(u.s.pic, x, y, 16, 16)
      rect(x, y, x+15, y+15, 0)
      pset(x+1,  y+1,  0)
      pset(x+14, y+1,  0)
      pset(x+1,  y+14, 0)
      pset(x+14, y+14, 0)
      palt(12, true)
    else
      spr(118, x, y, 2, 2)
    end
    
    local plt = body_colors[u.s.color]
    palmap{plt[1], plt[2], plt[3], lit[plt[3]]}
    
    spr(116, x-15, y, 2, 2)
    
    palt(11, true)
    if u.s.dead then
      spr(144, x-14, y, 2, 2)
    else
      spr(32, x-14, y, 2, 2)
    end
    palt(11, false)
    
    palmap{1, 2, 3, 4}
    
    if not in_game then
      local str
      
      if u.s.ready then
        str = "ready"
      end
      
      if btnv(6) > x-15 and btnv(7) > y and btnv(7) < y + 16 then
        if str then
          str = str..": "..(u.s.username or "Guest")
        else
          str = u.s.username or "Guest"
        end
      end
    
      if str then
        printp_color(5, plt[2], 0)
        printp(0x0330, 0x3123, 0x0330, 0x0, 0x0)
        
        local w = str_px_width(str)
        pprint(str, x - 18 - w, y - 2)
      end
      
    elseif btnv(6) > x-15 and btnv(7) > y and btnv(7) < y + 16 then
      printp_color(5, plt[2], 0)
      printp(0x0330, 0x3123, 0x0330, 0x0, 0x0)
      local str = u.s.username or "Guest"
      local w = str_px_width(str)
      pprint(str, x - 18 - w, y - 2)
    end
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
        dt = 0.06,
        sprites = {32, 32, 32, 32, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 46, 46, 32, 44, 44, 32, 32, 32, 32, 32},
        w = 2,
        h = 2
      },
      run = {
        dt = 0.06,
        sprites = {34, 36, 38, 40, 42},
        w = 2,
        h = 2
      },
      res = {
        dt = 0.06,
        sprites = {126, 126, 126, 124, 124},
        w = 2,
        h = 2
      }
    },
    dead_apple = {
      idle = {
        dt = 0.06,
        sprites = {144, 144, 144, 144, 144, 156, 156, 144, 158, 158, 144, 156, 156, 144, 158, 158, 144, 156, 156, 144, 144, 144, 144, 144},
        w = 2,
        h = 2
      },
      run = {
        dt = 0.06,
        sprites = {146, 148, 150, 152, 154},
        w = 2,
        h = 2
      },
      hurt = {
        dt = 0.06,
        sprites = {124, 124, 124, 126, 126, 158},
        w = 2,
        h = 2
      }
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


-- MISC MISC

function palmap(m)
  for ca,cb in pairs(m) do
    pal(ca, cb)
  end
end

