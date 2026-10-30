import "DataBlock" as DataBlock
from "%rGui/utils/cacheDasScriptForView.nut" import getDasScriptByPath
from "console" import register_command
from "dagor.math" import E3DCOLOR
from "blkLoad" import tryLoadBlk
from "%rGui/globals/ui_library.nut" import *

let sonarDebugEnabled = Watched(false)
register_command(@() sonarDebugEnabled.set(!sonarDebugEnabled.get()), "sonar.debug")


local activeSonarScriptConfig = null

function getActiveSonarConfig() {
  if (activeSonarScriptConfig != null)
    return activeSonarScriptConfig

  let hudBlk = DataBlock()
  if (!tryLoadBlk(hudBlk, "config/hud.blk"))
    return {}

  let cfgBlk = hudBlk?.activeSonar
  activeSonarScriptConfig = {
    disabledTicksColor = cfgBlk?.getE3dcolor("disabledTicksColor", E3DCOLOR(192, 192, 192, 255))
    activeTicksColor = cfgBlk?.getE3dcolor("activeTicksColor", E3DCOLOR(38, 127, 0, 255))
    minorTickLenPx = cfgBlk?.getReal("minorTickLenPx", 3.0)
    majorTickLenPx = cfgBlk?.getReal("majorTickLenPx", 9.0)
    ticksPerArc = cfgBlk?.getInt("ticksPerArc", 25)
    majorTickEvery = cfgBlk?.getInt("majorTickEvery", 4)
    tickLineWidth = cfgBlk?.getReal("tickLineWidth", 1.5)
    cooldownBarColor = cfgBlk?.getE3dcolor("cooldownBarColor", E3DCOLOR(38, 127, 0, 255))
    cooldownBarOffset = cfgBlk?.getReal("cooldownBarOffset", 5.0)
    cooldownBarWidth = cfgBlk?.getReal("cooldownBarWidth", 3.0)
    pulseRingColor = cfgBlk?.getE3dcolor("pulseRingColor", E3DCOLOR(38, 127, 0, 255))
    pulseRingAlpha = cfgBlk?.getReal("pulseRingAlpha", 0.33)
    pulseRingMinSaturation = cfgBlk?.getReal("pulseRingMinSaturation", 0.0)
    pulseAnimationTime = cfgBlk?.getReal("pulseAnimationTime", 2.0)
    pulseRingWidth = cfgBlk?.getReal("pulseRingWidth", 40.0)
    pulseFadeTime = cfgBlk?.getReal("pulseFadeTime", 0.6)
    rangeTextColor = cfgBlk?.getE3dcolor("rangeTextColor", E3DCOLOR(10, 202, 10, 250))
  }
  return activeSonarScriptConfig
}

let activeSonarIndication = {
  size = FLEX
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/sonarIndication.das")
  drawFunc = "draw_active_sonar_indication"
  setupFunc = "setup_data"
  font = Fonts.tiny_text_hud
}.__update(getActiveSonarConfig())

let sonarIndicationDebug = {
  size = FLEX
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/sonarIndicationDebug.das")
  drawFunc = "draw_sonar_indication"
  setupFunc = "setup_data"
  fovColor = Color(180, 180, 180, 255)
  targetColor = Color(255, 0, 0, 255)
  font = Fonts.hud
}

let hydrophoneMeasureIndication = {
  size = FLEX
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/hydrophoneMeasure.das")
  drawFunc = "draw_hydrophone_measure"
  setupFunc = "setup_data"
  font = Fonts.hud
  hpBearingPicture    = Picture("ui/gameuiskin#hydrophone_bearing.svg:512:512:K")
  hpAimPicture        = Picture("ui/gameuiskin#hydrophone_aim.avif")
  hpGainCenterPicture = Picture("ui/gameuiskin#hydrophone_gain_center.svg:128:128:K")
  hpGainPicture       = Picture("ui/gameuiskin#hydrophone_gain.svg:128:128:K")
  hpBearingArrPicture = Picture("ui/gameuiskin#hydrophone_bearing_arrow.svg:128:128:K")
}

local activeSonarInterceptScriptConfig = null

function getActiveSonarInterceptConfig() {
  if (activeSonarInterceptScriptConfig != null)
    return activeSonarInterceptScriptConfig

  let hudBlk = DataBlock()
  if (!tryLoadBlk(hudBlk, "config/hud.blk"))
    return {}

  let cfgBlk = hudBlk?.activeSonarIntercept
  activeSonarInterceptScriptConfig = {
    pulseArcColor = cfgBlk?.getE3dcolor("pulseArcColor", E3DCOLOR(255, 0, 0, 128))
    pulseSectorColor = cfgBlk?.getE3dcolor("pulseSectorColor", E3DCOLOR(0, 0, 0, 0))
    pulseArcRadius = cfgBlk?.getReal("pulseArcRadius", 0.25)
    pulseArcWidth = cfgBlk?.getReal("pulseArcWidth", 0.5)
    pulseArcLineWidth = cfgBlk?.getReal("pulseArcLineWidth", 20.0)
    pulseArrowSize = cfgBlk?.getReal("pulseArrowSize", 0.025)
    pulseFadeTime = cfgBlk?.getReal("pulseFadeTime", 1.0)
  }
  return activeSonarInterceptScriptConfig
}

let activeSonarInterceptIndication = {
  size = FLEX
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/activeSonarInterceptIndication.das")
  drawFunc = "draw_active_sonar_intercept_indication"
  setupFunc = "setup_data"
}.__update(getActiveSonarInterceptConfig())

function sonarIndication() {
  return @(){
    watch = sonarDebugEnabled
    size = FLEX
    children = [
      activeSonarIndication
      hydrophoneMeasureIndication
      sonarDebugEnabled.get() ? sonarIndicationDebug : null
      activeSonarInterceptIndication
    ]
  }
}

return freeze({
  sonarIndication
})
