-- =====================================================================================
-- sonda_kudos_bloqueados_gv3.lua — Investiga el castigo de «Kudos bloqueados» de GV3 (game3.exe):
-- en pantalla sale en NEGATIVO, en memoria está en POSITIVO. El usuario lo redujo (2026-11-08) a:
--   1EB84B92A1C · 1EC087719D0   (la 1.ª = [game3.exe+1F02FE8]+0x2FC, objeto base de los Kudos).
--   Descartada 1EC07DA7578: cayó a 0 al pasar a otra fase del nivel (copia temporal).
-- Qué hace (sin escribir memoria):
--   A) Cada dirección como entero de 4 bytes, float y 2 bytes; su relación con el objeto base [B],
--      el objeto jugador [[[B]+10]+10] y el bloque de EXP [[[B]+20]+110]; y si coincide con el valor de pantalla.
--   B) Punteros estáticos de 1 nivel en game3.exe hacia cada dirección (offset ≤ 0x2000).
--   C) Muestreo de 5 min (cada 500 ms): las 3 direcciones, [B]+0x2F8/+0x2FC/+0x300 y los Kudos ([B]+0x264)
--      con su compañero [B]+0x268: primero → último, mín./máx., nº de cambios y en cuántas lecturas
--      bajó el castigo mientras subían los Kudos.
-- Uso: GV3 dentro de un nivel CON castigo activo. Lua Engine > pegar > Execute. Durante el muestreo
-- gana Kudos para ir pagando el castigo (y, si puedes, provoca otro castigo).
-- Resultado: ventana + portapapeles + dumps\sonda_kudos_bloqueados_gv3_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\sonda_kudos_bloqueados_gv3_]] ..
                 os.date("%Y-%m-%d_%H%M") .. ".txt"
local MUESTREO, PASO = 300000, 500

local b3 = getAddressSafe("game3.exe")
if not b3 then showMessage("Adjunta Cheat Engine a game3.exe primero."); return end
local size = getModuleSize("game3.exe")
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local function enMod(a) return a and a >= b3 and a < b3 + size end
local function dir(a) return enMod(a) and string.format("game3.exe+%X", a - b3) or string.format("%X", a or 0) end
local B = readQword(BASE)
if not valido(B) then showMessage("No se encontró la base de GV3 (game3.exe+1F02FE8). Entra a un nivel."); return end
local P = readQword(B + 0x10); P = valido(P) and readQword(P + 0x10) or nil
local X = readQword(B + 0x20); X = valido(X) and readQword(X + 0x110) or nil

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end

local txt = inputQuery("Kudos bloqueados GV3", "Direcciones a investigar (separadas por espacios; hex):",
                       "1EB84B92A1C 1EC087719D0")
if not txt then return end
local DIRS = {}
for h in txt:gmatch("%x+") do DIRS[#DIRS + 1] = tonumber(h, 16) end
local pant = tonumber(inputQuery("Kudos bloqueados GV3",
  "Castigo que ves AHORA en pantalla (sin el signo «−»; vacío = omitir):", "") or "")

local function tipos(a)
  local i, f, w = readInteger(a), readFloat(a), readSmallInteger(a)
  return i, f, w
end
local function rel(a)
  local r = {}
  if B and a >= B and a < B + 0x2000 then r[#r + 1] = string.format("[B]+0x%X", a - B) end
  if P and a >= P and a < P + 0x2000 then r[#r + 1] = string.format("jugador+0x%X", a - P) end
  if X and a >= X and a < X + 0x4000 then r[#r + 1] = string.format("bloque EXP+0x%X", a - X) end
  return #r > 0 and table.concat(r, " · ") or "fuera de los objetos conocidos"
end

-- Punteros estáticos de 1 nivel: QWORD dentro de game3.exe con valor en [a−0x2000, a]
local function estaticos(a)
  local ms = createMemScan()
  ms.firstScan(soValueBetween, vtQword, rtRounded, string.format("%X", a - 0x2000), string.format("%X", a),
               b3, b3 + size, "", fsmAligned, "8", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, 8) - 1 do
    local s = tonumber(fl.Address[i], 16)
    r[#r + 1] = string.format("[%s]+0x%X", dir(s), a - readQword(s))
  end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

-- ---------------------------------------------------------------- A y B
local ok, err = pcall(function()
  p("== Sonda de Kudos bloqueados GV3 — %s ==", os.date("%Y-%m-%d %H:%M"))
  p("[B] = %X · jugador = %X · bloque EXP = %X · Kudos [B]+264 = %s · castigo en pantalla = %s",
    B, P or 0, X or 0, tostring(readFloat(B + 0x264)), pant and ("−" .. pant) or "?")
  p("\n== A) Direcciones ==")
  for _, a in ipairs(DIRS) do
    local i, f, w = tipos(a)
    local coincide = ""
    if pant then
      if i == pant then coincide = "  ← = pantalla como ENTERO"
      elseif f and math.abs(f - pant) < 1 then coincide = "  ← = pantalla como FLOAT"
      elseif w == pant then coincide = "  ← = pantalla como 2 BYTES" end
    end
    p("  %X  entero %s · float %s · 2 B %s  (%s)%s", a, tostring(i), tostring(f), tostring(w), rel(a), coincide)
  end
  p("\n== B) Punteros estáticos de 1 nivel en game3.exe (offset ≤ 0x2000) ==")
  for _, a in ipairs(DIRS) do
    local r, total = estaticos(a)
    p("  %X → %d%s", a, total, total > 0 and (": " .. table.concat(r, " · ")) or "")
  end
end)
if not ok then p("\nERROR: %s", tostring(err)) end

-- ---------------------------------------------------------------- C) muestreo
local SEG = {}
for k, a in ipairs(DIRS) do SEG[#SEG + 1] = { n = string.format("Dirección %d (%X)", k, a), a = function() return a end } end
for _, o in ipairs({ 0x2F8, 0x2FC, 0x300 }) do
  SEG[#SEG + 1] = { n = string.format("[B]+0x%X", o), a = function() local b = readQword(BASE); return valido(b) and b + o end }
end
local iK = #SEG + 1
SEG[#SEG + 1] = { n = "Kudos [B]+0x264", a = function() local b = readQword(BASE); return valido(b) and b + 0x264 end, f = true }
SEG[#SEG + 1] = { n = "[B]+0x268 (compañero)", a = function() local b = readQword(BASE); return valido(b) and b + 0x268 end, f = true }
for _, s in ipairs(SEG) do s.cambios, s.bajaConKudos = 0, 0 end

local nLect = 0
local function leer(s)
  local a = s.a()
  if not a then return nil, nil end
  return readInteger(a), readFloat(a)
end
local function lectura()
  nLect = nLect + 1
  local kAnt = SEG[iK].ult
  local kNow = select(2, leer(SEG[iK]))
  for _, s in ipairs(SEG) do
    local i, f = leer(s)
    local v = s.f and f or i
    if v then
      if s.prim == nil then s.prim, s.min, s.max, s.fprim = v, v, v, f end
      if s.ult ~= nil and v ~= s.ult then
        s.cambios = s.cambios + 1
        if not s.f and v < s.ult and kAnt and kNow and kNow > kAnt then s.bajaConKudos = s.bajaConKudos + 1 end
      end
      if v < s.min then s.min = v end
      if v > s.max then s.max = v end
      s.ult, s.fult = v, f
    end
  end
end

local function terminar(seg)
  p("\n== C) Muestreo de %d s (%d lecturas) ==", seg, nLect)
  for _, s in ipairs(SEG) do
    if s.prim ~= nil then
      local extra = s.f and "" or string.format("  · float %s → %s · bajó mientras subían los Kudos: %d",
        tostring(s.fprim), tostring(s.fult), s.bajaConKudos)
      p("  %-28s %s → %s  (mín. %s, máx. %s, %d cambios)%s", s.n, tostring(s.prim), tostring(s.ult),
        tostring(s.min), tostring(s.max), s.cambios, extra)
    else
      p("  %-28s (no legible)", s.n)
    end
  end
  p("\nAnota el castigo y los Kudos que ves al final en pantalla y pásalos con este informe.")
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

showMessage("Lecturas listas. Al cerrar este aviso empiezan 5 min de muestreo:\n" ..
  "· gana Kudos para ir pagando el castigo;\n· si puedes, provoca otro castigo;\n· NO pauses el juego.\n" ..
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
