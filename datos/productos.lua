-- Productos sellados. Cada producto es una entrada: la tienda, la mesa, el
-- armario y el mercado leen esta lista, asi que uno nuevo es una linea mas (y
-- su dibujo en src/productos.lua si tiene otra forma).
-- sobres: cuantos sobres de su set lleva (mix: de que sets, en los de varios)
-- fundas, tops: lo que trae ademas
-- precio: veces lo que cuestan sus sobres en la tienda, mas extra (centimos).
--   Un sobre suelto da como mucho el 80% de su precio (S1 90%); los productos
--   pueden dar algo mas (blister un poco, tin y ETB mas), nunca mas del 100-105%
-- porDia: los que llegan a la tienda cada dia mientras el set esta a la venta
-- cabe: cuantos caben en un hueco de la tienda y del armario
-- sitio: gancho, balda o suelo. sets: solo de esos sets (nil: todos)
-- desbloqueo: el de datos/desbloqueos.lua con el que sale (nil: desde el principio)
-- sale = false: hecho, pero aun no se vende
local lista = {
    { id = "blister", nombre = "BLÍSTER", sitio = "gancho", sobres = 2, precio = 0.975, extra = 0, porDia = 2, cabe = 5 },
    { id = "tin", nombre = "TIN", sitio = "balda", sobres = 5, tops = 10, precio = 0.95, extra = 150, porDia = 1, cabe = 4,
      sets = { s1 = true, s2 = true }, desbloqueo = "cajas" },
    { id = "etb", nombre = "ETB", sitio = "balda", sobres = 9, fundas = 10, precio = 0.92, extra = 100, porDia = 1, cabe = 2,
      desbloqueo = "cajas" },
    -- la caja de siempre: su precio, stock y valor estan en datos/sobres.lua (sobres.caja)
    { id = "caja", nombre = "CAJA", sitio = "suelo", sobres = 18, cabe = 2, desbloqueo = "cajas" },
    { id = "tinmix", nombre = "TIN MIX", sitio = "balda", mix = { set1 = 3, set2 = 2 }, tops = 10, precio = 1, extra = 200,
      porDia = 2, cabe = 4, sale = false },
}

local productos = {
    lista = lista,
    -- sobres sueltos que caben en un hueco del armario
    sobresPorHueco = 20,
    -- lo que vale cada funda y cada top que trae (lo de la tienda: 20 fundas 1 €, 10 tops 1,50 €)
    valorFunda = 5,
    valorTop = 15,
}
for _, x in ipairs(lista) do productos[x.id] = x end
return productos
