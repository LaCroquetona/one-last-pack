-- Cosas que se pintan por encima del lienzo de 640x360, ya a la resolucion de
-- la ventana: lo que llevas en la mano y lo que vuela girando. Asi al girar
-- se ve el pixel entero girado y no se rompe en escalones.
local lg = love.graphics

local encima = {}
local lista = {}
-- el lienzo del juego va ampliado (main.lua): lo anotado viene en sus pixeles
encima.escala = 1

-- f se llama luego con las coordenadas del juego (640x360); se guarda el
-- desplazamiento de ahora (el temblor de pantalla)
function encima.anotar(f)
    local tx, ty = lg.transformPoint(0, 0)
    lista[#lista + 1] = { f, tx, ty }
end

function encima.dibujar(e, ox, oy)
    for i = 1, #lista do
        local f, tx, ty = lista[i][1], lista[i][2], lista[i][3]
        lg.push("all")
        lg.origin()
        lg.translate(ox + tx / encima.escala * e, oy + ty / encima.escala * e)
        lg.scale(e, e)
        f()
        lg.pop()
        lista[i] = nil
    end
end

return encima
