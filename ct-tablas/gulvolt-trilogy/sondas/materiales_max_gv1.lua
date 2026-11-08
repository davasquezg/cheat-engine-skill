-- =====================================================================================
-- materiales_max_gv1.lua — Sube los 28 materiales de GV1 (game1.exe) a una cantidad fija.
-- Bloque de partida hallado por la multisonda: Créditos = game1.exe+7B3668 (build 2026-10-07),
-- materiales = Créditos + 0x3B0 (gv1.CT: +0x3A8; en la Trilogy hay 2 DWORD extra antes), 28 DWORD.
-- Al DESACTIVAR restaura las cantidades que había antes (deshacer).
-- Usar desde el mapa / menú fuera de combate y GUARDAR la partida para que persista.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local base = getAddressSafe("game1.exe")
if not base then error("Adjunta Cheat Engine a game1.exe") end
local SAVE = base + 0x7B3668
local MAT  = SAVE + 0x3B0   -- confirmado con etiquetado (2026-11-01)

-- Comprobación de forma antes de escribir (evita escribir en memoria equivocada)
for i = 0, 27 do
  local v = readInteger(MAT + 4 * i)
  if v == nil or v < 0 or v > 9999 then
    error(string.format("El bloque de materiales no tiene la forma esperada (slot %d = %s). ¿Otra build?", i, tostring(v)))
  end
end

local t = inputQuery("Materiales GV1", "Cantidad para cada material (1 a 999; 99 recomendado):", "99")
if not t then error("Cancelado por el usuario") end
local n = math.floor(tonumber(t) or 99)
if n < 1 then n = 1 end
if n > 999 then n = 999 end

local modo = inputQuery("Materiales GV1",
  "O = solo los materiales que ya tienes (cantidad > 0)\nT = los 28 (incluye únicos que aún no consigues)", "O")
if not modo then error("Cancelado por el usuario") end
local todos = modo:upper():sub(1, 1) == "T"

MATS_GV1_BACKUP = {}
local cambiados = 0
for i = 0, 27 do
  local a = MAT + 4 * i
  local v = readInteger(a)
  MATS_GV1_BACKUP[i] = v
  if todos or v > 0 then
    writeInteger(a, n); cambiados = cambiados + 1
  end
end
showMessage(string.format("Materiales: %d de 28 puestos en %d.\nDesactiva el script para restaurar las cantidades anteriores.", cambiados, n))
