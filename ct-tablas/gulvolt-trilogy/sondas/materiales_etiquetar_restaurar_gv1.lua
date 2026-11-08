local base = getAddressSafe("game1.exe")
if base and MATS_GV1_ETIQ then
  local MAT = base + 0x7B3668 + 0x3B0
  for i = 0, 27 do
    if MATS_GV1_ETIQ[i] then writeInteger(MAT + 4 * i, MATS_GV1_ETIQ[i]) end
  end
  MATS_GV1_ETIQ = nil
end
