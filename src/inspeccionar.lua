-- INSPECCIONAR: una carta en grande que se gira (clic derecho, doble toque, F
-- o arrastrando a los lados) para ver el dorso de su funda, con una ficha
-- para elegir la copia, la funda y el top (lo que quitas vuelve a su caja).
-- Lo abren la mesa, el armario y el album; lo reutilizaran la carpeta y el gradeo.
local p = require "datos.paleta"
local rarezas = require "datos.rarezas"
local sets = require "datos.sets"
local datosFundas = require "datos.fundas"
local partida = require "src.partida"
local mercado = require "src.mercado"
local carta = require "src.carta"
local fundasDib = require "src.fundas"
local fuentes = require "src.fuentes"
local muebles = require "src.muebles"
local desbloqueos = require "src.desbloqueos"
local sonido = require "src.sonido"
local fx = require "src.fx"
local ui = require "src.ui"

local lg = love.graphics
local inspeccionar = {}

local CW, CH = carta.ANCHO, carta.ALTO
local E = 4                          -- la carta a x4
local CX, CY = 170, 176              -- centro de la carta
local FX, FY, FW = 330, 40, 290      -- la ficha
-- giro en 5 fotogramas: frente, se estrecha, canto, se ensancha, dorso
local GIRO = { 1, 0.55, 0.12, 0.55, 1 }
local PASO = 0.05

local st -- { id, u, cara, giro, pulsado, ultimo, opciones }

local function copia()
    return st and partida.copia(st.id, st.u)
end

local function copias()
    return partida.lista(st.id)
end

-- ancho y lado que se ve ahora (con el giro a medias)
local function vista()
    if not st.giro then return 1, st.cara end
    local f = math.min(#GIRO, math.floor(st.giro.t / PASO) + 1)
    local cara = st.giro.desde
    if f >= 4 then cara = not st.giro.desde end
    return GIRO[f], cara, f == 3
end

local function girar()
    if st.giro then return end
    st.giro = { t = 0, desde = st.cara }
    sonido.tocar("encima", st.cara and 0.9 or 1.1)
end

-- opciones de funda o de top: nil (sin), true (la basica) y los disenos que
-- tienes (y el que lleva puesto)
local function opciones(esTop)
    local c = copia()
    local puesto = esTop and c.t or c.f
    local l = { false }
    local de = esTop and partida.topsDe or partida.fundasDe
    if de(true) > 0 or puesto == true then table.insert(l, true) end
    for _, d in ipairs(esTop and datosFundas.tops or datosFundas.lista) do
        if de(d.id) > 0 or puesto == d.id then table.insert(l, d.id) end
    end
    return l, puesto or false
end

local function cambiar(esTop, paso)
    local c = copia()
    if not c then return end
    local l, puesto = opciones(esTop)
    local pos = 1
    for i, x in ipairs(l) do if x == puesto then pos = i end end
    local nuevo = l[(pos - 1 + paso) % #l + 1]
    if nuevo == puesto then return end
    local bien
    if esTop then
        if nuevo == false then bien = partida.quitarTop(c)
        else bien = partida.cambiarTop(c, nuevo) end
    else
        if nuevo == false then bien = partida.desenfundarCopia(c)
        else bien = partida.cambiarFunda(c, nuevo) end
    end
    if bien then
        sonido.tocar(nuevo and "nueva" or "giro")
        if nuevo then fx.explosion(CX, CY, fundasDib.color(nuevo, esTop), 10, 60) end
        partida.guardar()
    end
end

local function nombreDe(id, esTop)
    if id == false or id == nil then return esTop and "SIN TOP" or "SIN FUNDA" end
    return datosFundas.nombre(id, esTop)
end

-- la carta grande, de frente o de dorso (con el giro a medias)
local function dibujarCarta(def, c)
    local sx, cara, canto = vista()
    -- sombra
    lg.setColor(0, 0, 0, 0.4)
    lg.rectangle("fill", CX - CW * E * sx / 2 + 4, CY - CH * E / 2 + 6, CW * E * sx, CH * E)
    if canto then
        local col = c.f and fundasDib.color(c.f) or p.grisclaro
        muebles.rect(p.negro, CX - 3, CY - CH * E / 2 - 1, 6, CH * E + 2)
        muebles.rect(col, CX - 2, CY - CH * E / 2, 4, CH * E)
        muebles.rect(p.blanco, CX - 1, CY - CH * E / 2 + 4, 1, CH * E - 8, 0.5)
        return
    end
    if cara then
        -- la de torneo es apaisada: se enseña tumbada
        local rot = def.estilo == "apaisada" and -math.pi / 2 or 0
        carta.dibujar(def, CX, CY, E * sx, E, rot, true, nil, c.f, { primera = c.p, top = c.t, quieta = true })
    else
        -- por detras: el dorso de la carta (con funda, su dibujo) y el top encima
        if c.f then
            lg.setColor(1, 1, 1)
            lg.draw(fundasDib.dorso(c.f), CX, CY, 0, E * sx, E, fundasDib.W / 2, fundasDib.H / 2)
        else
            carta.dibujar(def, CX, CY, E * sx, E, 0, false)
        end
        if c.t then
            local col = fundasDib.color(c.t, true)
            local w, h = (CW + 6) * E * sx, (CH + 7) * E
            lg.setColor(col[1], col[2], col[3], 0.35)
            lg.rectangle("fill", CX - w / 2, CY - h / 2, w, 2 * E)
            lg.setColor(col[1], col[2], col[3], 0.8)
            lg.setLineWidth(2)
            lg.rectangle("line", CX - w / 2, CY - h / 2, w, h)
            lg.setLineWidth(1)
        end
    end
    lg.setShader()
    lg.setColor(1, 1, 1)
end

-- fila con flechas: ETIQUETA  <  valor  >
local function fila(y, etiqueta, valor, color, idm, idM, activo)
    fuentes.texto(etiqueta, FX + 8, y + 3, 1, p.grisclaro)
    ui.boton(idm, "<", FX + 60, y, 14, 12, p.azul, activo)
    muebles.rect(p.negro, FX + 76, y, FW - 100, 12, 0.6)
    fuentes.texto(valor, FX + 76, y + 3, 1, color, "center", FW - 100)
    ui.boton(idM, ">", FX + FW - 22, y, 14, 12, p.azul, activo)
end

local function dibujar(ancho, alto)
    local c = copia()
    if not c then
        -- ya no esta (vendida): se pasa a otra o se cierra
        local l = partida.lista(st.id)
        if #l == 0 then ui.overlay = nil return end
        st.u = l[1].u
        c = l[1]
    end
    local def = partida.carta(st.id)
    local r = rarezas.de(def)
    lg.setColor(0, 0, 0, 0.82)
    lg.rectangle("fill", ui.izq or 0, 0, (ui.der or ancho) - (ui.izq or 0), alto)

    dibujarCarta(def, c)
    ui.zona("insp_carta", CX - CW * E / 2, CY - CH * E / 2, CW * E, CH * E)
    local _, cara = vista()
    fuentes.texto(cara and "DE FRENTE" or "POR DETRÁS", CX - 80, CY + CH * E / 2 + 10, 1, p.grisclaro, "center", 160)
    fuentes.texto(ui.tactil and "DOBLE TOQUE O ARRASTRA PARA GIRARLA" or "CLIC DERECHO, F O ARRASTRA PARA GIRARLA",
        CX - 120, CY + CH * E / 2 + 19, 1, p.gris, "center", 240)

    -- ficha
    ui.caja(FX, FY, FW, 286)
    fuentes.texto(rarezas.nombre(def):upper(), FX + 8, FY + 7, 2, p.blanco)
    fuentes.texto(r.nombre .. (def.chase and " - CHASE" or "") .. "   " .. sets[def.set].nombre:upper() .. " #" .. def.num,
        FX + 8, FY + 21, 1, r.color)
    ui.boton("insp_cerrar", "X", FX + FW - 18, FY + 4, 14, 12, p.rojo)
    local l = copias()
    local pos = 1
    for i, x in ipairs(l) do if x.u == st.u then pos = i end end
    local y = FY + 36
    fila(y, "COPIA", pos .. " DE " .. #l .. (c.p and "  1ª ED" or ""), c.p and p.amarillo or p.blanco, "insp_copia_-1", "insp_copia_1", #l > 1)
    y = y + 16
    local libre = not c.a
    local vendible = not c.a and not c.k and partida.vendible(st.id)
    if desbloqueos.hay("fundas") then
        fila(y, "FUNDA", nombreDe(c.f), c.f and fundasDib.color(c.f) or p.gris, "insp_funda_-1", "insp_funda_1", libre and #opciones(false) > 1)
        y = y + 16
    end
    if desbloqueos.hay("tops") then
        fila(y, "TOP", nombreDe(c.t, true), c.t and fundasDib.color(c.t, true) or p.gris, "insp_top_-1", "insp_top_1", libre and #opciones(true) > 1)
        y = y + 16
    end
    if c.a then fuentes.texto("A LA VENTA EN EL MÓVIL", FX + 8, y + 2, 1, p.naranja) y = y + 10 end
    if c.m then fuentes.texto("ESTÁ EN LA MESA", FX + 8, y + 2, 1, p.lima) y = y + 10 end
    if c.k then
        local k = partida.carpeta(c.k)
        fuentes.texto("EN LA CARPETA " .. (k and k.nombre or ""), FX + 8, y + 2, 1, p.naranja)
        y = y + 10
    end
    fuentes.texto("LO QUE CAMBIAS VUELVE A SU CAJA. FUNDAS Y TOPS NO CAMBIAN EL PRECIO", FX + 8, y + 4, 1, p.gris, "left", FW - 16)
    y = y + 22

    -- tus copias en fila
    fuentes.texto("TUS COPIAS", FX + 8, y, 1, p.grisclaro)
    y = y + 10
    local desde = math.max(1, math.min(pos - 3, #l - 6))
    for i = desde, math.min(#l, desde + 6) do
        local x = FX + 24 + (i - desde) * 40
        local cc = l[i]
        carta.dibujar(def, x, y + 26, 0.9, 0.9, 0, true, nil, cc.f, { primera = cc.p, top = cc.t, quieta = true })
        lg.setShader()
        if cc.u == st.u then
            lg.setColor(p.amarillo)
            lg.rectangle("line", x - 19.5, y + 2.5, 39, 49)
        end
        ui.zona("insp_c" .. i, x - 18, y + 2, 36, 48)
    end
    y = y + 60

    -- botones
    local valor = mercado.ventaRapida(st.id, c.p)
    ui.boton("insp_vender", "VENDER ESTA +" .. ui.dinero(valor), FX + 8, y, 136, 16, #l == 1 and p.rojo or p.naranja, vendible)
    if st.opciones.carpeta then
        ui.boton("insp_sacar", "SACAR DE LA CARPETA", FX + 150, y, FW - 158, 16, p.azul)
    elseif st.opciones.alArmario and c.m then
        ui.boton("insp_armario", "AL ARMARIO", FX + 150, y, FW - 158, 16, p.azul)
    end
    ui.boton("insp_vale", "CERRAR", FX + 8, FY + 286 - 22, FW - 16, 16, p.gris)
    lg.setColor(1, 1, 1)
end

-- elegir otra copia; desde una carpeta, cambia la del bolsillo (las del movil no valen)
local function elegirCopia(u)
    local k = st.opciones.carpeta
    if k then
        local nueva = partida.copia(st.id, u)
        if not nueva or nueva.a then
            fx.texto(ui.mx, ui.my - 10, "ESTÁ EN EL MÓVIL", p.naranja)
            return
        end
        if partida.cambiarCopiaCarpeta(k.cid, k.slot, u) then partida.guardar() end
    end
    st.u = u
end

local function click(id)
    local c = copia()
    if id == "insp_cerrar" or id == "insp_vale" then
        ui.overlay = nil
        return
    end
    if not c then return end
    if id == "insp_carta" then
        local ahora = love.timer.getTime()
        if st.ultimo and ahora - st.ultimo < 0.35 then
            girar()
            st.ultimo = nil
        else
            st.ultimo = ahora
        end
        st.pulsado = { x = ui.mx }
        return
    end
    local paso = tonumber(id:match("^insp_copia_(%-?1)$") or "")
    if paso then
        local l = copias()
        local pos = 1
        for i, x in ipairs(l) do if x.u == st.u then pos = i end end
        elegirCopia(l[(pos - 1 + paso) % #l + 1].u)
        return
    end
    paso = tonumber(id:match("^insp_funda_(%-?1)$") or "")
    if paso then return cambiar(false, paso) end
    paso = tonumber(id:match("^insp_top_(%-?1)$") or "")
    if paso then return cambiar(true, paso) end
    local i = tonumber(id:match("^insp_c(%d+)$") or "")
    if i then
        local l = copias()
        if l[i] then elegirCopia(l[i].u) end
        return
    end
    if id == "insp_sacar" and st.opciones.carpeta then
        local k = st.opciones.carpeta
        partida.sacarDeCarpeta(k.cid, k.slot)
        partida.guardar()
        sonido.tocar("giro")
        ui.overlay = nil
        return
    end
    if id == "insp_armario" and st.opciones.alArmario then
        st.opciones.alArmario(c)
        ui.overlay = nil
        return
    end
    if id == "insp_vender" then
        local def = partida.carta(st.id)
        local u = st.u
        local function hacer()
            local ganado = partida.venderCopias(st.id, { u })
            if ganado and ganado > 0 then
                sonido.tocar("moneda")
                fx.texto(FX + 76, FY + 200, "+" .. ui.dinero(ganado), p.amarillo)
                partida.guardar()
            end
        end
        if #copias() == 1 then
            local overlay = ui.overlay
            ui.confirmar("¿VENDER LA ÚLTIMA?", { "ES TU ÚNICA COPIA DE " .. rarezas.nombre(def):upper(), "DESAPARECERÁ DEL ÁLBUM" },
                "SÍ, VENDERLA", function()
                    hacer()
                    if overlay == ui.overlay then ui.overlay = nil end
                end)
        else
            hacer()
        end
    end
end

local function soltar(x)
    if st and st.pulsado then
        if math.abs(x - st.pulsado.x) > 24 then girar() end
        st.pulsado = nil
    end
end

local function tecla(t)
    if t == "f" then girar() return true end
    if t == "left" then click("insp_copia_-1") return true end
    if t == "right" then click("insp_copia_1") return true end
    return false
end

function inspeccionar.update(dt)
    if not st or not st.giro then return end
    st.giro.t = st.giro.t + dt
    if st.giro.t >= #GIRO * PASO then
        st.cara = not st.giro.desde
        st.giro = nil
    end
end

function inspeccionar.abierto()
    return st ~= nil and ui.overlay ~= nil and ui.overlay.inspeccionar == true
end

-- abre la carta id (copia u, o la primera); opciones.alArmario(c): boton AL
-- ARMARIO para las de la mesa
function inspeccionar.abrir(id, u, opc)
    if partida.copias(id) == 0 then return end
    if not u or not partida.copia(id, u) then u = partida.lista(id)[1].u end
    st = { id = id, u = u, cara = true, opciones = opc or {} }
    ui.overlay = { dibujar = dibujar, click = click, derecho = girar, soltar = soltar, tecla = tecla, inspeccionar = true }
    sonido.tocar("encima", 1.2)
end

-- para las pruebas
function inspeccionar.estado() return st end
inspeccionar.girar = girar
inspeccionar.vista = vista

return inspeccionar
