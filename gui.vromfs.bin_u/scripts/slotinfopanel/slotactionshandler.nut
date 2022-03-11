let protectionAnalysis = require("scripts/dmViewer/protectionAnalysis.nut")
let { slotInfoPanelButtons } = require("scripts/slotInfoPanel/slotInfoPanelButtons.nut")
let { getShowedUnit, getShowedUnitName } = require("scripts/slotbar/playerCurUnit.nut")

let slotActionsHandler = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/slotInfoPanel/slotInfoPanelActions.blk"

  function initScreen()
  {
    ::dmViewer.init(this)

    //Must be before replace fill tabs
    let buttonsPlace = scene.findObject("buttons_place")
    if (::check_obj(buttonsPlace))
    {
      let data = "".join(slotInfoPanelButtons.value.map(@(view) ::handyman.renderCached("%gui/commonParts/button", view)))
      guiScene.replaceContentFromText(buttonsPlace, data, data.len(), this)
    }

    // Fixes DM selector being locked after battle.
    ::dmViewer.update()
  }

  function getCurShowUnitName()
  {
    return getShowedUnitName()
  }

  function getCurShowUnit()
  {
    return getShowedUnit()
  }

  function onUnitInfoTestDrive()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    ::queues.checkAndStart(@() ::gui_start_testflight({ unit }), null, "isCanNewflight")
  }

  function onAirInfoWeapons()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    ::open_weapons_for_unit(unit)
  }

  function onProtectionAnalysis()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return

    checkedCrewModify(
      @() ::handlersManager.animatedSwitchScene(@() protectionAnalysis.open(unit)))
  }

  function onShowExternalDmPartsChange(obj)
  {
    if (::check_obj(obj))
      ::dmViewer.showExternalPartsArmor(obj.getValue())
  }

  function onShowHiddenXrayPartsChange(obj)
  {
    if (::check_obj(obj))
      ::dmViewer.showExternalPartsXray(obj.getValue())
  }

  function onAirInfoToggleDMViewer(obj)
  {
    ::dmViewer.toggle(obj.getValue())
  }

  function onDMViewerHintTimer(obj, dt)
  {
    ::dmViewer.placeHint(obj)
  }

  function updateButtons()
  {
    let unit = getCurShowUnit()
    if (!unit)
      return null

    updateTestDriveButtonText(unit)
    updateWeaponryDiscounts(unit)
  }

  function onSceneActivate(show)
  {
    if (show && isSceneForceHidden)
      return

    if (show)
      ::dmViewer.init(this)

    base.onSceneActivate(show)
  }

  function onEventHangarModelLoading(params)
  {
    doWhenActiveOnce("updateButtons")
  }

  function onEventCrewChanged(params)
  {
    doWhenActiveOnce("updateButtons")
  }

  function updateTestDriveButtonText(unit)
  {
    let obj = scene.findObject("btnTestdrive")
    if (!::check_obj(obj))
      return

    obj.setValue(unit.unitType.getTestFlightText())
  }

  function updateWeaponryDiscounts(unit)
  {
    let discount = unit ? ::get_max_weaponry_discount_by_unitName(unit.name) : 0
    let discountObj = scene.findObject("btnAirInfoWeaponry_discount")
    ::showCurBonus(discountObj, discount, "mods", true, true)
    if (::check_obj(discountObj))
      discountObj.show(discount > 0)
  }
}

::gui_handlers.SlotActionsHandler <- slotActionsHandler

return {
  open = function(parentScene) {
    if (!::check_obj(parentScene))
      return null
    let containerObj = parentScene.findObject("slot_info")
    if (!::check_obj(containerObj))
      return null

    ::handlersManager.loadHandler(slotActionsHandler, { scene = containerObj })
  }
}
