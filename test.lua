
function love.load()
  castle.print("start")

  local canvas = love.graphics.newCanvas(32,32)
  
  love.graphics.setCanvas(canvas)
  
  local image = love.graphics.newImage("https://ca.slack-edge.com/TFP1M7GLS-UFNNX723T-391df848a157-48")
  
  love.graphics.setCanvas()
  
  castle.print("finish")
end