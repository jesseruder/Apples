if CASTLE_PREFETCH then
  CASTLE_PREFETCH({
    "https://raw.githubusercontent.com/castle-games/share.lua/master/cs.lua",
    "nnetwork.lua",
    "game.lua",
    "object.lua",
    "anim.lua",
    "sugarcoat/sugarcoat.lua",
    "assets/sheet.png",
--    "assets/jump.wav",
--    "assets/snake.wav"
  })
end

require("sugarcoat/sugarcoat")
sugar.utility.using_package(sugar.S, true)

require("nnetwork")
start_client()

require("game")

function client.load()
  init_sugar("Apple!", 256, 160, 3)
  screen_render_integer_scale(false)
--  screen_resizeable(true)
  
--  set_frame_waiting(30)
  
  use_palette(palettes.bubblegum16)
  set_background_color(15)
  
  define_controls()
  load_assets()
  
  _init()
end

function client.update()
  if ROLE then client.preupdate() end

  _update()
  
  if ROLE then client.postupdate() end
end

function client.draw()
  _draw()
end