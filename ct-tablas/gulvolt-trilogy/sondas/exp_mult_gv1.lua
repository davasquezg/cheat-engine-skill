-- =====================================================================================
-- exp_mult_gv1.lua — Multiplica las GANANCIAS de EXP de GV1. Sin inyectar código: un temporizador
-- compara la EXP con la lectura anterior y suma (ganancia × (k − 1)).
-- EXP = Créditos+0x478 = game1.exe+7B3AE0 (verificado 2026-11-08: subió con la EXP del menú y el nivel,
-- en +0x47C, subió 31 → 43). El juego copia la EXP en Créditos+0x438 por su cuenta.
-- El factor se elige en la lista desplegable de la tabla, que lee/escribe:
--   gv1_exp_mult = factor 1, 2, 4 … 1024 (por defecto 2; 4 bytes en memoria reservada; cambia en vivo).
-- Registra gv1_exp. Tope: 2 147 483 647 (DWORD con signo).
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if MULTI_EXP and MULTI_EXP.timer then MULTI_EXP.timer.destroy() end
local TOPE = 0x7FFFFFFF
local b1 = getAddressSafe("game1.exe")
if not b1 then error("Adjunta Cheat Engine a game1.exe") end
local EXP, NIVEL = b1 + 0x7B3AE0, b1 + 0x7B3AE4

-- Comprobación de forma antes de escribir (evita escribir en memoria equivocada si cambia la build)
local nv = readSmallInteger(NIVEL)
if not nv or nv < 1 or nv > 99 then
  error(string.format("El nivel en game1.exe+7B3AE4 no tiene la forma esperada (%s). ¿Otra build?", tostring(nv)))
end
registerSymbol("gv1_exp", EXP, true)

-- Variable de 4 bytes en el juego (se reutiliza si ya existe: el valor elegido sobrevive a desactivar)
local aMult = getAddressSafe("gv1_exp_mult")
if not aMult then
  aMult = allocateMemory(16)
  registerSymbol("gv1_exp_mult", aMult, true)
  writeInteger(aMult, 2)
end

local function factor()
  local k = readInteger(aMult) or 1
  if k < 1 then k = 1 end
  if k > 1024 then k = 1024 end
  return k
end

MULTI_EXP = { last = readInteger(EXP) }
local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    local v, last = readInteger(EXP), MULTI_EXP.last
    if v and last then
      local k = factor()
      if v > last and k > 1 then
        v = math.min(last + (v - last) * k, TOPE)
        writeInteger(EXP, v)
      end
    end
    MULTI_EXP.last = v
  end)
end
MULTI_EXP.timer = tm
tm.Enabled = true
