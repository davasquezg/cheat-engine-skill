-- =====================================================================================
-- diag_gv3.lua (v3) — Diagnóstico de GV3 (game3.exe) en la Trilogy, sin depurador.
-- Resultados anteriores (build 2026-10-13, ANALISIS §9.1–9.2):
--   ✅ AOB de vida de RTX_XXXX/wepon1984 única en game3.exe+8B5B62 (movss [rcx+08],xmm0; HP float).
--   ✅ Base de wepon1984 movida a game3.exe+1F02FE8 (+0xD6150): sus cadenas leen EXP, Kudos (float, = pantalla),
--      Score y Tiempo. ❌ Las AOB de RTX_XXXX (GV3 suelto) no están; +510 es ambigua y +69A no aparece.
-- Esta v3:
--   A) Build.
--   B) Base: prueba game3.exe+1F02FE8; si no encaja, la busca en .data con Nivel/Prestigio (tolerante).
--   C) Lee las 9 cadenas de wepon1984 desde esa base.
--   D) Captura del jugador: gancho en la AOB de vida (se QUITA al terminar). Si la zona ya está parchada
--      por otro script, informa adónde salta y sigue sin captura.
--   E) Muestreo de 5 min: cadenas de wepon1984 + mapa de campos que cambian en el objeto base [B],
--      en el objeto jugador [[[B]+10]+10] y, si hubo captura, alrededor del componente de vida.
-- Escribe en el juego SOLO el gancho de captura (y lo restaura).
-- ANTES: desactiva en la tabla el script «Health» de GV3 (wepon1984) si está activo.
-- Uso: CE adjunto a game3.exe, DENTRO de un nivel. Memory View > Tools > Lua Engine > pegar > Execute.
-- Resultado: ventana + portapapeles + dumps\diag_gv3_v3_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD      = "game3.exe"
local OUTFILE  = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\diag_gv3_v3_]] ..
                 os.date("%Y-%m-%d_%H%M") .. ".txt"
local MUESTREO = 300000                 -- ms de muestreo (5 min)
local PASO     = 1000                   -- ms entre lecturas
local BASE_N   = 0x1F02FE8              -- base de wepon1984 en la build 2026-10-13 (hallada en la v2)
local VIDA_AOB = "F3 0F 11 41 08 83 49 18 01 C3 0F"
local VIDA_ORI = { 0xF3, 0x0F, 0x11, 0x41, 0x08 }      -- movss [rcx+08],xmm0 (bytes que se reemplazan)

-- Cadenas de wepon1984 (orden de aplicación) y tipo
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

local function aob(bytes, maxN)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtByteArray, rtRounded, bytes, "", base, base + size, "",
               fsmNotAligned, "1", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxN or 10) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

-- Secciones escribibles del módulo (encabezado PE en memoria)
local function seccionesEscribibles()
  local pe = readInteger(base + 0x3C)
  local n = readSmallInteger(base + pe + 6)
  local opt = readSmallInteger(base + pe + 0x14)
  local t = base + pe + 0x18 + opt
  local r = {}
  for i = 0, n - 1 do
    local s = t + 40 * i
    local vsize, va, car = readInteger(s + 8), readInteger(s + 12), readInteger(s + 36)
    if car and (car & 0x80000000) ~= 0 then r[#r + 1] = { desde = base + va, hasta = base + va + vsize } end
  end
  return r
end

-- ---------------------------------------------------------------- mapas de campos
-- Un mapa sigue una región [dirección(), +largo) y cuenta qué DWORD cambian. Si la dirección del
-- objeto cambia (otro nivel, otro personaje), lo anota y sigue comparando con el objeto nuevo.
local function comoFloat(v) return (string.unpack("<f", string.pack("<I4", v))) end
local function nuevoMapa(nombre, fdir, largo)
  return { nombre = nombre, fdir = fdir, largo = largo, prim = {}, ult = {}, camb = {}, n = 0, movs = 0, obj = nil }
end
local function leerMapa(m)
  local a = m.fdir()
  if not valido(a) then return end
  if m.obj and a ~= m.obj then m.movs = m.movs + 1 end
  m.obj = a
  local b = readBytes(a, m.largo, true)
  if not b then return end
  m.n = m.n + 1
  for i = 0, m.largo // 4 - 1 do
    local k = 4 * i + 1
    local v = b[k] | (b[k + 1] << 8) | (b[k + 2] << 16) | (b[k + 3] << 24)
    if m.prim[i] == nil then m.prim[i] = v; m.camb[i] = 0
    elseif v ~= m.ult[i] then m.camb[i] = m.camb[i] + 1 end
    m.ult[i] = v
  end
end
local function informeMapa(m, maxFilas)
  p("\n  -- %s: objeto %X, %d lecturas, el objeto cambió %d vez/veces --", m.nombre, m.obj or 0, m.n, m.movs)
  local filas = 0
  for i = 0, m.largo // 4 - 1 do
    if (m.camb[i] or 0) > 0 then
      local f0, f1 = comoFloat(m.prim[i]), comoFloat(m.ult[i])
      local fs = (math.abs(f1) < 1e7 and math.abs(f1) > 1e-4) and string.format("  | float %.3f → %.3f", f0, f1) or ""
      p("    +0x%03X  %d → %d  (%d cambios)%s", 4 * i, m.prim[i], m.ult[i], m.camb[i], fs)
      filas = filas + 1
      if filas >= maxFilas then p("    …"); break end
    end
  end
  if filas == 0 then p("    (ningún campo cambió)") end
end

-- ---------------------------------------------------------------- A, B, C
local Q = nil
local ok, err = pcall(function()
  p("== Diagnóstico GV3 v3 — %s ==", os.date("%Y-%m-%d %H:%M"))
  local pe = readInteger(base + 0x3C)
  local ts = pe and readInteger(base + pe + 8)
  p("%s base %X  tamaño %X  TimeDateStamp %s (%s)", MOD, base, size,
    ts and string.format("%08X", ts) or "?", ts and os.date("!%Y-%m-%d %H:%M UTC", ts) or "?")

  p("\n== B) Base de wepon1984 ==")
  local function forma(q)
    local n = leerCad(q, CAD[4])
    local t = leerCad(q, CAD[5])
    local k = leerCad(q, CAD[8])
    return n and n >= 1 and n <= 99 and t and t >= 0 and t < 1e7 and k and k >= 0 and k <= 99999
  end
  if forma(base + BASE_N) then
    Q = base + BASE_N
    p("  [%s] encaja ✅ (misma posición que en la v2)", dir(Q))
  else
    p("  [%s] no encaja; se busca en .data con los valores de pantalla", dir(base + BASE_N))
    local nv = tonumber(inputQuery("Diagnóstico GV3 v3", "NIVEL del personaje que ves AHORA:", "") or "")
    local kd = tonumber(inputQuery("Diagnóstico GV3 v3", "PRESTIGIO (Kudos) que ves AHORA\n(vacío = no usarlo):", "") or "")
    if nv then
      for _, s in ipairs(seccionesEscribibles()) do
        for q = s.desde, s.hasta - 8, 8 do
          if valido(readQword(q)) and leerCad(q, CAD[4]) == nv and forma(q) then
            local k = leerCad(q, CAD[8])
            if not kd or math.abs(k - kd) <= math.max(100, kd * 0.05) then Q = q; break end
          end
        end
        if Q then break end
      end
    end
    p("  base hallada: %s", Q and string.format("%s (Δ %+X respecto a la v2)", dir(Q), Q - (base + BASE_N)) or "ninguna")
  end

  p("\n== C) Cadenas de wepon1984 desde %s ==", Q and dir(Q) or "—")
  if Q then
    p("  [B] = %X   objeto jugador [[[B]+10]+10] = %X", readQword(Q) or 0, (cadena(Q, {0x10, 0x10, 0}) or 0))
    for _, c in ipairs(CAD) do
      local v, a = leerCad(Q, c)
      p("    %-30s %-14X = %s", c[1], a or 0, tostring(v))
    end
  end
end)
if not ok then p("\nERROR: %s", tostring(err)) end

-- ---------------------------------------------------------------- D) gancho de captura
local A, puesto = nil, false
local function quitarGancho()
  if puesto and A then
    writeBytes(A, VIDA_ORI)
    unregisterSymbol("gv3_hp"); unregisterSymbol("gv3_last")
    puesto = false
  end
end
local okD, errD = pcall(function()
  p("\n== D) Captura del jugador (gancho en la AOB de vida) ==")
  local r, total = aob(VIDA_AOB, 2)
  if total ~= 1 then
    local r2, t2 = aob("E9 ?? ?? ?? ?? 83 49 18 01 C3 0F", 2)
    if t2 == 1 then
      local destino = r2[1] + 5 + readInteger(r2[1] + 1, true)
      p("  ⚠️ La zona de vida (%s) ya está parchada: salta a %X. Otro script la usa", dir(r2[1]), destino)
      p("     (¿«Health» de GV3 en la tabla?). Se sigue SIN captura; desactívalo para la próxima corrida.")
      return
    end
    error(string.format("La AOB de vida aparece %d veces: no se instala el gancho.", total))
  end
  A = r[1]
  local src = string.format([[
alloc(gv3cap_mem,$100,%s)
label(gv3cap_ret)
label(gv3_hp)
label(gv3_last)
registersymbol(gv3_hp)
registersymbol(gv3_last)
gv3cap_mem:
  movss [rcx+08],xmm0
  mov [gv3_last],rcx
  cmp dword ptr [rcx+20],1
  jne @f
  mov [gv3_hp],rcx
@@:
  jmp gv3cap_ret
align 8
gv3_hp:
  dq 0
gv3_last:
  dq 0
%s:
  jmp gv3cap_mem
gv3cap_ret:
]], dir(A), dir(A))
  if not autoAssemble(src) then error("autoAssemble falló al instalar el gancho") end
  puesto = true
  p("  gancho instalado en %s (recibe un golpe o cúrate para capturar)", dir(A))
end)
if not okD then p("  ERROR: %s", tostring(errD)) end

-- ---------------------------------------------------------------- E) muestreo
local mapas = {}
if Q then
  mapas[#mapas + 1] = nuevoMapa("Objeto base [B]", function() return readQword(Q) end, 0x600)
  mapas[#mapas + 1] = nuevoMapa("Objeto jugador [[[B]+10]+10]", function() return cadena(Q, {0x10, 0x10, 0}) end, 0x800)
end
local mapaComp = nil
local primera, ultima, cambios, nLect = {}, {}, {}, 0

local function lectura()
  if Q then
    nLect = nLect + 1
    for i, c in ipairs(CAD) do
      local v = leerCad(Q, c)
      if nLect == 1 then primera[i] = v; cambios[i] = 0
      elseif v ~= ultima[i] then cambios[i] = cambios[i] + 1 end
      ultima[i] = v
    end
  end
  if puesto and not mapaComp then
    local g = getAddressSafe("gv3_hp")
    local C = g and readQword(g)
    if valido(C) then
      local P2 = Q and cadena(Q, {0x10, 0x10, 0})
      p("\n  Jugador capturado: componente de vida %X  HP %s / %s (float)%s", C, tostring(readFloat(C + 8)),
        tostring(readFloat(C + 0xC)), P2 and string.format("  → componente − objeto jugador = %+X", C - P2) or "")
      mapaComp = nuevoMapa("Componente de vida capturado (−0x400 … +0x400)", function()
        local c = readQword(getAddressSafe("gv3_hp") or 0); return c and c - 0x400 end, 0x800)
      mapas[#mapas + 1] = mapaComp
    end
  end
  for _, m in ipairs(mapas) do leerMapa(m) end
end

local function terminar(seg)
  quitarGancho()
  p("\n== E) Muestreo de %d s ==", seg)
  if Q then
    p("  Cadenas de wepon1984 (%d lecturas):", nLect)
    for i, c in ipairs(CAD) do
      p("    %-30s %s → %s  (%d cambios)", c[1], tostring(primera[i]), tostring(ultima[i]), cambios[i] or 0)
    end
  end
  if not mapaComp then p("  (sin captura del jugador: %s)", A and "no se recibió daño ni curación" or "gancho no instalado") end
  for _, m in ipairs(mapas) do informeMapa(m, 80) end
  p("\nAnota lo que ves en pantalla al final (HP, Nivel, EXP, Prestigio, Score, talismanes, tiempo) y pásalo con el informe.")
  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

if not Q and not puesto then
  terminar(0)
else
  showMessage(string.format("Listo. Al cerrar este aviso empiezan %d min de muestreo:\n" ..
    "· recibe golpes (y cúrate si puedes) — sirve para la captura y la invencibilidad;\n" ..
    "· gana Prestigio, EXP y Score; usa talismanes, habilidades y la barra Fetters;\n" ..
    "· NO pauses el juego ni abras menús.\n" ..
    "Al terminar aparece el informe (no cierres Cheat Engine).", MUESTREO // 60000))
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
      if not okT then quitarGancho(); showMessage("ERROR en el muestreo: " .. tostring(errT)) end
    end
  end
  t.Enabled = true
end
