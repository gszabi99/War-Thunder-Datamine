import "%rGui/style/teamColors.nut" as teamColors
from "math" import sqrt, round
from "wt.behaviors" import Projection
from "%sqstd/math.nut" import ceil
from "%rGui/missionState.nut" import localTeam
from "%rGui/hud/plantSites/plantSitesState.nut" import plantSitesList
from "%rGui/hud/plantSites/plantSiteCommon.nut" import curTime, heroPos, blinkAnims, mkBlinkBucketW, fuseTimeLeft, siteColor, siteLetter
from "%rGui/globals/ui_library.nut" import *

const MARKER_SHOW_ONLY_IN_VIEWPORT = 0x01

const MARKER_Y_OFFS = 2.0
const NEAR_DISTANCE = 4.0
const PLANTED_MIN_DISTANCE = 0.5

const labelColor = 0xCCFFFFFF

const iconSize = hdpxi(24)
const labelFontSize = hdpx(16)
const screenMargin = hdpx(28)

let fontFx = {
  fontFxFactor = hdpx(24)
  fontFxColor = 0xFF000000
  fontFx = FFT_SHADOW
}

let markIcon = @(site) Picture($"ui/gameuiskin#basezone_small_mark_{siteLetter(site)}.svg:{iconSize}:{iconSize}:K")

function distanceTo(site, heroPosVal) {
  if (site.pos == null || heroPosVal == null)
    return -1.0
  let dx = site.pos.x - heroPosVal.x
  let dy = site.pos.y - heroPosVal.y
  let dz = site.pos.z - heroPosVal.z
  return sqrt(dx * dx + dy * dy + dz * dz)
}

let mkIcon = @(site, blinkBucketW) function() {
  let bucket = blinkBucketW.get()
  return {
    watch = [localTeam, teamColors, blinkBucketW]
    key = $"plant_site_icon_{bucket}"
    size = iconSize
    rendObj = ROBJ_IMAGE
    image = markIcon(site)
    color = siteColor(site, localTeam.get(), teamColors.get())
    keepAspect = true
    animations = blinkAnims[bucket]
  }
}

let mkLabel = @(site) function() {
  local text = ""
  if (site.isPlanted)
    text = $"{max(0, ceil(fuseTimeLeft(site, curTime.get())).tointeger())} {loc("measureUnits/seconds")}"
  else {
    let dist = distanceTo(site, heroPos.get())
    if (dist >= 0)
      text = $"{round(dist).tointeger()} {loc("measureUnits/meters_dist_short")}"
  }
  return {
    watch = [curTime, heroPos]
    markerFlags = MARKER_SHOW_ONLY_IN_VIEWPORT
    rendObj = ROBJ_TEXT
    font = Fonts.small_text_hud
    fontSize = labelFontSize
    color = labelColor
    text
  }.__update(fontFx)
}

function mkMarker(site) {
  let isNearW = Computed(function() {
    let dist = distanceTo(site, heroPos.get())
    return dist >= 0 && dist < NEAR_DISTANCE
  })
  let blinkBucketW = mkBlinkBucketW(site)
  return @() {
    watch = isNearW
    key = site.eid
    data = {
      eid = site.eid
      yOffs = MARKER_Y_OFFS
      minDistance = site.isPlanted ? PLANTED_MIN_DISTANCE : NEAR_DISTANCE
      clampToBorder = !isNearW.get()
    }
    transform = {}
    flow = FLOW_VERTICAL
    halign = ALIGN_CENTER
    gap = hdpx(2)
    children = [
      mkIcon(site, blinkBucketW)
      mkLabel(site)
    ]
  }
}

let plantSiteMarkers = @() {
  watch = plantSitesList
  size = [sw(100) - screenMargin * 2, sh(100) - screenMargin * 2]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  behavior = Projection
  children = plantSitesList.get().filter(@(s) s.isActive).map(mkMarker)
}

return freeze({
  plantSiteMarkers
})
