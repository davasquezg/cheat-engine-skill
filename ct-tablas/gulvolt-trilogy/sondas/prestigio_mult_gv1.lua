-- =====================================================================================
-- prestigio_mult_gv1.lua — Multiplica las GANANCIAS de Prestigio (gv1_kudos, interno ×256) y,
-- opcionalmente, impide que BAJE al recibir golpes. Sin inyectar código: un temporizador compara
-- el valor con el anterior y suma (ganancia × (k − 1)).
-- El factor y el «mantener» se eligen en las listas desplegables de la tabla, que leen/escriben:
--   gv1_kudos_mult = factor 1, 2, 4 … 1024 (por defecto 2)   gv1_kudos_keep = 0 No / 1 Sí (por defecto 0)
-- (4 bytes cada uno en memoria reservada dentro del juego; se pueden cambiar en vivo).
-- Requiere gv1_kudos (kudos_gv1.lua). Tope: 9999 en pantalla (= 9999 × 256 interno).
-- Ojo: el juego baja el Prestigio a 0 al canjearlo al final del nivel; con «mantener» se quedará fijo.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if MULTI_KUDOS and MULTI_KUDOS.timer then MULTI_KUDOS.timer.destroy() end
local TOPE = 9999 * 256

-- Variables de 4 bytes en el juego (se reutilizan si ya existen: lo elegido sobrevive a desactivar)
local aMult = getAddressSafe("gv1_kudos_mult")
if not aMult then
  aMult = allocateMemory(16)
  registerSymbol("gv1_kudos_mult", aMult, true)
  writeInteger(aMult, 2)
end
local aKeep = getAddressSafe("gv1_kudos_keep")
if not aKeep then
  aKeep = allocateMemory(16)
  registerSymbol("gv1_kudos_keep", aKeep, true)
  writeInteger(aKeep, 0)
end

local function factor()
  local k = readInteger(aMult) or 1
  if k < 1 then k = 1 end
  if k > 1024 then k = 1024 end
  return k
end

MULTI_KUDOS = { a = nil, last = nil }
local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    local a = getAddressSafe("gv1_kudos")
    if not a then MULTI_KUDOS.a = nil; MULTI_KUDOS.last = nil; return end
    if a ~= MULTI_KUDOS.a then MULTI_KUDOS.a = a; MULTI_KUDOS.last = readInteger(a); return end
    local v, last = readInteger(a), MULTI_KUDOS.last
    if v and last then
      local k = factor()
      if v > last and k > 1 then
        v = math.min(last + (v - last) * k, TOPE)
        writeInteger(a, v)
      elseif v < last and readInteger(aKeep) == 1 then
        writeInteger(a, last); v = last
      end
    end
    MULTI_KUDOS.last = v
  end)
end
MULTI_KUDOS.timer = tm
tm.Enabled = true
