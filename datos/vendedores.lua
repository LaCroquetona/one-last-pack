-- Vendedores de segunda mano (movil > MERCADO): venden sobres, cajas y cartas.
-- Cada dia cada producto tiene sus ofertas; el precio sale de una campana
-- alrededor de una referencia:
--   tienda:  mientras la tienda lo vende, su precio oficial
--   sellado: cuando ya no, lo que vale cerrado en el mercado
--   caja:    las cajas, siempre (su referencia es la de la tienda o la
--            de sus sobres cerrados)
--   carta:   lo que vale la carta (algo por encima: si no, se compraria
--            para venderla al momento)
-- media y desv de la campana; min y max la recortan. Los de mas estrellas
-- piden algo mas (porEstrella por cada estrella por encima de 4).
return {
    cuantos = 48,
    precio = {
        tienda  = { media = 1.04, desv = 0.10, min = 0.78, max = 1.50 },
        sellado = { media = 1.06, desv = 0.10, min = 0.80, max = 1.60 },
        carta   = { media = 1.14, desv = 0.08, min = 0.92, max = 1.60 },
        -- las cajas cerradas se revenden caras (y asi no sale a cuenta
        -- comprarlas para vender sus sobres sueltos en directo)
        caja    = { media = 1.12, desv = 0.07, min = 0.95, max = 1.50 },
        porEstrella = 0.025,
    },
    -- una caja de reventa se mira contra sus 36 sobres cerrados
    cajaReventa = 1.0,
    -- cuantas ofertas hay de cada cosa ({ minimo, maximo }) y cuantas unidades
    -- tiene cada vendedor
    ofertas = { sobre = { 2, 5 }, caja = { 0, 3 } },
    stock = { sobre = { 1, 10 }, caja = { 1, 2 }, carta = { 1, 2 } },
    -- cartas: segun la rareza (nivel 1 comun ... 6 secreta)
    cartas = { { 2, 4 }, { 2, 4 }, { 1, 3 }, { 0, 2 }, { 0, 2 }, { 0, 1 } },
    nombres = {
        "CARTASPACO", "LA_TIENDITA", "SOBRES_YA", "MINTCONDITION", "PACKHUNTER", "EL_COLECCIONISTA",
        "CHOLLOSTCG", "TOPDECK_SHOP", "LUCIA_CARDS", "HOLOHOUSE", "BINDER_BRO", "CARDKINGDOM_ES",
        "TIO_PEPE_TCG", "NOMINT_NOLIFE", "SLEEVED_UP", "RAREZA_TOTAL", "GOATED_PACKS", "CAJAS_MARIO",
        "SECRETAZO", "FULLART_FAN", "PACKS_N_SNACKS", "LA_BODEGA_TCG", "DON_SOBRE", "RIPANDSHIP",
        "CARDBOARD_CRACK", "MAMI_COLECCIONA", "VINTAGE_VIBES", "FOILFRENZY", "LOS_DE_MALAGA", "EL_ARMARIO",
        "TCG_CORNER", "SUPER_SOBRES", "COMPRO_VENDO", "PULL_RATE", "SHINYSHOP", "SOBRE_A_SOBRE",
        "CARTONCITO", "DEALZ_TCG", "ZONA_CHASE", "MESA_LIMPIA", "BOX_BREAKER", "TOPLOADER_KING",
        "LA_CROQUETA_TCG", "PLASTIQUITO", "MANGO_CARDS", "SEALED_ONLY", "EL_REPE", "NEXT_PACK",
    },
}
