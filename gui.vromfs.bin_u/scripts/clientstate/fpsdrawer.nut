local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")

::update_status_string <- function update_status_string(fps, ping, packetLoss, sessionId)
{
  ::fpsDrawer.updateStatus(fps, ping, packetLoss, sessionId)
}

::fpsDrawer <- {
  QUALITY_COLOR_EPIC = "constantColorFps"
  QUALITY_COLOR_GOOD = "constantColorFps"
  QUALITY_COLOR_OKAY = "qualityColorOkay"
  QUALITY_COLOR_POOR = "qualityColorPoor"

  paramsList = ["fps", "ping", "pl", "sid"]
  objIdPrefix = "status_text_"

  mainSceneObjects = {}
  loadingSceneObjects = {}
}

fpsDrawer.init <- function init()
{
  ::subscribe_handler(this)
}

fpsDrawer.updateStatus <- function updateStatus(fps, ping, packetLoss, sessionId)
{
  local objects = getCurSceneObjects()
  if (!objects)
    return

  checkVisibility(objects)
  updateTexts(objects, fps, ping, packetLoss, sessionId)
}

fpsDrawer.getCurSceneObjects <- function getCurSceneObjects()
{
  local guiScene = ::get_cur_gui_scene()
  if (!guiScene)
    return null

  local objects = mainSceneObjects
  if (!guiScene.isEqual(::get_main_gui_scene()))
    objects = loadingSceneObjects

  if (!validateObjects(objects, guiScene))
    return null

  return objects
}

fpsDrawer.validateObjects <- function validateObjects(objects, guiScene)
{
  if (::checkObj(::getTblValue(paramsList[0], objects)))
    return true

  local holderObj = guiScene["status_texts_holder"]
  if (!::checkObj(holderObj))
    return false

  foreach(param in paramsList)
    objects[param] <- holderObj.findObject(objIdPrefix + param)
  objects.show <- true
  return true
}

fpsDrawer.updateTexts <- function updateTexts(objects, fps, ping, pl, sessionId) //validate objects before calling this
{
  fps = (fps + 0.5).tointeger();
  local fpsText = ""
  if ((::is_dev_version || (!isPlatformSony && !isPlatformXboxOne && !::is_platform_android)) && fps < 10000 && fps > 0)
    fpsText = ::colorize(getFpsColor(fps), ::format("FPS: %d", fps))
  objects.fps.setValue(fpsText)

  local pingText = ""
  local plText = ""
  local sidText = ""
  if (ping >= 0)
  {
    pingText = ::colorize(getPingColor(ping), "Ping: " + ping)
    plText = ::colorize(getPacketlossColor(pl), "PL: " + pl + "%")
    sidText = sessionId
  }
  objects.ping.setValue(pingText)
  objects.pl.setValue(plText)
  objects.sid.setValue(sidText)
}

fpsDrawer.getFpsColor <- function getFpsColor(fps)
{
  return "constantColorFps";
}

fpsDrawer.getPingColor <- function getPingColor(ping)
{
  if (ping <= 50)
    return QUALITY_COLOR_EPIC
  else if (ping <= 100)
    return QUALITY_COLOR_GOOD
  else if (ping <= 300)
    return QUALITY_COLOR_OKAY
  return QUALITY_COLOR_POOR
}

fpsDrawer.getPacketlossColor <- function getPacketlossColor(pl)
{
  if (pl <= 1)
    return QUALITY_COLOR_EPIC
  else if (pl <= 10)
    return QUALITY_COLOR_GOOD
  else if (pl <= 20)
    return QUALITY_COLOR_OKAY
  return QUALITY_COLOR_POOR
}

fpsDrawer.checkVisibility <- function checkVisibility(objects)
{
  local show = ::is_hud_visible()
  if (objects.show == show)
    return

  foreach(param in paramsList)
    objects[param].show(show)
  objects.show = show
}

fpsDrawer.onEventShowHud <- function onEventShowHud(p)
{
  local objects = getCurSceneObjects()
  if (objects)
    checkVisibility(objects)
}

::fpsDrawer.init()
