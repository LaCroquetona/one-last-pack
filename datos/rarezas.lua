-- precio: lo que te dan al vender una copia
-- suspense: segundos que tiembla antes de girarse
-- efecto: fuerza del brillo holo (nil = sin brillo)
-- las probabilidades de cada rareza estan en datos/sobres.lua
local p = require "datos.paleta"

local lista = {
    { id = "comun",       nivel = 1, nombre = "Común",       color = p.grisclaro, precio = 2,   suspense = 0 },
    { id = "infrecuente", nivel = 2, nombre = "Infrecuente", color = p.verde,     precio = 6,   suspense = 0 },
    { id = "rara",        nivel = 3, nombre = "Rara",        color = p.celeste,   precio = 20,  suspense = 0.35 },
    { id = "holo",        nivel = 4, nombre = "Holo",        color = p.violeta,   precio = 80,  suspense = 0.7, efecto = 0.35 },
    { id = "fullart",     nivel = 5, nombre = "Full Art",    color = p.naranja,   precio = 200, suspense = 1.1, efecto = 0.5 },
    { id = "secreta",     nivel = 6, nombre = "Secreta",     color = p.amarillo,  precio = 600, suspense = 1.6, efecto = 0.8 },
}

local rarezas = { lista = lista }
for _, r in ipairs(lista) do
    rarezas[r.id] = r
end
return rarezas
