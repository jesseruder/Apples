if CASTLE_PREFETCH then
  CASTLE_PREFETCH({
    "https://raw.githubusercontent.com/castle-games/share.lua/master/cs.lua",
    "nnetwork.lua",
    "game.lua",
    "object.lua",
    "anim.lua",
    "sugarcoat/sugarcoat.lua",
    "assets/sheet.png",
    "assets/jump.wav",
    "assets/snake.wav",
    "assets/apple_death.wav",
    "assets/apple_rebirth.wav",
    "assets/bomb_boom.wav",
    "assets/bomb_tick.wav",
    "assets/butt_hover.wav",
    "assets/butt_press.wav",
    "assets/butt_release.wav", 
    "assets/snake_die.wav",
    "assets/snake_tick.wav",
    "assets/snake_tick_end.wav"
  })
end

require("sugarcoat/sugarcoat")
sugar.utility.using_package(sugar.S, true)

require("nnetwork")
start_client()

require("game")

shaders = {
  just_chroma = [[
    varying vec2 v_vTexcoord;
    varying vec4 v_vColour;
    
    extern float time;
    
    const float PI = 3.1415926535897932384626433832795;

    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords)
    {
      vec4 col = Texel_color(texture, coords);

      vec2 tn = vec2(0.65/SCREEN_SIZE.x, 0.35/SCREEN_SIZE.y);
      
      vec4 col1 = Texel_color(texture, coords-tn);
      vec4 col2 = col;
      vec4 col3 = Texel_color(texture, coords+tn);
      
      col1 += Texel_color(texture, coords-tn*2.0);
      col2 += col;
      col3 += Texel_color(texture, coords+tn*2.0);
      
      float v = coords.y*64.0+8.0*time;
      vec4 ncol = vec4((0.6+0.4*cos(v))*(col1.r+col3.b),
                       (0.6+0.4*cos(v+1.0*PI/3.0))*(col1.r+col2.g),
                       (0.6+0.4*cos(v+2.0*PI/3.0))*(col2.g+col3.b),
                       1.0);
      
      return mix(col, ncol, 0.05) + 0.2 * ncol;
    }
  ]],
  just_pixels = [[
    varying vec2 v_vTexcoord;
    varying vec4 v_vColour;

    float power2(float);
    
    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords)
    {
      vec4 col = Texel_color(texture, coords);
      
      vec2 co = mod(coords * SCREEN_SIZE, 1.0);
      float k = 1.0 - max(power2(co.x), power2(co.y));

      vec4 fcol = (0.75*k + 0.75) * col;

      return fcol;
    }
    
    float power2(float a){
      return a*a;//*a*a;
    }
  ]],
  all = [[
    varying vec2 v_vTexcoord;
    varying vec4 v_vColour;
    
    extern float time;
    
    const float PI = 3.1415926535897932384626433832795;
    
    float power2(float);
    
    vec4 effect(vec4 color, Image texture, vec2 coords, vec2 screen_coords)
    {
      vec4 col = Texel_color(texture, coords);
      
      vec2 co = mod(coords * SCREEN_SIZE, 1.0);
      float k = 1.0 - max(power2(co.x), power2(co.y));

      vec4 fcol = (0.75*k + 0.75) * col;

      vec2 tn = vec2(0.65/SCREEN_SIZE.x, 0.35/SCREEN_SIZE.y);
      
      vec4 col1 = Texel_color(texture, coords-tn);
      vec4 col2 = col;
      vec4 col3 = Texel_color(texture, coords+tn);
      
      col1 += Texel_color(texture, coords-tn*2.0);
      col2 += col;
      col3 += Texel_color(texture, coords+tn*2.0);
      
      float v = coords.y*64.0+8.0*time;
      vec4 ncol = vec4((0.6+0.4*cos(v))*(col1.r+col3.b),
                       (0.6+0.4*cos(v+1.0*PI/3.0))*(col1.r+col2.g),
                       (0.6+0.4*cos(v+2.0*PI/3.0))*(col2.g+col3.b),
                       1.0);
      
      return mix(fcol, ncol, 0.05) + 0.2 * ncol;
    }
    
    float power2(float a){
      return a*a;//*a*a;
    }
  ]]
}

shader_chroma = true
shader_pixels = true
shader_moves = true

function client.load()
  init_sugar("Apple!", 256+32, 160, 3)
  screen_render_integer_scale(true)
--  screen_render_integer_scale(false)
--  screen_resizeable(true)

  screen_shader(shaders.all)
  
--  set_frame_waiting(30)
  
  use_palette(palettes.bubblegum16)
  set_background_color(0)
  
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
  if shader_moves then
    screen_shader_input({time = t()})
  else
    screen_shader_input({time = 0.12345})
  end
  
  _draw()
end