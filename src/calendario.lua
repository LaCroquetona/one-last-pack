-- Cuando sale cada set, cuando se agota y cuando se reimprime. Se sortea al
-- empezar la partida (con los rangos de datos/calendario.lua) y se guarda.
local sets = require "datos.sets"
local datos = require "datos.calendario"

local calendario = {}

local function entre(rng, r)
    return rng:random(r[1], r[2])
end

-- plan[setId] = lista de tiradas { tipo = "impresion" | "reimpresion", desde, hasta, rumor }
function calendario.generar(semilla)
    local rng = love.math.newRandomGenerator(semilla)
    local plan = {}
    for i, s in ipairs(sets.lista) do
        local desde = 1 + (i - 1) * datos.cada
        plan[s.id] = { { tipo = "impresion", desde = desde, hasta = desde + entre(rng, datos.impresion) - 1 } }
    end

    -- reimpresiones en rueda, empezando por el primer set
    local n = #sets.lista
    local t = plan[sets.lista[1].id][1].hasta + entre(rng, datos.espera) + 1
    local i = 1
    while t < datos.horizonte do
        local elegido
        for _ = 1, n do
            local s = sets.lista[i]
            i = i % n + 1
            local tiradas = plan[s.id]
            if tiradas[1].hasta < t and tiradas[#tiradas].hasta < t then
                elegido = s
                break
            end
        end
        if elegido then
            local dur = entre(rng, datos.reimpresion)
            table.insert(plan[elegido.id], { tipo = "reimpresion", desde = t, hasta = t + dur - 1, rumor = entre(rng, datos.rumor) })
            t = t + dur - entre(rng, datos.solape)
        else
            t = t + 1
        end
    end
    return plan
end

calendario.plan = nil

-- fase de un set un dia: "futuro", "anunciado", "impresion", "reimpresion",
-- "agotado" o "rumor" (agotado, con una reimpresion a punto de llegar).
-- info: d (dias desde que empezo la tirada), quedan, tirada, e (dias agotado),
-- k (reimpresiones que ya han empezado antes), faltan (para salir)
function calendario.fase(setId, dia)
    local tiradas = calendario.plan[setId]
    local primera = tiradas[1]
    if dia < primera.desde - datos.anuncio then return "futuro", { faltan = primera.desde - dia } end
    if dia < primera.desde then return "anunciado", { faltan = primera.desde - dia } end
    local anterior
    local k = 0
    for _, tirada in ipairs(tiradas) do
        if dia < tirada.desde then
            local info = { e = dia - anterior.hasta, k = k, siguiente = tirada }
            if tirada.desde - dia <= (tirada.rumor or 0) then return "rumor", info end
            return "agotado", info
        end
        if dia <= tirada.hasta then
            return tirada.tipo, { d = dia - tirada.desde, quedan = tirada.hasta - dia, tirada = tirada, k = k }
        end
        anterior = tirada
        if tirada.tipo == "reimpresion" then k = k + 1 end
    end
    return "agotado", { e = dia - anterior.hasta, k = k }
end

function calendario.salido(setId, dia)
    return dia >= calendario.plan[setId][1].desde
end

function calendario.conocido(setId, dia)
    return dia >= calendario.plan[setId][1].desde - datos.anuncio
end

-- si hoy hay sobres en la tienda y de que edicion
function calendario.enTienda(setId, dia)
    local fase, info = calendario.fase(setId, dia)
    if fase == "impresion" then return true, true, info end
    if fase == "reimpresion" then return true, false, info end
    return false
end

function calendario.lanzando(setId, dia)
    local fase, info = calendario.fase(setId, dia)
    return fase == "impresion" and info.d < datos.lanzamiento
end

-- dias desde que acabo la primera tirada (nil si aun no ha acabado)
function calendario.finPrimera(setId, dia)
    local fin = calendario.plan[setId][1].hasta
    if dia > fin then return dia - fin end
end

-- lo que sale en las noticias cada dia por el calendario
-- devuelve una lista de { clave, set, texto }
function calendario.avisos(dia)
    local lista = {}
    for _, s in ipairs(sets.lista) do
        local tiradas = calendario.plan[s.id]
        local primera = tiradas[1]
        if dia == primera.desde - datos.anuncio then
            table.insert(lista, { clave = "anuncio", set = s, texto = "Se anuncia el " .. s.nombre .. ": sale en la tienda el día " .. primera.desde })
        end
        for _, t in ipairs(tiradas) do
            if dia == t.desde then
                if t.tipo == "impresion" then
                    table.insert(lista, { clave = "lanzamiento", set = s, texto = "¡Sale el " .. s.nombre .. "! Ya hay sobres en la tienda" })
                else
                    table.insert(lista, { clave = "reimpresion", set = s, texto = "Vuelve el " .. s.nombre .. ": reimpresión en la tienda" })
                end
            end
            if dia == t.hasta - datos.ultimos + 1 then
                local que = t.tipo == "impresion" and "impresión" or "reimpresión"
                table.insert(lista, { clave = "ultimos", set = s, texto = "Últimos " .. datos.ultimos .. " días de " .. que .. " del " .. s.nombre })
            end
            if dia == t.hasta + 1 then
                table.insert(lista, { clave = "agotado", set = s, texto = "El " .. s.nombre .. " se agota: ya solo hay de reventa" })
            end
            if t.rumor and dia == t.desde - t.rumor then
                table.insert(lista, { clave = "rumor", set = s, texto = "Se rumorea una reimpresión del " .. s.nombre })
            end
        end
    end
    return lista
end

return calendario
