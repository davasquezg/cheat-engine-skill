-- =====================================================================================
-- multiplicador_gv1.lua — Multiplica las GANANCIAS de Prestigio (gv1_kudos) y EXP (gv1_exp)
-- y, opcionalmente, impide que el Prestigio BAJE al recibir golpes. Sin inyectar código:
-- un temporizador compara el valor con el anterior y suma (ganancia × (k − 1)).
-- Requiere los símbolos registrados con el buscador (script 7). Si falta uno, se omite.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if MULTI_GV1 and MULTI_GV1.timer then MULTI_GV1.timer.destroy() end
local t = inputQuery("Multiplicador GV1", "Multiplicador de ganancias (1 a 10):", "2")
if not t then error("Cancelado por el usuario") end
local k = math.floor(tonumber(t) or 2)
if k < 1 then k = 1 end
if k > 10 then k = 10 end
local m = inputQuery("Multiplicador GV1",
  "Mantener el Prestigio (no dejar que baje al recibir golpes)? S/N\n" ..
  "Ojo: el juego también lo baja a 0 al canjearlo al final del nivel; con S se quedará fijo.", "S")
if not m then error("Cancelado por el usuario") end
local mantener = m:upper():sub(1, 1) == "S"

local vars = { { nombre = "gv1_kudos" }, { nombre = "gv1_exp" } }
MULTI_GV1 = { k = k, mantener = mantener, vars = vars }
local tm = createTimer(nil, false)
tm.Interval = 50
tm.OnTimer = function()
  pcall(function()
    for _, x in ipairs(MULTI_GV1.vars) do
      local a2 = getAddressSafe(x.nombre)
      if not a2 then x.a = nil; x.last = nil; goto siguiente end
      if a2 ~= x.a then x.a = a2; x.last = readInteger(a2) end
      local v = readInteger(x.a)
      if v and x.last then
        if v > x.last and MULTI_GV1.k > 1 then
          v = v + (v - x.last) * (MULTI_GV1.k - 1)
          writeInteger(x.a, v)
        elseif v < x.last and MULTI_GV1.mantener and x.nombre == "gv1_kudos" then
          writeInteger(x.a, x.last); v = x.last
        end
      end
      x.last = v
      ::siguiente::
    end
  end)
end
MULTI_GV1.timer = tm
tm.Enabled = true
showMessage(string.format("Multiplicador ×%d activo sobre el Prestigio%s.%s", k,
  getAddressSafe("gv1_exp") and " y la EXP" or " (EXP aún sin localizar)",
  mantener and "\nPrestigio protegido contra bajadas." or ""))
