-- =====================================================================================
-- camara_lenta_gv3.lua — «Cámara lenta» de GV3 (game3.exe) como interruptor (activar = Sí, desactivar = No).
-- Objeto jugador = [[[game3.exe+1F02FE8]+10]+10]. El campo de 2 bytes en jugador+0x592 (wepon1984 lo
-- llamaba «Invincibility Timer») resultó ser el temporizador del efecto de golpe: al mantenerlo alto el
-- juego va en CÁMARA LENTA (probado por el usuario 2026-11-08). NO da invencibilidad.
-- Mantiene el valor más alto que el juego le haya puesto tras un golpe (lo aprende); hasta el primer golpe usa 120.
-- Sin inyectar código: temporizador Lua cada 50 ms.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if LENTA_GV3 and LENTA_GV3.timer then LENTA_GV3.timer.destroy() end
local b3 = getAddressSafe("game3.exe")
if not b3 then error("Adjunta Cheat Engine a game3.exe") end
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function jugador()
  local a = readQword(BASE)
  if not valido(a) then return nil end
  a = readQword(a + 0x10)
  if not valido(a) then return nil end
  a = readQword(a + 0x10)
  return valido(a) and a or nil
end
if not jugador() then error("No se encontró el objeto jugador de GV3. Entra a un nivel y vuelve a intentar.") end

LENTA_GV3 = { max = 0 }
local t = createTimer(nil, false)
t.Interval = 50
t.OnTimer = function()
  pcall(function()
    local P = jugador()
    if not P then return end
    local a = P + 0x592
    local v = readSmallInteger(a)
    if not v then return end
    if v > LENTA_GV3.max and v < 0x7FFF then LENTA_GV3.max = v end
    local objetivo = LENTA_GV3.max > 0 and LENTA_GV3.max or 120
    if v < objetivo then writeSmallInteger(a, objetivo) end
  end)
end
LENTA_GV3.timer = t
t.Enabled = true
