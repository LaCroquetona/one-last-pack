-- peso: probabilidad en el hueco de la carta buena (el 5o del sobre)
-- suspense: segundos que tiembla antes de girarse
-- efecto: fuerza del brillo holo (nil = sin brillo)
local lista = {
    { id = "comun",       nivel = 1, nombre = "Común",       color = {0.70, 0.72, 0.76}, peso = 0,  suspense = 0 },
    { id = "infrecuente", nivel = 2, nombre = "Infrecuente", color = {0.40, 0.85, 0.55}, peso = 0,  suspense = 0 },
    { id = "rara",        nivel = 3, nombre = "Rara",        color = {0.35, 0.60, 1.00}, peso = 72, suspense = 0.35 },
    { id = "holo",        nivel = 4, nombre = "Holo",        color = {0.75, 0.45, 1.00}, peso = 20, suspense = 0.7, efecto = 0.35 },
    { id = "fullart",     nivel = 5, nombre = "Full Art",    color = {1.00, 0.45, 0.35}, peso = 6,  suspense = 1.1, efecto = 0.5 },
    { id = "secreta",     nivel = 6, nombre = "Secreta",     color = {1.00, 0.82, 0.25}, peso = 2,  suspense = 1.6, efecto = 0.8 },
}

local rarezas = { lista = lista }
for _, r in ipairs(lista) do
    rarezas[r.id] = r
end
return rarezas
