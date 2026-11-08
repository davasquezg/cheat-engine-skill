-- =====================================================================================
-- verificar_candidatas_gv1.lua (v3) — Verificación en vivo de GV1 (build 2026-10-07), sin depurador.
-- La v1 (2026-11-08) probó las candidatas de wepon1984 (original/trilogy.CT, otra build) con un Δ fijo:
--   ✅ Nivel = Créditos+0x47C · EXP = Créditos+0x478 · el bloque de combate +7ED64C es el que manda.
--   ✅ Punteros estáticos al jugador: game1.exe+7B3220, +7E02F8, +7ED630 (el candidato +7B3238 fallaba).
--   ❌ Tiempo / Medallas / Score / Kudos con Δ fijo: esas zonas se movieron distinto → se BUSCAN aquí.
-- La v2 (2026-11-08 03:53, otra partida cargada):
--   ✅ Los 3 punteros al jugador siguen válidos con otro objeto · ✅ PV máx. = bloque de combate +0x2C (+5 por nivel).
--   Pistas: Tiempo de nivel en +7E10D4 (= wepon1984 +7D80D4 + 0x9000 exacto) · Tiempo total en Créditos−0xE0
--   (≈ 7500/s) · Kudos ×1 en +7FFEC8 / +7FFEE0 (38 → ≈2360) · copia de la EXP en Créditos+0x438.
-- Esta v3 sigue esas pistas (sección N) además de repetir las búsquedas de la v2:
--   A) Bloque de partida ... Créditos, Nivel, EXP.
--   B) Jugador ............. los 3 punteros estáticos (repetir tras reiniciar el exe).
--   C) Bloque de combate ... +7ED64C frente a la copia +7ED67C.
--   D) Kudos estático ...... busca en game1.exe el Prestigio en pantalla ×1, ×160 y ×256 y sigue cada
--                            coincidencia (de gv1_kudos_vis si el script de Prestigio está activo; si no,
--                            pide el valor de la pantalla).
--   D2) Medallas ........... pide las medallas actuales, las busca en game1.exe e informa las que suben.
--   E) Tiempo .............. escaneo «valor desconocido» en game1.exe y «aumentó» cada 10 s.
--   F) Totales del menú .... pide PUNTOS TOTALES y TIEMPO TOTAL (hh:mm:ss) del menú de estado y los busca
--                            en game1.exe (tiempo en segundos, fotogramas y milisegundos).
-- Muestreo de 5 min (una lectura por segundo). NO pausar el juego durante el muestreo.
-- Uso: CE adjunto a game1.exe, DENTRO de un nivel. Memory View > Tools > Lua Engine > pegar > Execute
-- (o activar «🔎 Verificar candidatas» en la tabla). Los escaneos tardan unos segundos (CE parece congelado).
-- Resultado: ventana + portapapeles + dumps\verificar_candidatas_gv1_v3_<fecha>_<hora>.txt (no se pisan). NO escribe memoria del juego.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD      = "game1.exe"
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\verificar_candidatas_gv1_v3_]] ..
                 os.date("%Y-%m-%d_%H%M") .. ".txt"
local MUESTREO = 300000                 -- ms de muestreo (5 min)
local PASO     = 1000                   -- ms entre lecturas
local PASO_T   = 10000                  -- ms entre pasadas «aumentó» del escaneo de Tiempo
local CRED     = 0x7B3668               -- Créditos (verificado)
local COMB     = 0x7ED64C               -- Energía, inicio del bloque de combate (verificado)
local COPIA    = 0x7ED67C               -- copia del bloque de combate (no manda)
local PJUG     = { 0x7B3220, 0x7E02F8, 0x7ED630 }   -- punteros estáticos al jugador (2026-11-08)

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local base = getAddressSafe(MOD)
if not base then showMessage("Adjunta Cheat Engine a " .. MOD .. " primero."); return end
local size = getModuleSize(MOD)
local function enMod(a) return a and a >= base and a < base + size end
local function dir(a) return enMod(a) and string.format("%s+%X", MOD, a - base) or string.format("%X", a or 0) end
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end

-- ---------------------------------------------------------------- valores fijos que se siguen
-- { sección, nombre, rva, pista }  (todos DWORD salvo el Nivel, de 2 bytes)
local C = {
  {"A", "Créditos",                    CRED,          "debe coincidir con la pantalla"},
  {"A", "Nivel (Créditos+0x47C, 2 B)", CRED + 0x47C,  "nivel del personaje"},
  {"A", "EXP (Créditos+0x478)",        CRED + 0x478,  "EXP total del menú"},
  {"C", "Energía (bloque 1)",          COMB,          "×10 000"},
  {"C", "Energía (copia)",             COPIA,         ""},
  {"C", "Skill Points (bloque 1)",     COMB + 4,      "1 punto = 20000000"},
  {"C", "Skill Points (copia)",        COPIA + 4,     ""},
  {"C", "PV máx. (bloque 1 +0x2C)",    COMB + 0x2C,   "PV máx. del menú (+5 por nivel)"},
  {"N", "Tiempo de nivel (+7E10D4)",   0x7E10D4,      "wepon1984 +7D80D4 + 0x9000; ≈ 7100/s en v2"},
  {"N", "Medallas (+7E10DC)",          0x7E10DC,      "Tiempo + 8 (como en wepon1984)"},
  {"N", "Score (+8AFC68)",             0x8AFC68,      "wepon1984 +8A6C68 + 0x9000"},
  {"N", "Kudos ×160? (+8D4E10)",       0x8D4E10,      "wepon1984 +8CBE10 + 0x9000"},
  {"N", "Kudos ×1? (+7FFEC8)",         0x7FFEC8,      "38 → 2357 en v2"},
  {"N", "Kudos ×1? (+7FFEE0)",         0x7FFEE0,      "38 → 2363 en v2"},
  {"N", "Tiempo total (Créditos−0xE0)", CRED - 0xE0,  "≈ 7500/s en v2 (forma de gv1.CT)"},
  {"N", "EXP copia? (Créditos+0x438)", CRED + 0x438,  "= EXP en v2"},
}
local function leer(c)
  return c[2]:find("2 B") and readSmallInteger(base + c[3]) or readInteger(base + c[3])
end
local function foto()
  local s = {}
  for i, c in ipairs(C) do s[i] = leer(c) end
  return s
end

local function leerVis()
  local kv = getAddressSafe("gv1_kudos_vis")
  return kv and readInteger(kv)
end

-- DWORD exactos dentro de game1.exe (máx. maxN direcciones)
local function buscarEnModulo(valor, maxN)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtDword, rtRounded, tostring(valor), "",
               base, base + size, "", fsmAligned, "4", false, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxN) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

-- Kudos: coincidencias a seguir { a = dirección, k = 1|160|256, n = lecturas que coinciden, ini = valor inicial }
local kudos = {}
-- Medallas: coincidencias del valor escrito por el usuario { a = dirección, ini = valor inicial }
local medallas = {}
-- Tiempo: escaneo persistente y primer valor visto de cada superviviente
local tms, tPrim, tCuenta = nil, {}, nil

local ok, err = pcall(function()
  p("== Verificación GV1 v3 (build 2026-10-07) — %s ==", os.date("%Y-%m-%d %H:%M"))
  p("game1.exe base %X  tamaño %X", base, size)

  -- ------------------------------------------------------------ A y C: lectura inmediata
  local sec = nil
  local TIT = { A = "A) Bloque de partida", C = "C) Bloque de combate", N = "N) Pistas de la v2 (nivel en curso y totales)" }
  for _, c in ipairs(C) do
    if c[1] ~= sec then sec = c[1]; p("\n== %s ==", TIT[sec]) end
    p("  %-30s %-16s = %-12s %s", c[2], dir(base + c[3]), tostring(leer(c)), c[4])
  end
  local dif = {}
  for k = 0, 0x2C, 4 do
    local a, b = readInteger(base + COMB + k), readInteger(base + COPIA + k)
    if a ~= b then dif[#dif + 1] = string.format("+%X (%s / %s)", k, tostring(a), tostring(b)) end
  end
  p("  Bloque 1 vs copia (0x30 bytes): %s", #dif == 0 and "idénticos" or ("difieren en " .. table.concat(dif, ", ")))

  -- ------------------------------------------------------------ B) jugador
  p("\n== B) Punteros estáticos al jugador ==")
  -- forma del objeto: [P+3D8] = P+398 (componente de vida), flag jugador [P+398+18] = 1, HP ≤ máx.
  local function forma(P)
    if not valido(P) then return false end
    local comp = readQword(P + 0x3D8)
    if comp ~= P + 0x398 then return false end
    local hp, mx = readInteger(comp), readInteger(comp + 4)
    return readBytes(comp + 0x18, 1) == 1 and hp and mx and mx > 0 and hp <= mx and mx % 16 == 0
  end
  local cap = getAddressSafe("gv1_player")
  local Pcap = cap and readQword(cap)
  for _, rva in ipairs(PJUG) do
    local P = readQword(base + rva)
    local hp, mx = valido(P) and readInteger(P + 0x398), valido(P) and readInteger(P + 0x39C)
    p("  [%s] = %X  forma: %-5s %s  HP %s / %s", dir(base + rva), P or 0, forma(P) and "SÍ ✅" or "no",
      valido(Pcap) and (P == Pcap and "= gv1_player" or "≠ gv1_player") or "(sin gv1_player)",
      tostring(hp and hp // 16), tostring(mx and mx // 16))
  end

  -- ------------------------------------------------------------ D) Kudos: búsqueda en el módulo
  p("\n== D) Kudos estático (Prestigio en pantalla ×1 / ×160 / ×256 dentro de game1.exe) ==")
  local vis = leerVis()
  if vis then
    p("  Prestigio tomado de gv1_kudos_vis = %d (se sigue en cada lectura)", vis)
  else
    vis = tonumber(inputQuery("Verificar GV1", "Prestigio (Kudos) que ves AHORA en pantalla\n" ..
      "(vacío = omitir; con el script de Prestigio activo no hace falta):", "") or "")
    if vis then p("  Prestigio escrito por el usuario = %d (sin seguimiento: se informa qué coincidencias cambiaron)", vis) end
  end
  if not vis then
    p("  (omitido)")
  elseif vis < 3 then
    p("  Prestigio = %d: demasiado bajo para buscar (habría miles de coincidencias). Gana algo y repite.", vis)
  else
    for _, k in ipairs({ 1, 160, 256 }) do
      local r, total = buscarEnModulo(vis * k, 200)
      p("  %d × %d = %d → %d coincidencia(s)%s", vis, k, vis * k, total, total > #r and " (se siguen 200)" or "")
      for _, a in ipairs(r) do kudos[#kudos + 1] = { a = a, k = k, n = 0, ini = readInteger(a) } end
    end
  end

  -- ------------------------------------------------------------ D2) Medallas: búsqueda en el módulo
  p("\n== D2) Medallas (valor escrito por el usuario dentro de game1.exe) ==")
  local med = tonumber(inputQuery("Verificar GV1", "Medallas que llevas AHORA en este nivel\n" ..
    "(vacío = omitir; luego recoge al menos 1 durante el muestreo):", "") or "")
  if med and med < 1 then
    p("  Medallas = 0: demasiadas coincidencias. Recoge 1 primero y repite.")
  elseif med then
    local r, total = buscarEnModulo(med, 20000)
    p("  %d → %d coincidencia(s)%s; se informan las que suban exactamente +1, +2 o +3", med, total,
      total > #r and " (se siguen 20000)" or "")
    for _, a in ipairs(r) do medallas[#medallas + 1] = { a = a, ini = med } end
  else
    p("  (omitido)")
  end

  -- ------------------------------------------------------------ F) Totales del menú (pantalla de estado)
  p("\n== F) Totales del menú (valores escritos por el usuario) ==")
  local pt = tonumber(inputQuery("Verificar GV1", "PUNTOS TOTALES del menú de estado\n(vacío = omitir):", "") or "")
  if pt then
    local r, total = buscarEnModulo(pt, 20)
    p("  Puntos totales %d → %d coincidencia(s) en game1.exe", pt, total)
    for _, a in ipairs(r) do p("    %-18s  Créditos%+d (0x%X)", dir(a), a - (base + CRED), math.abs(a - (base + CRED))) end
  else
    p("  Puntos totales: (omitido)")
  end
  local tt = inputQuery("Verificar GV1", "TIEMPO TOTAL del menú de estado (hh:mm:ss)\n(vacío = omitir):", "")
  local hh, mm, ss = (tt or ""):match("^%s*(%d+):(%d+):(%d+)%s*$")
  if hh then
    local seg = tonumber(hh) * 3600 + tonumber(mm) * 60 + tonumber(ss)
    p("  Tiempo total %s = %d s. Se busca en [t, t+10 min] por si el reloj siguió corriendo:", tt, seg)
    for _, u in ipairs({ { "segundos", 1 }, { "fotogramas (60/s)", 60 }, { "milisegundos", 1000 } }) do
      local ms = createMemScan()
      ms.firstScan(soValueBetween, vtDword, rtRounded, tostring(seg * u[2]), tostring((seg + 600) * u[2]),
                   base, base + size, "", fsmAligned, "4", false, false, false, false)
      ms.waitTillDone()
      local fl = createFoundList(ms); fl.initialize()
      p("    en %-18s → %d coincidencia(s)", u[1], fl.Count)
      for i = 0, math.min(fl.Count, 10) - 1 do
        local a = tonumber(fl.Address[i], 16)
        p("      %-18s = %-10s Créditos%+d", dir(a), tostring(readInteger(a)), a - (base + CRED))
      end
      fl.deinitialize(); fl.destroy(); ms.destroy()
    end
    p("  gv1.CT ponía «Total Time» en Créditos−0xE0: %s = %s", dir(base + CRED - 0xE0), tostring(readInteger(base + CRED - 0xE0)))
  else
    p("  Tiempo total: (omitido o formato no válido)")
  end

  -- ------------------------------------------------------------ E) Tiempo: primer escaneo
  tms = createMemScan()
  tms.firstScan(soUnknownValue, vtDword, rtRounded, "", "", base, base + size, "+W",
                fsmAligned, "4", false, false, false, false)
  tms.waitTillDone()
end)
if not ok then p("\nERROR: %s", tostring(err)) end

-- ---------------------------------------------------------------- muestreo
local primera, ultima, cambios = nil, nil, {}
local nLect, visIni, visFin = 0, nil, nil
for i = 1, #C do cambios[i] = 0 end

local function lectura()
  local f = foto()
  local vis = leerVis()
  nLect = nLect + 1
  if not primera then primera, visIni = f, vis end
  for i = 1, #C do
    if ultima and f[i] ~= ultima[i] then cambios[i] = cambios[i] + 1 end
  end
  if vis then
    for _, h in ipairs(kudos) do
      if readInteger(h.a) == vis * h.k then h.n = h.n + 1 end
    end
  end
  ultima, visFin = f, vis
end

local function pasadaTiempo(seg)
  if not tms then return end
  tms.nextScan(soIncreasedValue, rtRounded, "", "", false, false, false, false, false)
  tms.waitTillDone()
  local fl = createFoundList(tms); fl.initialize()
  tCuenta = fl.Count
  if fl.Count <= 2000 then
    for i = 0, fl.Count - 1 do
      local a = tonumber(fl.Address[i], 16)
      if not tPrim[a] then tPrim[a] = { v = readInteger(a), s = seg } end
    end
  end
  fl.deinitialize(); fl.destroy()
end

local function terminar(seg)
  p("\n== Muestreo de %d s (%d lecturas) ==", seg, nLect)
  p("  Valores fijos que cambiaron:")
  local n = 0
  for i, c in ipairs(C) do
    if cambios[i] > 0 then
      p("    %-30s %s → %s  (%d cambios)", c[2], tostring(primera[i]), tostring(ultima[i]), cambios[i]); n = n + 1
    end
  end
  if n == 0 then p("    (ninguno; ¿estabas en pausa o en un menú?)") end

  p("\n  D) Kudos — Prestigio en pantalla: %s → %s", tostring(visIni), tostring(visFin))
  if #kudos == 0 then
    p("    (sin coincidencias que seguir)")
  else
    table.sort(kudos, function(x, y) return x.n > y.n end)
    local seguido = visIni ~= nil
    table.sort(kudos, function(x, y)
      if seguido then return x.n > y.n end
      return (readInteger(x.a) ~= x.ini and 1 or 0) > (readInteger(y.a) ~= y.ini and 1 or 0)
    end)
    local m = 0
    for _, h in ipairs(kudos) do
      local ahora = readInteger(h.a)
      if seguido or ahora ~= h.ini then
        p("    %-18s ×%-3d %s  (%s → %s)", dir(h.a), h.k,
          seguido and string.format("coincide en %3d/%d lecturas", h.n, nLect) or "cambió",
          tostring(h.ini), tostring(ahora))
        m = m + 1
        if m >= 15 then break end
      end
    end
    if m == 0 then p("    (ninguna coincidencia cambió: el Kudos estático no está en game1.exe o no ganaste Prestigio)") end
    p("    → El Kudos estático es la dirección que sigue al Prestigio en pantalla (con su escala ×1/×160/×256).")
  end

  p("\n  D2) Medallas — coincidencias que subieron +1…+3:")
  local nm = 0
  for _, h in ipairs(medallas) do
    local ahora = readInteger(h.a)
    if ahora and ahora > h.ini and ahora <= h.ini + 3 then
      p("    %-18s %d → %d", dir(h.a), h.ini, ahora); nm = nm + 1
      if nm >= 20 then p("    …"); break end
    end
  end
  if nm == 0 then p("    (ninguna: ¿recogiste una medalla durante el muestreo?)") end

  p("\n  E) Tiempo — DWORD de game1.exe que aumentaron en cada pasada de %d s: %s", PASO_T // 1000, tostring(tCuenta))
  if tms and tCuenta and tCuenta <= 2000 then
    local fl = createFoundList(tms); fl.initialize()
    local filas = {}
    for i = 0, fl.Count - 1 do
      local a = tonumber(fl.Address[i], 16)
      local v, pr = readInteger(a), tPrim[a]
      local ritmo = (pr and v and seg > pr.s) and (v - pr.v) / (seg - pr.s) or 0
      filas[#filas + 1] = { a = a, v = v, r = ritmo }
    end
    fl.deinitialize(); fl.destroy()
    table.sort(filas, function(x, y) return x.a < y.a end)
    for i = 1, math.min(#filas, 30) do
      local f = filas[i]
      p("    %-18s = %-12s  ritmo ≈ %.1f /s", dir(f.a), tostring(f.v), f.r)
    end
    if #filas > 30 then p("    … y %d más", #filas - 30) end
    p("    → Pista: un cronómetro en fotogramas sube ≈ 60/s; en milisegundos ≈ 1000/s.")
  elseif tCuenta then
    p("    (demasiados para listar: repite sin pausar el juego)")
  end
  if tms then tms.destroy(); tms = nil end

  p("\nCompara con la pantalla del juego y anota qué dirección acierta.")
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

showMessage(string.format("Lecturas y escaneos listos. Al cerrar este aviso empiezan %d min de muestreo:\n" ..
  "· NO pauses el juego ni abras menús (el escaneo de Tiempo lo necesita);\n" ..
  "· gana Prestigio (Kudos) encadenando enemigos sin recibir daño;\n" ..
  "· recoge al menos 1 medalla;\n" ..
  "· si puedes, termina la misión cerca del final del muestreo.\n" ..
  "Al terminar aparece el informe (no cierres Cheat Engine).", MUESTREO // 60000))
lectura()
local t0, tUlt = getTickCount(), getTickCount()
local t = createTimer(nil, false)
t.Interval = PASO
t.OnTimer = function(tm)
  local ahora = getTickCount()
  local seg = (ahora - t0) // 1000
  local okL, errL = pcall(function()
    lectura()
    if ahora - tUlt >= PASO_T then tUlt = ahora; pasadaTiempo(seg) end
  end)
  if not okL or ahora - t0 >= MUESTREO then
    tm.destroy()
    if not okL then p("\nERROR en una lectura: %s", tostring(errL)) end
    local okT, errT = pcall(terminar, seg)
    if not okT then showMessage("ERROR en el muestreo: " .. tostring(errT)) end
  end
end
t.Enabled = true
