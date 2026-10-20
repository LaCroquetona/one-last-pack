function love.conf(t)
    t.identity = "one-last-pack"
    t.window.title = "One Last Pack"
    t.window.width = 1280
    t.window.height = 720
    -- en Android solo horizontal: con la ventana redimensionable el movil
    -- dejaba girar la pantalla a vertical
    t.window.resizable = love._os ~= "Android"
    t.window.minwidth = 640
    t.window.minheight = 360
    -- tamaños en pixeles reales aunque Windows tenga el escalado al 125% o 150%
    t.window.highdpi = true
    t.window.usedpiscale = false
    t.modules.joystick = false
    t.modules.physics = false
end
