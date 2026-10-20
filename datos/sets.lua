-- Cada set tiene sus cartas (datos/cartas.lua, campo set), su sobre
-- (datos/sobres.lua) y lo que vale cada rareza en el mercado, en centimos.
-- Ajustados para que abrir un sobre de 1ª edicion a mitad de tirada devuelva de
-- media un 90% de lo que cuesta, mas o menos (lo demas sale del movil, los
-- directos y la suerte).
-- Salen en este orden, uno cada pocos dias (datos/calendario.lua)
local lista = {
    {
        id = "s1", codigo = "S1", nombre = "Set 1", sobre = "set1",
        valores = { comun = 2.25, infrecuente = 4.5, rara = 14, holo = 90, fullart = 585, secreta = 3060 },
    },
    {
        id = "s2", codigo = "S2", nombre = "Set 2", sobre = "set2",
        valores = { comun = 5.4, infrecuente = 14, rara = 76, holo = 990, fullart = 4320, secreta = 23400 },
    },
    {
        id = "s3", codigo = "S3", nombre = "Set 3", sobre = "set3",
        valores = { comun = 4.05, infrecuente = 8.1, rara = 32, holo = 378, fullart = 1800, secreta = 9000 },
    },
    {
        id = "s4", codigo = "S4", nombre = "Set 4", sobre = "set4",
        valores = { comun = 8.1, infrecuente = 16, rara = 45, holo = 504, fullart = 3600, secreta = 18900 },
    },
}

local sets = { lista = lista }
for i, s in ipairs(lista) do
    s.orden = i
    sets[s.id] = s
end
return sets
