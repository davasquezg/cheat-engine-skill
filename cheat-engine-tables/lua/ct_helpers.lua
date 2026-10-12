--[==[
ct_helpers.lua — Funciones auxiliares para la ventana Lua de Cheat Engine (Ctrl+Alt+L).
Skill: cheat-engine-tables

Carga:
  dofile([[C:\ruta\a\ct_helpers.lua]])

Funciones:
  ctFindStatic(targetAddr, offsets, module [, opts])
      Busca HACIA ATRÁS la base estática "module+RVA" de una cadena de punteros cuya
      FORMA (offsets) se conoce, partiendo de la dirección actual de un valor conocido.
      offsets: en ORDEN DE APLICACIÓN, tal como los imprime `ct_tool.py chains`.
        Ej.: [[[mod+X]+238]+70]+70  ->  {0x238, 0x70, 0x70}
      Devuelve tabla de RVAs candidatas (y las imprime).

  ctFollow(base, offsets)
      Recorre una cadena hacia adelante. base = número o string ("mod.exe+E120A40").
      Devuelve la dirección final (o nil y el nivel donde se rompió).

  ctVerify(module, rva, offsets, vtype)
      Atajo: sigue la cadena desde module+rva y muestra dirección y valor final.

  ctDumpModule(module, path)
      Guarda el módulo mapeado en disco para `sigmaker.py --dump` (útil si el .exe está
      empaquetado o protegido y el análisis estático del archivo no encuentra referencias).
--]==]

local function hex(n) return string.format("%X", n) end

local function scanQwordHolders(value, opts)
  -- Devuelve direcciones que contienen 'value' como QWORD (posibles punteros a él)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtQword, rtRounded, hex(value), "", 0, 0x7FFFFFFFFFFF,
               opts.protection or "+W", fsmAligned, opts.align or "4", true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms)
  fl.initialize()
  local res = {}
  local n = math.min(fl.Count, opts.maxPerLevel or 200)
  for i = 0, n - 1 do res[#res + 1] = tonumber(fl.Address[i], 16) end
  local total = fl.Count
  fl.deinitialize(); fl.destroy(); ms.destroy()
  return res, total
end

function ctFindStatic(targetAddr, offsets, module, opts)
  opts = opts or {}
  local modBase = getAddressSafe(module)
  if not modBase or modBase == 0 then error("Módulo no encontrado: " .. tostring(module)) end
  local modEnd = modBase + getModuleSize(module)
  -- Para el último nivel (la base estática) no exigir +W: algunas .data son R/W, otras no.
  local cur = { targetAddr }
  local n = #offsets
  for k = n, 1, -1 do
    local nextSet, seen = {}, {}
    local lastLevel = (k == 1)
    for _, t in ipairs(cur) do
      local v = t - offsets[k]
      local holders, total = scanQwordHolders(v, {
        protection = lastLevel and "" or (opts.protection or "+W"),
        align = opts.align, maxPerLevel = opts.maxPerLevel })
      if total > #holders then
        print(string.format("  aviso: nivel %d, valor %s: %d coincidencias (truncado a %d)",
                            k, hex(v), total, #holders))
      end
      for _, h in ipairs(holders) do
        if not seen[h] and (not lastLevel or (h >= modBase and h < modEnd)) then
          seen[h] = true; nextSet[#nextSet + 1] = h
        end
      end
    end
    print(string.format("Nivel %d (offset +%s): %d candidato(s)", k, hex(offsets[k]), #nextSet))
    if #nextSet == 0 then
      print("  Cadena rota en este nivel: la estructura pudo cambiar. Use el Pointer Scanner de CE.")
      return {}
    end
    cur = nextSet
  end
  local out = {}
  for _, s in ipairs(cur) do
    local rva = s - modBase
    out[#out + 1] = rva
    print(string.format("  BASE ESTÁTICA: \"%s\"+%s", module, hex(rva)))
  end
  return out
end

function ctFollow(base, offsets)
  local a = type(base) == "string" and getAddressSafe(base) or base
  if not a then return nil, 0 end
  local p = readQword(a)
  if not p then return nil, 0 end
  for i, o in ipairs(offsets) do
    if i == #offsets then return p + o end
    p = readQword(p + o)
    if not p or p == 0 then return nil, i end
  end
  return p
end

function ctVerify(module, rva, offsets, vtype)
  local base = getAddressSafe(module) + rva
  local addr, lvl = ctFollow(base, offsets)
  if not addr then
    print(string.format("Cadena rota en el nivel %d", lvl or -1)); return nil
  end
  local v
  if vtype == "byte" then v = readBytes(addr, 1)
  elseif vtype == "2" then v = readSmallInteger(addr)
  elseif vtype == "8" then v = readQword(addr)
  elseif vtype == "float" then v = readFloat(addr)
  else v = readInteger(addr) end
  print(string.format("%s+%s -> %s = %s", module, hex(rva), hex(addr), tostring(v)))
  return addr, v
end

function ctDumpModule(module, path)
  local base = getAddressSafe(module)
  if not base then error("Módulo no encontrado: " .. module) end
  local size = getModuleSize(module)
  local ok = writeRegionToFile(path, base, size)
  print(string.format("Volcado %s (%d MB) -> %s : %s", module, size // 1048576, path, tostring(ok)))
end

print("ct_helpers.lua cargado: ctFindStatic, ctFollow, ctVerify, ctDumpModule")
