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
return rarezas
