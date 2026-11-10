-- Tutorial con la mascota (la croqueta). Tres capas:
--  1. intro de la partida nueva: 3 pasos en la mesa, no bloquea nada.
--  2. avisos de desbloqueo (src/desbloqueos.lua): los de la mesa salen aqui;
--     los de otras pantallas son un toast y un punto rojo (src/guia.lua).
--  3. explicaciones de cada pantalla y app (datos/guia.lua): la primera vez
--     que entras salen solas y oscurecen lo demas hasta cerrarlas; con el ?
--     de la barra se vuelven a ver.
-- Ademas, la primera vez que coges el movil en directo, avisa de que se corta.
-- partida.tutorial: paso de la intro, o false si ya se acabo o se salto
local p = require "datos.paleta"
local datos = require "datos.guia"
local datosDesbloqueos = require "datos.desbloqueos"
local partida = require "src.partida"
local directo = require "src.directo"
local apertura = require "src.apertura"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"
local ui = require "src.ui"
local desbloqueos = require "src.desbloqueos"
local guia = require "src.guia"
local opciones = require "src.opciones"
local encima = require "src.encima"
local movil = require "src.movil"
local transicion = require "src.transicion"

local lg = love.graphics

local tutorial = {}

-- cuando se da por hecho cada paso de la intro (el texto, en datos/guia.lua)
local HECHO = {
    [2] = function() return directo.activo() end,
    [3] = function() return partida.abiertos > 0 and not apertura.bloqueada() end,
}
local INTRO = datos.intro

local abierta    -- explicacion abierta: { pasos, i, bloquea, escena }
local pregunta   -- coger el movil en directo: { accion }
local t = 0

function tutorial.activo()
    return partida.tutorial and INTRO[partida.tutorial] ~= nil
end

-- mientras hay algo que leer delante, el juego no recibe clics ni teclas
function tutorial.bloquea()
    return pregunta ~= nil or (abierta ~= nil and abierta.bloquea)
end

local function terminar()
    partida.tutorial = false
    desbloqueos.vale(datosDesbloqueos.esperaTutorial)
    partida.guardar()
end

local function siguiente()
    partida.tutorial = partida.tutorial + 1
    if not INTRO[partida.tutorial] then
        terminar()
        sonido.tocar("nueva")
    else
        sonido.tocar("encima", 1.4)
    end
    partida.guardar()
end

-- la mascota: se pinta encima a la resolucion de la pantalla para que se
-- vea tal cual es el dibujo (en el lienzo de 640x360 se emborronaria)
local imagenes = {}
local ALTO = 70           -- lo que mide la pose mas alta, en pixeles del juego
local ALTO_IMAGEN = 1936  -- alto de esa pose en el archivo
local ESCALA = ALTO / ALTO_IMAGEN
tutorial.ANCHO_MASCOTA = 56

local function imagen(pose)
    if imagenes[pose] == nil then
        local ok, img = pcall(lg.newImage, "sprites/mascota_" .. pose .. ".png", { mipmaps = true })
        if ok then
            img:setFilter("linear", "linear")
            img:setMipmapFilter("linear")
        end
        imagenes[pose] = ok and img or false
    end
    return imagenes[pose] or nil
end

-- x: borde izquierdo; abajo: donde apoya los pies
local function mascota(pose, x, abajo)
    local img = imagen(pose or "saludo")
    if not img then return end
    local y = abajo - img:getHeight() * ESCALA + math.sin(t * 2.5) * 1.2
    encima.anotar(function()
        lg.setColor(1, 1, 1)
        lg.draw(img, x, y, 0, ESCALA, ESCALA)
    end)
end

-- todo oscuro menos lo que se señala
local function oscurecer(z)
    local x0, x1 = ui.izq or 0, ui.der or 640
    lg.setColor(0, 0, 0, 0.6)
    if not z then
        lg.rectangle("fill", x0, 0, x1 - x0, 360)
        return
    end
    local a, b, c, d = z.x - 4, z.y - 4, z.x + z.w + 4, z.y + z.h + 4
    lg.rectangle("fill", x0, 0, x1 - x0, b)
    lg.rectangle("fill", x0, d, x1 - x0, 360 - d)
    lg.rectangle("fill", x0, b, a - x0, d - b)
    lg.rectangle("fill", c, b, x1 - c, d - b)
end

-- marco y flecha sobre lo que hay que tocar
local function flecha(z)
    local a = 0.6 + math.sin(t * 6) * 0.4
    lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], a)
    lg.setLineWidth(2)
    lg.rectangle("line", z.x - 3, z.y - 3, z.w + 6, z.h + 6, 3, 3)
    lg.setLineWidth(1)
    local cx = z.x + z.w / 2
    local bote = math.abs(math.sin(t * 5)) * 5
    lg.setColor(p.amarillo)
    if z.y > 60 then
        local y = z.y - 8 - bote
        lg.polygon("fill", cx - 7, y - 9, cx + 7, y - 9, cx, y)
    else
        local y = z.y + z.h + 8 + bote
        lg.polygon("fill", cx - 7, y + 9, cx + 7, y + 9, cx, y)
    end
end

-- el panel con lo que dice la mascota.
-- d: { titulo, contador, texto, apunta, pose, bloquea, botones = { { id, texto, color }... } }
-- el ultimo boton va a la derecha; los demas, a la izquierda
local function panel(escena, d)
    -- en las listas se señala la primera fila
    local z = d.apunta and ui.rect(d.apunta, d.apunta:sub(-1) == "_")
    if d.bloquea then oscurecer(z) end
    if z then flecha(z) end

    local enMovil = escena == "movil"
    local w = enMovil and 196 or 270
    local _, lineas = fuentes.envolver(d.texto, w - 16)
    local h = 26 + #lineas * fuentes.linea() + 18
    local x, y
    if enMovil then
        x, y = 436, 40
    else
        -- lejos de la flecha; la mascota a la izquierda
        x = math.floor(320 - w / 2 + tutorial.ANCHO_MASCOTA / 2)
        y = (z and z.y + z.h / 2 > 200) and 26 or 360 - h - 6
    end

    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", x + 3, y + 4, w, h, 4, 4)
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 5, 5)
    lg.setColor(p.azulosc)
    lg.rectangle("fill", x, y, w, h, 4, 4)
    lg.setColor(p.amarillo)
    lg.rectangle("fill", x, y, 3, h, 2, 2)

    -- el piquito del bocadillo, hacia la mascota
    local mx, abajo
    if enMovil then
        mx, abajo = x + w - tutorial.ANCHO_MASCOTA - 4, y + h + 8 + ALTO
        local px = x + w - 30
        lg.setColor(p.negro)
        lg.polygon("fill", px - 7, y + h, px + 7, y + h, px, y + h + 8)
        lg.setColor(p.azulosc)
        lg.polygon("fill", px - 5, y + h - 1, px + 5, y + h - 1, px, y + h + 6)
    else
        mx = x - tutorial.ANCHO_MASCOTA - 6
        abajo = math.max(y + h + 2, 22 + ALTO)
        local py = math.min(y + h - 12, abajo - 40)
        lg.setColor(p.negro)
        lg.polygon("fill", x, py - 6, x, py + 6, x - 8, py)
        lg.setColor(p.amarillo)
        lg.polygon("fill", x + 1, py - 4, x + 1, py + 4, x - 5, py)
    end

    fuentes.texto(d.titulo, x + 8, y + 6, 1, p.amarillo)
    if d.contador then fuentes.texto(d.contador, x, y + 6, 1, p.grisclaro, "right", w - 8) end
    fuentes.parrafo(d.texto, x + 8, y + 17, p.blanco, w - 16)

    local by = y + h - 17
    local bx = x + 8
    for i, b in ipairs(d.botones) do
        local bw = math.max(50, fuentes.ancho(b[2]) + 12)
        if i == #d.botones then
            ui.boton(b[1], b[2], x + w - bw - 8, by, bw, 12, b[3])
        else
            ui.boton(b[1], b[2], bx, by, bw, 12, b[3])
            bx = bx + bw + 4
        end
    end
    mascota(d.pose, mx, abajo)
end

-- las explicaciones que miran una pantalla (o la app abierta del movil)
local function claves(escena)
    if escena == "movil" then
        local a = movil.appActual()
        return { a == "inicio" and "movil" or ("app_" .. a) }
    end
    return datos.pantallas[escena] or {}
end

local function abrir(lista, escena, bloquea)
    local pasos = {}
    for _, c in ipairs(lista) do
        for _, paso in ipairs(datos[c].pasos) do
            table.insert(pasos, { titulo = datos[c].titulo, texto = paso.texto, apunta = paso.apunta, pose = paso.pose, armario = paso.armario })
        end
        guia.marcar(c)
    end
    if #pasos == 0 then return end
    abierta = { pasos = pasos, i = 1, bloquea = bloquea, escena = escena }
    sonido.tocar("nueva")
end

-- sin tutorial (OPCIONES) o en las pruebas viejas no se explica nada
local function callada()
    return guia.apagada or not opciones.tutorial
end

-- algo en marcha: no es momento de explicar nada
local function ocupado(escena)
    if transicion.activa() or ui.arrastrando() then return true end
    if escena == "mesa" then return apertura.bloqueada() or directo.editando() end
    if escena == "movil" then return not movil.quieto() end
    return false
end

-- la que toca abrir sola al entrar (o nil)
local function automatica(escena)
    if ocupado(escena) then return nil end
    if callada() then
        -- sin tutorial: lo que ya has visto deja de tener punto rojo
        if not guia.apagada then
            for _, c in ipairs(claves(escena)) do
                if guia.pendiente(c) and (c ~= "venta" or directo.tipo() == "venta") then guia.marcar(c) end
            end
        end
        return nil
    end
    for _, c in ipairs(claves(escena)) do
        local d = datos[c]
        if d and d.auto ~= false and guia.pendiente(c) and (c ~= "venta" or directo.tipo() == "venta") then
            return c
        end
    end
end

-- el ? de la barra: hay algo que explicar aqui
function tutorial.hayAyuda(escena)
    if abierta or pregunta or callada() then return false end
    if escena == "mesa" and tutorial.activo() then return false end
    for _, c in ipairs(claves(escena)) do
        if guia.disponible(c) then return true end
    end
    return false
end

function tutorial.ayuda(escena)
    local lista = {}
    for _, c in ipairs(claves(escena)) do
        if guia.disponible(c) then table.insert(lista, c) end
    end
    abrir(lista, escena, escena ~= "mesa")
end

-- coger el movil en directo: la primera vez se avisa. true si se ha parado
-- para preguntar (accion: lo que se hace si lo coges igual)
function tutorial.avisarMovil(accion)
    if callada() or guia.vista("movilDirecto") then return false end
    pregunta = { accion = accion }
    sonido.tocar("nueva")
    return true
end

local function pintarExplicacion(escena)
    local paso = abierta.pasos[abierta.i]
    local ultimo = abierta.i == #abierta.pasos
    -- en el armario, cada paso abre la pestaña que explica
    if paso.armario and escena == "armario" then require("src.armario").ponerModo(paso.armario) end
    local botones = {}
    if not ultimo then table.insert(botones, { "tut_g_saltar", "SALTAR", p.grisosc }) end
    table.insert(botones, { "tut_g_sig", ultimo and "¡ENTENDIDO!" or "SIGUIENTE", p.verde })
    panel(escena, {
        titulo = paso.titulo, texto = paso.texto, apunta = paso.apunta, pose = paso.pose,
        contador = #abierta.pasos > 1 and (abierta.i .. "/" .. #abierta.pasos) or nil,
        bloquea = abierta.bloquea, botones = botones,
    })
end

function tutorial.dibujar(escena)
    if ui.modal or ui.overlay then return end
    if escena ~= "mesa" and escena ~= "tienda" and escena ~= "armario" and escena ~= "movil" then return end
    t = t + love.timer.getDelta()

    -- una explicacion que no bloquea se cierra al irse de su pantalla
    if abierta and abierta.escena ~= escena then abierta = nil end

    if pregunta then
        local d = datos.movilDirecto
        panel(escena, { titulo = d.titulo, texto = d.pasos[1].texto, pose = d.pasos[1].pose, bloquea = true, apunta = "ir_movil",
            botones = { { "tut_seguir", "SEGUIR EN DIRECTO", p.verde }, { "tut_coger", "COGERLO IGUAL", p.rojo } } })
        return
    end
    if abierta then
        pintarExplicacion(escena)
        return
    end

    -- la intro, en la mesa
    if escena == "mesa" and tutorial.activo() then
        local hecho = HECHO[partida.tutorial]
        if hecho and hecho() then siguiente() end
        if not tutorial.activo() then return end
        local paso = INTRO[partida.tutorial]
        local ultimo = partida.tutorial == #INTRO
        local botones = { { "tut_saltar", ultimo and "TERMINAR TUTORIAL" or "SALTAR TUTORIAL", ultimo and p.verde or p.grisosc } }
        if paso.boton then table.insert(botones, { "tut_sig", paso.boton, p.verde }) end
        panel(escena, { titulo = "TUTORIAL", contador = partida.tutorial .. "/" .. #INTRO, texto = paso.texto,
            apunta = paso.apunta, pose = paso.pose, botones = botones })
        return
    end

    -- la primera vez en esta pantalla (o app)
    local c = automatica(escena)
    if c then
        abrir({ c }, escena, datos[c].bloquea ~= false)
        pintarExplicacion(escena)
        return
    end

    -- avisos de desbloqueo: solo en la mesa, que es donde se usan
    if escena ~= "mesa" or tutorial.activo() then return end
    local a = desbloqueos.siguiente()
    if not a then return end
    local n, total = desbloqueos.posicion()
    panel(escena, { titulo = "¡NUEVO!", contador = total > 1 and (n .. "/" .. total) or nil, texto = a.texto,
        apunta = a.apunta, pose = a.pose or "pulgar", botones = { { "tut_vale", "VALE", p.verde } } })
end

local function cerrar()
    abierta = nil
end

function tutorial.click(id, escena)
    if id == "tut_saltar" then
        terminar()
    elseif id == "tut_sig" then
        siguiente()
    elseif id == "tut_vale" then
        desbloqueos.vale()
        sonido.tocar("encima", 1.4)
    elseif id == "tut_g_sig" and abierta then
        abierta.i = abierta.i + 1
        if abierta.i > #abierta.pasos then cerrar() end
        sonido.tocar("encima", 1.4)
    elseif id == "tut_g_saltar" then
        cerrar()
    elseif id == "tut_ayuda" then
        tutorial.ayuda(escena)
    elseif id == "tut_seguir" then
        guia.marcar("movilDirecto")
        pregunta = nil
    elseif id == "tut_coger" and pregunta then
        guia.marcar("movilDirecto")
        local accion = pregunta.accion
        pregunta = nil
        accion()
    end
end

-- ESC con algo delante: lo cierra (y en el movil, sigue el directo)
function tutorial.escape()
    if pregunta then
        tutorial.click("tut_seguir")
        return true
    end
    if abierta and abierta.bloquea then
        cerrar()
        return true
    end
    return false
end

-- volver a verlo todo desde el menu
function tutorial.repetir()
    partida.tutorial = 1
    guia.reiniciar()
    abierta, pregunta = nil, nil
end

-- al empezar o cargar una partida no queda nada abierto de la anterior
function tutorial.reiniciar()
    abierta, pregunta = nil, nil
end

return tutorial
