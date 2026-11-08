-- Restaura las cantidades de materiales guardadas por materiales_max_gv1.lua
local base = getAddressSafe("game1.exe")
if base and MATS_GV1_BACKUP then
  local MAT = base + 0x7B3668 + 0x3B0
  for i = 0, 27 do
    if MATS_GV1_BACKUP[i] then writeInteger(MAT + 4 * i, MATS_GV1_BACKUP[i]) end
  end
  MATS_GV1_BACKUP = nil
end
