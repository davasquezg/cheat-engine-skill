-- =====================================================================================
-- invencible_gv1.lua — Invencibilidad de GV1 como interruptor (activar = Sí, desactivar = No).
-- Mantiene el temporizador de invencibilidad del jugador ([gv1_player]+0x518) en 11520
-- (valor que el juego pone tras un golpe; confirmado 2026-11-01). Requiere la sonda 1.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if INV_GV1 and INV_GV1.timer then INV_GV1.timer.destroy() end
if not getAddressSafe("gv1_player") then
  local r = getAddressList().getMemoryRecordByDescription("Captura jugador (base de los trucos; se activa sola)")
  if r and not r.Active then r.Active = true end
end
if not getAddressSafe("gv1_player") then
  error("No se pudo activar 'Captura jugador'. Entra a un nivel y vuelve a intentar.")
end
INV_GV1 = {}
local t = createTimer(nil, false)
t.Interval = 50
t.OnTimer = function()
  pcall(function()
    local pp = getAddressSafe("gv1_player")
    local P = pp and readQword(pp)
    if P and P > 0x10000 then
      local a = P + 0x518
      local v = readInteger(a)
      if v ~= nil and v < 11520 then writeInteger(a, 11520) end
    end
  end)
end
INV_GV1.timer = t
t.Enabled = true
