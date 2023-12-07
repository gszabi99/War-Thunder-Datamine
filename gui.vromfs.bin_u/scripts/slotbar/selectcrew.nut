//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { toPixels } = require("%sqDagui/daguiUtil.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getSafearea } = require("%scripts/options/safeAreaMenu.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { get_gui_balance } = require("%scripts/user/balance.nut")
let { buildUnitSlot, fillUnitSlotTimers, getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { getCrewsListByCountry, isUnitInSlotbar, getBestTrainedCrewIdxForUnit, getFirstEmptyCrewSlot
} = require("%scripts/slotbar/slotbarState.nut")

::gui_start_selecting_crew <- function gui_start_selecting_crew(config) {
  if (CrewTakeUnitProcess.safeInterrupt())
    handlersManager.destroyPrevHandlerAndLoadNew(gui_handlers.SelectCrew, config)
}

let function getObjPosInSafeArea(obj) {
  let pos = obj.getPosRC()
  let size = obj.getSize()
  let safeArea = getSafearea()
  let screen = [screen_width(), screen_height()]
  local border = safeArea.map(@(value, idx) (screen[idx] * (1.0 - value) / 2).tointeger())
  return pos.map(@(val, idx) clamp(val, border[idx], screen[idx] - border[idx] - size[idx]))
}

gui_handlers.SelectCrew <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/shop/shopTakeAircraft.blk"

  unit = null
  unitObj = null
  cellClass = "slotbarClone"
  getEdiffFunc = null
  afterCloseFunc = null
  afterSuccessFunc = null

  useTutorial = false

  restrictCancel = false

  country = ""
  messageText = ""

  takeCrewIdInCountry = -1
  isNewUnit = false

  isSelectByGroups = false

  function initScreen() {
    if (!this.unit || !this.unit.isUsable() || this.isHandlerUnitInSlotbar()) {
      this.goBack()
      return
    }

    this.country = getUnitCountry(this.unit)
    this.checkAvailableCrew()

    this.guiScene.setUpdatesEnabled(false, false)

    local tdClone = null
    if (this.unitObj != null) {
      let tdObj = this.unitObj.getParent()
      let tdPos = getObjPosInSafeArea(tdObj)

      gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

      tdClone = tdObj.getClone(this.scene, this)
      tdClone.pos = tdPos[0] + ", " + tdPos[1]
      tdClone["class"] = this.cellClass
      tdClone.position = "root"
    } else {
      local icon = buildUnitSlot(this.unit.name, this.unit, {})
      this.guiScene.appendWithBlk(this.scene, icon, this)
      tdClone = this.scene.findObject($"td_{this.unit.name}")
      tdClone.position = "absolute"
      tdClone.pos = "0.5sw - w/2, 0.5sh - h"
    }

    fillUnitSlotTimers(tdClone.findObject(this.unit.name), this.unit)
    if (!hasFeature("GlobalShowBattleRating") && hasFeature("SlotbarShowBattleRating")) {
      let rankObj = tdClone.findObject("rank_text")
      if (checkObj(rankObj)) {
        let unitRankText = getUnitSlotRankText(this.unit, null, true, this.getCurrentEdiff())
        rankObj.setValue(unitRankText)
      }
    }

    let bDiv = tdClone.findObject("air_item_bottom_buttons")
    if (checkObj(bDiv))
      this.guiScene.destroyElement(bDiv)

    let markerObj = tdClone.findObject("unlockMarker")
    if (markerObj?.isValid())
      this.guiScene.destroyElement(markerObj)

    let crew = getCrewsListByCountry(this.country)?[this.takeCrewIdInCountry]
    this.createSlotbar(
      {
        crewId = crew?.id
        shouldSelectCrewRecruit =  this.takeCrewIdInCountry > 0 && !crew
        singleCountry = this.country
        hasActions = false
        showNewSlot = true
        showEmptySlot = true,
        needActionsWithEmptyCrews = false
        unitForSpecType = this.unit,
        alwaysShowBorder = true
        hasExtraInfoBlock = true
        slotbarBehavior = "posNavigator"
        needFullSlotBlock = true

        applySlotSelectionOverride = @(_, __) this.onChangeUnit()
        onSlotDblClick = Callback(this.onApplyCrew, this)
        onSlotActivate = Callback(this.onApplyCrew, this)
      },
      "take-aircraft-slotbar")

    this.onChangeUnit()

    let legendObj = this.fillLegendData()

    move_mouse_on_child_by_value(this.slotbarWeak && this.slotbarWeak.getCurrentAirsTable())

    let textObj = this.scene.findObject("take-aircraft-text")
    textObj.setValue(this.messageText)

    this.guiScene.setUpdatesEnabled(true, true)

    this.updateObjectsPositions(tdClone, legendObj, textObj)
    this.checkUseTutorial()
  }

  createSlotbarHandler = @(params) this.isSelectByGroups
    ? slotbarWidget.create(params)
    : gui_handlers.SlotbarWidget.create(params)

  function updateObjectsPositions(tdClone, legendObj, headerObj) {
    let rootSize = this.guiScene.getRoot().getSize()
    let sh = rootSize[1]
    let bh = toPixels(this.guiScene, "@bh")
    let interval = toPixels(this.guiScene, "@itemsIntervalBig")

    //count position by visual card obj. real td is higher and wider than a card.
    let visTdObj = tdClone.childrenCount() ? tdClone.getChild(0) : tdClone
    let tdPos = visTdObj.getPosRC()
    let tdSize = visTdObj.getSize()

    //top and bottom of already positioned items
    local top = tdPos[1]
    local bottom = tdPos[1] + tdSize[1]

    //place slotbar
    let sbObj = this.scene.findObject("slotbar_with_buttons")
    let sbSize = sbObj.getSize()
    let isSlotbarOnTop = bottom + interval + sbSize[1] > sh - bh
    local sbPosY = 0
    if (isSlotbarOnTop) {
      sbPosY = top - interval - sbSize[1]
      top = sbPosY
    }
    else {
      sbPosY = bottom + interval
      bottom = sbPosY + sbSize[1]
    }
    sbObj.top = sbPosY

    //place legend
    if (checkObj(legendObj)) {
      let legendSize = legendObj.getSize()

      //try to put legend near unit td, but below slotbar when possible
      local isNearTd = false
      local bottomNoTd = bottom
      if (tdPos[1] + tdSize[1] == bottom) {
        bottomNoTd = tdPos[1] - interval
        isNearTd = true
      }

      let isLegendBottom = bottomNoTd + interval + legendSize[1] <= sh - bh
      local legendPosY = 0
      if (isLegendBottom)
        legendPosY = bottomNoTd + interval
      else {
        isNearTd = tdPos[1] == top
        let topNoTd = isNearTd ? tdPos[1] + tdSize[1] + interval : top
        legendPosY = topNoTd - interval - legendSize[1]
        top = min(legendPosY, top)
      }

      legendObj.top = legendPosY

      if (isNearTd) { //else centered.
        let sw = rootSize[0]
        let bw = toPixels(this.guiScene, "@bw")
        local legendPosX = tdPos[0] + tdSize[0] + interval
        if (legendPosX + legendSize[0] > sw - bw)
          legendPosX = tdPos[0] - interval - legendSize[0]
        legendObj.left = legendPosX
      }
    }

    //place headerMessage
    let headerPosY = top - interval - headerObj.getSize()[1]
    headerObj.top = headerPosY
  }

  function checkAvailableCrew() {
    if (this.takeCrewIdInCountry >= 0)
      return

    this.takeCrewIdInCountry = getBestTrainedCrewIdxForUnit(this.unit, true)
    if (this.takeCrewIdInCountry >= 0)
      return

    this.takeCrewIdInCountry = getFirstEmptyCrewSlot()
    if (this.takeCrewIdInCountry >= 0)
      return

    let costTable = ::get_crew_slot_cost(this.country)
    if (!costTable)
      return

    let cost = Cost(costTable.cost, costTable.costGold)
    if (cost.gold > 0)
      return

    this.takeCrewIdInCountry = cost <= get_gui_balance() ? ::get_crew_count(this.country) : this.takeCrewIdInCountry
  }

  function getCurrentEdiff() {
    return u.isFunction(this.getEdiffFunc) ? this.getEdiffFunc() : ::get_current_ediff()
  }

  function getTakeAirCost() {
    return this.isSelectByGroups
      ? Cost()
      : CrewTakeUnitProcess.getProcessCost(
          this.getCurCrew(),
          this.unit
        )
  }

  function onChangeUnit() {
    this.takeCrewIdInCountry = this.getCurCrew()?.idInCountry ?? ::get_crew_count(this.country)
    this.updateButtons()
  }

  function updateButtons() {
    placePriceTextToButton(this.scene, "btn_set_air", loc("mainmenu/btnTakeAircraft"), this.getTakeAirCost())
  }

  function onEventOnlineShopPurchaseSuccessful(_p) {
    this.updateButtons()
  }

  function checkUseTutorial() {
    if (this.useTutorial)
      this.startTutorial()
  }

  function startTutorial() {
    let playerBalance = Cost()
    let playerInfo = ::get_profile_info()
    playerBalance.wp = playerInfo.balance
    playerBalance.gold = playerInfo.gold

    this.restrictCancel = this.getTakeAirCost() < playerBalance
    this.showSceneBtn("btn_set_cancel", !this.restrictCancel)

    this.guiScene.applyPendingChanges(false)
    let steps = [
      {
        obj = this.getSlotbar() && this.getSlotbar().getBoxOfUnits()
        text = loc("help/takeAircraft", { unitName = getUnitName(this.unit) })
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = "btn_set_air"
        text = loc("help/pressOnReady")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }
    ]

    ::gui_modal_tutor(steps, this)
  }

  function onApply() {
    this.onApplyCrew(this.getCurCrew())
  }

  function onApplyCrew(crew) {
    let onFinishCb = Callback(this.onTakeProcessFinish, this)
    if (this.isSelectByGroups)
      slotbarPresets.setUnit({
        crew = crew
        unit = this.unit
        onFinishCb = onFinishCb
      })
    else
      CrewTakeUnitProcess(crew, this.unit, onFinishCb)
  }

  function onTakeProcessFinish(isSuccess) {
    if (!isSuccess)
      return

    if (this.isNewUnit) {
      sendBqEvent("CLIENT_GAMEPLAY_1", "choosed_crew_for_new_unit", {
        unit = this.unit.name
        crew = this.getCurCrew()?.id
      })
    }
    if (this.afterSuccessFunc)
      this.afterSuccessFunc()
    this.goBack()
  }

  function onEventSetInQueue(_params) {
    let reqMoneyMsg = this.scene.findObject("need_money")
    if (checkObj(reqMoneyMsg))
      this.guiScene.destroyObject(reqMoneyMsg)

    let noMoneyMsg = this.scene.findObject("no_money")
    if (checkObj(noMoneyMsg))
      this.guiScene.destroyObject(noMoneyMsg)

    this.goBack()
  }

  function onTakeCancel() {
    if (this.restrictCancel)
      return

    this.goBack()
  }

  function addLegendData(result, specType) {
    foreach (data in result)
      if (specType == data.specType)
        return

    result.append({
      id = specType.specName,
      specType = specType,
      imagePath = specType.trainedIcon,
      locId = loc("crew/trained") + loc("ui/colon") + specType.getName()
    })
  }

  function fillLegendData() {
    let legendData = []
    foreach (_idx, crew in getCrewsListByCountry(this.country)) {
      let specType = ::g_crew_spec_type.getTypeByCode(::g_crew_spec_type.getTrainedSpecCode(crew, this.unit))
      this.addLegendData(legendData, specType)
    }

    if (u.isEmpty(legendData))
      return null

    legendData.sort(function(a, b) {
      if (a.specType.code != b.specType.code)
        return a.specType.code > b.specType.code ? 1 : -1
      return 0
    })

    let view = {
      header = loc("mainmenu/legend") + loc("ui/colon") + colorize("userlogColoredText", getUnitName(this.unit, false))
      haveLegend = legendData.len() > 0
      legendData = legendData
    }

    let obj = this.scene.findObject("qualification_legend")
    if (!checkObj(obj))
      return null

    let blk = handyman.renderCached("%gui/slotbar/legend_block.tpl", view)
    this.guiScene.replaceContentFromText(obj, blk, blk.len(), this)

    return obj
  }

  function onDestroy() {
    if (this.afterCloseFunc)
      this.afterCloseFunc()
  }

  function onUnitMainFunc(_obj) {}
  function onUnitMainFuncBtnUnHover() {}
  onUnitMarkerClick = @() null

  function isHandlerUnitInSlotbar() {
    return !this.isSelectByGroups && isUnitInSlotbar(this.unit)
  }
}
