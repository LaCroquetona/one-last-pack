-- Pantalla de error propia: si el juego peta se guarda un reporte con el
-- error y la partida (src/reporte.lua) y se dice en pantalla, en vez de la
-- pantalla azul de LOVE. Si algo de esto falla, sale la de LOVE de siempre.
local p = require "datos.paleta"
local reporte = require "src.reporte"
local fuentes = require "src.fuentes"

local lg = love.graphics

local errores = {}

-- lo pone main.lua: la partida en texto como esta en memoria
errores.partida = nil

local estado      -- { error, nombre, contenido, copiado }
local BOTONES = {
    { id = "copiar", texto = "COPIAR REPORTE", x = 150, w = 110 },
    { id = "carpeta", texto = "ABRIR CARPETA", x = 265, w = 110, pc = true },
    { id = "salir", texto = "SALIR", x = 380, w = 110 },
}

local function escala()
    local w, h = lg.getDimensions()
    local e = math.min(w / 640, h / 360)
    return e, (w - 640 * e) / 2, (h - 360 * e) / 2
end

-- prepara el reporte (se puede probar sin petar el juego)
function errores.preparar(msg)
    local traza = debug.traceback(tostring(msg), 3):gsub("\n[^\n]+boot%.lua[^\n]*", "")
    local partidaTexto
    if errores.partida then
        local ok, t = pcall(errores.partida)
        if ok then partidaTexto = t end
    end
    estado = { error = tostring(msg) }
    local ok, nombre, contenido = pcall(reporte.guardar, "(el juego se cerro solo)", traza, partidaTexto)
    if ok then estado.nombre, estado.contenido = nombre, contenido end
end

local function visibles()
    local lista = {}
    for _, b in ipairs(BOTONES) do
        if not b.pc or (estado.nombre and reporte.puedeAbrirCarpeta()) then table.insert(lista, b) end
    end
    return lista
end

function errores.dibujar()
    lg.clear(p.azulosc)
    local e, ox, oy = escala()
    lg.push()
    lg.translate(ox, oy)
    lg.scale(e)
    fuentes.texto("VAYA, ALGO SE HA ROTO", 0, 70, 4, p.amarillo, "center", 640)
    local lineas = {}
    if estado.nombre then
        table.insert(lineas, { "HEMOS GUARDADO UN REPORTE CON EL ERROR Y TU PARTIDA:", p.blanco })
        table.insert(lineas, { estado.nombre:upper(), p.lima })
        table.insert(lineas, { "MÁNDASELO AL DESARROLLADOR PARA QUE LO ARREGLE. ¡GRACIAS!", p.blanco })
    else
        table.insert(lineas, { "NO SE HA PODIDO GUARDAR EL REPORTE", p.naranja })
    end
    table.insert(lineas, { "TU PARTIDA SIGUE COMO SE GUARDÓ POR ÚLTIMA VEZ", p.grisclaro })
    if estado.copiado ~= nil then
        table.insert(lineas, { estado.copiado and "COPIADO: PÉGALO EN UN CORREO O UN MENSAJE" or "NO SE HA PODIDO COPIAR", p.lima })
    end
    local y = 120
    for _, l in ipairs(lineas) do
        fuentes.texto(l[1], 0, y, 1, l[2], "center", 640)
        y = y + 12
    end
    -- el error, corto y con lo que la fuente sabe pintar
    local corto = fuentes.limpiar(estado.error:upper()):sub(1, 150)
    fuentes.parrafo(corto, 120, 200, p.grisclaro, 400)
    for _, b in ipairs(visibles()) do
        if b.id ~= "copiar" or estado.contenido then
            lg.setColor(p.negro)
            lg.rectangle("fill", b.x, 280, b.w, 20)
            lg.setColor(b.id == "salir" and p.gris or p.azul)
            lg.rectangle("fill", b.x + 1, 281, b.w - 2, 18)
            fuentes.texto(b.texto, b.x, 287, 1, p.blanco, "center", b.w)
        end
    end
    lg.pop()
end

-- devuelve "salir" si hay que cerrar
function errores.pulsar(px, py)
    local e, ox, oy = escala()
    local x, y = (px - ox) / e, (py - oy) / e
    for _, b in ipairs(visibles()) do
        if x >= b.x and x <= b.x + b.w and y >= 276 and y <= 304 then
            if b.id == "salir" then return "salir" end
            if b.id == "copiar" and estado.contenido then estado.copiado = reporte.copiar(estado.contenido) end
            if b.id == "carpeta" then reporte.abrirCarpeta() end
        end
    end
end

local function pantalla(msg)
    print(debug.traceback(tostring(msg), 3))
    -- en las pruebas automaticas no se espera a nadie
    if os.getenv("OLP_PRUEBA") then return function() return 1 end end
    errores.preparar(msg)
    if love.audio then love.audio.stop() end
    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
    end
    if love.keyboard then love.keyboard.setTextInput(false) end
    lg.reset()
    lg.setCanvas()
    -- se prueba a pintar una vez: si peta, que salga la de LOVE
    errores.dibujar()
    return function()
        love.event.pump()
        for nombre, a, b in love.event.poll() do
            if nombre == "quit" then return 1 end
            if nombre == "keypressed" and a == "escape" then return 1 end
            -- en el movil los toques tambien llegan como clicks
            if nombre == "mousepressed" and errores.pulsar(a, b) == "salir" then return 1 end
        end
        local ok = pcall(errores.dibujar)
        if not ok then return 1 end
        lg.present()
        if love.timer then love.timer.sleep(0.05) end
    end
end

function errores.instalar()
    local original = love.errorhandler or love.errhand
    love.errorhandler = function(msg)
        local ok, bucle = pcall(pantalla, msg)
        if ok and bucle then return bucle end
        return original(msg)
    end
end

return errores
