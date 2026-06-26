from "%scripts/dagui_library.nut" import *
from "app" import isAppActive

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { endsWith } = require("%sqstd/string.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { resetTimeout, clearTimer } = require("dagor.workcycle")
let { hangar_get_current_unit_name } = require("hangar")
let { getWeaponParamsByWeaponBlkPath } = require("%scripts/weaponry/weaponryPresets.nut")
let { SINGLE_WEAPON, MODIFICATION, SINGLE_BULLET } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getBulletSetNameByBulletName, getBulletsSetData, getBulletsSearchName,
  getModificationBulletsEffect
} = require("%scripts/weaponry/bulletsInfo.nut")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let { openModalInfo, destroyModalInfo, getModalInfoByUnitId, isUseGamePad
} = require("%scripts/modalInfo/modalInfo.nut")
let { delayedTooltipOnHover } = require("%scripts/utils/delayedTooltip.nut")
let { parse_json } = require("json")

let shellFocusedInHangar = Watched("")

const DELAYED_SHOW_HINT_SEC = 0.3

let defData = {
  isVisible = false
  needShow = false
  needUpdate = false
  obj = null
  viewData = null
}

function isShellFocusedInHangar(shellName) {
  if (shellFocusedInHangar.get() == "")
    return false
  return shellFocusedInHangar.get() == shellName
}

function openPresetWndForShell(obj) {
  destroyModalInfo()
  let tooltipId = obj?.tooltipId ?? ""
  if (tooltipId == "")
    return
  let params = parse_json(tooltipId)
  let presetName = params?.presetName
  if (presetName == null)
    return
  eventbus_send("click_demonstrated_shell", { presetName })
}

function openDelayedOrModalTooltip(obj, tooltipProvider, unitName, params, isCursorInBoundsOptional, getTooltipIdFn) {
  let parentObj = obj.getParent()
  parentObj.tooltipId = getTooltipIdFn()
  if (isUseGamePad()) {
    delayedTooltipOnHover(parentObj, isCursorInBoundsOptional)
    return
  }
  let handler = handlersManager.getActiveBaseHandler()
  openModalInfo(obj, handler, tooltipProvider, unitName, params, null, isCursorInBoundsOptional)
}

function fillSecondaryWeaponHint(obj, unitName, weaponBlkName, presetName) {
  let weapon = getWeaponParamsByWeaponBlkPath(unitName, weaponBlkName)
  if (weapon == null) {
    obj.show(false)
    return
  }
  if (presetName == "")
    presetName = weapon.presetId
  let params = { blkPath = weaponBlkName, tType = weapon.trigger, presetName = presetName }
  let isCursorInBoundsOptional = @() isShellFocusedInHangar(weaponBlkName)
  openDelayedOrModalTooltip(obj, SINGLE_WEAPON, unitName, params, isCursorInBoundsOptional,
    @() SINGLE_WEAPON.getTooltipId(unitName, params))
  obj.show(true)
}

function fillBulletHint(obj, unitName, bulletName, bulletType) {
  let unit = getAircraftByName(unitName)
  if (unit == null) {
    obj.show(false)
    return
  }

  let ammoType = bulletName != "" ? bulletName : bulletType
  let bulletSetName = getBulletSetNameByBulletName(unit, bulletName)
  let modName = bulletSetName ?? ammoType
  let bulletsSet = getBulletsSetData(unit, modName)
  if (bulletsSet == null) {
    obj.show(false)
    return
  }
  let isBulletBelt = (bulletsSet?.isBulletBelt ?? false)
    && ((bulletsSet?.bulletDataByType.len() ?? 0) > 1)
  let isCursorInBoundsOptional = @() isShellFocusedInHangar(bulletName)
  if (!isBulletBelt) {
    let params = { modName = bulletSetName }
    params.__update({ forceHideActionText = true })
    openDelayedOrModalTooltip(obj, MODIFICATION, unitName, params, isCursorInBoundsOptional,
      @() MODIFICATION.getTooltipId(unitName, bulletSetName, params))
  }
  else {
    let bSet = bulletsSet.__merge({ bullets = [bulletType] },
      bulletsSet.bulletDataByType?[bulletType] ?? {})

    let searchName = getBulletsSearchName(unit, modName)
    let useDefaultBullet = searchName != modName
    let bulletParameters = calculate_tank_bullet_parameters(unit.name,
      useDefaultBullet ? bulletsSet.weaponBlkName : getModificationBulletsEffect(searchName),
      useDefaultBullet, false)

    let bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)
    let params = {
      bulletName = bulletType
      modName = bulletName
      bSet
      bulletParams
    }
    params.__update({ forceHideActionText = true })
    openDelayedOrModalTooltip(obj, SINGLE_BULLET, unitName, params, isCursorInBoundsOptional,
      @() SINGLE_BULLET.getTooltipId(unitName, bulletType, params))
  }
  obj.show(true)
}

function fillWeaponsHint(obj, viewData) {
  let { unitName, weaponName, presetName, bulletType } = viewData
  if (unitName == "") {
    obj.show(false)
    return
  }
  if (endsWith(weaponName, ".blk"))
    fillSecondaryWeaponHint(obj, unitName, weaponName, presetName)
  else
    fillBulletHint(obj, unitName, weaponName, bulletType)
}

let hintsDataById = {
  clickToView = {
    objId = "click_to_view_hint"
  }.__update(defData)
  weaponsHint = {
    objId = "custom_hint"
    updateObjData = fillWeaponsHint
    isModalTooltip = true
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
  let hintDataToShow = hintsDataById.findvalue(@(v) v.needShow)
  if (hintDataToShow == null)
    return

  let { isModalTooltip = false } = hintDataToShow

  let cursorPos = get_dagui_mouse_cursor_pos_RC()
  let size = isModalTooltip ? [2*offset[0], 2*offset[1]] : obj.getSize()
  let [posX, posY] = isModalTooltip
    ? [cursorPos[0] - offset[0], cursorPos[1] - offset[1]]
    : [cursorPos[0] + offset[0], cursorPos[1] + offset[1]]

  obj.left = clamp(posX, unsafe[0], max(unsafe[0], screen[0] - unsafe[0] - size[0])).tointeger()
  obj.top = clamp(posY, unsafe[1], max(unsafe[1], screen[1] - unsafe[1] - size[1])).tointeger()
  obj["size"] = isModalTooltip ? $"{size[0]},{size[1]}" : "w,h"
}

function showHint() {
  let hintDataToShow = hintsDataById.findvalue(@(v) v.isVisible)
    ?? hintsDataById.findvalue(@(v) v.needShow)
  if (hintDataToShow == null)
    return

  let hintObj = getHintObj(hintDataToShow)
  if (!hintObj?.isValid())
    return

  let { updateObjData = @(obj, _viewData) obj.show(true), viewData } = hintDataToShow
  hintDataToShow.obj = hintObj
  hintDataToShow.isVisible = true
  hintDataToShow.needUpdate = false
  let handler = handlersManager.getActiveBaseHandler()
  let parentObj = !!handler ? handler.scene.findObject("hangar_hint") : hintObj.getParent()
  placeBackgroundModelHint(parentObj)
  updateObjData(hintObj, viewData)
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
  hintData.obj = null
  shellFocusedInHangar.set("")
  let hintObj = getHintObj(hintData)
  if (!hintObj?.isValid())
    return
  hintObj.show(false)
  if (hintData?.isModalTooltip)
    hintObj.getParent().tooltipId = ""
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

  if (!isUseGamePad()) 
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
  let unitName = hangar_get_current_unit_name()

  let shownModalInfo = getModalInfoByUnitId(unitName)
  if (shownModalInfo) {
    if (isUseGamePad())
      return
    destroyModalInfo()
  }

  let { weaponsHint } = hintsDataById
  weaponsHint.viewData = {
    unitName
    weaponName = params.name
    presetName = params.presetName
    bulletType = params.bulletType
  }
  if (weaponsHint.isVisible) 
    weaponsHint.needUpdate = true

  weaponsHint.needShow = true
  shellFocusedInHangar.set(params.name)
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
  openPresetWndForShell
}
