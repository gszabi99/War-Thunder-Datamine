let saclosMissileBeaconIRSourceBand = persist("saclosMissileBeaconIRSourceBand", @() ::Watched(4))
let reloadCooldownTimeByCaliber = persist("reloadCooldownTimeByCaliber", @() ::Watched({}))


let function initWeaponParams() {
  let blk = ::DataBlock()
  blk.load("config/gameplay.blk")
  if(blk?.sensorsConstants)
    saclosMissileBeaconIRSourceBand(blk.sensorsConstants?.saclosMissileBeaconInfraRedBrightnessSourceBand ?? 4)

  reloadCooldownTimeByCaliber({})
  let cooldown_time = blk?.reloadCooldownTimeByCaliber
  if (!cooldown_time)
    return

  foreach (time in cooldown_time % "time")
    reloadCooldownTimeByCaliber.mutate(@(v) v[time.x] <- time.y) // warning disable: -iterator-in-lambda
}

return {
  saclosMissileBeaconIRSourceBand
  reloadCooldownTimeByCaliber
  initWeaponParams
}
