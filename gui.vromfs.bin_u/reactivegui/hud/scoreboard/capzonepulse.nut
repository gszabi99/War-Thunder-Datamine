from "%rGui/globals/ui_library.nut" import *

const PULSE_RING_ICON = "ui/gameuiskin#capture_zone_pulse_ring.svg"

const PULSE_START_SEC = 0.3 
const PULSE_PERIOD_SEC = 1.0 
const PULSE_LIFE_SEC = 1.4 
const PULSE_RINGS_COUNT = 2
const PULSE_SCALE_FROM = 1.02
const PULSE_SCALE_TO = 1.72

let mkRingAnims = @(idx) freeze([
  { prop = AnimProp.scale, from = [PULSE_SCALE_FROM, PULSE_SCALE_FROM], to = [PULSE_SCALE_TO, PULSE_SCALE_TO],
    duration = PULSE_LIFE_SEC, loopPause = PULSE_PERIOD_SEC * PULSE_RINGS_COUNT - PULSE_LIFE_SEC,
    delay = PULSE_START_SEC + idx * PULSE_PERIOD_SEC, easing = OutCubic, loop = true, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0,
    duration = PULSE_LIFE_SEC, loopPause = PULSE_PERIOD_SEC * PULSE_RINGS_COUNT - PULSE_LIFE_SEC,
    delay = PULSE_START_SEC + idx * PULSE_PERIOD_SEC, easing = OutQuad, loop = true, play = true }
])
let ringAnims = freeze(array(PULSE_RINGS_COUNT).map(@(_, idx) mkRingAnims(idx)))

let pulseEnvelopeAnims = freeze([
  { prop = AnimProp.opacity, from = 0, to = 1, duration = 0.3, delay = PULSE_START_SEC, play = true }
  { prop = AnimProp.opacity, from = 1, to = 0, duration = 0.45, playFadeOut = true }
])

let mkPulseRing = @(idx, image, color) {
  size = FLEX
  rendObj = ROBJ_IMAGE
  image
  color
  opacity = 0
  transform = true
  animations = ringAnims[idx]
}

function mkCapZonePulse(zoneId, zoneSize, color) {
  let ringPx = (zoneSize * PULSE_SCALE_TO + 0.5).tointeger()
  let image = Picture($"{PULSE_RING_ICON}:{ringPx}:{ringPx}:P")
  return {
    key = $"capZonePulse_{zoneId}"
    size = FLEX
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    animations = pulseEnvelopeAnims
    children = array(PULSE_RINGS_COUNT).map(@(_, idx) mkPulseRing(idx, image, color))
  }
}

const WAVE_RING_ICON = "ui/gameuiskin#capture_zone_wave_ring.svg"
const WAVE_RING_THIN_ICON = "ui/gameuiskin#capture_zone_wave_ring_thin.svg"
const WAVE_SEC = 0.9

let waveRings = [
  { icon = WAVE_RING_ICON, scaleTo = 2.9, opacity = 0.95, delay = 0.0, isZoneColor = true }
  { icon = WAVE_RING_THIN_ICON, scaleTo = 2.3, opacity = 0.5, delay = 0.12, isZoneColor = false }
]

let mkWaveRingAnims = @(ring, trigger) freeze([
  { prop = AnimProp.scale, from = array(2, 1 / ring.scaleTo), to = [1, 1],
    duration = WAVE_SEC, delay = ring.delay, easing = OutExp, trigger }
  { prop = AnimProp.opacity, from = ring.opacity, to = 0,
    duration = WAVE_SEC, delay = ring.delay, trigger }
])

let getCapZoneWaveTrigger = @(zoneId) $"capZoneWave_{zoneId}"

function startCapZoneWave(zoneId) {
  anim_start(getCapZoneWaveTrigger(zoneId))
}

let waveRingAnimsByTrigger = {}
function getWaveRingAnims(trigger) {
  if (trigger not in waveRingAnimsByTrigger)
    waveRingAnimsByTrigger[trigger] <- freeze(waveRings.map(@(ring) mkWaveRingAnims(ring, trigger)))
  return waveRingAnimsByTrigger[trigger]
}

function mkWaveRing(ring, idx, trigger, anims, zoneSize, color) {
  let ringPx = (zoneSize * ring.scaleTo + 0.5).tointeger()
  return {
    key = $"{trigger}_{idx}"
    size = ringPx
    rendObj = ROBJ_IMAGE
    image = Picture($"{ring.icon}:{ringPx}:{ringPx}:P")
    color = ring.isZoneColor ? color : 0xFFFFFFFF
    opacity = 0
    transform = true
    animations = anims[idx]
  }
}

function mkCapZoneWave(zoneId, zoneSize, color) {
  let trigger = getCapZoneWaveTrigger(zoneId)
  let anims = getWaveRingAnims(trigger)
  return {
    key = trigger
    size = FLEX
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = waveRings.map(@(ring, idx) mkWaveRing(ring, idx, trigger, anims, zoneSize, color))
  }
}

return freeze({
  mkCapZonePulse
  mkCapZoneWave
  startCapZoneWave
})
