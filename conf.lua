function love.conf(t)
    t.identity = "one-last-pack"
    t.window.title = "One Last Pack"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360
    -- tamaños en pixeles reales aunque Windows tenga el escalado al 125% o 150%
    t.window.highdpi = true
    t.window.usedpiscale = false
    t.modules.joystick = false
    t.modules.physics = false
end
