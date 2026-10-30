from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/weaponry/unitWeaponsHandler.nut" import unitWeaponsHandler
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameModeEdiff
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function getLoadedAmmoText(ammo) {
  let { weapons, mainGun, hasRoundInGun } = ammo
  return " \u00B7 ".join(weapons.filter(@(w) w.totalShells > 0).map(@(w) hasRoundInGun && w == mainGun
    ? $"{w.shells - w.loadedShells}+{w.loadedShells}/{w.totalShells}"
    : $"{w.shells}/{w.totalShells}"))
}

function getLoadedAmmoTooltip(ammo) {
  let text = loc("mainmenu/btnShowLoadedAmmo/tooltip")
  if (!ammo.hasRoundInGun)
    return text
  let { shells, loadedShells } = ammo.mainGun
  return "\n".join([text, loc("mainmenu/btnShowLoadedAmmo/tooltip_gun", { rack = shells - loadedShells, loaded = loadedShells })])
}

let XrayAmmoLoadWindow = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  needVoiceChat = false
  sceneTplName = "%gui/dmViewer/xrayAmmoLoadWindow.tpl"

  unit = null
  isShowLoadedAmmo = false
  loadedAmmoText = ""
  loadedAmmoTooltip = ""
  onShowLoadedAmmoChangeFn = null

  function getSceneTplView() {
    return { isShowLoadedAmmo = this.isShowLoadedAmmo }
  }

  function initScreen() {
    let handler = handlersManager.loadHandler(unitWeaponsHandler, {
      scene = this.scene.findObject("unit_weapons_selector")
      unit = this.unit
      fixedSizeForItem = true
      needRecountWidth = false
      isTooltipOnIcon = true
      getCurrentEdiff = @() getCurrentGameModeEdiff()
    })
    this.registerSubHandler(handler)
    this.updateLoadedAmmo(this.isShowLoadedAmmo, this.loadedAmmoText, this.loadedAmmoTooltip)
    this.updateLayout()
  }

  function updateLayout() {
    if (!this.isValid())
      return
    this.guiScene.applyPendingChanges(false)
    let selectorWidth = this.scene.findObject("unit_weapons_selector").getSize()[0]
    this.scene.findObject("dmviewer_show_loaded_ammo").width = selectorWidth.tostring()
    this.guiScene.applyPendingChanges(false)
    let popupObj = this.scene.findObject("ammo_load_popup")
    let posY = -popupObj.getSize()[1] - to_pixels("1@blockInterval")
    popupObj["pos"] = $"0, {posY}"
  }

  updateLayoutDelayed = @() this.guiScene.performDelayed(this, this.updateLayout)

  onEventUnitWeaponChanged = @(_p) this.updateLayoutDelayed()
  onEventModificationChanged = @(_p) this.updateLayoutDelayed()

  function updateLoadedAmmo(isShow, text, tooltip) {
    let cbObj = this.scene.findObject("dmviewer_show_loaded_ammo")
    if (!checkObj(cbObj))
      return
    cbObj.setValue(isShow)
    cbObj.tooltip = tooltip
    let countObj = cbObj.findObject("dmviewer_loaded_ammo_count")
    countObj.setValue(text)
    countObj.overlayTextColor = isShow ? "active" : "faded"
  }

  function onShowLoadedAmmoChange(obj) {
    this.onShowLoadedAmmoChangeFn?(obj.getValue())
  }

  function close() {
    if (!this.isValid())
      return
    this.guiScene.destroyElement(this.scene.findObject("ammo_load_popup_nest"))
  }

  function isValid() {
    return base.isValid()
      && (this.scene.findObject("ammo_load_popup_nest")?.isValid() ?? false)
  }
}

register_gui_handler("XrayAmmoLoadWindow", XrayAmmoLoadWindow)

let XrayAmmoLoadWidget = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  needVoiceChat = false
  sceneTplName = "%gui/dmViewer/xrayAmmoLoadWidget.tpl"

  btnWidth = null
  onShowLoadedAmmoChangeFn = null
  popupWnd = null
  unit = null
  isShowLoadedAmmo = false
  loadedAmmoText = ""
  loadedAmmoTooltip = ""

  function getSceneTplView() {
    return { btnWidth = this.btnWidth }
  }

  initScreen = @() this.updateButton()

  function updateAmmo(unit, ammo, isShowLoadedAmmo) {
    if (this.unit != unit)
      this.closePopup()
    this.unit = unit
    this.isShowLoadedAmmo = isShowLoadedAmmo
    this.loadedAmmoText = getLoadedAmmoText(ammo)
    this.loadedAmmoTooltip = getLoadedAmmoTooltip(ammo)
    this.updateButton()
    if (this.isPopupOpen())
      this.popupWnd.updateLoadedAmmo(isShowLoadedAmmo, this.loadedAmmoText, this.loadedAmmoTooltip)
  }

  function updateButton() {
    let countObj = this.scene.findObject("ammo_load_button_count")
    if (!checkObj(countObj))
      return
    countObj.setValue(this.loadedAmmoText)
    countObj.overlayTextColor = this.isShowLoadedAmmo ? "active" : "faded"
  }

  isPopupOpen = @() this.popupWnd?.isValid() ?? false

  function onAmmoLoadBtnClick(_obj) {
    if (!this.isValid())
      return
    if (this.isPopupOpen()) {
      this.closePopup()
      return
    }
    if (this.unit == null)
      return
    this.popupWnd = handlersManager.loadHandler(XrayAmmoLoadWindow, {
      scene = this.scene.findObject("ammo_load_window_nest")
      unit = this.unit
      isShowLoadedAmmo = this.isShowLoadedAmmo
      loadedAmmoText = this.loadedAmmoText
      loadedAmmoTooltip = this.loadedAmmoTooltip
      onShowLoadedAmmoChangeFn = this.onShowLoadedAmmoChangeFn
    })
  }

  function closePopup() {
    if (this.isPopupOpen())
      this.popupWnd.close()
    this.popupWnd = null
  }
}

register_gui_handler("XrayAmmoLoadWidget", XrayAmmoLoadWidget)

return freeze({
  openXrayAmmoLoad = @(params = {}) handlersManager.loadHandler(XrayAmmoLoadWidget, params)
})