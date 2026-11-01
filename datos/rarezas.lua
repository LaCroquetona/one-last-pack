-- suspense: segundos que tiembla antes de girarse
-- brillo: tipo de acabado (src/carta.lua): reflejo, foil, purpurina u oro
-- efecto: fuerza del brillo (nil = sin brillo)
-- las probabilidades de cada rareza estan en datos/sobres.lua y los precios en datos/sets.lua
local p = require "datos.paleta"

local lista = {
    { id = "comun",       nivel = 1, nombre = "Común",       color = p.grisclaro, suspense = 0 },
    { id = "infrecuente", nivel = 2, nombre = "Infrecuente", color = p.verde,     suspense = 0 },
    { id = "rara",        nivel = 3, nombre = "Rara",        color = p.celeste,   suspense = 0.35, brillo = "reflejo",   efecto = 0.5 },
    { id = "holo",        nivel = 4, nombre = "Holo",        color = p.violeta,   suspense = 0.7,  brillo = "foil",      efecto = 0.6 },
    { id = "fullart",     nivel = 5, nombre = "Full Art",    color = p.naranja,   suspense = 1.1,  brillo = "purpurina", efecto = 0.8 },
    { id = "secreta",     nivel = 6, nombre = "Secreta",     color = p.amarillo,  suspense = 1.6,  brillo = "oro",       efecto = 1 },
}

local rarezas = { lista = lista }
for _, r in ipairs(lista) do
    rarezas[r.id] = r
end

-- como se presenta una carta al abrirla: las de fuera de set (ALT, SILVER y
-- GOLDEN, datos/variantes.lua) cogen la de su rareza y la suben un poco;
-- id sigue siendo el de su rareza (sonidos, chat, propinas)
local variantes = require "datos.variantes"
local cache = {}
function rarezas.de(def)
    local r = rarezas[def.rareza]
    if not def.variante then return r end
    local clave = def.variante .. "_" .. r.id
    if cache[clave] then return cache[clave] end
    local v = variantes[def.variante]
    local nueva = {}
    for k, x in pairs(r) do nueva[k] = x end
    if def.variante == "alt" then
        nueva.nombre = r.nombre .. " Alt"
        nueva.nivel = math.min(6, r.nivel + 1)
        nueva.suspense = r.suspense + 0.4
    else
        nueva.nombre = v.nombre
        nueva.color = v.color
        nueva.suspense = v.suspense
        nueva.brillo = v.brillo
        nueva.efecto = 1
        nueva.especial = def.variante
    end
    cache[clave] = nueva
    return nueva
end

-- clave de una carta de fuera de set en sets.valores y sobres.variantes
-- (alt_holo, alt_fullart, alt_secreta, silver, golden); nil si es normal
function rarezas.clave(def)
    if def.variante == "alt" then return "alt_" .. def.rareza end
    return def.variante
end

-- nombre para mostrar: "Trueno", "Trueno Alt", "Plasma Golden"
function rarezas.nombre(def)
    if not def.variante then return def.nombre end
    return def.nombre .. " " .. variantes[def.variante].nombre
end

-- para ordenar de peor a mejor: dentro de una rareza, la normal, ALT, SILVER y GOLDEN
local RANGO = { alt = 1, silver = 2, golden = 3 }
function rarezas.rango(def)
    return rarezas[def.rareza].nivel * 10 + (RANGO[def.variante] or 0)
end

return rarezas
