-- =====================================================================================
-- kudos_diag_gv1.lua — VERSIÓN 2 — Diagnóstico paso a paso del Prestigio (Kudos) de GV1
-- Pegar en Memory View > Tools > Lua Engine y ejecutar UNA vez por paso.
--
-- En cada paso escribe el Prestigio que ves en pantalla (distinto de 0 de preferencia).
--   Paso 1: busca la estructura por DOS métodos y guarda los candidatos:
--           A) FIRMA:  K+0x34 = game1.exe+234130  y  K+0x3C = game1.exe+4C470
--           B) PAR:    QWORD [pantalla | interno] = valor | valor×256 (en cualquier lugar)
--   Paso 2+: (cambia tu Prestigio en el juego) filtra los candidatos que siguen al valor.
--   r = reiniciar.
-- Cada paso informa: candidatos, valores, y los punteros a game1.exe alrededor de cada uno
-- (para construir una firma estable). Resultado: ventana + portapapeles + archivo en dumps.
-- No escribe memoria del juego. Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD     = "game1.exe"
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\kudos_diag.txt]]

local base = getAddressSafe(MOD)
if not base then showMessage("Adjunta Cheat Engine a " .. MOD); return end
local size = getModuleSize(MOD)
local F2, F3 = base + 0x234130, base + 0x4C470

local out = {}
local function p(f, ...) out[#out + 1] = string.format(f, ...) end
local function enMod(a) return a and a >= base and a < base + size end
local function rva(a) return enMod(a) and string.format("game1.exe+%X", a - base) or string.format("%X", a or 0) end

-- ---------------------------------------------------------------- entrada
local estado = KD_GV1 and string.format(" (paso %d, candidatos: %d)", KD_GV1.paso + 1, #KD_GV1.c) or " (paso 1)"
local txt = inputQuery("Diagnóstico Prestigio GV1", "Prestigio que ves en pantalla" .. estado .. "\nr = reiniciar", "")
if not txt or txt == "" then return end
if txt == "r" then KD_GV1 = nil; showMessage("Reiniciado. Vuelve a ejecutar con el valor actual."); return end
local v = tonumber(txt)
if not v then showMessage("Valor no numérico: " .. txt); return end

-- ---------------------------------------------------------------- utilidades
local function scan(vt, valor, maxN)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vt, rtRounded, string.format("%X", valor), "", 0x10000, 0x7FFFFFFFFFFF,
               "+W", fsmAligned, "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r, total = {}, fl.Count
  for i = 0, math.min(total, maxN) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r, total
end

local function describir(K)
  local vis, raw = readInteger(K), readInteger(K + 4)
  local ptrs = {}
  for off = -0x44, 0x48, 4 do                      -- paso 4: K no siempre está alineado a 8
    local q = readQword(K + off)
    if enMod(q) then ptrs[#ptrs + 1] = string.format("%s%X→%s", off < 0 and "-" or "+", math.abs(off), rva(q)) end
  end
  return string.format("K=%X  pantalla=%s  interno=%s (%s)  K-0x14=%s  K-0x4=%s  punteros: %s", K, tostring(vis), tostring(raw),
    (raw and vis and raw == vis * 256) and "= pantalla×256" or "≠ pantalla×256",
    tostring(readInteger(K - 0x14)), tostring(readInteger(K - 0x4)),
    #ptrs > 0 and table.concat(ptrs, " ") or "(ninguno)")
end

-- ---------------------------------------------------------------- paso 1
if not KD_GV1 then
  local cands, visto = {}, {}
  local function add(K, metodo)
    if not visto[K] then visto[K] = true; cands[#cands + 1] = { K = K, m = metodo } end
  end
  p("== PASO 1 (v2) — valor en pantalla %d ==", v)

  local hA, tA = scan(vtQword, F2, 5000)
  local nA = 0
  for _, h in ipairs(hA) do
    local K = h - 0x34
    if readQword(K + 0x3C) == F3 then add(K, "firma"); nA = nA + 1 end
  end
  p("A) Firma (+34/+3C): %d coincidencias de +34, %d con +3C válido", tA, nA)
  -- Histograma del campo K-0x14 entre los objetos con la firma (¿1662 es único del Prestigio?)
  local hist = {}
  for _, c in ipairs(cands) do
    local id = readInteger(c.K - 0x14) or -1
    hist[id] = (hist[id] or 0) + 1
  end
  local hs = {}
  for id, n in pairs(hist) do hs[#hs + 1] = string.format("%d×%d", id, n) end
  table.sort(hs)
  p("   K-0x14 (valor×cantidad): %s", table.concat(hs, "  "))

  if v > 0 then
    local par = (v * 256) * 0x100000000 + v
    local hB, tB = scan(vtQword, par, 200)
    for _, K in ipairs(hB) do add(K, "par") end
    p("B) Par pantalla|interno (%d | %d): %d coincidencias", v, v * 256, tB)
  else
    p("B) Par: omitido (con 0 coincide con casi todo; usa un valor > 0)")
  end

  -- Mostrar primero los candidatos con K-0x14 = 1662 (posible ID del Prestigio)
  table.sort(cands, function(a, b)
    local ia, ib = readInteger(a.K - 0x14) == 1662, readInteger(b.K - 0x14) == 1662
    if ia ~= ib then return ia end
    return (readInteger(a.K) or 0) > (readInteger(b.K) or 0)
  end)
  KD_GV1 = { paso = 1, c = cands }
  p("\nCandidatos: %d (primero los que tienen K-0x14 = 1662, luego los de mayor valor)", #cands)
  for i, c in ipairs(cands) do
    if i > 25 then p("  … (%d más)", #cands - 25); break end
    p("  %2d) [%s] %s", i, c.m, describir(c.K))
  end
else
-- ---------------------------------------------------------------- pasos siguientes
  KD_GV1.paso = KD_GV1.paso + 1
  p("== PASO %d — valor en pantalla %d ==", KD_GV1.paso, v)
  local keep = {}
  for _, c in ipairs(KD_GV1.c) do
    if readInteger(c.K) == v then keep[#keep + 1] = c end
  end
  p("Siguen al valor: %d de %d", #keep, #KD_GV1.c)
  KD_GV1.c = keep
  for i, c in ipairs(keep) do
    if i > 25 then p("  … (%d más)", #keep - 25); break end
    p("  %2d) [%s] %s", i, c.m, describir(c.K))
  end
  if #keep == 1 then
    p("\nÚNICO candidato. Pega este informe en el chat para fijar la firma definitiva.")
  elseif #keep == 0 then
    p("\nNinguno sigue al valor: escribe r y empieza de nuevo con el valor actual.")
  else
    p("\nCambia tu Prestigio en el juego y vuelve a ejecutar.")
  end
end

local rep = table.concat(out, "\n")
local f = io.open(OUTFILE, "a"); if f then f:write(rep .. "\n\n"); f:close() end
writeToClipboard(rep)
showMessage(rep .. "\n\n(Copiado al portapapeles)")
