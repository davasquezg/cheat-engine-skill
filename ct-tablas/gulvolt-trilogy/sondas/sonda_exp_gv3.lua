-- =====================================================================================
-- sonda_exp_gv3.lua — Busca la EXP REAL de GV3 (game3.exe), la que decide el nivel.
-- Motivo: la cadena de wepon1984 [[[game3.exe+1F02FE8]+20]+110]+2A80 sí cambia con la EXP, pero el
-- multiplicador la subió de 40 313 a 371 228 y el nivel solo pasó de 36 a 37 → no es la que manda.
-- Qué hace (sin escribir memoria):
--   A) Lee la cadena de wepon1984 (EXP y Nivel) para comparar.
--   B) Pide la EXP que muestra el MENÚ de estado y el Nivel; busca ese valor como entero de 4 bytes en
--      TODA la memoria escribible (hasta 3000 coincidencias) y como float. Marca las que tienen el Nivel
--      cerca (byte o 2 bytes en ±0x10) y las que están dentro de game3.exe.
--   C) Muestreo de 5 min: qué coincidencias SUBEN con la EXP de la cadena (se informan las que suben y
--      cuánto), y punteros estáticos de 1 nivel en game3.exe hacia las mejores.
-- Uso: abre el menú de estado, anota EXP y Nivel, vuelve al nivel y ejecuta (Lua Engine > pegar > Execute).
-- Desactiva antes «EXP ×N». Durante el muestreo gana EXP (derrota enemigos).
-- Resultado: ventana + portapapeles + dumps\sonda_exp_gv3_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\sonda_exp_gv3_]] ..
                 os.date("%Y-%m-%d_%H%M") .. ".txt"
local MUESTREO, PASO, MAXH = 300000, 1000, 3000

local b3 = getAddressSafe("game3.exe")
if not b3 then showMessage("Adjunta Cheat Engine a game3.exe primero."); return end
local size = getModuleSize("game3.exe")
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function enMod(a) return a and a >= b3 and a < b3 + size end
local function dir(a) return enMod(a) and string.format("game3.exe+%X", a - b3) or string.format("%X", a or 0) end
local function dirExpCadena()
  local a = readQword(BASE)
  if not valido(a) then return nil end
  a = readQword(a + 0x20); if not valido(a) then return nil end
  a = readQword(a + 0x110); if not valido(a) then return nil end
  return a + 0x2A80
end

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end

local function escanear(tipo, valor, desde, hasta, maxN)
  local ms = createMemScan()
  ms.firstScan(soExactValue, tipo, rtRounded, tostring(valor), "", desde, hasta, "+W",
               fsmAligned, "4", false, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxN) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end
local function estaticos(a)
  local ms = createMemScan()
  ms.firstScan(soValueBetween, vtQword, rtRounded, string.format("%X", a - 0x3000), string.format("%X", a),
               b3, b3 + size, "", fsmAligned, "8", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, 5) - 1 do
    local s = tonumber(fl.Address[i], 16)
    r[#r + 1] = string.format("[%s]+0x%X", dir(s), a - readQword(s))
  end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

local hits = {}          -- { a, ini, ult, sube, cambios, nivel = texto|nil }
local expC0, expC = nil, nil
local ok, err = pcall(function()
  p("== Sonda de EXP GV3 — %s ==", os.date("%Y-%m-%d %H:%M"))
  local ac = dirExpCadena()
  expC0 = ac and readInteger(ac)
  p("A) Cadena de wepon1984: EXP %s · Nivel %s  (%X)", tostring(expC0), tostring(ac and readBytes(ac + 6, 1)), ac or 0)

  local ex = tonumber(inputQuery("Sonda de EXP GV3", "EXP que muestra el MENÚ de estado:", "") or "")
  local nv = tonumber(inputQuery("Sonda de EXP GV3", "NIVEL que muestra el menú:", "") or "")
  if not ex then error("Sin EXP del menú no hay búsqueda.") end
  p("B) Menú: EXP %d · Nivel %s", ex, tostring(nv))

  local r, total = escanear(vtDword, ex, 0x10000, 0x7FFFFFFFFFFF, MAXH)
  p("  EXP como entero de 4 bytes: %d coincidencia(s)%s", total, total > #r and string.format(" (se siguen %d)", #r) or "")
  local rf, tf = escanear(vtSingle, ex, 0x10000, 0x7FFFFFFFFFFF, 50)
  p("  EXP como float: %d coincidencia(s)", tf)
  for _, a in ipairs(r) do
    local h = { a = a, ini = ex, ult = ex, sube = 0, cambios = 0, f = false }
    if nv then
      for o = -0x10, 0x10 do
        if o ~= 0 and (readBytes(a + o, 1) == nv or readSmallInteger(a + o) == nv) then
          h.nivel = string.format("Nivel en %+d", o); break
        end
      end
    end
    hits[#hits + 1] = h
  end
  for _, a in ipairs(rf) do hits[#hits + 1] = { a = a, ini = ex, ult = ex, sube = 0, cambios = 0, f = true } end
  local conNivel, enModulo = 0, 0
  for _, h in ipairs(hits) do
    if h.nivel then conNivel = conNivel + 1 end
    if enMod(h.a) then enModulo = enModulo + 1 end
  end
  p("  con el Nivel a ±0x10: %d · dentro de game3.exe: %d", conNivel, enModulo)
end)
if not ok then p("\nERROR: %s", tostring(err)) end

local nLect = 0
local function lectura()
  nLect = nLect + 1
  local ac = dirExpCadena()
  expC = ac and readInteger(ac)
  for _, h in ipairs(hits) do
    local v = h.f and readFloat(h.a) or readInteger(h.a)
    if v and v ~= h.ult then
      h.cambios = h.cambios + 1
      if v > h.ult then h.sube = h.sube + 1 end
      h.ult = v
    end
  end
end

local function terminar(seg)
  p("\n== C) Muestreo de %d s (%d lecturas) ==", seg, nLect)
  p("  Cadena de wepon1984: EXP %s → %s", tostring(expC0), tostring(expC))
  local subieron = {}
  for _, h in ipairs(hits) do if h.sube > 0 then subieron[#subieron + 1] = h end end
  table.sort(subieron, function(x, y)
    local nx, ny = x.nivel and 1 or 0, y.nivel and 1 or 0
    if nx ~= ny then return nx > ny end
    return x.sube > y.sube
  end)
  p("  Coincidencias que SUBIERON: %d de %d", #subieron, #hits)
  for i = 1, math.min(#subieron, 25) do
    local h = subieron[i]
    p("    %-18s %s → %s  (subió %d veces)%s%s", dir(h.a), tostring(h.ini), tostring(h.ult), h.sube,
      h.f and "  [float]" or "", h.nivel and ("  · " .. h.nivel) or "")
  end
  if #subieron == 0 then p("    (ninguna: ¿ganaste EXP durante el muestreo? ¿«EXP ×N» estaba desactivado?)") end
  p("\n  Punteros estáticos (1 nivel, offset ≤ 0x3000) hacia las 5 primeras:")
  for i = 1, math.min(#subieron, 5) do
    local r, total = estaticos(subieron[i].a)
    p("    %-18s → %d%s", dir(subieron[i].a), total, total > 0 and (": " .. table.concat(r, " · ")) or "")
  end
  p("\nAnota la EXP y el Nivel del menú al terminar y pásalos con este informe.")
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

if #hits == 0 then
  terminar(0)
else
  showMessage("Búsqueda lista. Al cerrar este aviso empiezan 5 min de muestreo:\n" ..
    "· derrota enemigos para ganar EXP (con «EXP ×N» DESACTIVADO);\n· NO pauses el juego.\n" ..
    "Al terminar aparece el informe (no cierres Cheat Engine).")
  local t0 = getTickCount()
  lectura()
  local t = createTimer(nil, false)
  t.Interval = PASO
  t.OnTimer = function(tm)
    local ahora = getTickCount()
    local okL, errL = pcall(lectura)
    if not okL or ahora - t0 >= MUESTREO then
      tm.destroy()
      if not okL then p("\nERROR en una lectura: %s", tostring(errL)) end
      local okT, errT = pcall(terminar, (ahora - t0) // 1000)
      if not okT then showMessage("ERROR: " .. tostring(errT)) end
    end
  end
  t.Enabled = true
end
