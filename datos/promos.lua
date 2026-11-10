-- Promos: cartas con los bichos y nombres de las del set (nunca secretas ni de
-- fuera de set), con un estilo segun de donde salen. No cuentan para el 100%
-- del set: cada set tiene su pagina de PROMOS en el album.
--   etb:      sobrecito dentro de la ETB, 1 de 4 (la dorada sale menos)   estilo rayos
--   caja:     sobrecito dentro de la caja, 1 de 4 (la dorada sale menos)  estilo noche
--   blister:  la suya, a la vista en el plastico; 1 de cada 10, su ALT    sin marco
--   tin:      igual que el blister                                       sin marco
--   preventa: compra de 15 € o mas mientras el set esta anunciado         rayos plata
--   torneo:   sobres de torneo del mercado, 1 de 2 (la final, dorada)    apaisada
-- Colabs (una cada 15-20 dias, solo en el mercado) y las placas del canal van aparte.
-- valor: veces lo que cuesta un sobre del set (su precio de base en el mercado).
-- Ids: 5000 + set * 100 + n (promos) y 9000 + n (colabs).
local p = require "datos.paleta"
local sobres = require "datos.sobres"
local productos = require "datos.productos"

local ORO = { 0.84, 0.62, 0.16 }
local PLATA = { 0.70, 0.74, 0.82 }

local promos = {
    -- lo que sale de cada sitio (en orden de numero dentro del set)
    lista = {
        -- tinte(C): los colores con los del sobre de cada set (las doradas y la preventa, fijos)
        { origen = "etb", estilo = "rayos", tinte = function(C) return { C.borde, C.base } end, valor = 0.35, peso = 3 },
        { origen = "etb", estilo = "rayos", tinte = function(C) return { C.base, C.rayas } end, valor = 0.35, peso = 3 },
        { origen = "etb", estilo = "rayos", tinte = function(C) return { C.borde, C.rayas } end, valor = 0.35, peso = 3 },
        { origen = "etb", estilo = "rayos", colores = { p.rojo, ORO }, valor = 1.6, peso = 1, oro = true },
        { origen = "caja", estilo = "noche", tinte = function(C) return { C.rayas } end, valor = 0.3, peso = 3 },
        { origen = "caja", estilo = "noche", tinte = function(C) return { C.letras } end, valor = 0.3, peso = 3 },
        { origen = "caja", estilo = "noche", colores = { p.blanco }, valor = 0.3, peso = 3 },
        { origen = "caja", estilo = "noche", colores = { ORO }, valor = 1.5, peso = 1, oro = true },
        { origen = "blister", estilo = "sinmarco", tinte = function(C) return { C.borde, C.base, C.rayas } end, valor = 0.15, peso = 9 },
        { origen = "blister", estilo = "sinmarco", colores = { p.morado, p.rojo, p.naranja }, valor = 1, peso = 1, oro = true, alt = true },
        { origen = "tin", estilo = "sinmarco", tinte = function(C) return { C.base, C.rayas, C.letras } end, valor = 0.25, peso = 9 },
        { origen = "tin", estilo = "sinmarco", colores = { p.negro, p.morado, p.violeta }, valor = 1.4, peso = 1, oro = true, alt = true },
        { origen = "preventa", estilo = "rayos", colores = { p.gris, PLATA }, valor = 1, peso = 1 },
        -- torneo: participacion, top 8 (plata) y la final (dorada)
        { origen = "torneo", estilo = "apaisada", tinte = function(C) return { C.base, C.rayas, C.borde, p.negro } end, valor = 1.2, peso = 6 },
        { origen = "torneo", estilo = "apaisada", colores = { p.gris, PLATA, p.azulosc, p.negro }, valor = 2.5, peso = 3, plata = true },
        { origen = "torneo", estilo = "apaisada", colores = { p.naranja, p.amarillo, p.morado, p.rojo }, valor = 6, peso = 1, oro = true },
    },
    -- preventa: lo que hay que gastar de una vez en la tienda (centimos)
    preventa = 1500,
    -- torneo: sobres en el mercado; precio = lo que vale de media lo que trae
    -- x margen x (1 + dias desde que salio el set / subida); cada dia hay menos
    torneo = { margen = 1.15, subida = 90, stock = 5, menosCada = 25 },
    -- colabs: cada cuanto sale una, cuantas copias hay, cuanto suben al dia
    -- los primeros dias y cuantas puedes comprar tu
    colab = { cada = { 15, 20 }, primera = 12, stock = { 18, 28 }, venden = { 0.3, 0.55 }, sube = 0.3, diasSube = 6,
              maximo = 3, valor = 2.5 },
    marcas = {
        { "MCDONAS", p.rojo, p.amarillo, p.rojo }, { "NAIK", p.blanco, p.negro, p.blanco },
        { "TELEPIZO", p.azul, p.rojo, p.blanco }, { "KOLALOKA", p.negro, p.rojo, p.blanco },
        { "ADIDOS", p.negro, p.blanco, p.negro }, { "PEPSO", p.azul, p.blanco, p.azul },
        { "LEGOS", p.amarillo, p.rojo, p.amarillo }, { "SONI", p.grisosc, p.blanco, p.grisosc },
        { "BURGUI K", p.naranja, p.rojo, p.amarillo }, { "FANTO", p.naranja, p.azul, p.blanco },
        { "SEGO", p.azul, p.blanco, p.azul }, { "ZARO", p.blanco, p.negro, p.blanco },
        { "MERCANA", p.verde, p.blanco, p.naranja }, { "IKEO", p.azul, p.amarillo, p.azul },
        { "CHUPACHU", p.amarillo, p.rojo, p.rojo }, { "DONUTOS", p.naranja, p.blanco, p.morado },
        { "COLAKAU", p.amarillo, p.rojo, p.azulosc }, { "GOOGOL", p.blanco, p.azul, p.rojo },
        { "SPOTIFAI", p.negro, p.verde, p.verde }, { "RENFO", p.morado, p.blanco, p.blanco },
        { "PRINGLIS", p.rojo, p.blanco, p.amarillo }, { "MONSTRO", p.negro, p.lima, p.lima },
        { "HARIBU", p.azul, p.amarillo, p.rojo }, { "NOCILLO", p.naranja, p.amarillo, p.blanco },
    },
    -- placas del canal: te las manda la empresa al llegar a estos seguidores (no se venden)
    canal = {
        { seguidores = 100, nombre = "BRONCE", cifra = "100", c1 = { 0.72, 0.45, 0.25 }, c2 = p.naranja },
        { seguidores = 500, nombre = "PLATA", cifra = "500", c1 = PLATA, c2 = p.blanco },
        { seguidores = 1000, nombre = "ORO", cifra = "1.000", c1 = ORO, c2 = p.amarillo },
        { seguidores = 5000, nombre = "RUBÍ", cifra = "5.000", c1 = p.rojo, c2 = p.naranja },
        { seguidores = 10000, nombre = "DIAMANTE", cifra = "10.000", c1 = p.cian, c2 = p.blanco },
    },
    -- de donde sale cada una (fichas y huecos del album)
    origenes = { etb = "SALE EN LA ETB (1 DE 4)", caja = "SALE EN LA CAJA (1 DE 4)", blister = "VIENE EN EL BLÍSTER",
        tin = "VIENE EN EL TIN", preventa = "PREVENTA: COMPRA DE 15 € CON EL SET ANUNCIADO",
        torneo = "SOBRES DE TORNEO (MERCADO)", colab = "COLAB: SOLO EN EL MERCADO",
        canal = "TE LA MANDA ONE LAST PACK POR CORREO (SEGUIDORES)" },
    -- las promos suben solas con el tiempo (no tienen reimpresion): quietas los
    -- primeros dias desde que sale su set y luego (1 + dias / ritmo) ^ potencia
    -- (las doradas suben mas). Con esto, las mejores llegan a 100-300 € hacia el dia 300
    subida = { quietas = 60, ritmo = 120, normal = 0.85, plata = 1, oro = 1.15 },
    ORO = ORO,
    PLATA = PLATA,
}

-- las cartas de cada set que pueden salir en promo (sin secretas ni de fuera de set)
local function basesDe(lista, set)
    local l = {}
    for _, c in ipairs(lista) do
        if c.set == set and not c.fuera and c.rareza ~= "secreta" then table.insert(l, c) end
    end
    return l
end

-- crea las promos y las colabs a partir de las cartas (datos/cartas.lua las añade a la lista)
function promos.crear(lista)
    local nuevas = {}
    -- el numero sigue de un set al siguiente (P001... en el S1, el S2 sigue
    -- donde acaba el S1); las ALT no suman: llevan el de su promo
    local num, base = 0, nil
    for i, tipo in ipairs(sobres.lista) do
        local bases = basesDe(lista, tipo.set)
        local usados, k = {}, i * 3
        local function siguiente()
            local def
            repeat
                k = k + 1
                def = bases[(k * 7) % #bases + 1]
            until not usados[def.id]
            usados[def.id] = true
            return def
        end
        for n, d in ipairs(promos.lista) do
            -- el tin solo esta en algunos sets: sin tin, sin sus promos
            if d.origen == "tin" and not (productos.tin.sets or {})[tipo.set] then goto siguiente end
            -- la ALT del blister y del tin lleva el mismo bicho y numero
            if not d.alt then
                num = num + 1
                base = siguiente()
            end
            table.insert(nuevas, {
                id = 5000 + i * 100 + n, set = tipo.set, promo = d.origen, estilo = d.estilo,
                colores = d.tinte and d.tinte(tipo.colores) or d.colores, oro = d.oro, plata = d.plata, alt = d.alt, num = num, codigo = string.format("P%03d", num),
                nombre = base.nombre, elemento = base.elemento, semilla = base.semilla or base.id * 7919 + 13, deCarta = base.id,
                rareza = d.oro and "holo" or "rara", valor = math.floor(tipo.precio * d.valor + 0.5), peso = d.peso,
            })
            ::siguiente::
        end
    end
    -- colabs: el bicho de una carta de cada set, por turnos (3 por set)
    for n, m in ipairs(promos.marcas) do
        local set = sobres.lista[(n - 1) % #sobres.lista + 1]
        local bases = basesDe(lista, set.set)
        local b = bases[(n * 13) % #bases + 1]
        table.insert(nuevas, {
            id = 9000 + n, set = set.set, promo = "colab", colab = n, estilo = "colab", marca = m[1], colores = { m[2], m[3], m[4] },
            num = n, codigo = string.format("C%02d", n), nombre = b.nombre, elemento = b.elemento,
            semilla = b.semilla or b.id * 7919 + 13, deCarta = b.id, rareza = "holo", oro = true,
            valor = math.floor(set.precio * promos.colab.valor + 0.5),
        })
    end
    -- placas del canal: llegan por correo y van al album ESPECIALES; no se venden
    for i, d in ipairs(promos.canal) do
        table.insert(nuevas, {
            id = 9500 + i, set = sobres.lista[1].set, promo = "canal", estilo = "placa", nivel = i, noVende = true,
            num = i, codigo = d.nombre, nombre = "Placa " .. d.nombre, elemento = "fuego", semilla = 9500 + i,
            rareza = "holo", oro = i >= 3, valor = 0,
        })
    end
    return nuevas
end

return promos
