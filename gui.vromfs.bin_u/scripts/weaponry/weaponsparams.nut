local saclosMissileBeaconIRSourceBand = persist("saclosMissileBeaconIRSourceBand", @() ::Watched(4))
local reloadCooldownTimeByCaliber = persist("reloadCooldownTimeByCaliber", @() ::Watched({}))


local function initWeaponParams() {
  local blk = ::DataBlock()
  blk.load("config/gameplay.blk")
  if(blk?.sensorsConstants)
    saclosMissileBeaconIRSourceBand(blk.sensorsConstants?.saclosMissileBeaconInfraRedBrightnessSourceBand ?? 4)

  reloadCooldownTimeByCaliber({})
  local cooldown_time = blk?.reloadCooldownTimeByCaliber
  if (!cooldown_time)
    return

  foreach (time in cooldown_time % "time")
    reloadCooldownTimeByCaliber[time.x] <- time.y
}

return {
  saclosMissileBeaconIRSourceBand
  reloadCooldownTimeByCaliber
  initWeaponParams
}
