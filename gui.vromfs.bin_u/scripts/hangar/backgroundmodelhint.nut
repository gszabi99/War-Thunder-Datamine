from "%scripts/dagui_natives.nut" import is_mouse_last_time_used
from "%scripts/dagui_library.nut" import *
from "app" import isAppActive

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe } = require("eventbus")
let { endsWith } = require("%sqstd/string.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { resetTimeout, clearTimer } = require("dagor.workcycle")
let { hangar_get_current_unit_name } = require("hangar")
let { getWeaponParamsByWeaponBlkPath } = require("%scripts/weaponry/weaponryPresets.nut")
let { SINGLE_WEAPON, MODIFICATION } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getBulletSetNameByBulletName } = require("%scripts/weaponry/bulletsInfo.nut")

const DELAYED_SHOW_HINT_SEC = 0.3

let defData = {
  isVisible = false
  needShow = false
  needUpdate = false
  obj = null
  viewData = null
}

function fillSecondaryWeaponHint(obj, unitName, weaponBlkName, presetName) {
  let weapon = getWeaponParamsByWeaponBlkPath(unitName, weaponBlkName)
  if (weapon == null) {
    obj.show(false)
    return
  }
  if (presetName == "")
    presetName = weapon.presetId
  SINGLE_WEAPON.fillTooltip(obj, {}, unitName,
    { blkPath = weaponBlkName, tType = weapon.trigger, presetName = presetName })
  obj.width = "1@bulletTooltipCardWidth"
  obj.show(true)
}

function fillBulletHint(obj, unitName, bulletName) {
  let unit = getAircraftByName(unitName)
  if (unit == null) {
    obj.show(false)
    return
  }
  let bulletSetName = getBulletSetNameByBulletName(unit, bulletName)
  if (bulletSetName == null) {
    obj.show(false)
    return
  }
  MODIFICATION.fillTooltip(obj, {}, unitName, { modName = bulletSetName })
  obj.width = "1@bulletTooltipCardWidth"
  obj.show(true)
}

function fillWeaponsHint(obj, viewData) {
  let { unitName, weaponName, presetName } = viewData
  if (unitName == "") {
    obj.show(false)
    return
  }
  if (endsWith(weaponName, ".blk"))
    fillSecondaryWeaponHint(obj, unitName, weaponName, presetName)
  else
    fillBulletHint(obj, unitName, weaponName)
}

let hintsDataById = {
  clickToView = {
    objId = "click_to_view_hint"
  }.__update(defData)
  weaponsHint = {
    objId = "custom_hint"
    updateObjData = fillWeaponsHint
  }.__update(defData)
}

local screen = [ 0, 0 ]
local unsafe = [ 0, 0 ]
local offset = [ 0, 0 ]

function initBackgroundModelHint(handler) {
  let obj = handler.scene.findObject("hangar_hint")
  if (!obj?.isValid())
    return
  let cursorOffset = handler.guiScene.calcString("22@dp", null)
  screen = [ screen_width(), screen_height() ]
  unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
  offset = [ cursorOffset, cursorOffset ]
  obj.setUserData(handler)
}

function getHintObj(hintData) {
  let { obj, objId } = hintData
  if (obj?.isValid())
    return obj
  let handler = handlersManager.getActiveBaseHandler()
  if (!handler)
    return null
  let res = handler.scene.findObject(objId)
  return res?.isValid() ? res : null
}


function placeBackgroundModelHint(obj) {
  if (hintsDataById.findvalue(@(v) v.needShow) == null)
    return

  let cursorPos = get_dagui_mouse_cursor_pos_RC()
  let size = obj.getSize()
  obj.left = clamp(cursorPos[0] + offset[0], unsafe[0], max(unsafe[0], screen[0] - unsafe[0] - size[0])).tointeger()
  obj.top = clamp(cursorPos[1] + offset[1], unsafe[1], max(unsafe[1], screen[1] - unsafe[1] - size[1])).tointeger()
}

function showHint() {
  let hintDataToShow = hintsDataById.findvalue(@(v) v.isVisible)
    ?? hintsDataById.findvalue(@(v) v.needShow)
  if (hintDataToShow == null)
    return

  let hintObj = getHintObj(hintDataToShow)
  if (!hintObj)
    return

  let { updateObjData = @(obj, _viewData) obj.show(true), viewData } = hintDataToShow
  hintDataToShow.obj = hintObj
  hintDataToShow.isVisible = true
  hintDataToShow.needUpdate = false
  updateObjData(hintObj, viewData)
  placeBackgroundModelHint(hintObj.getParent())
}

function startHintTimer() {
  if (hintsDataById.findvalue(@(v) v.isVisible && !v.needUpdate)) 
    return
  resetTimeout(DELAYED_SHOW_HINT_SEC, showHint)
}

function hideSingleHint(hintData) {
  if (!hintData.needShow)
    return
  hintData.isVisible = false
  hintData.needShow = false
  hintData.needUpdate = false
  getHintObj(hintData)?.show(false)
  hintData.obj = null
}

function hideAllHints() {
  clearTimer(showHint)
  hintsDataById.each(hideSingleHint)
}

function hideHintAndCheckShowAnother(hintData) {
  hideSingleHint(hintData)
  if (hintsDataById.findvalue(@(v) v.needShow))
    startHintTimer()
}

function showBackgroundModelHint(params) {
  let { isHovered = false } = params
  let { clickToView } = hintsDataById
  if (!isHovered) {
    hideHintAndCheckShowAnother(clickToView)
    return
  }

  if (!showConsoleButtons.get() || is_mouse_last_time_used()) 
    return

  clickToView.needShow = true
  startHintTimer()
}

function updateBackgroundModelHint(obj) {
  if (!isAppActive()) {
    hideAllHints()
    return
  }

  placeBackgroundModelHint(obj)
}

eventbus_subscribe("backgroundHangarVehicleHoverChanged", showBackgroundModelHint)

function showWeaponTooltip(params) {
  let { weaponsHint } = hintsDataById
  weaponsHint.viewData = {
    unitName = hangar_get_current_unit_name()
    weaponName = params.name
    presetName = params.presetName
  }
  if (weaponsHint.isVisible) 
    weaponsHint.needUpdate = true
  weaponsHint.needShow = true
  startHintTimer()
}

eventbus_subscribe("focus_demonstrated_shell", showWeaponTooltip)
eventbus_subscribe("unfocus_demonstrated_shell", @(_) hideHintAndCheckShowAnother(hintsDataById.weaponsHint))

addListenersWithoutEnv({
  ActiveHandlersChanged = @(_p) hideAllHints()
  HangarModelLoading = @(_p) hideAllHints()
})

return {
  initBackgroundModelHint
  updateBackgroundModelHint
}
