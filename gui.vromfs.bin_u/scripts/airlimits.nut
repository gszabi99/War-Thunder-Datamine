from "%scripts/dagui_library.nut" import *
let { getFmFile } = require("%scripts/unit/unitParams.nut")

function getAirFmFile(unit) {
  if (unit.isAir())
    return getFmFile(unit.name)
  return null
}


function getFlapsDestructionIndSpeed(unit) {
  let fmFile = getAirFmFile(unit)
  if (!fmFile?.AvailableControls.hasFlapsControl)
    return -1

  let mass = fmFile?.Mass
  if (mass == null)
    return -1

  let flapsDestructionIndSpeedP = mass?.FlapsDestructionIndSpeedP
  if (flapsDestructionIndSpeedP != null && (typeof flapsDestructionIndSpeedP == "Point4"))
    return min(flapsDestructionIndSpeedP.y, flapsDestructionIndSpeedP.w)

  let speeds = [null]
  local i = "FlapsDestructionIndSpeedP0" in mass ? 0 : 1
  for (i; $"FlapsDestructionIndSpeedP{i}" in mass; ++i)
    speeds.append(mass[$"FlapsDestructionIndSpeedP{i}"].y)

  if (speeds.len() > 2)
    return min.pacall(speeds)

  return speeds?[1] ?? -1
}


function getGearDestructionIndSpeed(unit) {
  let fmFile = getAirFmFile(unit)
  if (!fmFile?.AvailableControls.hasGearControl)
    return -1

  return fmFile?.Mass.GearDestructionIndSpeed ?? -1
}


function getWingPlaneStrength(unit) {
  let fmFile = getAirFmFile(unit)
  if (!fmFile)
    return null

  if (("VneMach" in fmFile) && ("Vne" in fmFile))
    return [{
      vne = fmFile.Vne
      mne = fmFile.VneMach
    }]

  let aerodynamics = fmFile?.Aerodynamics
  if (aerodynamics == null)
    return null

  if (aerodynamics?.WingPlane.Strength != null)
    return [{
      vne = aerodynamics.WingPlane.Strength.VNE
      mne = aerodynamics.WingPlane.Strength.MNE
    }]

  let res = []
  for (local i = 0; $"WingPlaneSweep{i}" in aerodynamics; ++i) {
    let strength = aerodynamics[$"WingPlaneSweep{i}"].Strength
    res.append({
      vne = strength.VNE
      mne = strength.MNE
    })
  }

  if (res.len() == 0)
    return null

  return [res[0], res[res.len() - 1]]
}

return {
  getFlapsDestructionIndSpeed
  getGearDestructionIndSpeed
  getWingPlaneStrength
}