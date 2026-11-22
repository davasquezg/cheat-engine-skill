if INV3 and INV3.timer then INV3.timer.destroy(); INV3.timer = nil end
-- Devolver el bit de colisión: el juego lo vuelve a poner solo, pero así no queda apagado si estaba en modo 1
local b3 = getAddressSafe("game3.exe")
if b3 then
  pcall(function()
    local a = readQword(b3 + 0x1F02FE8); a = a and readQword(a + 0x10); a = a and readQword(a + 0x10)
    if a and a > 0x10000 then
      local m = readInteger(a + 0x274)
      if m and readInteger(getAddressSafe("gv3_inv_modo") or 0) ~= 2 then writeInteger(a + 0x274, m | 0x10000) end
    end
  end)
end
