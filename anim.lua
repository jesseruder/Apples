

local anim_info

function draw_anim(x,y,object,state,t,flipx,flipy)
  local state = state or "only"
  local info  = anim_info[object][state]
  
  local w, h  = info.w or 1, info.h or 1
  local step  = flr(t / info.dt) % #info.sprites + 1
  
  if info.sheet then
    spritesheet(info.sheet)
  end
  
  spr(info.sprites[step], x - w*4, y - h*4, w, h, flipx, flipy)
end

function draw_anim_rotated(x,y,object,state,t,r,flipx,flipy)
  local state = state or "only"
  local info  = anim_info[object][state]
  
  local w,h   = info.w, info.h
  local step  = flr(t/info.dt)%#info.sprites+1
  
  if info.sheet then
    spritesheet(info.sheet)
  end
  
  aspr(info.sprites[step], x, y, r, w, h, 0.5, 0.5, flipx and -1 or 1, flipy and -1 or 1)
end

function draw_self(s)
  draw_anim(s.x, s.y, s.name, s.state, s.animt, s.faceleft)
end

function anim_step(object, state, t)
 local info=anim_info[object][state]
 
 local v=flr(t/info.dt%#info.sprites)
 local k=flr((t/info.dt)/#info.sprites)
 
 return v,(t%info.dt<dt()),k
end

function init_anims(info)
  anim_info = info
end