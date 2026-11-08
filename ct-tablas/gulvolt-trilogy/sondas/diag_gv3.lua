-- =====================================================================================
-- diag_gv3.lua — Primer diagnóstico de GV3 (game3.exe) en la Trilogy. SOLO LECTURA, sin depurador.
-- Objetivo: saber qué se puede rescatar de las tablas de referencia para llegar, como mínimo, a los
-- mismos cheats que GV1 (ANALISIS_tablas_referencia.md §9).
--   A) Build ............... TimeDateStamp del encabezado PE en memoria (identifica la build).
--   B) Firmas AOB .......... cuántas veces aparece cada AOB de RTX_XXXX (gv3.CT) y wepon1984 en game3.exe
--                            (1 = utilizable; 0 = cambió el código; >1 = ambigua).
--   C) Base de wepon1984 ... [game3.exe+1E2CE98] y sus cadenas (EXP, Nivel, Tiempo, Score, Kudos, Fetters…).
--   D) Barrido de la base .. si C no sirve: prueba cada QWORD de game3.exe+1E2CE98 ±0x80000 como base,
--                            usando el Nivel (y el Prestigio, si lo escribes) que ves en pantalla.
--   E) Muestreo de 5 min ... qué valores de las cadenas cambian mientras juegas (con la base de C o de D).
-- Uso: CE adjunto a game3.exe, DENTRO de un nivel. Memory View > Tools > Lua Engine > pegar > Execute.
-- Los escaneos tardan unos segundos (CE parece congelado). NO pausar el juego durante el muestreo.
-- Resultado: ventana + portapapeles + dumps\diag_gv3_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD      = "game3.exe"
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\diag_gv3_]] ..
                 os.date("%Y-%m-%d_%H%M") .. ".txt"
local MUESTREO = 300000                 -- ms de muestreo (5 min)
local PASO     = 1000                   -- ms entre lecturas
local BASE_W   = 0x1E2CE98              -- base de wepon1984 (su build)
local VENTANA  = 0x80000                -- barrido ±VENTANA alrededor de BASE_W

-- AOB de las referencias. «rel32» = la firma incluye el desplazamiento de un call: frágil entre builds.
local AOBS = {
  {"Vida (Health / 1HK)",           "F3 0F 11 41 08 83 49 18 01 C3 0F", "RTX_XXXX y wepon1984: movss [rcx+08],xmm0 — HP float"},
  {"Invencible jugador",            "F3 0F 10 86 10 05 00 00 45",       "RTX_XXXX: movss xmm0,[rsi+510] — temporizador float"},
  {"Invencible ambos (rel32)",      "E8 AC 17 DF FF",                   "RTX_XXXX: call relativo, casi seguro que cambió"},
  {"Talismán infinito",             "88 91 9A 06 00 00",                "RTX_XXXX: mov [rcx+69A],dl"},
  {"High Score",                    "F3 0F 11 83 F8 00 00 00 40",       "RTX_XXXX: movss [rbx+F8],xmm0 — Score float"},
}

-- Cadenas de wepon1984 (offsets en orden de aplicación) y tipo
local CAD = {
  {"Invencibilidad: temporizador", {0x10, 0x10, 0x592}, "i2"},
  {"Invencibilidad: on/off",       {0x10, 0x10, 0x594}, "i2"},
  {"EXP",                          {0x20, 0x110, 0x2A80}, "i4"},
  {"Nivel",                        {0x20, 0x110, 0x2A86}, "b"},
  {"Tiempo de nivel",              {0x354}, "f"},
  {"Score",                        {0x44}, "i4"},
  {"Fetters Gauge",                {0x478}, "f"},
  {"Kudos (Prestigio)",            {0x264}, "f"},
  {"Image Chips (bits)",           {0x198}, "b"},
}

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local base = getAddressSafe(MOD)
if not base then showMessage("Adjunta Cheat Engine a " .. MOD .. " primero (GV3, dentro de un nivel)."); return end
local size = getModuleSize(MOD)
local function enMod(a) return a and a >= base and a < base + size end
local function dir(a) return enMod(a) and string.format("%s+%X", MOD, a - base) or string.format("%X", a or 0) end
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end

-- Sigue una cadena desde la dirección q (que guarda el puntero base). Devuelve la dirección final o nil.
local function cadena(q, offs)
  local a = readQword(q)
  for i = 1, #offs - 1 do
    if not valido(a) then return nil end
    a = readQword(a + offs[i])
  end
  if not valido(a) then return nil end
  return a + offs[#offs]
end
local LEE = {
  i4 = readInteger,
  i2 = readSmallInteger,
  b  = function(a) return readBytes(a, 1) end,
  f  = function(a) local v = readFloat(a); return v and math.floor(v * 100 + 0.5) / 100 end,
}
local function leerCad(q, c)
  local a = cadena(q, c[2])
  return a and LEE[c[3]](a), a
end

-- Coincidencias de un AOB dentro del módulo (máx. 10 direcciones)
local function aob(bytes)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtByteArray, rtRounded, bytes, "", base, base + size, "",
               fsmNotAligned, "1", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, 10) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

local Q = nil            -- dirección (en game3.exe) que guarda el puntero base elegido
local ok, err = pcall(function()
  p("== Diagnóstico GV3 — %s ==", os.date("%Y-%m-%d %H:%M"))

  -- ------------------------------------------------------------ A) build
  local pe = readInteger(base + 0x3C)
  local ts = pe and readInteger(base + pe + 8)
  p("%s base %X  tamaño %X  TimeDateStamp %s (%s)", MOD, base, size,
    ts and string.format("%08X", ts) or "?", ts and os.date("!%Y-%m-%d %H:%M UTC", ts) or "?")

  -- ------------------------------------------------------------ B) firmas AOB
  p("\n== B) Firmas AOB de las referencias en %s ==", MOD)
  for _, x in ipairs(AOBS) do
    local r, total = aob(x[2])
    local estado = total == 1 and "✅ única" or (total == 0 and "❌ no está" or "⚠️ ambigua")
    p("  %-28s %-34s → %d  %s", x[1], x[2], total, estado)
    for i = 1, math.min(#r, 3) do p("      %s", dir(r[i])) end
    p("      (%s)", x[3])
  end

  -- ------------------------------------------------------------ C) base de wepon1984
  p("\n== C) Base de wepon1984 [%s] ==", dir(base + BASE_W))
  local P = readQword(base + BASE_W)
  p("  puntero = %X %s", P or 0, valido(P) and "" or "(no válido)")
  for _, c in ipairs(CAD) do
    local v, a = leerCad(base + BASE_W, c)
    p("    %-30s %-18s = %s", c[1], a and string.format("%X", a) or "—", tostring(v))
  end

  -- ------------------------------------------------------------ D) barrido con valores de pantalla
  local nv = tonumber(inputQuery("Diagnóstico GV3", "NIVEL del personaje que ves AHORA\n(vacío = omitir el barrido):", "") or "")
  local kd = tonumber(inputQuery("Diagnóstico GV3", "PRESTIGIO (Kudos) que ves AHORA\n(vacío = no usarlo en el barrido):", "") or "")
  p("\n== D) Barrido de bases: %s ±0x%X (Nivel = %s, Prestigio = %s) ==", dir(base + BASE_W), VENTANA,
    tostring(nv), tostring(kd))
  local cNivel, cKudos, cTiempo = CAD[4], CAD[8], CAD[5]
  local function encaja(q)
    local n = leerCad(q, cNivel)
    if not n or (nv and n ~= nv) or (not nv and (n < 1 or n > 99)) then return false end
    local t = leerCad(q, cTiempo)
    if not t or t < 0 or t > 1e7 then return false end
    if kd then
      local k = leerCad(q, cKudos)
      if not k or math.abs(k - kd) > 0.5 then return false end
    end
    return true
  end
  local hits = {}
  if nv then
    local desde = math.max(base, base + BASE_W - VENTANA)
    local hasta = math.min(base + size - 8, base + BASE_W + VENTANA)
    for q = desde, hasta, 8 do
      if encaja(q) then hits[#hits + 1] = q end
    end
    p("  %d base(s) candidata(s)%s", #hits, #hits > 20 and " (se muestran 20)" or "")
    for i = 1, math.min(#hits, 20) do
      local q = hits[i]
      local vals = {}
      for _, c in ipairs(CAD) do vals[#vals + 1] = string.format("%s=%s", (c[1]:match("^[^:(]+"):gsub("%s+$", "")), tostring((leerCad(q, c)))) end
      p("    [%s] (Δ %+d)  %s", dir(q), q - (base + BASE_W), table.concat(vals, " · "))
    end
  else
    p("  (omitido: sin Nivel)")
  end

  -- base para el muestreo: la de wepon1984 si encaja; si no, la primera del barrido
  if nv and encaja(base + BASE_W) then Q = base + BASE_W
  elseif #hits > 0 then Q = hits[1]
  elseif valido(P) then Q = base + BASE_W end
  p("\n  Base usada en el muestreo: %s", Q and dir(Q) or "ninguna")
end)
if not ok then p("\nERROR: %s", tostring(err)) end

-- ---------------------------------------------------------------- E) muestreo
local primera, ultima, cambios, nLect = {}, {}, {}, 0
local function lectura()
  if not Q then return end
  nLect = nLect + 1
  for i, c in ipairs(CAD) do
    local v = leerCad(Q, c)
    if nLect == 1 then primera[i] = v; cambios[i] = 0
    elseif v ~= ultima[i] then cambios[i] = cambios[i] + 1 end
    ultima[i] = v
  end
end

local function terminar(seg)
  p("\n== E) Muestreo de %d s (%d lecturas) con la base %s ==", seg, nLect, Q and dir(Q) or "—")
  if Q then
    for i, c in ipairs(CAD) do
      p("  %-30s %s → %s  (%d cambios)", c[1], tostring(primera[i]), tostring(ultima[i]), cambios[i] or 0)
    end
  else
    p("  (sin base: no hay muestreo)")
  end
  p("\nAnota lo que ves en pantalla al final (Nivel, EXP, Prestigio, Score, tiempo) y pásalo con este informe.")
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

if not Q then
  terminar(0)
else
  showMessage(string.format("Lecturas listas. Al cerrar este aviso empiezan %d min de muestreo:\n" ..
    "· NO pauses el juego ni abras menús;\n" ..
    "· gana Prestigio, EXP y algo de Score; usa un talismán / habilidad;\n" ..
    "· recibe al menos un golpe (para ver la invencibilidad).\n" ..
    "Al terminar aparece el informe (no cierres Cheat Engine).", MUESTREO // 60000))
  lectura()
  local t0 = getTickCount()
  local t = createTimer(nil, false)
  t.Interval = PASO
  t.OnTimer = function(tm)
    local ahora = getTickCount()
    local okL, errL = pcall(lectura)
    if not okL or ahora - t0 >= MUESTREO then
      tm.destroy()
      if not okL then p("\nERROR en una lectura: %s", tostring(errL)) end
      local okT, errT = pcall(terminar, (ahora - t0) // 1000)
      if not okT then showMessage("ERROR en el muestreo: " .. tostring(errT)) end
    end
  end
  t.Enabled = true
end
