-- Simula el mercado N dias sin jugar y saca los precios a CSV
local mercado = require "src.mercado"
local sobres = require "datos.sobres"
local cartas = require "datos.cartas"
function love.load(arg)
    local dias = 600
    local semilla = tonumber(arg[1]) or 12345
    love.math.setRandomSeed(semilla)
    mercado.nuevo(semilla)
    local seguir = {}
    for _, c in ipairs(cartas) do
        if c.chase or c.id == 1 or c.id == 101 or (c.rareza == "holo" and (c.id == 33 or c.id == 140)) then table.insert(seguir, c) end
    end
    local f = io.open(arg[2] or "sim.csv", "w")
    local cab = { "dia" }
    for _, c in ipairs(seguir) do table.insert(cab, c.set .. "_" .. c.nombre .. "_1"); table.insert(cab, c.set .. "_" .. c.nombre .. "_n") end
    for _, t in ipairs(sobres.lista) do table.insert(cab, t.id .. "_sellado1"); table.insert(cab, t.id .. "_selladoR") end
    f:write(table.concat(cab, ",") .. "\n")
    local noticias = {}
    for d = 1, dias do
        if d > 1 then
            for _, n in ipairs(mercado.pasarDia()) do table.insert(noticias, d .. ": " .. n.texto) end
        end
        local fila = { d }
        for _, c in ipairs(seguir) do
            local disp = mercado.disponible(c.id)
            table.insert(fila, disp and string.format("%.0f", mercado.valorExacto(c.id, true)) or "")
            table.insert(fila, (disp and mercado.hayNormales(c.set)) and string.format("%.0f", mercado.valorExacto(c.id, false)) or "")
        end
        for _, t in ipairs(sobres.lista) do
            table.insert(fila, mercado.sellado(t, true) or "")
            table.insert(fila, mercado.sellado(t, false) or "")
        end
        f:write(table.concat(fila, ",") .. "\n")
    end
    f:close()
    local g = io.open((arg[2] or "sim.csv") .. ".noticias.txt", "w")
    g:write(table.concat(noticias, "\n"))
    g:close()
    love.event.quit()
end
