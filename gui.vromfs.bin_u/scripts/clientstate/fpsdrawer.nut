from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { subscribe } = require("eventbus")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")


const QUALITY_COLOR_EPIC = "constantColorFps"
const QUALITY_COLOR_GOOD = "constantColorFps"
const QUALITY_COLOR_OKAY = "qualityColorOkay"
const QUALITY_COLOR_POOR = "qualityColorPoor"


let paramsList = freeze(["fps", "latency", "ping", "pl", "sid"])
const objIdPrefix = "status_text_"

let mainSceneObjects = {}
let loadingSceneObjects = {}


let function getFpsColor(fps) {
  return "constantColorFps"
}


let function getPingColor(ping) {
  if (ping <= 50)
    return QUALITY_COLOR_EPIC
  else if (ping <= 100)
    return QUALITY_COLOR_GOOD
  else if (ping <= 300)
    return QUALITY_COLOR_OKAY
  return QUALITY_COLOR_POOR
}


let function getPacketlossColor(pl) {
  if (pl <= 1)
    return QUALITY_COLOR_EPIC
  else if (pl <= 10)
    return QUALITY_COLOR_GOOD
  else if (pl <= 20)
    return QUALITY_COLOR_OKAY
  return QUALITY_COLOR_POOR
}


let function validateObjects(objects, guiScene) {
  if (checkObj(getTblValue(paramsList[0], objects)))
    return true

  let holderObj = guiScene["status_texts_holder"]
  if (!checkObj(holderObj))
    return false

  foreach(param in paramsList)
    objects[param] <- holderObj.findObject(objIdPrefix + param)
  objects.show <- true
  return true
}


let function getCurSceneObjects() {
  let guiScene = ::get_cur_gui_scene()
  if (!guiScene)
    return null

  local objects = mainSceneObjects
  if (!guiScene.isEqual(::get_main_gui_scene()))
    objects = loadingSceneObjects

  if (!validateObjects(objects, guiScene))
    return null

  return objects
}


//validate objects before calling this
let function updateTexts(objects, params) {
  let { fps, ping, pl, sessionId, latency, latencyA, latencyR } = params
  let fpsInt = (fps + 0.5).tointeger();
  local fpsText = ""
  let isAllowedForPlatform = !isPlatformSony && !isPlatformXboxOne && !is_platform_android
  let isAllowedForUser = hasFeature("FpsCounterOverride")
  if ((::is_dev_version || isAllowedForPlatform || isAllowedForUser) && fpsInt < 10000 && fpsInt > 0)
    fpsText = colorize(getFpsColor(fpsInt), format("FPS: %d", fpsInt))
  objects.fps.setValue(fpsText)

  local latencyText = ""
  local pingText = ""
  local plText = ""
  local sidText = ""
  if (latency >= 0) {
    if (latencyA >= 0 && latencyR >= 0)
      latencyText = format("%s:%5.1fms (A:%5.1fms R:%5.1fms)", loc("latency", "Latency"), latency, latencyA, latencyR)
    else
      latencyText = format("%s:%5.1fms", loc("latency", "Latency"), latency)
  }
  if (ping >= 0)
  {
    pingText = colorize(getPingColor(ping), "Ping: " + ping)
    plText = colorize(getPacketlossColor(pl), "PL: " + pl + "%")
    sidText = sessionId
  }
  objects.latency.setValue(latencyText)
  objects.ping.setValue(pingText)
  objects.pl.setValue(plText)
  objects.sid.setValue(sidText)
}


let function checkVisibility(objects) {
  let show = ::is_hud_visible()
  if (objects.show == show)
    return

  foreach(param in paramsList)
    objects[param].show(show)
  objects.show = show
}


let function updateStatus(params) {
  let objects = getCurSceneObjects()
  if (!objects)
    return

  checkVisibility(objects)
  updateTexts(objects, params)
}



let function init() {
  ::subscribe_handler({
    function onEventShowHud(p) {
      let objects = getCurSceneObjects()
      if (objects)
        checkVisibility(objects)
    }
  })
}

init()

subscribe("updateStatusString", updateStatus)
