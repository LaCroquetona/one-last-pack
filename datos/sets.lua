-- Cada set tiene sus cartas (datos/cartas.lua, campo set), su sobre
-- (datos/sobres.lua) y lo que vale cada rareza en el mercado, en centimos.
-- Salen en este orden, uno cada pocos dias (datos/calendario.lua)
local lista = {
    {
        id = "s1", codigo = "S1", nombre = "Set 1", sobre = "set1",
        valores = { comun = 3, infrecuente = 10, rara = 45, holo = 250, fullart = 900, secreta = 3500 },
    },
    {
        id = "s2", codigo = "S2", nombre = "Set 2", sobre = "set2",
        valores = { comun = 8, infrecuente = 25, rara = 130, holo = 1500, fullart = 6000, secreta = 30000 },
    },
    {
        id = "s3", codigo = "S3", nombre = "Set 3", sobre = "set3",
        valores = { comun = 5, infrecuente = 15, rara = 70, holo = 550, fullart = 2400, secreta = 11000 },
    },
    {
        id = "s4", codigo = "S4", nombre = "Set 4", sobre = "set4",
        valores = { comun = 12, infrecuente = 35, rara = 120, holo = 950, fullart = 4800, secreta = 24000 },
    },
}

local sets = { lista = lista }
for i, s in ipairs(lista) do
    s.orden = i
    sets[s.id] = s
end
return sets
