-- =====================================================================================
-- invencible_exp_gv3.lua (v2) — Invencibilidad EXPERIMENTAL de GV3 (game3.exe).
-- Objeto del jugador = [[[game3.exe+1F02FE8]+10]+10]. Sondas v5–v6 (2026-11-09, 12 golpes):
--   · +0x274 pasa de 0x7FFFF a 0x6FFFF (se apaga SOLO el bit 0x10000) exactamente mientras dura el parpadeo de
--     invulnerabilidad, 6/6 golpes en las dos sondas → probable máscara de colisión («se le puede golpear»).
--   · +0x060 es el estado de ANIMACIÓN (8 = herido, 6 = reposo, 7/9/10 = otras): no da invencibilidad sola.
-- Modo (lista desplegable gv3_inv_modo):
--   1 = máscara: mantiene apagado el bit 0x10000 de +0x274 (por defecto).
--   2 = estado: mantiene +0x060 en el valor de gv3_inv_estado (por defecto 8 = herido; puede dejarte en la
--       animación de golpe).
-- Sin inyectar código: temporizador Lua cada 30 ms. Si ves algo raro, desactívalo: el juego restaura sus valores.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if INV3 and INV3.timer then INV3.timer.destroy() end
local b3 = getAddressSafe("game3.exe")
if not b3 then error("Adjunta Cheat Engine a game3.exe") end
local BASE = b3 + 0x1F02FE8
local BIT = 0x10000
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function jugador()
  local a = readQword(BASE)
  a = valido(a) and readQword(a + 0x10) or nil
  a = valido(a) and readQword(a + 0x10) or nil
  return valido(a) and a or nil
end
if not jugador() then error("No se encontró el objeto del jugador de GV3. Entra a un nivel.") end

local aModo = getAddressSafe("gv3_inv_modo")
if not aModo then
  aModo = allocateMemory(16)
  registerSymbol("gv3_inv_modo", aModo, true)
  writeInteger(aModo, 1)
end
local aEst = getAddressSafe("gv3_inv_estado")
if not aEst then
  aEst = allocateMemory(16)
  registerSymbol("gv3_inv_estado", aEst, true)
  writeInteger(aEst, 8)
end

INV3 = {}
local t = createTimer(nil, false)
t.Interval = 30
t.OnTimer = function()
  pcall(function()
    local P = jugador()
    if not P then return end
    if readInteger(aModo) == 2 then
      local objetivo = readInteger(aEst) or 8
      if readInteger(P + 0x60) ~= objetivo then writeInteger(P + 0x60, objetivo) end
    else
      local m = readInteger(P + 0x274)
      if m and (m & BIT) ~= 0 then writeInteger(P + 0x274, m & ~BIT) end
    end
  end)
end
INV3.timer = t
t.Enabled = true
