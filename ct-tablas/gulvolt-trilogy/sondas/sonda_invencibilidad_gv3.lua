-- =====================================================================================
-- sonda_invencibilidad_gv3.lua — Busca la invencibilidad de GV3 (game3.exe) SIN depurador, con el método
-- de GV1 (sonda_invencibilidad_gv1.lua): muestrea el objeto jugador y el objeto base cada 50 ms durante
-- 20 s mientras recibes golpes. Detecta los golpes por el campo de cámara lenta (jugador+0x592, 2 bytes,
-- que pasa de 0 a >0 en cada golpe) y busca:
--   · TEMPORIZADORES: campos que pasan de 0 a >0 justo tras el golpe y bajan solos hasta 0
--     (se prueban como entero de 4 bytes, como float y como cada mitad de 2 bytes);
--   · BANDERAS: campos que cambian durante ~1,5 s tras el golpe y vuelven a su valor anterior.
-- Objetos: jugador = [[[game3.exe+1F02FE8]+10]+10] (0x1000 bytes) y base = [game3.exe+1F02FE8] (0x800 bytes).
-- Pista de RTX_XXXX (GV3 suelto): temporizador float en +0x510 de algún objeto.
-- Uso: GV3 dentro de un nivel, con enemigos cerca. Lua Engine > pegar > Execute. Recibe 2–4 golpes
-- SEPARADOS (espera a que termine el parpadeo entre uno y otro). No escribe memoria.
-- Resultado: ventana + portapapeles + dumps\sonda_invencibilidad_gv3_<fecha>_<hora>.txt.
-- Licencia: PolyForm Noncommercial 1.0.0.
-- =====================================================================================
local OUTFILE = [[D:\SCM\cheat-engine-skill\ct-tablas\gulvolt-trilogy\dumps\sonda_invencibilidad_gv3_]] ..
                os.date("%Y-%m-%d_%H%M") .. ".txt"
local MS, TICKS = 50, 400                -- 400 × 50 ms = 20 s
local VENT, TRAS = 30, 15                -- banderas: ventana tras el golpe y margen para «volver»

local b3 = getAddressSafe("game3.exe")
if not b3 then showMessage("Adjunta Cheat Engine a game3.exe primero."); return end
local BASE = b3 + 0x1F02FE8
local function valido(a) return a and a > 0x10000 and a < 0x7FFFFFFFFFFF end
local B = readQword(BASE)
local P = valido(B) and readQword(B + 0x10)
P = valido(P) and readQword(P + 0x10)
if not valido(B) or not valido(P) then showMessage("No se encontró el objeto jugador de GV3. Entra a un nivel."); return end

local OBJS = { { nombre = "jugador", a = P, largo = 0x1000, snaps = {} },
               { nombre = "base",    a = B, largo = 0x800,  snaps = {} } }
local lenta = {}                          -- jugador+0x592 en cada muestra (marca de golpe)

local function u32(b, o) return b[o + 1] | (b[o + 2] << 8) | (b[o + 3] << 16) | (b[o + 4] << 24) end
local function u16(b, o) return b[o + 1] | (b[o + 2] << 8) end
local function f32(b, o) return (string.unpack("<f", string.pack("<I4", u32(b, o)))) end

-- Lectores por interpretación: { etiqueta, desplazamiento extra, función }
local INTERP = {
  { "i4",   0, u32 },
  { "f",    0, function(b, o) local v = f32(b, o); return (v == v and math.abs(v) < 1e6) and v or -1 end },
  { "u16a", 0, u16 },
  { "u16b", 2, u16 },
}

local function analizar()
  local out = {}
  local function p(f, ...) out[#out + 1] = string.format(f, ...) end
  p("== Sonda de invencibilidad GV3 — %s ==", os.date("%Y-%m-%d %H:%M"))
  p("jugador %X · base %X · %d muestras de %d ms", P, B, #lenta, MS)

  local golpes = {}
  for k = 2, #lenta do if lenta[k - 1] == 0 and lenta[k] > 0 then golpes[#golpes + 1] = k end end
  p("Golpes detectados (cámara lenta 0 → >0): %d", #golpes)
  for _, k in ipairs(golpes) do p("  t = %d ms (cámara lenta = %d)", (k - 1) * MS, lenta[k]) end
  if #golpes == 0 then p("No se detectaron golpes: repite recibiendo daño.") end

  for _, ob in ipairs(OBJS) do
    local S = ob.snaps
    -- Temporizadores
    local cands = {}
    for o = 0, ob.largo - 4, 4 do
      for _, it in ipairs(INTERP) do
        local oo = o + it[2]
        local score, ej = 0, nil
        for _, k in ipairs(golpes) do
          if S[k - 1] and S[k] then
            local antes = it[3](S[k - 1], oo)
            local pico, kp = 0, nil
            for j = k, math.min(k + 4, #S) do local v = it[3](S[j], oo); if v > pico then pico, kp = v, j end end
            if math.abs(antes) < 1e-6 and pico > 0 and pico < 1e5 then
              local mono, vuelve, prev = true, false, pico
              for j = kp + 1, #S do
                local v = it[3](S[j], oo)
                if v > prev + 1e-6 then mono = false; break end
                prev = v
                if math.abs(v) < 1e-6 then vuelve = true; break end
              end
              if mono then
                score = score + (vuelve and 2 or 1)
                if not ej then
                  local s = {}
                  for j = k - 1, math.min(k + 14, #S) do
                    local v = it[3](S[j], oo)
                    s[#s + 1] = it[1] == "f" and string.format("%.2f", v) or tostring(v)
                  end
                  ej = table.concat(s, ",")
                end
              end
            end
          end
        end
        if score > 0 then cands[#cands + 1] = { o = oo, t = it[1], s = score, e = ej } end
      end
    end
    table.sort(cands, function(a, b) return a.s > b.s end)
    p("\n== Objeto %s: candidatos a TEMPORIZADOR (máx. %d puntos = 2 por golpe) ==", ob.nombre, 2 * #golpes)
    for i = 1, math.min(#cands, 20) do
      local c = cands[i]
      p("  +0x%03X %-4s puntaje %d  valores: %s", c.o, c.t, c.s, c.e)
    end
    if #cands == 0 then p("  (ninguno)") end

    -- Banderas: distinto del valor previo durante la ventana tras el golpe y de vuelta después
    local flags = {}
    for o = 0, ob.largo - 4, 4 do
      local score, ej = 0, nil
      for _, k in ipairs(golpes) do
        if S[k - 1] and S[math.min(k + VENT + TRAS, #S)] and k + VENT + TRAS <= #S then
          local antes = u32(S[k - 1], o)
          local distintos = 0
          for j = k, k + VENT do if u32(S[j], o) ~= antes then distintos = distintos + 1 end end
          local despues = u32(S[k + VENT + TRAS], o)
          if distintos >= 5 and despues == antes then
            score = score + 1
            if not ej then ej = string.format("%d → %d → %d", antes, u32(S[k + 2], o), despues) end
          end
        end
      end
      if score > 0 then flags[#flags + 1] = { o = o, s = score, e = ej } end
    end
    table.sort(flags, function(a, b) return a.s > b.s end)
    p("\n== Objeto %s: candidatos a BANDERA (cambia tras el golpe y vuelve) ==", ob.nombre)
    for i = 1, math.min(#flags, 20) do p("  +0x%03X  golpes %d  ej.: %s", flags[i].o, flags[i].s, flags[i].e) end
    if #flags == 0 then p("  (ninguno)") end
  end

  local rep = table.concat(out, "\n")
  local fh = io.open(OUTFILE, "w"); if fh then fh:write(rep); fh:close() end
  writeToClipboard(rep)
  showMessage(rep .. "\n\n(Copiado al portapapeles y guardado en " .. OUTFILE .. ")")
end

showMessage("Al cerrar este aviso empiezan 20 s de muestreo.\n" ..
  "Recibe 2–4 golpes SEPARADOS (espera a que termine el parpadeo entre uno y otro).\n" ..
  "Desactiva antes «Cámara lenta», «Vida al máximo» e «Invencibilidad» si están activos.")
local t = createTimer(nil, false)
t.Interval = MS
t.OnTimer = function(tm)
  local ok = pcall(function()
    for _, ob in ipairs(OBJS) do ob.snaps[#ob.snaps + 1] = readBytes(ob.a, ob.largo, true) end
    lenta[#lenta + 1] = readSmallInteger(P + 0x592) or 0
  end)
  if not ok or #lenta >= TICKS then
    tm.destroy()
    local okA, errA = pcall(analizar)
    if not okA then showMessage("ERROR al analizar: " .. tostring(errA)) end
  end
end
t.Enabled = true
