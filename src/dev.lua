-- Herramientas de desarrollador para probar partidas. F1 o el boton DEV.
local p = require "datos.paleta"
local sobres = require "datos.sobres"
local cartas = require "datos.cartas"
local partida = require "src.partida"
local mercado = require "src.mercado"
local generador = require "src.generador"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"
local ui = require "src.ui"
local nav = require "src.nav"

local dev = {
    abierto = false,
    velocidad = 1,
    saltar = false,
    scroll = 0,
}

local VELOCIDADES = { 1, 2, 4, 8 }
local X, Y, W = 470, 26, 164

local function botones()
    return {
        { "DINERO" },
        { "dev_dinero1", "+1 €" }, { "dev_dinero10", "+10 €" }, { "dev_dinero100", "+100 €" },
        { "SOBRES" },
        { "dev_sobres5", "+5 DE CADA" }, { "dev_sobres20", "+20 DE CADA" },
        { "dev_productos", "+2 DE CADA PRODUCTO" },
        { "dev_lote5", "ABRIR 5 DE GOLPE" }, { "dev_lote20", "ABRIR 20 DE GOLPE" },
        { "dev_velocidad", "VELOCIDAD x" .. dev.velocidad },
        { "dev_saltar", dev.saltar and "SALTAR ANIMACIÓN: SÍ" or "SALTAR ANIMACIÓN: NO", dev.saltar },
        { "dev_godpack", generador.forzar == "godpack" and "SIGUIENTE: GOD PACK (LISTO)" or "SIGUIENTE: GOD PACK", generador.forzar == "godpack" },
        { "dev_secreta", generador.forzar == "secreta" and "SIGUIENTE: SECRETA (LISTO)" or "SIGUIENTE: SECRETA", generador.forzar == "secreta" },
        { "dev_alt", generador.forzar == "alt" and "SIGUIENTE: ALT (LISTO)" or "SIGUIENTE: ALT", generador.forzar == "alt" },
        { "dev_silver", generador.forzar == "silver" and "SIGUIENTE: SILVER (LISTO)" or "SIGUIENTE: SILVER", generador.forzar == "silver" },
        { "dev_golden", generador.forzar == "golden" and "SIGUIENTE: GOLDEN (LISTO)" or "SIGUIENTE: GOLDEN", generador.forzar == "golden" },
        { "MERCADO" },
        { "dev_dia", "PASAR DÍA" }, { "dev_dia7", "PASAR 7 DÍAS" },
        { "dev_dia16", "PASAR 16 DÍAS" }, { "dev_dia30", "PASAR 30 DÍAS" },
        { "dev_dia100", "PASAR 100 DÍAS" }, { "dev_dia300", "PASAR 300 DÍAS" },
        { "dev_ofertas", "OFERTAS AHORA" }, { "dev_noticia", "NOTICIA AL AZAR" },
        { "dev_burbuja", "BURBUJA EN UNA CHASE" }, { "dev_torneo", "TORNEO NACIONAL" },
        { "dev_moda", "UN SET SE PONE DE MODA" }, { "dev_caida", "UN SET PIERDE INTERÉS" },
        { "dev_crash", "CRASH: ALMACÉN DE 1ª EDICIÓN" },
        { "dev_encargo", "ENCARGO NUEVO" }, { "dev_peticion", "PETICIÓN DEL CHAT" },
        { "COLECCIÓN" },
        { "dev_completar", "+1 DE CADA CARTA" },
    }
end

-- datos de la ventana, para cuando algo se ve raro en otro ordenador
local function infoPantalla()
    local w, h = love.graphics.getDimensions()
    local pw, ph = love.graphics.getPixelDimensions()
    local dw, dh = love.window.getDesktopDimensions()
    local e = math.min(w / 640, h / 360)
    return {
        string.format("VENTANA %dX%d  PIXELES %dX%d", w, h, pw, ph),
        string.format("ESCRITORIO %dX%d  DPI X%.2f", dw, dh, love.window.getDPIScale()),
        string.format("ESCALA X%.2f  %s", e, love.window.getFullscreen() and "PANTALLA COMPLETA" or "VENTANA"),
    }
end

function dev.dibujar()
    if not dev.abierto then return end
    local lista = botones()
    local alto = 16 + 30
    for _, b in ipairs(lista) do alto = alto + (b[2] and 13 or 11) end
    alto = alto + 8 * #infoPantalla()
    -- si no cabe, scroll con la rueda o con SUBIR/BAJAR
    local MAX = 360 - Y - 4
    local hayScroll = alto > MAX
    dev.scroll = math.max(0, math.min(dev.scroll, hayScroll and alto - MAX + 16 or 0))
    local fin = hayScroll and Y + MAX - 15 or Y + alto
    local function cabe(yy, h) return yy >= Y + 12 and yy + h <= fin end
    ui.caja(X, Y, W, math.min(alto, MAX), p.negro)
    local lg = love.graphics
    lg.setColor(p.naranja)
    lg.rectangle("fill", X + 1, Y + 1, W - 2, 10)
    fuentes.texto("HERRAMIENTAS DE DESARROLLADOR", X, Y + 3, 1, p.negro, "center", W)
    local y = Y + 14 - dev.scroll
    local col = 0
    for i, b in ipairs(lista) do
        if not b[2] then
            if col == 1 then y = y + 13 col = 0 end
            if cabe(y, 10) then fuentes.texto(b[1], X + 6, y + 3, 1, p.naranja) end
            y = y + 11
        else
            -- los botones cortos van de dos en dos
            local corto = b[1]:match("^dev_dinero") or b[1]:match("^dev_sobres") or b[1]:match("^dev_dia")
            if corto then
                if cabe(y, 11) then ui.boton(b[1], b[2], X + 6 + col * 77, y, 75, 11, p.gris) end
                col = col + 1
                local siguiente = lista[i + 1]
                local sigCorto = siguiente and siguiente[2] and (siguiente[1]:match("^dev_dinero") or siguiente[1]:match("^dev_sobres") or siguiente[1]:match("^dev_dia"))
                if col == 2 or not sigCorto then
                    y = y + 13
                    col = 0
                end
            else
                if cabe(y, 11) then ui.boton(b[1], b[2], X + 6, y, W - 12, 11, b[3] and p.verde or p.gris) end
                y = y + 13
            end
        end
    end
    if cabe(y, 10) then fuentes.texto("PANTALLA", X + 6, y + 3, 1, p.naranja) end
    for i, l in ipairs(infoPantalla()) do
        if cabe(y + 4 + i * 8, 6) then fuentes.texto(l, X + 6, y + 4 + i * 8, 1, p.grisclaro) end
    end
    if hayScroll then
        ui.boton("dev_subir", "SUBIR", X + 6, fin + 2, 75, 11, p.azul, dev.scroll > 0)
        ui.boton("dev_bajar", "BAJAR", X + 83, fin + 2, 75, 11, p.azul, dev.scroll < alto - MAX + 16)
    end
end

-- de los sets que ya han salido; 1ª edicion si aun no se ha reimpreso
local function regalarSobres(n)
    for _, tipo in ipairs(sobres.lista) do
        if mercado.salido(tipo.set) then
            partida.regalar(tipo.id, n, not mercado.hayNormales(tipo.set))
        end
    end
end

function dev.click(id)
    if id == "dev_dinero1" then
        partida.dinero = partida.dinero + 100
    elseif id == "dev_dinero10" then
        partida.dinero = partida.dinero + 1000
    elseif id == "dev_dinero100" then
        partida.dinero = partida.dinero + 10000
    elseif id == "dev_sobres5" then
        regalarSobres(5)
    elseif id == "dev_sobres20" then
        regalarSobres(20)
    elseif id == "dev_productos" then
        -- de los sets que ya han salido: blister, tin, ETB y caja
        for _, t in ipairs(sobres.lista) do
            if mercado.salido(t.set) then
                for _, prod in ipairs(mercado.productosDe(t)) do partida.meterProd(prod.id, t.id, not mercado.hayNormales(t.set), 2) end
            end
        end
        partida.guardar()
    elseif id == "dev_lote5" or id == "dev_lote20" then
        local n = id == "dev_lote5" and 5 or 20
        local faltan = n - partida.sobresGuardados()
        if faltan > 0 then partida.regalar(sobres.lista[1].id, faltan, true) end
        nav.lote(n)
    elseif id == "dev_velocidad" then
        for i, v in ipairs(VELOCIDADES) do
            if v == dev.velocidad then
                dev.velocidad = VELOCIDADES[i % #VELOCIDADES + 1]
                break
            end
        end
    elseif id == "dev_saltar" then
        dev.saltar = not dev.saltar
    elseif id == "dev_subir" or id == "dev_bajar" then
        dev.scroll = dev.scroll + (id == "dev_subir" and -80 or 80)
        return
    elseif id == "dev_godpack" then
        generador.forzar = generador.forzar ~= "godpack" and "godpack" or nil
    elseif id == "dev_secreta" or id == "dev_alt" or id == "dev_silver" or id == "dev_golden" then
        local que = id:sub(5)
        generador.forzar = generador.forzar ~= que and que or nil
    elseif id == "dev_dia" then
        nav.pasarDia()
    elseif id:match("^dev_dia%d") then
        for _ = 1, tonumber(id:sub(8)) do nav.pasarDia(true) end
    elseif id == "dev_ofertas" then
        partida.generarOfertas()
    elseif id == "dev_noticia" then
        mercado.noticia()
    elseif id == "dev_torneo" then
        mercado.torneo(true)
    elseif id == "dev_burbuja" then
        mercado.burbujaAhora()
    elseif id == "dev_moda" or id == "dev_caida" then
        mercado.forzarRacha(id == "dev_moda")
    elseif id == "dev_crash" then
        if not mercado.noticia("almacen1") then mercado.noticia("almacen") end
    elseif id == "dev_encargo" then
        partida.generarEncargo()
    elseif id == "dev_peticion" then
        require("src.directo").forzarPeticion()
    elseif id == "dev_completar" then
        for _, c in ipairs(cartas) do
            if mercado.disponible(c.id) then partida.anadir(c.id, not mercado.hayNormales(c.set)) end
        end
    end
    sonido.tocar("moneda")
    partida.guardar()
end

return dev
