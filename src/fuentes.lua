local fuentes = {}

function fuentes.preparar()
    fuentes.mini = love.graphics.newFont(8, "mono")
    fuentes.normal = love.graphics.newFont(12, "mono")
    fuentes.grande = love.graphics.newFont(20, "mono")
end

return fuentes
