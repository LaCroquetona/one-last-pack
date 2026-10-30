-- Logros: se ven en el movil (app LOGROS) y avisan al conseguirlos. No dan
-- dinero. si(partida, mercado) se mira cada poco; los que no tienen si() se
-- marcan desde el juego (logros.marcar).
local rarezas = require "datos.rarezas"

local function tieneRareza(partida, mercado, nivel, chase)
    for id, l in pairs(partida.inv) do
        if #l > 0 then
            local def = mercado.carta(id)
            if def and ((chase and def.chase) or (not chase and rarezas[def.rareza].nivel >= nivel)) then return true end
        end
    end
    return false
end

local function tieneVariante(partida, mercado, cual)
    for id, l in pairs(partida.inv) do
        if #l > 0 then
            local def = mercado.carta(id)
            if def and def.variante == cual then return true end
        end
    end
    return false
end

return {
    { id = "sobre1", nombre = "EL PRIMERO", texto = "Abre tu primer sobre",
      si = function(pa) return pa.abiertos >= 1 end },
    { id = "sobre100", nombre = "ADICTO AL PLÁSTICO", texto = "Abre 100 sobres",
      si = function(pa) return pa.abiertos >= 100 end },
    { id = "sobre1000", nombre = "ONE LAST PACK", texto = "Abre 1.000 sobres",
      si = function(pa) return pa.abiertos >= 1000 end },
    { id = "godpack", nombre = "GOD PACK", texto = "Saca un god pack" },
    { id = "holo", nombre = "BRILLI BRILLI", texto = "Consigue una holo",
      si = function(pa, me) return tieneRareza(pa, me, 4) end },
    { id = "secreta", nombre = "SECRETITO", texto = "Consigue una carta secreta",
      si = function(pa, me) return tieneRareza(pa, me, 6) end },
    { id = "chase", nombre = "LA CHASE", texto = "Consigue una chase",
      si = function(pa, me) return tieneRareza(pa, me, 0, true) end },
    { id = "set", nombre = "ÁLBUM LLENO", texto = "Completa un set entero",
      si = function(pa, me)
          for _, s in ipairs(me.setsSalidos()) do
              local tienes, _, total = pa.progreso(s.id)
              if total > 0 and tienes >= total then return true end
          end
          return false
      end },
    { id = "alt", nombre = "OTRO ARTE", texto = "Consigue una carta ALT",
      si = function(pa, me) return tieneVariante(pa, me, "alt") end },
    { id = "golden", nombre = "PURO ORO", texto = "Consigue una GOLDEN",
      si = function(pa, me) return tieneVariante(pa, me, "golden") end },
    { id = "master", nombre = "MASTER SET", texto = "Completa un set y su fuera de set",
      si = function(pa, me)
          for _, s in ipairs(me.setsSalidos()) do
              if pa.master(s.id) then return true end
          end
          return false
      end },
    { id = "caja", nombre = "BOX BREAK", texto = "Abre una caja de sobres" },
    { id = "vendedor", nombre = "DE SEGUNDA MANO", texto = "Compra algo a un vendedor del móvil" },
    { id = "encargo", nombre = "CUMPLIDOR", texto = "Termina un encargo" },
    { id = "dinero100", nombre = "PRIMEROS 100 €", texto = "Ten 100 € en la cartera",
      si = function(pa) return pa.dinero >= 10000 end },
    { id = "dinero1000", nombre = "MIL PAVOS", texto = "Ten 1.000 € en la cartera",
      si = function(pa) return pa.dinero >= 100000 end },
    { id = "coleccion", nombre = "INVERSOR", texto = "Ten una colección que valga 10.000 €",
      si = function(pa) return pa.valorColeccion() >= 1000000 end },
    { id = "seg100", nombre = "CIEN SEGUIDORES", texto = "Llega a 100 seguidores",
      si = function(pa) return pa.canal.seguidores >= 100 end },
    { id = "seg1000", nombre = "MIL SEGUIDORES", texto = "Llega a 1.000 seguidores",
      si = function(pa) return pa.canal.seguidores >= 1000 end },
    { id = "record", nombre = "LLENO TOTAL", texto = "Ten 25 espectadores a la vez",
      si = function(pa) return (pa.canal.record or 0) >= 25 end },
}
