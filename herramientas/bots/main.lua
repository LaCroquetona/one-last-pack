-- Bots que juegan con distintas estrategias para ver si se gana dinero
local mercado = require "src.mercado"
local partida = require "src.partida"
local generador = require "src.generador"
local sobres = require "datos.sobres"
local datos = require "datos.mercado"
local calendario = require "src.calendario"
local directo = require "src.directo"

-- en directo: cada sobre trae seguidores y propinas (sin chat ni tiempo real)
local enDirecto = false
local VENTA, COSTE, FACTOR = 0, 0, 1
local seguidoresSueltos = 0

local abiertosHoy, LIMITE = 0, math.huge
local function abrir(tipo, primera)
    abiertosHoy = abiertosHoy + 1
    local defs, gp = generador.sobre(tipo)
    for _, d in ipairs(defs) do partida.anadir(d.id, primera) end
    if enDirecto then
        local esp = directo.espectadoresBase(partida.canal.seguidores)
        local seg, propinas = directo.simularSobre(esp, defs, gp, FACTOR)
        seguidoresSueltos = seguidoresSueltos + seg
        local enteros = math.floor(seguidoresSueltos)
        partida.canal.seguidores = partida.canal.seguidores + enteros
        seguidoresSueltos = seguidoresSueltos - enteros
        partida.dinero = partida.dinero + propinas
        partida.canal.propinas = partida.canal.propinas + propinas
    end
end

-- vender por el movil: de media lo que pagan los compradores menos la comision
local function venderMovil(id, uids)
    local A = datos.anuncios
    local f = (A.rango[1] + A.rango[2]) / 2 * (1 - datos.comision)
    local total = 0
    for _, u in ipairs(uids) do
        local c = partida.copia(id, u)
        total = total + math.floor(mercado.valorExacto(id, c.p) * f)
        mercado.vendida(id, 0.5)
    end
    local antes = partida.dinero
    partida.venderCopias(id, uids)
    partida.dinero = antes + total
end

local function venderRepes(movil)
    local o = { todo = false, primeras = true, proteccion = "todo" }
    if movil then
        -- a mano: todas menos una de cada
        for id, l in pairs(partida.inv) do
            local uids = {}
            for k = 2, #l do uids[#uids + 1] = l[k].u end
            if #uids > 0 then venderMovil(id, uids) end
        end
    else
        partida.venderLote(o)
    end
end

local function enTienda()
    local lista = {}
    for _, t in ipairs(sobres.lista) do
        local precio, primera = mercado.enTienda(t)
        if precio then lista[#lista + 1] = { t = t, primera = primera, d = select(2, calendario.fase(t.set, mercado.dia())).d } end
    end
    return lista
end

-- abre todos los sobres guardados (los de premio tambien)
local function abrirGuardados(guardar)
    for _, t in ipairs(sobres.lista) do
        local quedan = guardar and partida.sobres(t.id, false) or partida.sobres(t.id)
        for _ = 1, quedan do
            if enDirecto and abiertosHoy >= LIMITE then return end
            local tipo, primera = partida.sacarSobre(t.id)
            if tipo then abrir(tipo, primera) end
        end
    end
end

local function comprarYAbrir(filtro)
    for _, x in ipairs(enTienda()) do
        if not filtro or filtro(x) then
            local n = math.min(partida.maxCompra(x.t), 10)
            if n > 0 then partida.comprar(x.t, n) end
        end
    end
    abrirGuardados()
end

-- minutos de directo al dia (MINUTOS=20 ./bots.sh)
local MINUTOS = tonumber(os.getenv("MINUTOS") or "10")
-- sobres por minuto abiertos en directo (RITMO=9: como un jugador rapido)
local RITMO = tonumber(os.getenv("RITMO") or "4")
LIMITE = MINUTOS * RITMO
-- lo que da cada sobre si se abre mas rapido de lo normal (src/directo.lua)
FACTOR = math.min(1, require("datos.directo").ritmo.normal / RITMO)
local datosDirecto = require "datos.directo"
local datosMejoras = require "datos.mejoras"
local vendedores = require "src.vendedores"

-- venta de sobres en directo: los compradores de MINUTOS minutos se llevan
-- sobres guardados al precio de mercado con margen (como directo.reservar)
local function venderEnDirecto()
    local V = datosDirecto.venta
    local esp = directo.espectadoresBase(partida.canal.seguidores)
    if esp < V.espectadoresMin then return 0 end
    local n = math.floor(math.min(V.maxPorMinuto, V.porMinuto + esp * V.porEspectador) * MINUTOS)
    local vendidos = 0
    for _ = 1, n do
        local lista = {}
        for _, t in ipairs(sobres.lista) do if partida.sobres(t.id) > 0 then lista[#lista + 1] = t end end
        if #lista == 0 then break end
        local t = lista[love.math.random(#lista)]
        local margen = V.margen[1] + love.math.random() * (V.margen[2] - V.margen[1]) + math.min(V.margenMax, esp * V.margenPorEspectador)
        margen = 1 + (margen - 1) * partida.efecto("aro")
        local tipo, primera = partida.sacarSobre(t.id)
        local precio = mercado.sellado(t, primera) or mercado.sellado(t, not primera) or t.precio
        partida.dinero = partida.dinero + math.floor(precio * margen / 10 + 0.5) * 10
        VENTA = (VENTA or 0) + math.floor(precio * margen / 10 + 0.5) * 10
        COSTE = (COSTE or 0) + precio
        -- las cartas son del comprador: solo cuentan seguidores y propinas
        local defs, gp = generador.sobre(tipo)
        local seg, propinas = directo.simularSobre(esp, defs, gp, FACTOR)
        if defs and generador and seg then
            -- al comprador le toca algo bueno: seguidores de suerte
            for _, def in ipairs(defs) do
                if require("datos.rarezas")[def.rareza].nivel >= 4 then seg = seg + datosDirecto.venta.seguidoresSuerte break end
            end
        end
        seguidoresSueltos = seguidoresSueltos + seg
        partida.dinero = partida.dinero + propinas
        partida.canal.propinas = partida.canal.propinas + propinas
        vendidos = vendidos + 1
        abiertosHoy = abiertosHoy + 1
        if abiertosHoy >= LIMITE then break end
    end
    local enteros = math.floor(seguidoresSueltos)
    partida.canal.seguidores = partida.canal.seguidores + enteros
    seguidoresSueltos = seguidoresSueltos - enteros
    return vendidos
end

local function comprarTodo(filtro)
    for _, x in ipairs(enTienda()) do
        if not filtro or filtro(x) then
            local n = math.min(partida.maxCompra(x.t), 25)
            if n > 0 then partida.comprar(x.t, n) end
        end
    end
end

-- compra la mejora mas barata si le sobra el triple de lo que cuesta
local function comprarMejoras(grupos)
    local mejor, coste
    for _, m in ipairs(datosMejoras) do
        if grupos[m.grupo] then
            local c = partida.costeMejora(m)
            if c and (not coste or c < coste) then mejor, coste = m, c end
        end
    end
    if mejor and partida.dinero > coste * 3 then partida.comprarMejora(mejor) end
end

local ESTRATEGIAS = {
    nada = function() end,
    -- compra todo lo que puede del set mas barato, abre y vende repes rapido
    abreRapido = function()
        comprarYAbrir()
        venderRepes(false)
    end,
    -- igual pero vende por el movil
    abreMovil = function()
        comprarYAbrir()
        venderRepes(true)
    end,
    -- solo compra los primeros dias de un set nuevo, abre y vende por el movil
    lanzamiento = function()
        comprarYAbrir(function(x) return x.primera and x.d < 4 end)
        venderRepes(true)
    end,
    -- lanzamiento + guarda la mitad de los sobres de 1ª ed cerrados y los vende al doble
    mixto = function()
        for _, x in ipairs(enTienda()) do
            if x.primera then
                local n = math.min(partida.maxCompra(x.t), 10)
                if n > 0 then partida.comprar(x.t, n) end
            end
        end
        -- abre los de lanzamiento y los de premio; el resto se guarda
        for _, t in ipairs(sobres.lista) do
            local f, i = calendario.fase(t.set, mercado.dia())
            local abre = (f == "impresion" and i.d < 4) and partida.sobres(t.id) or partida.sobres(t.id, false)
            for _ = 1, abre do
                local tipo, primera = partida.sacarSobre(t.id)
                if tipo then abrir(tipo, primera) end
            end
            local v = mercado.sellado(t, true)
            if v and partida.sobres(t.id, true) > 0 and v >= t.precio * 2 then partida.venderSobres(t, partida.sobres(t.id, true), true) end
        end
        venderRepes(true)
    end,
    -- como abreRapido pero abriendo siempre en directo
    directo = function()
        enDirecto = true
        comprarYAbrir()
        venderRepes(false)
        enDirecto = false
    end,
    -- EL QUE SABE: compra en tienda y lo revende en directo de venta; abre
    -- en directo lo que no vende, mejoras de directo y venta
    vendeDirecto = function()
        comprarTodo()
        venderEnDirecto()
        enDirecto = true
        abrirGuardados()
        enDirecto = false
        venderRepes(true)
        comprarMejoras({ directo = true, venta = true, tienda = true })
    end,
    -- MENESES: como juego yo. Compra todo en la tienda, las cajas
    -- de la tienda y las de los vendedores que salgan por debajo de sus sobres,
    -- las rompe para vender sobres en directo, abre el resto en directo, vende
    -- rapido lo malo y por el movil lo bueno, y mejora
    meneses = function()
        comprarTodo()
        for _, x in ipairs(enTienda()) do
            while partida.comprarCaja(x.t) do end
            -- y los demas productos (ETB, tins, blisters): se abren al momento
            if os.getenv("PRODUCTOS") ~= "no" then
                for _, prod in ipairs(mercado.productosDe(x.t, true)) do
                    while partida.comprarProd(prod, x.t) do end
                    while partida.vaciarProd(prod.id, x.t) do end
                end
            end
        end
        for _, t in ipairs(sobres.lista) do
            for _, pr in ipairs({ true, false }) do
                local s = mercado.sellado(t, pr) or (mercado.enTienda(t))
                for _, o in ipairs(vendedores.deCaja(t, pr)) do
                    while s and o.quedan > 0 and o.precio < s * 18 and vendedores.comprar(o) do end
                end
            end
            while partida.cajasDe(t.id) > 0 do
                partida.abrirCaja(t)
                partida.meterSobres(t.id, partida.cajaAbierta.quedan, partida.cajaAbierta.primera)
                partida.cajaAbierta = nil
            end
        end
        venderEnDirecto()
        enDirecto = true
        abrirGuardados()
        enDirecto = false
        -- lo bueno por el movil, lo demas rapido
        for id, l in pairs(partida.inv) do
            local uids = {}
            for k = 1, #l do
                if mercado.valorExacto(id, l[k].p) >= 300 then uids[#uids + 1] = l[k].u end
            end
            if #uids > 0 then venderMovil(id, uids) end
        end
        partida.venderLote({ todo = true, primeras = true, proteccion = "todo" })
        comprarMejoras({ directo = true, venta = true, suerte = true, tienda = true })
    end,
    -- NOVATO: abre en directo y vende repes; con los seguidores de la venta
    -- hace directos de venta; si se queda sin nada vende todo lo que no es 1ª ed
    novato = function()
        comprarTodo(function(x) return x.t.precio <= 300 end)
        if partida.canal.seguidores >= datosDirecto.venta.desbloqueo then venderEnDirecto() end
        enDirecto = true
        abrirGuardados()
        enDirecto = false
        venderRepes(false)
        if partida.dinero < 200 and partida.sobresGuardados() == 0 then
            partida.venderLote({ todo = true, primeras = true, proteccion = "todo" })
        end
        comprarMejoras({ directo = true, venta = true, suerte = true })
    end,
    -- LUDOPATA: cajas y sobres, todo abierto en directo, vende todo rapido
    ludopata = function()
        for _, x in ipairs(enTienda()) do
            while partida.comprarCaja(x.t) do end
        end
        comprarTodo()
        for _, t in ipairs(sobres.lista) do
            while partida.cajasDe(t.id) > 0 do partida.abrirCaja(t) partida.meterSobres(t.id, partida.cajaAbierta.quedan, partida.cajaAbierta.primera) partida.cajaAbierta = nil end
        end
        enDirecto = true
        abrirGuardados()
        enDirecto = false
        partida.venderLote({ todo = true, primeras = true, proteccion = "todo" })
        comprarMejoras({ suerte = true })
    end,
    -- ESPECULADOR: no abre; compra 1ª ed en tienda y sobres de reventa
    -- baratos, vende cerrados a x1,5
    especulador = function()
        comprarTodo(function(x) return x.primera end)
        for _, t in ipairs(sobres.lista) do
            for _, pr in ipairs({ true, false }) do
                local v = mercado.sellado(t, pr)
                if v and partida.sobres(t.id, pr) > 0 and v >= t.precio * 1.5 then partida.venderSobres(t, partida.sobres(t.id, pr), pr) end
                local c = mercado.compraReventa(t, pr)
                if c and c < t.precio * 0.9 then while partida.comprarReventa(t, pr) do end end
            end
        end
    end,
    -- compra 1ª ed y la guarda cerrada; vende cerrados cuando valen x2
    guardar = function()
        for _, x in ipairs(enTienda()) do
            if x.primera then
                local n = math.min(partida.maxCompra(x.t), 10)
                if n > 0 then partida.comprar(x.t, n) end
            end
        end
        for _, t in ipairs(sobres.lista) do
            local v = mercado.sellado(t, true)
            if v and partida.sobres(t.id, true) > 0 and v >= t.precio * 2 then partida.venderSobres(t, partida.sobres(t.id, true), true) end
        end
    end,
}

local function patrimonio()
    local s = 0
    for _, t in ipairs(sobres.lista) do
        s = s + (mercado.sellado(t, true) or t.precio) * partida.sobres(t.id, true) + (mercado.sellado(t, false) or t.precio) * partida.sobres(t.id, false)
    end
    return partida.dinero + partida.valorColeccion() + s
end

function love.load()
    local nombres = { "nada", "abreRapido", "abreMovil", "directo", "lanzamiento", "guardar", "mixto", "vendeDirecto", "ludopata", "especulador", "novato", "meneses" }
    -- SOLO=directo ./bots.sh: solo esa estrategia
    if os.getenv("SOLO") then nombres = { os.getenv("SOLO") } end
    for _, nombre in ipairs(nombres) do
        local res = { 5, 10, 20, 30, 60, 240 }
        local suma = {}
        local seg, prop, abiertos, quiebras, diaQuiebra = 0, 0, 0, 0, 0
        local mejorasT = 0
        local SEM = tonumber(os.getenv("SEMILLAS") or "6")
        for semilla = 1, SEM do
            love.math.setRandomSeed(semilla)
            VENTA, COSTE = 0, 0
            partida.nueva()
            mercado.nuevo(semilla)
            local roto = false
            for d = 1, 240 do
                abiertosHoy = 0
                ESTRATEGIAS[nombre]()
                if os.getenv("TRAZA") and (os.getenv("TRAZA") == "todas" and d == 20 or semilla == 1 and (d % 10 == 0 or d < 10 and d % 2 == 0)) then
                    print(string.format("  dia %d: %.0f€ seguidores %d espectadores %.0f propinas %.0f€ venta directo %.0f€ (mercado %.0f€) abiertos %d", d, partida.dinero / 100, partida.canal.seguidores, directo.espectadoresBase(partida.canal.seguidores), partida.canal.propinas / 100, (VENTA or 0) / 100, (COSTE or 0) / 100, partida.abiertos))
                end
                if not roto and nombre ~= "nada" and partida.dinero < 200 and partida.sobresGuardados() == 0 then
                    roto = true
                    quiebras = quiebras + 1
                    diaQuiebra = diaQuiebra + d
                end
                partida.pasarDia()
                for k, dia in ipairs(res) do
                    if d == dia then
                        suma[k] = suma[k] or { 0, 0 }
                        suma[k][1] = suma[k][1] + partida.dinero / SEM
                        suma[k][2] = suma[k][2] + patrimonio() / SEM
                    end
                end
            end
            seg = seg + partida.canal.seguidores / SEM
            prop = prop + partida.canal.propinas / SEM
            abiertos = abiertos + partida.abiertos / SEM
            for _, n in pairs(partida.mejoras) do mejorasT = mejorasT + n / SEM end
        end
        local linea = string.format("%-12s", nombre)
        for k, dia in ipairs(res) do linea = linea .. string.format("  d%d: %7.2f€ (total %8.2f€)", dia, suma[k][1] / 100, suma[k][2] / 100) end
        linea = linea .. string.format("  sobres %d", abiertos)
        if quiebras > 0 then linea = linea .. string.format(", sin blanca %d/" .. SEM .. " (dia %d)", quiebras, diaQuiebra / quiebras) end
        if mejorasT > 0 then linea = linea .. string.format(", niveles de mejora %.1f", mejorasT) end
        if nombre == "directo" or nombre == "vendeDirecto" or nombre == "ludopata" or nombre == "novato" or nombre == "meneses" then
            linea = linea .. string.format(", seguidores %d, propinas %.2f€", seg, prop / 100)
        end
        print(linea)
    end
    love.event.quit()
end
