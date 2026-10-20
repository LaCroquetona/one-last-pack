-- Cada set tiene sus cartas (datos/cartas.lua, campo set), su sobre
-- (datos/sobres.lua) y lo que vale cada rareza en el mercado, en centimos.
-- Ajustados para que abrir un sobre de 1ª edicion a mitad de tirada devuelva de
-- media un 85% de lo que cuesta, mas o menos (las mejoras de suerte lo suben;
-- lo demas sale del movil, los directos, los encargos y la suerte).
-- Salen en este orden, uno cada pocos dias (datos/calendario.lua)
local lista = {
    {
        id = "s1", codigo = "S1", nombre = "Set 1", sobre = "set1",
        valores = { comun = 2.04, infrecuente = 4.09, rara = 13, holo = 81, fullart = 531, secreta = 2780 },
    },
    {
        id = "s2", codigo = "S2", nombre = "Set 2", sobre = "set2",
        valores = { comun = 3.79, infrecuente = 9.72, rara = 54, holo = 695, fullart = 3031, secreta = 16416 },
    },
    {
        id = "s3", codigo = "S3", nombre = "Set 3", sobre = "set3",
        valores = { comun = 3.58, infrecuente = 7.14, rara = 28, holo = 333, fullart = 1589, secreta = 7945 },
    },
    {
        id = "s4", codigo = "S4", nombre = "Set 4", sobre = "set4",
        valores = { comun = 7.44, infrecuente = 16, rara = 41, holo = 463, fullart = 3307, secreta = 17364 },
    },
    -- v0.8.0: cuatro sets nuevos, cada uno con su elemento
    {
        id = "s5", codigo = "S5", nombre = "Set 5", sobre = "set5",
        valores = { comun = 4.1, infrecuente = 8.2, rara = 32, holo = 381, fullart = 1821, secreta = 9099 },
    },
    {
        id = "s6", codigo = "S6", nombre = "Set 6", sobre = "set6",
        valores = { comun = 3.31, infrecuente = 6.63, rara = 21.2, holo = 133, fullart = 862, secreta = 4516 },
    },
    {
        id = "s7", codigo = "S7", nombre = "Set 7", sobre = "set7",
        valores = { comun = 4.09, infrecuente = 10.46, rara = 57, holo = 748, fullart = 3269, secreta = 17698 },
    },
    {
        id = "s8", codigo = "S8", nombre = "Set 8", sobre = "set8",
        valores = { comun = 6.1, infrecuente = 13.11, rara = 33.5, holo = 378, fullart = 2708, secreta = 14236 },
    },
}

local sets = { lista = lista }
for i, s in ipairs(lista) do
    s.orden = i
    sets[s.id] = s
end
return sets
