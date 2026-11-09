-- =====================================================================================
-- autoacople.lua — Detecta qué juego de Azure Striker Gunvolt Trilogy Enhanced está corriendo y acopla
-- Cheat Engine a él sin intervención del usuario.
-- La colección abre cada juego como un PROCESO APARTE (game.exe = menú; game1.exe GV1, game2.exe GV2,
-- game3.exe GV3, game4.exe Connect iX). Cada 1,5 s:
--   · si CE no está acoplado a un juego (o el juego se cerró), busca uno en la lista de procesos;
--   · al encontrarlo, abre el proceso y ACTIVA el grupo de ese juego en la tabla (los demás se desactivan);
--   · el título de la ventana de CE muestra el estado («acoplado a GV3 …» / «esperando un juego…»).
-- Lo activa la tabla al cargarse (LuaScript de la tabla). Desactivar la entrada = dejar de vigilar.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
if AUTOACOPLE and AUTOACOPLE.timer then AUTOACOPLE.timer.destroy() end

local JUEGOS = {
  { exe = "game1.exe", nombre = "GV1",        grupo = "▶ Azure Striker Gunvolt 1 (game1.exe) — activar para adjuntar" },
  { exe = "game2.exe", nombre = "GV2",        grupo = "▶ Azure Striker Gunvolt 2 (game2.exe) — activar para adjuntar" },
  { exe = "game3.exe", nombre = "GV3",        grupo = "▶ Azure Striker Gunvolt 3 (game3.exe) — activar para adjuntar" },
  { exe = "game4.exe", nombre = "Connect iX", grupo = "▶ Azure Striker Gunvolt Connect iX (game4.exe) — activar para adjuntar" },
}

local form = getMainForm()
AUTOACOPLE = { titulo = AUTOACOPLE and AUTOACOPLE.titulo or form.Caption, juego = nil, pid = nil }

local function estado(txt) form.Caption = AUTOACOPLE.titulo .. "  —  Gunvolt: " .. txt end

local function procesos()
  local r = {}
  for pid, nombre in pairs(getProcessList() or {}) do r[#r + 1] = { pid = pid, nombre = (nombre or ""):lower() } end
  return r
end

local function vivo(pid)
  for _, pr in ipairs(procesos()) do if pr.pid == pid then return true end end
  return false
end

local function grupo(j)
  return getAddressList().getMemoryRecordByDescription(j.grupo)
end

local function soltar()
  for _, j in ipairs(JUEGOS) do
    local r = grupo(j)
    if r and r.Active then pcall(function() r.Active = false end) end
  end
  AUTOACOPLE.juego, AUTOACOPLE.pid = nil, nil
end

local function acoplar(j, pid)
  soltar()
  if not openProcess(pid) and getOpenedProcessID() ~= pid then return false end
  AUTOACOPLE.juego, AUTOACOPLE.pid = j, pid
  local r = grupo(j)
  if r then pcall(function() r.Active = true end) end
  estado(string.format("acoplado a %s (%s, PID %d)", j.nombre, j.exe, pid))
  beep()
  return true
end

local function revisar()
  -- ¿sigue vivo el juego al que estamos acoplados?
  if AUTOACOPLE.pid and vivo(AUTOACOPLE.pid) and getOpenedProcessID() == AUTOACOPLE.pid then return end
  if AUTOACOPLE.pid then soltar() end
  -- buscar un juego en marcha (si hay varios, el primero de la lista)
  local lista = procesos()
  for _, j in ipairs(JUEGOS) do
    for _, pr in ipairs(lista) do
      if pr.nombre == j.exe then
        if acoplar(j, pr.pid) then return end
      end
    end
  end
  estado("esperando un juego (abre GV1, GV2, GV3 o Connect iX desde el menú de la colección)…")
end

local t = createTimer(nil, false)
t.Interval = 1500
t.OnTimer = function() pcall(revisar) end
AUTOACOPLE.timer = t
pcall(revisar)
t.Enabled = true
