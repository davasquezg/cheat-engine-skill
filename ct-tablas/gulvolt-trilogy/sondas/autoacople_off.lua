if AUTOACOPLE then
  if AUTOACOPLE.timer then AUTOACOPLE.timer.destroy(); AUTOACOPLE.timer = nil end
  if AUTOACOPLE.titulo then getMainForm().Caption = AUTOACOPLE.titulo end
end
