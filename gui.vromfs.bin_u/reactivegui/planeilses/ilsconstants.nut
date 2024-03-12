from "%rGui/globals/ui_library.nut" import *
let { floor } = require("%sqstd/math.nut")

const mpsToKnots = 1.94384
const metrToFeet = 3.28084
const mpsToFpm = 196.8504
const mpsToKmh = 3.6
const metrToMile = 0.000621371
const metrToNavMile = 0.000539957
const feetToNavMile = 0.000164579
let radToDeg = 180.0 / 3.14159
let degToRad = 3.14159 / 180.0
let baseLineWidth = floor(4 * LINE_WIDTH + 0.5)

enum weaponTriggerName {
  MACHINE_GUNS_TRIGGER,
  CANNONS_TRIGGER,
  ADDITIONAL_GUNS_TRIGGER,

  ROCKETS_TRIGGER,
  BOMBS_TRIGGER,
  MINES_TRIGGER,
  TORPEDOES_TRIGGER,

  AGM_TRIGGER,
  AAM_TRIGGER,
  GUIDED_BOMBS_TRIGGER,

  EXTERNAL_FUEL_TANKS_TRIGGER,
  BOOSTERS_JETTISON_TRIGGER,
  UNDERCARRIAGE_TRIGGER,
  AIRDROPS_TRIGGER,

  COUNTERMEASURES_TRIGGER,

  SPECIAL_GUNS_TRIGGER,
  SMOKE_GRENADE_TRIGGER,
}

return {
  mpsToKnots
  metrToFeet
  mpsToFpm
  mpsToKmh
  baseLineWidth
  metrToMile
  metrToNavMile
  radToDeg
  feetToNavMile,
  weaponTriggerName,
  degToRad
}