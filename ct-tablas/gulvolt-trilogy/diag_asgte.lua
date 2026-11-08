-- =====================================================================================
-- diag_asgte.lua — Diagnóstico preliminar para Azure Striker Gunvolt Trilogy Enhanced
-- Uso: adjunta Cheat Engine al ejecutable del juego (p. ej. game1.exe), abre
--      Memory View > Tools > Lua Engine, pega TODO este script y ejecútalo.
-- Resultado: ventana con el informe + copia al portapapeles (pégalo en el chat).
-- No escribe memoria ni modifica el juego.
-- Licencia: PolyForm Noncommercial 1.0.0 (ver LICENSE en la raíz del repositorio).
-- =====================================================================================
local out = {}
local function p(fmt, ...) out[#out + 1] = string.format(fmt, ...) end

-- 1) Procesos del recopilatorio en ejecución
p("== Procesos que contienen 'game' ==")
local pl = getProcesslist()
for pid, name in pairs(pl) do
  if tostring(name):lower():find("game") then p("  %s  (PID %d)", name, pid) end
end

-- 2) Proceso adjunto y módulo principal
local proc = process
if not proc or proc == "" then
  showMessage("No hay proceso adjunto. Adjunta Cheat Engine a game1.exe / game2.exe / game3.exe.")
  return
end
local base = getAddressSafe(proc)
local size = getModuleSize(proc) or 0
p("\n== Proceso adjunto: %s ==", proc)
p("  base = %X   tamaño = %X   64 bits = %s", base or 0, size, tostring(targetIs64Bit()))

-- 3) Firma de la tabla original (Health Editor)
local AOB = "8B ?? 41 3B ?? 45 8B ?? 44 0F"
p("\n== AOB de la tabla original: %s ==", AOB)
local hits = AOBScan(AOB, "+X")          -- solo memoria ejecutable
local inMod = {}
if hits then
  for i = 0, hits.Count - 1 do
    local a = tonumber(hits[i], 16)
    if base and a >= base and a < base + size then inMod[#inMod + 1] = a end
  end
  p("  coincidencias totales: %d   dentro de %s: %d", hits.Count, proc, #inMod)
  hits.destroy()
else
  p("  sin coincidencias en memoria ejecutable")
end

-- 4) Desensamblado de cada coincidencia (máx. 4) para revisar los 5 bytes que se copian
for n = 1, math.min(#inMod, 4) do
  local a = inMod[n]
  p("\n-- coincidencia #%d en %s --", n, getNameFromAddress(a))
  local cur, copied = a, 0
  for _ = 1, 8 do
    local d = disassemble(cur)
    local sz = getInstructionSize(cur)
    local mark = (copied < 5) and "  <- dentro de los 5 bytes copiados" or ""
    p("  %s%s", d, mark)
    copied = copied + sz
    cur = cur + sz
  end
end

-- 5) Si el Health Editor original está activo, volcar la estructura capturada
local data = getAddressSafe("data")
if data then
  local ptr = readQword(data)
  p("\n== [data] = %X (Health Editor activo) ==", ptr or 0)
  if ptr and ptr > 0x10000 then
    for off = 0, 0x20, 4 do
      p("  +%02X : %s", off, tostring(readInteger(ptr + off)))
    end
  end
else
  p("\n(Health Editor no activo: el símbolo 'data' no existe; no se vuelca la estructura)")
end

-- 6) Volcado del módulo (el .exe en disco está cifrado por SteamStub/.bind: las firmas
--    AOB se generan desde este volcado con sigmaker.py --dump). Solo lectura del juego.
local DUMP_DIR = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\]]
local ruta = DUMP_DIR .. proc:gsub("%.exe$", "") .. ".dmp"
local okDump = base and size > 0 and writeRegionToFile(ruta, base, size)
p("\n== Volcado del módulo ==")
p("  %s  ->  %s", ruta, okDump and "OK" or "FALLÓ (revisa que exista la carpeta dumps y la ruta)")

local txt = table.concat(out, "\n")
writeToClipboard(txt)
showMessage(txt .. "\n\n(Copiado al portapapeles)")
