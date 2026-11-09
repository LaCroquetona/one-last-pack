-- Fundas y top loaders con diseno. Solo son de estilo: no cambian el precio
-- de la carta, no se venden sueltas y vuelven a su caja al vender la carta.
-- La basica (transparente) no esta aqui: en la copia es c.f = true / c.t = true.
-- familia: set (tienda del set), etb, mix (temporadas), especial (premios y raras)
-- corto: lo que cabe en la cajita de la mesa
-- color: el filo de la funda (o el plastico del top)
local p = require "datos.paleta"
local sobres = require "datos.sobres"

local ORO_CLARO = { 0.98, 0.84, 0.42 }

local lista = {}
local function f(t) table.insert(lista, t) end

-- tienda del set: un pack trae 10 lisas o 10 de rayas (al azar)
for i = 1, 8 do
    local c = sobres["set" .. i].colores
    f({ id = "lisa" .. i, nombre = "LISA S" .. i, corto = "LISA S" .. i, familia = "set", set = "s" .. i, de = "PACK DEL SET " .. i, color = c.base })
    f({ id = "rayas" .. i, nombre = "RAYAS S" .. i, corto = "RAYAS S" .. i, familia = "set", set = "s" .. i, de = "PACK DEL SET " .. i, color = c.rayas })
end

-- ETB: el motivo de su set
local ETB = {
    { "llamas", "LLAMAS", p.naranja }, { "olas", "OLAS", p.celeste }, { "dunas", "DUNAS", p.amarillo },
    { "galaxia", "GALAXIA", p.violeta }, { "burbujas", "BURBUJAS", p.lima }, { "nubes", "NUBES", p.cian },
    { "escamas", "ESCAMAS", p.verde }, { "sol", "SOL", p.amarillo },
}
for i, e in ipairs(ETB) do
    f({ id = e[1], nombre = e[2], corto = e[2], familia = "etb", set = "s" .. i, de = "ETB DEL SET " .. i, color = e[3] })
end

-- MIX: sale una cada pocos dias (temporada) y luego se va
f({ id = "cuadros", nombre = "AJEDREZ", corto = "AJEDREZ", familia = "mix", de = "MIX, TEMPORADA", color = p.grisclaro })
f({ id = "lunares", nombre = "LUNARES", corto = "LUNARES", familia = "mix", de = "MIX, TEMPORADA", color = p.rojo })
f({ id = "retro", nombre = "ATARDECER RETRO", corto = "RETRO", familia = "mix", de = "MIX, TEMPORADA", color = p.naranja })
f({ id = "circuito", nombre = "CIRCUITO", corto = "CIRCUITO", familia = "mix", de = "MIX, TEMPORADA", color = p.lima })
f({ id = "camuflaje", nombre = "CAMUFLAJE", corto = "CAMUFLA.", familia = "mix", de = "MIX, TEMPORADA", color = p.verde })
f({ id = "tartan", nombre = "TARTÁN", corto = "TARTÁN", familia = "mix", de = "MIX, TEMPORADA", color = p.rojo })
f({ id = "clasico", nombre = "DORSO CLÁSICO", corto = "CLÁSICO", familia = "mix", de = "MIX, TEMPORADA", color = p.rojo })
f({ id = "noche", nombre = "NOCHE", corto = "NOCHE", familia = "mix", de = "MIX, TEMPORADA", color = p.celeste })

-- especiales
f({ id = "holo", nombre = "HOLO", corto = "HOLO", familia = "especial", de = "1 DE CADA 10 ETB", color = p.violeta })
f({ id = "plata", nombre = "PLATA", corto = "PLATA", familia = "especial", de = "1 DE CADA 10 ETB", color = p.grisclaro })
f({ id = "dorada", nombre = "DORADA", corto = "DORADA", familia = "especial", de = "PREMIO: MASTER SET", color = ORO_CLARO })
-- la de la chase de cada set, al completarlo al 100%
local CHASE = { 40, 164, 258, 348, 456, 565 }
local cartas = require "datos.cartas"
local porId = {}
for _, c in ipairs(cartas) do porId[c.id] = c end
for i = 1, 8 do
    local id = CHASE[i]
    if not id then
        for _, c in ipairs(cartas) do
            if c.set == "s" .. i and c.chase then id = c.id break end
        end
    end
    local def = porId[id]
    if def then
        f({ id = "chase" .. i, nombre = def.nombre:upper(), corto = def.nombre:upper(), familia = "especial", set = "s" .. i,
            de = "PREMIO: SET " .. i .. " AL 100%", color = ORO_CLARO, carta = id })
    end
end

-- top loaders: color de su set (tin), pegatina del set (MIX) y magnetico (MIX)
local tops = {}
for i = 1, 8 do
    local c = sobres["set" .. i].colores
    table.insert(tops, { id = "color" .. i, nombre = "COLOR S" .. i, corto = "COLOR S" .. i, familia = "set", set = "s" .. i,
        de = "TIN DEL SET " .. i, estilo = "color", color = c.base })
end
for i = 1, 8 do
    local c = sobres["set" .. i].colores
    table.insert(tops, { id = "pegatina" .. i, nombre = "PEGATINA S" .. i, corto = "PEGAT. S" .. i, familia = "mix", set = "s" .. i,
        de = "PACK DEL MIX", estilo = "pegatina", color = p.blanco, pegatina = c })
end
table.insert(tops, { id = "magnetico", nombre = "MAGNÉTICO", corto = "MAGNÉT.", familia = "especial", de = "MIX, EL CARO",
    estilo = "magnetico", color = ORO_CLARO })

local fundas = {
    lista = lista,
    tops = tops,
    -- packs que se compran (centimos) y cuantas trae cada uno
    packSet = { n = 10, precio = 150 },
    packTemporada = { n = 10, precio = 200 },
    packPegatina = { n = 5, precio = 150 },
    packMagnetico = { n = 1, precio = 250 },
    -- 1 de cada 10 ETB trae sus fundas en holo o plata
    etbEspecial = 0.1,
    -- dias que dura una temporada del MIX
    temporada = { 3, 4 },
    -- lo que dan los premios
    premioChase = 10,
    premioDorada = 10,
}
for _, x in ipairs(lista) do fundas[x.id] = x end
fundas.top = {}
for _, x in ipairs(tops) do fundas.top[x.id] = x end
-- las del MIX en el orden en que salen la primera vez
fundas.mix = {}
for _, x in ipairs(lista) do if x.familia == "mix" then table.insert(fundas.mix, x.id) end end

-- nombre de una funda o top (true = la basica)
function fundas.nombre(id, esTop)
    if id == true or id == nil then return esTop and "TRANSPARENTE" or "TRANSPARENTE" end
    local d = esTop and fundas.top[id] or fundas[id]
    return d and d.nombre or "?"
end

return fundas
