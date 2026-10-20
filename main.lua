local p = require "datos.paleta"
local mercado = require "src.mercado"
local fuentes = require "src.fuentes"
local carta = require "src.carta"
local sobre = require "src.sobre"
local caja = require "src.caja"
local encima = require "src.encima"
local sonido = require "src.sonido"
local fx = require "src.fx"
local ui = require "src.ui"
local nav = require "src.nav"
local partida = require "src.partida"
local dev = require "src.dev"
local apertura = require "src.apertura"
local tienda = require "src.tienda"
local armario = require "src.armario"
local movil = require "src.movil"
local menu = require "src.menu"
local intro = require "src.firma"
local escritorio = require "src.escritorio"
local mesa = require "src.mesa"
local directo = require "src.directo"

local lg = love.graphics

local ANCHO, ALTO = 640, 360
local pantalla
local escena = "intro"
local escenas = { tienda = tienda, mesa = mesa, armario = armario, movil = movil, menu = menu }
local dineroVisto = 0

-- escala para llenar la ventana sin deformar: puede no ser entera (pantallas
-- que no son 1080p, o Windows con el escalado al 125%)
local function escalaVentana()
    local w, h = lg.getDimensions()
    local e = math.min(w / ANCHO, h / ALTO)
    return e, math.floor((w - ANCHO * e) / 2 + 0.5), math.floor((h - ALTO * e) / 2 + 0.5)
end

local function aJuego(x, y)
    local e, ox, oy = escalaVentana()
    return (x - ox) / e, (y - oy) / e
end

local function raton()
    return aJuego(love.mouse.getPosition())
end

-- se guarda aparte de la partida: es del ordenador, no de la partida
local ARCHIVO_PANTALLA = "pantalla.txt"

function nav.pantallaCompleta()
    return (love.window.getFullscreen())
end

function nav.alternarPantalla()
    local completa = not love.window.getFullscreen()
    love.window.setFullscreen(completa, "desktop")
    love.filesystem.write(ARCHIVO_PANTALLA, completa and "completa" or "ventana")
end

local function bloqueado()
    return (escena == "mesa" and apertura.bloqueada()) or (escena == "movil" and movil.ocupado())
end

function nav.ir(nombre)
    sonido.carga(0)
    -- el movil del directo es el mismo: si lo coges, se acaba el directo
    if nombre == "movil" then directo.terminar() end
    if nombre == "menu" then directo.terminar(true) end
    if escena == "movil" and nombre ~= "movil" then
        -- primero se guarda el movil y luego se cambia de pantalla
        movil.guardar(function() escena = nombre end)
        return
    end
    if nombre == "movil" and escena ~= "movil" then movil.sacar() end
    escena = nombre
end

function nav.empezar()
    dineroVisto = partida.dinero
    movil.reiniciar()
    armario.reiniciar()
    directo.reiniciar()
    mesa.reiniciar()
    nav.ir("mesa")
end

-- los sobres ya solo se abren en la mesa
function nav.abrir()
    nav.ir("mesa")
end

function nav.lote(n)
    if apertura.lote(n) then escena = "mesa" end
end

-- pasar el dia corta el directo
function nav.pasarDia()
    directo.terminar()
    movil.pasarDia()
end

function nav.verCarta(id)
    armario.seleccionar(id)
    nav.ir("armario")
end

function nav.ficha(id, primera)
    movil.abrirFicha(id, primera)
    nav.ir("movil")
end

function love.load()
    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("rough")
    pantalla = lg.newCanvas(ANCHO, ALTO)
    if love.filesystem.read(ARCHIVO_PANTALLA) == "completa" then
        love.window.setFullscreen(true, "desktop")
    end
    fuentes.preparar()
    carta.preparar()
    sobre.preparar()
    caja.preparar()
    sonido.preparar()
    escritorio.preparar()
    movil.preparar()
    mesa.preparar()
    partida.cargar()
    menu.preparar()
    dineroVisto = partida.dinero
    intro.empezar(function() escena = "menu" end)
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    fx.update(dt)
    dineroVisto = fx.lerp(dineroVisto, partida.dinero, math.min(1, dt * 8))
    partida.update(dt)
    -- premios por completar sets: aviso, confeti y monedas
    local premio = table.remove(partida.premiosNuevos, 1)
    if premio then
        local texto = "PREMIO: " .. premio.texto .. " +" .. premio.sobres .. " SOBRES"
        if premio.dinero then texto = texto .. " Y " .. ui.dinero(premio.dinero) end
        movil.avisar(texto, p.amarillo)
        fx.confeti(320, 40, 60, 160)
        sonido.tocar("moneda")
        partida.guardar()
    end
    -- encargos del movil terminados o caducados
    local hecho = table.remove(partida.encargosHechos, 1)
    if hecho then
        movil.avisar("ENCARGO DE " .. hecho.nombre:upper() .. " HECHO: +" .. ui.dinero(hecho.pago), p.lima)
        fx.monedas(320, 40, 30, 160, 200)
        sonido.tocar("moneda")
        partida.guardar()
    end
    local caducado = table.remove(partida.encargosCaducados, 1)
    if caducado then movil.avisar("SE ACABÓ EL PLAZO DEL ENCARGO DE " .. caducado.nombre:upper(), p.naranja) end
    local dtJuego = dt * fx.escalaTiempo()
    if escena == "intro" then
        intro.update(dt)
    elseif escena == "mesa" then
        mesa.update(dtJuego)
    end
    directo.update(dt, escena == "mesa")
    movil.update(dt)
end

function love.mousepressed(x, y, boton)
    if escena == "intro" then
        intro.saltar()
        return
    end
    if boton ~= 1 then return end
    local mx, my = aJuego(x, y)
    local id = ui.click(mx, my)
    if ui.clickModal(id) or ui.clickOverlay(id) then
        if id then sonido.tocar("click") end
        return
    end
    -- en las listas del movil el click se resuelve al soltar (se puede arrastrar)
    if escena == "movil" and movil.presionar(id, mx, my) then return end
    if id then sonido.tocar("click") end

    if id and id:match("^dev_") then
        dev.click(id)
    elseif id == "ir_dev" then
        dev.abierto = not dev.abierto
    elseif id == "ir_tienda" or id == "ir_mesa" or id == "ir_armario" or id == "ir_movil" then
        nav.ir(id:sub(4))
    elseif id and id:match("^set_") then
        armario.click(id)
    elseif escena == "mesa" then
        mesa.presionar(id, mx, my)
    elseif escena == "armario" then
        if not armario.coger(id, mx, my) and id then armario.click(id) end
    elseif id and escenas[escena] then
        escenas[escena].click(id)
    end
end

function love.mousereleased(x, y, boton)
    if boton ~= 1 then return end
    movil.soltar()
    armario.acabarBarrido()
    if escena == "mesa" then mesa.soltar(aJuego(x, y)) end
    if not ui.cogida then return end
    local mx, my = aJuego(x, y)
    armario.soltar(ui.soltar(), mx, my)
end

function love.mousemoved(x, y)
    local mx, my = aJuego(x, y)
    ui.moverRaton(mx, my)
    if escena == "armario" then armario.mover(mx, my) end
    if escena == "mesa" then mesa.mover(mx, my) end
    if escena == "movil" then movil.arrastrar(mx, my) end
end

function love.wheelmoved(_, y)
    if escena == "movil" then movil.rueda(y) end
end

function love.textinput(t)
    directo.texto(t)
end

local ORDEN = { "tienda", "mesa", "armario", "movil" }

function love.keypressed(tecla)
    -- escribiendo el nombre del canal las teclas son letras
    if directo.tecla(tecla) then return end
    local alt = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
    if tecla == "f11" or (tecla == "return" and alt) then
        nav.alternarPantalla()
        return
    end
    if escena == "intro" and tecla ~= "escape" then
        intro.saltar()
        return
    end
    if ui.modal or ui.overlay then
        if tecla == "escape" then ui.modal, ui.overlay = nil, nil end
        return
    end
    if tecla == "f1" then
        dev.abierto = not dev.abierto
    elseif tecla == "escape" and escena == "armario" and armario.tecla("escape") then
        return
    elseif tecla == "escape" then
        if escena == "menu" then
            love.event.quit()
        elseif not bloqueado() then
            partida.guardarYa()
            nav.ir("menu")
        end
    elseif escena == "menu" then
        return
    elseif tecla == "d" and not bloqueado() then
        nav.pasarDia()
    elseif tecla == "space" then
        if escena == "mesa" then mesa.espacio() end
    elseif tecla == "tab" and not bloqueado() then
        for i, n in ipairs(ORDEN) do
            if n == escena then
                nav.ir(ORDEN[i % #ORDEN + 1])
                return
            end
        end
        nav.ir("armario")
    elseif escena == "armario" then
        armario.tecla(tecla)
    elseif escena == "movil" then
        movil.tecla(tecla)
    end
end

function love.quit()
    directo.terminar(true)
    if escena ~= "intro" and escena ~= "menu" then partida.guardarYa() end
end

local function dibujarBarra()
    lg.setColor(p.negro)
    lg.rectangle("fill", 0, 0, ANCHO, 20)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", 0, 20, ANCHO, 1)

    if not bloqueado() then
        ui.boton("ir_tienda", "TIENDA", 6, 3, 38, 14, escena == "tienda" and p.verde or p.gris)
        ui.boton("ir_mesa", "MESA", 47, 3, 34, 14, escena == "mesa" and p.verde or (directo.activo() and p.rojo or p.gris))
        ui.boton("ir_armario", "ARMARIO", 84, 3, 42, 14, escena == "armario" and p.verde or p.gris)
        local ofertas = partida.ofertasTotales()
        ui.boton("ir_movil", ofertas > 0 and ("MÓVIL (" .. ofertas .. ")") or "MÓVIL", 129, 3, 50, 14, escena == "movil" and p.verde or (ofertas > 0 and p.naranja or p.gris))
        if ui.encima == "ir_movil" and directo.activo() then
            ui.tooltip("Se acaba el directo", p.rojo, { { "El móvil es el que graba" } })
        end
    end
    ui.boton("ir_dev", "DEV", 182, 3, 24, 14, dev.abierto and p.naranja or p.grisosc)
    if escena == "armario" then armario.pestanas() end

    local dinero = ui.dinero(dineroVisto)
    local x = ANCHO - 8 - fuentes.ancho(dinero, 2)
    fuentes.texto(dinero, x, 4, 2, p.amarillo)
    local info = "DÍA " .. mercado.dia() .. "   SOBRES " .. partida.sobresGuardados()
    local ix = x - 12 - fuentes.ancho(info)
    fuentes.texto(info, ix, 8, 1, p.grisclaro)
    -- fuera de la mesa se ve que sigues en directo
    if escena ~= "mesa" and directo.activo() then
        local cad = "EN DIRECTO " .. directo.espectadores()
        directo.indicador(ix - 14 - fuentes.ancho(cad) - 7, 8)
    end
end

-- primero se amplia con pixeles duros al entero de arriba y luego se reduce
-- suavizado a la escala exacta: llena la pantalla y el pixel sigue nitido
local grande, factorGrande

-- conMesa: el escritorio de fondo por toda la ventana (si no, negro);
-- conBarra: la barra de arriba se alarga de lado a lado
local function presentar(conMesa, conBarra)
    lg.setCanvas()
    local e, ox, oy = escalaVentana()
    local k = math.max(1, math.ceil(e - 0.001))
    if factorGrande ~= k then
        grande = lg.newCanvas(ANCHO * k, ALTO * k)
        grande:setFilter("linear", "linear")
        factorGrande = k
    end

    lg.setCanvas(grande)
    lg.clear(0, 0, 0, 0)
    lg.setBlendMode("alpha", "premultiplied")
    lg.draw(pantalla, 0, 0, 0, k, k)
    lg.setCanvas()

    lg.setBlendMode("alpha")
    lg.clear(p.negro[1], p.negro[2], p.negro[3])
    if conMesa then escritorio.dibujar(e, ox, oy, fx.tinteMesa()) end
    if conBarra then
        local w = lg.getDimensions()
        lg.setColor(p.negro)
        lg.rectangle("fill", 0, 0, w, oy + 20 * e)
        lg.setColor(p.grisosc)
        lg.rectangle("fill", 0, oy + 20 * e, w, math.max(1, e))
        lg.setColor(1, 1, 1)
    end
    lg.setBlendMode("alpha", "premultiplied")
    lg.draw(grande, ox, oy, 0, e / k, e / k)
    lg.setBlendMode("alpha")
    -- lo que gira (la mano, la caja volando) va encima a la resolucion real
    encima.dibujar(e, ox, oy)
end

function love.draw()
    ui.empezar(raton())

    lg.setCanvas(pantalla)
    if escena == "intro" then
        intro.dibujar(ANCHO, ALTO)
        presentar(false, false)
        return
    end
    lg.clear(0, 0, 0, 0)

    local dx, dy = fx.desplazamiento()
    lg.push()
    lg.translate(dx, dy)
    escenas[escena].dibujar()
    fx.dibujarParticulas()
    lg.pop()

    if escena ~= "menu" then
        dibujarBarra()
        if escena ~= "movil" then movil.dibujarToast() end
        dev.dibujar()
    end
    fx.dibujarDestello(ANCHO, ALTO)
    ui.dibujarOverlay(ANCHO, ALTO)
    ui.dibujarTooltip(ANCHO, ALTO)
    ui.dibujarModal(ANCHO, ALTO)
    presentar(true, escena ~= "menu")
end
