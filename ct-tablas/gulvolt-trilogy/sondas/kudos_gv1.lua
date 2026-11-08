-- =====================================================================================
-- kudos_gv1.lua — Localiza el Prestigio (Kudos) de GV1 en el heap por FIRMA DE MEMORIA,
-- sin depurador ni punteros estáticos (no hay de 1-2 niveles). Hallado el 2026-11-01:
--   K+0x0 = Prestigio en pantalla      K+0x4 = Prestigio interno ×256 (punto fijo 24.8)
--   K+0x34, K+0x3C = punteros a código de game1.exe (+234130, +4C470) — ESTABLES entre corridas
--   (K+0xC también apunta a código pero CAMBIA según el estado: +B2500 / +B6640; no se usa)
-- Registra:  gv1_kudos     = K+0x4 (interno; es el que hay que modificar)
--            gv1_kudos_vis = K+0x0 (pantalla; el juego lo recalcula desde el interno)
-- Un temporizador re-localiza la estructura si cambia (p. ej. al cambiar de nivel).
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if KUDOS_GV1 and KUDOS_GV1.timer then KUDOS_GV1.timer.destroy() end
local base = getAddressSafe("game1.exe")
if not base then error("Adjunta Cheat Engine a game1.exe") end
local F2, F3 = base + 0x234130, base + 0x4C470

local function valido(K)
  return K and readQword(K + 0x34) == F2 and readQword(K + 0x3C) == F3
end

-- La firma (+34/+3C) la comparten ~200 objetos del mismo tipo (diagnóstico 2026-11-01: 214).
-- Se elige el del Prestigio así: 1) campo K-0x14 = 1662 (constante en las 4 corridas observadas),
-- 2) interno = pantalla × 256, 3) pantalla > 0, 4) si aún hay dudas, el que CAMBIE (ver temporizador).
local ID_KUDOS = 1662

local function localizar()
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtQword, rtRounded, string.format("%X", F2), "", 0x10000, 0x7FFFFFFFFFFF,
               "+W", fsmAligned, "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local cands = {}
  for i = 0, math.min(fl.Count, 5000) - 1 do
    local K = tonumber(fl.Address[i], 16) - 0x34
    if valido(K) then
      local vis, raw = readInteger(K), readInteger(K + 4)
      if raw ~= nil and vis ~= nil and raw // 256 == vis then
        cands[#cands + 1] = { K = K, vis = vis, id = readInteger(K - 0x14) }
      end
    end
  end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  local function primero(f) for _, c in ipairs(cands) do if f(c) then return c.K end end end
  local K = primero(function(c) return c.id == ID_KUDOS and c.vis > 0 end)
         or primero(function(c) return c.id == ID_KUDOS end)
         or primero(function(c) return c.vis > 0 end)
  return K, #cands, cands
end

local function registrar(K)
  registerSymbol("gv1_kudos", K + 4, true)
  registerSymbol("gv1_kudos_vis", K, true)
  KUDOS_GV1.K = K
end

KUDOS_GV1 = { K = nil }
local K, n = localizar()
if K then registrar(K) end

local t = createTimer(nil, false)
t.Interval = 3000
t.OnTimer = function()
  pcall(function()
    local K = KUDOS_GV1.K
    if not valido(K) or (readInteger(K - 0x14) ~= ID_KUDOS and (readInteger(K) or 0) == 0) then
      local K2 = localizar()
      if K2 then registrar(K2) end
    end
  end)
end
KUDOS_GV1.timer = t
t.Enabled = true
if not KUDOS_SILENCIO then
  if K then
    showMessage(string.format("Prestigio localizado en %X (candidatos con la firma: %d).\n" ..
      "gv1_kudos = interno ×256 · gv1_kudos_vis = pantalla.\nSe re-localiza solo si cambia de nivel.", K, n))
  else
    showMessage("Prestigio aún no localizado (¿fuera de un nivel?). Se buscará automáticamente cada 3 s.")
  end
end
