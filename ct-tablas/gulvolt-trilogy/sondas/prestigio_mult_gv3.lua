-- =====================================================================================
-- prestigio_mult_gv3.lua — Multiplica las GANANCIAS de Prestigio (Kudos) de GV3 y, opcionalmente,
-- impide que BAJE. Kudos = [game3.exe+1F02FE8]+264 (float; wepon1984, base de la build 2026-10-13;
-- diagnóstico v3: 4108,46 con 4108 en pantalla, 579 → 1899,86 en 5 min).
-- Factor y «mantener» en las listas desplegables de la tabla:
--   gv3_kudos_mult = 1, 2, 4 … 1024 (por defecto 2)   gv3_kudos_keep = 0 No / 1 Sí (por defecto 0)
-- Tope: 99 999. Sin inyectar código: temporizador Lua cada 50 ms. Pendiente de probar en el juego.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if MULTI_KUDOS3 and MULTI_KUDOS3.timer then MULTI_KUDOS3.timer.destroy() end
local TOPE = 99999
local b3 = getAddressSafe("game3.exe")
if not b3 then error("Adjunta Cheat Engine a game3.exe") end
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function dirKudos()
  local a = readQword(BASE)
  return valido(a) and a + 0x264 or nil
end
if not dirKudos() then error("No se encontró la base de GV3. Entra a un nivel y vuelve a intentar.") end

local aMult = getAddressSafe("gv3_kudos_mult")
if not aMult then
  aMult = allocateMemory(16)
  registerSymbol("gv3_kudos_mult", aMult, true)
  writeInteger(aMult, 2)
end
local aKeep = getAddressSafe("gv3_kudos_keep")
if not aKeep then
  aKeep = allocateMemory(16)
  registerSymbol("gv3_kudos_keep", aKeep, true)
  writeInteger(aKeep, 0)
end
local function factor()
  local k = readInteger(aMult) or 1
  if k < 1 then k = 1 end
  if k > 1024 then k = 1024 end
  return k
end

MULTI_KUDOS3 = { a = nil, last = nil }
local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    local a = dirKudos()
    if not a then MULTI_KUDOS3.a = nil; MULTI_KUDOS3.last = nil; return end
    if a ~= MULTI_KUDOS3.a then MULTI_KUDOS3.a = a; MULTI_KUDOS3.last = readFloat(a); return end
    local v, last = readFloat(a), MULTI_KUDOS3.last
    if v and last then
      local k = factor()
      if v > last and k > 1 then
        v = math.min(last + (v - last) * k, TOPE)
        writeFloat(a, v)
      elseif v < last and readInteger(aKeep) == 1 then
        writeFloat(a, last); v = last
      end
    end
    MULTI_KUDOS3.last = v
  end)
end
MULTI_KUDOS3.timer = tm
tm.Enabled = true
