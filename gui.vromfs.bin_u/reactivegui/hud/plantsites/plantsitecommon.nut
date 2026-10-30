import "%sqstd/ecs.nut" as ecs
from "mission" import get_mission_time
from "dagor.workcycle" import setInterval, clearTimer
from "%rGui/hud/state/watched_hero.nut" import watchedHeroEid
from "%rGui/hud/plantSites/plantSitesState.nut" import plantSitesList
from "%rGui/globals/ui_library.nut" import *

const UPDATE_INTERVAL = 0.25

const BLINK_MIN_OPACITY = 0.25
const BLINK_MID_FUSE = 10.0
const BLINK_FAST_FUSE = 3.0


let curTime = Watched(get_mission_time())
let heroPos = Watched(null)

function updateState() {
  curTime.set(get_mission_time())
  heroPos.set(ecs.obsolete_dbg_get_comp_val(watchedHeroEid.get(), "transform", null)?.getcol(3))
}

function updateTimer(sites) {
  clearTimer(updateState)
  if (sites.len() == 0)
    return
  updateState()
  setInterval(UPDATE_INTERVAL, updateState)
}

plantSitesList.subscribe(updateTimer)
updateTimer(plantSitesList.get())

let mkBlinkAnim = @(duration) [
  { prop = AnimProp.opacity, from = 1.0, to = BLINK_MIN_OPACITY, duration, play = true, loop = true, easing = CosineFull }
]
let blinkAnims = [null, mkBlinkAnim(1.0), mkBlinkAnim(0.5), mkBlinkAnim(0.2)]
let blinkBucket = @(fuseLeft) fuseLeft > BLINK_MID_FUSE ? 1
  : fuseLeft > BLINK_FAST_FUSE ? 2
  : 3

function [pure, nodiscard] fuseTimeLeft(site, curTimeVal) {
  return site.explosionTimeEnd > 0 ? site.explosionTimeEnd - curTimeVal : site.explosionTimerPausedAtTime
}

let mkBlinkBucketW = @(site) Computed(function() {
  return site.isPlanted ? blinkBucket(fuseTimeLeft(site, curTime.get())) : 0
})

function [pure, nodiscard] siteColor(site, localTeamVal, colors) {
  return site.plantingTeam == localTeamVal ? colors.teamRedColor : colors.teamBlueColor
}

let siteLetter = @[pure, nodiscard](site) ('a' + clamp(site.iconIdx, 0, 15)).tochar()

return {
  curTime
  heroPos
  blinkAnims
  mkBlinkBucketW
  fuseTimeLeft
  siteColor
  siteLetter
}
