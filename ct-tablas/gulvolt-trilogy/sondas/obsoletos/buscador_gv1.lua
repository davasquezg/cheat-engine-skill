-- =====================================================================================
-- buscador_gv1.lua — "First/Next Scan" con ESCALAS para localizar valores de GV1
-- (Prestigio/Kudos, EXP, Puntos totales, Tiempo…), sin depurador.
--   1.ª ejecución: busca el valor en varias escalas (×1, ×10, ×16, ×160, ×256, ×10000),
--                  primero dentro de game1.exe y, si no aparece, en toda la memoria escribible.
--   Siguientes:    filtra la lista con el valor nuevo (cada dirección recuerda su escala).
--   r = reiniciar. Con 1 resultado pide un nombre (gv1_kudos, gv1_exp…) y lo registra.
-- No escribe memoria del juego. Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local MOD = "game1.exe"
local base = getAddressSafe(MOD)
if not base then error("Adjunta Cheat Engine a " .. MOD) end
local size = getModuleSize(MOD)
local ESCALAS = { 1, 10, 16, 160, 256, 10000 }

local estado = BUSCA_GV1 and string.format("   (lista actual: %d)", #BUSCA_GV1.lista) or ""
local txt = inputQuery("Buscador GV1",
  "Valor que ves en pantalla.\n1.ª vez: escanea · siguientes: filtra (cambia el valor en el juego entre medio)\nr = reiniciar" .. estado, "")
if not txt or txt == "" then return end
if txt == "r" then
  BUSCA_GV1 = nil
  txt = inputQuery("Buscador GV1", "Valor que ves en pantalla:", "")
  if not txt or txt == "" then return end
end
local v = tonumber(txt)
if not v then error("Valor no numérico: " .. txt) end

local function scan(valor, desde, hasta, maxHits)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtDword, rtRounded, string.format("%X", valor), "", desde, hasta,
               "+W", fsmAligned, "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local r = {}
  for i = 0, math.min(fl.Count, maxHits) - 1 do r[#r + 1] = tonumber(fl.Address[i], 16) end
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return r
end

local ambito = ""
if BUSCA_GV1 then
  local keep = {}
  for _, x in ipairs(BUSCA_GV1.lista) do
    if readInteger(x.a) == v * x.k then keep[#keep + 1] = x end
  end
  BUSCA_GV1.lista = keep
  ambito = BUSCA_GV1.ambito
else
  if v == 0 then error("Con 0 hay demasiadas coincidencias: espera a tener un valor distinto de 0.") end
  local lista = {}
  for _, k in ipairs(ESCALAS) do
    for _, a in ipairs(scan(v * k, base, base + size, 20000)) do lista[#lista + 1] = { a = a, k = k } end
  end
  ambito = "módulo"
  if #lista == 0 then
    for _, k in ipairs(ESCALAS) do
      for _, a in ipairs(scan(v * k, 0x10000, 0x7FFFFFFFFFFF, 30000)) do lista[#lista + 1] = { a = a, k = k } end
    end
    ambito = "toda la memoria"
  end
  BUSCA_GV1 = { lista = lista, ambito = ambito }
end

local L = BUSCA_GV1.lista
local function nombreDir(a)
  if a >= base and a < base + size then return string.format("%s+%X", MOD, a - base) end
  return string.format("%X (fuera del módulo: puede cambiar al reiniciar)", a)
end
local lines = { string.format("Valor %d -> quedan %d (%s)", v, #L, ambito) }
for i = 1, math.min(#L, 15) do lines[#lines + 1] = string.format("  %s  escala ×%d", nombreDir(L[i].a), L[i].k) end
if #L == 0 then
  lines[#lines + 1] = "Sin resultados: escribe r y prueba otra vez (¿el valor cambió mientras escribías?)."
elseif #L == 1 then
  local x = L[1]
  local nombre = inputQuery("Buscador GV1", "Quedó 1 dirección (escala ×" .. x.k .. "). Nombre del símbolo:", "gv1_kudos")
  if nombre and nombre ~= "" then
    registerSymbol(nombre, x.a, true)
    BUSCA_GV1_ESCALA = BUSCA_GV1_ESCALA or {}
    BUSCA_GV1_ESCALA[nombre] = x.k
    local m = getAddressList().createMemoryRecord()
    m.Description = string.format("%s (escala ×%d)  %s", nombre, x.k, nombreDir(x.a))
    m.Address = (x.a >= base and x.a < base + size) and string.format("%s+%X", MOD, x.a - base) or string.format("%X", x.a)
    m.Type = vtDword
    lines[#lines + 1] = "Registrado como '" .. nombre .. "' y agregado a la tabla."
    BUSCA_GV1 = nil
  end
else
  lines[#lines + 1] = "Cambia el valor en el juego y vuelve a ejecutar para filtrar."
end
local rep = table.concat(lines, "\n")
writeToClipboard(rep)
showMessage(rep)
