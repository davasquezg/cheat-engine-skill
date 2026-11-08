-- =====================================================================================
-- materiales_etiquetar_gv1.lua — Pone a cada material un valor distinto para identificarlo
-- en el inventario: slot #00 = 99, #01 = 98, … #27 = 72.  =>  slot = 99 - cantidad.
-- Al DESACTIVAR restaura las cantidades originales. NO guardes la partida con esto activo.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local base = getAddressSafe("game1.exe")
if not base then error("Adjunta Cheat Engine a game1.exe") end
local MAT = base + 0x7B3668 + 0x3B0
for i = 0, 27 do
  local v = readInteger(MAT + 4 * i)
  if v == nil or v < 0 or v > 9999 then
    error(string.format("El bloque de materiales no tiene la forma esperada (slot %d = %s).", i, tostring(v)))
  end
end
MATS_GV1_ETIQ = {}
for i = 0, 27 do
  MATS_GV1_ETIQ[i] = readInteger(MAT + 4 * i)
  writeInteger(MAT + 4 * i, 99 - i)
end
showMessage("Materiales etiquetados: slot #00 = 99 … slot #27 = 72.\n" ..
            "En el inventario: slot = 99 − cantidad.\n" ..
            "Anota nombre y cantidad de cada material y DESACTIVA el script antes de guardar.")
