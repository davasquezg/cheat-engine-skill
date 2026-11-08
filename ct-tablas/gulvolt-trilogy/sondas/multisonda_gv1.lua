-- =====================================================================================
-- multisonda_gv1.lua — Porta los datos de gv1.CT (WarCOzes, GV1 32 bits) a la Trilogy
--                      (game1.exe, 64 bits) SIN usar el depurador.
--
-- Qué hace (en este orden):
--   A) Bloque de PARTIDA: busca tus Créditos dentro de game1.exe y verifica la forma del bloque
--      de gv1.CT: 28 materiales en +0x3B0 (gv1.CT: +0x3A8), EXP en +0x470, nivel (2 B) en +0x474.
--   B) Bloque de COMBATE: busca la Energía llena (5 000 000) y verifica Skill Points en +4
--      (múltiplo de 20 000 000) y 4 cooldowns en +0xC…+0x18 (0…76 800).
--   C) Crea en la tabla un grupo "GV1 portado" con las entradas de gv1.CT apuntando a
--      game1.exe+RVA (sobreviven a reinicios mientras no cambie la build).
--   D) Informe: ventana + portapapeles + archivo resultados_multisonda_gv1.txt (carpeta dumps).
--
-- Requisitos: CE adjunto a game1.exe, DENTRO de un nivel, con la Energía (campo eléctrico)
-- LLENA y sabiendo cuántos Créditos tienes (menú). No escribe memoria del juego.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD     = "game1.exe"
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\resultados_multisonda_gv1.txt]]

local out = {}
local function p(fmt, ...) out[#out + 1] = string.format(fmt, ...) end
local function hx(n) return string.format("%X", n) end

local base = getAddressSafe(MOD)
if not base then showMessage("Adjunta Cheat Engine a " .. MOD .. " primero."); return end
local size = getModuleSize(MOD)
p("Módulo %s  base=%X  tamaño=%X", MOD, base, size)

-- Escaneo exacto de un DWORD dentro del módulo (memoria escribible)
local function scanDword(value, maxHits)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtDword, rtRounded, hx(value), "", base, base + size,
               "+W", fsmAligned, "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local res, n = {}, math.min(fl.Count, maxHits or 5000)
  for i = 0, n - 1 do res[#res + 1] = tonumber(fl.Address[i], 16) end
  local total = fl.Count
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return res, total
end
local function rd(a) return readInteger(a) end
local function rw(a) return readSmallInteger(a) end

-- Nombres de materiales en el orden del arreglo de gv1.CT (índice = posición, paso 4 B)
local MATS = {
  "Microdegenerator","Custom Servophoton","Spinel Quasicrystal","Ultradense Magnet",
  "Genomic Resonator","Phased Fluid Metal","Yellow Chalcedony","Hihirogane Shard",
  "Antigravity Engine","Propulsion Mechanism","Phoenix Ore","Shock Response Plate",
  "Six-miracle Graym","Apoitagara","Graym Extract 239","Electromotive Graym",
  "Kripp Alloy","Xiwidia","Faraging Steel","Nanochip 98","Proto Infrastructure",
  "High-end NcGbx","Garnet","Quartzite","Electrum","Graym Culture","Polymer Gm238",
  "Uranium-235 Crystal" }

-- ---------------------------------------------------------------- A) PARTIDA
-- Dos pasadas: la 1.ª escanea; si cambias los Créditos en el juego (gana o gasta) y vuelves a
-- ejecutar, se FILTRA la lista anterior (como "Next Scan"). Escribe r para reiniciar.
local credits = nil
local txt = inputQuery("Multisonda GV1",
  "Créditos actuales (vig).\n- 1.ª vez: escanea.\n- Siguientes: filtra la lista anterior (cambia tus Créditos entre medio).\n- r = reiniciar   - vacío = omitir", "")
if txt == "r" then MSGV1_PREV = nil; txt = inputQuery("Multisonda GV1", "Créditos actuales (vig):", "") end
if txt and txt ~= "" then credits = tonumber(txt) end
local SAVE = nil
SAVE_SOLO = nil

-- Busca cerca de 'c' una racha de 28 DWORD en 0..999 (no todos 0) = arreglo de materiales
local function buscarMateriales(c)
  local res, d = {}, -0x1000
  while d <= 0x1000 and #res < 6 do
    local ok, nz = true, 0
    for i = 0, 27 do
      local v = rd(c + d + 4 * i)
      if not v or v < 0 or v > 999 then ok = false; break end
      if v > 0 then nz = nz + 1 end
    end
    if ok and nz >= 3 then
      res[#res + 1] = string.format("%s0x%X (no-cero: %d)", d < 0 and "-" or "+", math.abs(d), nz)
      d = d + 28 * 4                      -- saltar la racha encontrada
    else
      d = d + 4
    end
  end
  return res
end

if credits then
  local hits, total
  if MSGV1_PREV and #MSGV1_PREV > 0 then
    hits = {}
    for _, a in ipairs(MSGV1_PREV) do if rd(a) == credits then hits[#hits + 1] = a end end
    total = #hits
    p("\n== A) Partida: FILTRO Créditos = %d -> quedan %d de %d ==", credits, total, #MSGV1_PREV)
  else
    hits, total = scanDword(credits)
    p("\n== A) Partida: Créditos = %d -> %d coincidencias en el módulo ==", credits, total)
  end
  MSGV1_PREV = hits
  for _, c in ipairs(hits) do
    local okMats, sum = 0, 0
    for i = 0, 27 do
      local v = rd(c + 0x3B0 + 4 * i)
      if v and v >= 0 and v <= 9999 then okMats = okMats + 1; sum = sum + v end
    end
    local lvl, exp = rw(c + 0x474), rd(c + 0x470)
    if okMats == 28 and lvl and lvl >= 1 and lvl <= 99 and exp and exp >= 0 then
      p("  CANDIDATO (forma de gv1.CT) game1.exe+%X  materiales suma %d  EXP=%d  Nivel=%d  TotalTime=%s",
        c - base, sum, exp, lvl, tostring(rd(c - 0xE0)))
      if not SAVE then SAVE = c end
    end
  end
  if not SAVE then
    if #hits <= 5 then
      p("  Sin la forma exacta de gv1.CT. Análisis flexible de cada coincidencia:")
      for _, c in ipairs(hits) do
        local m = buscarMateriales(c)
        p("    game1.exe+%X : posibles arreglos de materiales en %s", c - base,
          #m > 0 and table.concat(m, ", ") or "(ninguno a ±0x1000)")
      end
      if #hits == 1 then SAVE_SOLO = hits[1] end
    else
      p("  Demasiadas coincidencias: cambia tus Créditos en el juego y vuelve a ejecutar la sonda 3 (filtra).")
      for i = 1, math.min(#hits, 10) do p("    game1.exe+%X", hits[i] - base) end
    end
  end
end

-- ---------------------------------------------------------------- B) COMBATE
local BAT = nil
do
  local hits, total = scanDword(5000000)
  p("\n== B) Combate: Energía llena 5000000 -> %d coincidencias en el módulo ==", total)
  for _, e in ipairs(hits) do
    local sp = rd(e + 4)
    local ok = sp and sp >= 0 and sp <= 60000000 and sp % 20000000 == 0
    local cds = {}
    for i = 0, 3 do
      local v = rd(e + 0xC + 4 * i); cds[#cds + 1] = tostring(v)
      if not v or v < 0 or v > 76800 then ok = false end
    end
    if ok then
      p("  CANDIDATO game1.exe+%X  SP=%d (%d pts)  cooldowns=%s", e - base, sp, sp // 20000000, table.concat(cds, "/"))
      if not BAT then BAT = e end
    end
  end
  if not BAT then
    p("  Ningún candidato. Puede que la escala cambió (p. ej. punto fijo 24.8 como GV2).")
    for i = 1, math.min(#hits, 10) do p("    game1.exe+%X", hits[i] - base) end
  end
end

-- ---------------------------------------------------------------- C) ENTRADAS EN LA TABLA
local function addr(a) return string.format("%s+%X", MOD, a - base) end
if SAVE or BAT or SAVE_SOLO then
  local al = getAddressList()
  local g = al.createMemoryRecord()
  g.Description = "GV1 portado de gv1.CT (multisonda " .. os.date("%Y-%m-%d") .. ")"
  g.IsGroupHeader = true
  local function rec(desc, a, vt, parent)
    local m = al.createMemoryRecord()
    m.Description = desc; m.Address = addr(a); m.Type = vt or vtDword
    m.appendToEntry(parent or g)
    return m
  end
  local function grp(desc)
    local m = al.createMemoryRecord(); m.Description = desc; m.IsGroupHeader = true
    m.appendToEntry(g); return m
  end
  if BAT and not al.getMemoryRecordByDescription("Energy Bar / Electric Field (llena = 5000000; congelar = Inf.)") then
    rec("Energy Bar / Electric Field (llena = 5000000; congelar = Inf.)", BAT)
    rec("Skill Points (1 pt = 20000000; 3 = 60000000)", BAT + 4)
    local cd = grp("[ Skills Cooldown ] (lleno = 76800; congelar = sin cooldown)")
    for i = 0, 3 do rec(string.format("Slot %d Cooldown", i + 1), BAT + 0xC + 4 * i, vtDword, cd) end
  end
  if SAVE then
    local st = grp("[ Stats ]")
    rec("Credits (vig)", SAVE, vtDword, st)
    rec("Total Time", SAVE - 0xE0, vtDword, st)
    rec("Time (? -0x3CD0 — verificar)", SAVE - 0x3CD0, vtDword, st)
    rec("Medals (? -0x3CC8 — verificar)", SAVE - 0x3CC8, vtDword, st)
    rec("Exp", SAVE + 0x470, vtDword, st)
    rec("Level (no modificar)", SAVE + 0x474, vtWord, st)
    local mt = grp("[ Materials ]")
    for i = 0, 27 do rec(MATS[i + 1], SAVE + 0x3B0 + 4 * i, vtDword, mt) end
  end
  if SAVE_SOLO and not SAVE then rec("Credits (vig)", SAVE_SOLO) end
  p("\nEntradas creadas en la tabla: grupo '%s'", g.Description)
end

-- ---------------------------------------------------------------- D) INFORME
local report = table.concat(out, "\n")
local f = io.open(OUTFILE, "w"); if f then f:write(report); f:close() end
writeToClipboard(report)
showMessage(report .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
