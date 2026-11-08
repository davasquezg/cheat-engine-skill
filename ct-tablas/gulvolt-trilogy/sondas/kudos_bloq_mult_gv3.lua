-- =====================================================================================
-- kudos_bloq_mult_gv3.lua — Quita más rápido el castigo de «Kudos bloqueados» de GV3 (game3.exe).
-- Castigo = [game3.exe+1F02FE8]+0x2FC (POSITIVO en memoria, negativo en pantalla). Dirección hallada por el
-- usuario (1EB84B92A1C = [B]+0x2FC) y CONFIRMADA con sonda_kudos_bloqueados_gv3.lua (2026-11-08 06:17):
-- FLOAT 680,26 con −680 en pantalla; se paga solo (93 bajadas en 5 min) hasta 0. Respaldo: [game3.exe+1F02FD8]+0x12AC.
-- Cada vez que el castigo BAJA (se va pagando), multiplica esa bajada por k (sin pasar de 0).
-- Listas desplegables de la tabla:
--   gv3_kbloq_mult = 1, 2, 4 … 1024 (por defecto 2)   gv3_kbloq_cero = 0 No / 1 Sí: anular el castigo (lo deja en 0)
-- Sin inyectar código: temporizador Lua cada 50 ms.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if KBLOQ_GV3 and KBLOQ_GV3.timer then KBLOQ_GV3.timer.destroy() end
local b3 = getAddressSafe("game3.exe")
if not b3 then error("Adjunta Cheat Engine a game3.exe") end
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function dirCastigo()
  local a = readQword(BASE)
  return valido(a) and a + 0x2FC or nil
end
if not dirCastigo() then error("No se encontró la base de GV3. Entra a un nivel y vuelve a intentar.") end

local aMult = getAddressSafe("gv3_kbloq_mult")
if not aMult then
  aMult = allocateMemory(16)
  registerSymbol("gv3_kbloq_mult", aMult, true)
  writeInteger(aMult, 2)
end
local aCero = getAddressSafe("gv3_kbloq_cero")
if not aCero then
  aCero = allocateMemory(16)
  registerSymbol("gv3_kbloq_cero", aCero, true)
  writeInteger(aCero, 0)
end
local function factor()
  local k = readInteger(aMult) or 1
  if k < 1 then k = 1 end
  if k > 1024 then k = 1024 end
  return k
end

KBLOQ_GV3 = { a = nil, last = nil, tipo = "f" }   -- float confirmado por la sonda
local function leer(a) return KBLOQ_GV3.tipo == "f" and readFloat(a) or readInteger(a) end
local function escribir(a, v)
  if KBLOQ_GV3.tipo == "f" then writeFloat(a, v) else writeInteger(a, math.floor(v)) end
end

local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    local a = dirCastigo()
    if not a then KBLOQ_GV3.a = nil; KBLOQ_GV3.last = nil; return end
    if readInteger(aCero) == 1 then
      if readInteger(a) ~= 0 then writeInteger(a, 0) end      -- 0 es igual en entero y en float
      KBLOQ_GV3.last = 0
      return
    end
    if a ~= KBLOQ_GV3.a then KBLOQ_GV3.a = a; KBLOQ_GV3.last = leer(a); return end
    local v, last = leer(a), KBLOQ_GV3.last
    if v and last then
      local k = factor()
      if v < last and k > 1 then
        v = math.max(last - (last - v) * k, 0)
        escribir(a, v)
      end
    end
    KBLOQ_GV3.last = v
  end)
end
KBLOQ_GV3.timer = tm
tm.Enabled = true
