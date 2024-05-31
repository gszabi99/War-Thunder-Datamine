from "%scripts/dagui_library.nut" import *

function getAirFmFile(unit) {
  if (unit.isAir())
    return ::get_fm_file(unit.name)
  return null
}

// Maximum indicated airspeed (IAS) for full flap extension due to structural limits
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

// Maximum indicated airspeed (IAS) for landing gear extension due to structural limits
function getGearDestructionIndSpeed(unit) {
  let fmFile = getAirFmFile(unit)
  if (!fmFile?.AvailableControls.hasGearControl)
    return -1

  return fmFile?.Mass.GearDestructionIndSpeed ?? -1
}

// Maximum indicated airspeed and Mach number: VNE and MNE
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