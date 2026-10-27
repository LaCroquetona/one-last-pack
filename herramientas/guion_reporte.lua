-- Carga la partida de un reporte de bug (herramientas/reporte.sh) y saca
-- una foto de cada pantalla, sin tocar nada mas
return function(t)
    local ok, esperar, click, foto = t.ok, t.esperar, t.click, t.foto
    local partida, mercado = t.partida, t.mercado
    esperar(30); love.keypressed("space"); esperar(10)
    click("continuar"); esperar(15)
    ok(true, "partida del reporte: dia " .. mercado.dia() .. ", " .. partida.dinero .. " centimos, " .. partida.sobresSinAbrir() .. " sobres")
    for _, e in ipairs({ "ir_mesa", "ir_tienda", "ir_armario", "ir_movil" }) do
        click(e); esperar(25)
        foto("reporte_" .. e:sub(4))
    end
end
