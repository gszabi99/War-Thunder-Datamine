from "%scripts/dagui_library.nut" import *
from "%appGlobals/hud/hudMessageStacks.nut" import hintMessagesHeight, playerDamage, tankNotifications, shipNotifications

let hintMessageStacks = freeze([playerDamage, tankNotifications, shipNotifications])

const KILL_FEED_WIDTH = "0.5@shHud"
const HINT_MESSAGES_INDENT = "0.2@shHud"

const infantryKillFeedPlace = {
  height = "0.2@shHud"
  gap = "1@hudInfantryActionBarHeight + 0.04@shHud + 1@hudInfantryWeaponryMargin + 0.19@shHud + 0.03@shHud"
}

let getObjBox = @(obj) { pos = obj.getPosRC(), size = obj.getSize() }
let getBottom = @(box) box.pos[1] + box.size[1]


function getKillFeedBox(hud) {
  if (hud?.killFeedPlace == null)
    return null
  let { height, gap, aboveId = null } = hud.killFeedPlace
  let scene = getObjBox(hud.scene)
  let above = aboveId == null ? null : hud.scene.findObject(aboveId)
  if (aboveId != null && !checkObj(above))
    return null
  let size = [to_pixels(KILL_FEED_WIDTH), to_pixels(height)]
  let aboveTop = above == null ? getBottom(scene)
    : above.getFinalProp("display") != "hide" ? above.getPosRC()[1]
    : getBottom(getObjBox(above.getParent()))
  let bottom = aboveTop - to_pixels(gap)
  return { pos = [scene.pos[0] + scene.size[0] - size[0], bottom - size[1]], size }
}


function getHintMessagesBox(hud) {
  let aboveObj = hud.scene.findObject("actionbar_hints_nest")
  if (!checkObj(aboveObj))
    return null
  let hasLines = hintMessageStacks.findvalue(@(s) s.entries.get().len() > 0) != null
  let height = hasLines ? hintMessagesHeight.get() : 0
  aboveObj["margin-bottom"] = height
  hud.guiScene.applyPendingChanges(false)
  let column = hud.getWidgetParams("hud_hints_nest")
  let indent = to_pixels(HINT_MESSAGES_INDENT)
  return {
    pos = [column.pos[0] + indent, getBottom(getObjBox(aboveObj))]
    size = [column.size[0] - indent, height]
  }
}

let getMpScoreBox = @(hud) (hud?.hasMpScore ?? false) ? getObjBox(hud.scene) : null


let dargHudLayers = freeze([
  { screen = "hud.killFeed", getBox = getKillFeedBox }
  { screen = "hud.hintMessages", getBox = getHintMessagesBox }
  { screen = "hud.mpScore", getBox = getMpScoreBox }
])


function getDargLayerWidgets(hud) {
  let res = []
  foreach (layer in dargHudLayers) {
    let transform = layer.getBox(hud)
    if (transform != null)
      res.append({ widgetId = DargWidgets.SCREEN, screen = layer.screen, transform })
  }
  return res
}


let mkMpScoreWidget = @(lineY) { widgetId = DargWidgets.SCREEN, screen = "mpScore",
  transform = { pos = [0, to_pixels(lineY)], size = [to_pixels("sw"), 0] } }

return freeze({
  getDargLayerWidgets
  infantryKillFeedPlace
  mkMpScoreWidget
})
