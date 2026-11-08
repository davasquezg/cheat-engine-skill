-- =====================================================================================
-- exp_mult_gv3.lua — Multiplica las GANANCIAS de EXP de GV3 (game3.exe). Sin inyectar código: un
-- temporizador compara la EXP con la lectura anterior y suma (ganancia × (k − 1)).
-- EXP = [[[game3.exe+1F02FE8]+20]+110]+2A80 (DWORD) y Nivel = …+2A86 (byte): cadenas de wepon1984 con la
-- base hallada en la build 2026-10-13 (diagnóstico v3: EXP 36 863 → 40 313 y Nivel 34 → 36 en 5 min).
-- El factor se elige en la lista desplegable de la tabla, que lee/escribe:
--   gv3_exp_mult = factor 1, 2, 4 … 1024 (por defecto 2; 4 bytes en memoria reservada; cambia en vivo).
-- La dirección de la EXP se vuelve a resolver en cada lectura (cambia al cambiar de personaje o nivel).
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if MULTI_EXP3 and MULTI_EXP3.timer then MULTI_EXP3.timer.destroy() end
local TOPE = 0x7FFFFFFF
local b3 = getAddressSafe("game3.exe")
if not b3 then error("Adjunta Cheat Engine a game3.exe") end
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function dirExp()
  local a = readQword(BASE)
  if not valido(a) then return nil end
  a = readQword(a + 0x20)
  if not valido(a) then return nil end
  a = readQword(a + 0x110)
  if not valido(a) then return nil end
  local nv = readBytes(a + 0x2A86, 1)
  if not nv or nv < 1 or nv > 99 then return nil end      -- comprobación de forma antes de escribir
  return a + 0x2A80
end
if not dirExp() then error("No se encontró la EXP de GV3 (nivel fuera de 1–99). Entra a un nivel y vuelve a intentar.") end

local aMult = getAddressSafe("gv3_exp_mult")
if not aMult then
  aMult = allocateMemory(16)
  registerSymbol("gv3_exp_mult", aMult, true)
  writeInteger(aMult, 2)
end
local function factor()
  local k = readInteger(aMult) or 1
  if k < 1 then k = 1 end
  if k > 1024 then k = 1024 end
  return k
end

MULTI_EXP3 = { a = nil, last = nil }
local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    local a = dirExp()
    if not a then MULTI_EXP3.a = nil; MULTI_EXP3.last = nil; return end
    if a ~= MULTI_EXP3.a then MULTI_EXP3.a = a; MULTI_EXP3.last = readInteger(a); return end
    local v, last = readInteger(a), MULTI_EXP3.last
    if v and last then
      local k = factor()
      if v > last and k > 1 then
        v = math.min(last + (v - last) * k, TOPE)
        writeInteger(a, v)
      end
    end
    MULTI_EXP3.last = v
  end)
end
MULTI_EXP3.timer = tm
tm.Enabled = true
