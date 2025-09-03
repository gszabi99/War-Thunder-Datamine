from "%scripts/dagui_natives.nut" import get_crew_count, get_crew_slot_cost
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let slotbarWidget = require("%scripts/slotbar/slotbarWidgetByVehiclesGroups.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { toPixels, move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getSafearea } = require("%scripts/options/safeAreaMenu.nut")
let { CrewTakeUnitProcess } = require("%scripts/crew/crewTakeUnitProcess.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { get_gui_balance } = require("%scripts/user/balance.nut")
let { buildUnitSlot, fillUnitSlotTimers, getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { getBestTrainedCrewIdxForUnit, getFirstEmptyCrewSlot } = require("%scripts/slotbar/slotbarStateData.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let fillSlotbarLegend = require("%scripts/slotbar/fillSlotbarLegend.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let slotbarBaseCfg = require("%scripts/slotbar/selectCrewSlotbarBaseCfg.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")

function getObjPosInSafeArea(obj) {
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
  dragAndDropMode = false
  canSetCurUnit = false

  function initScreen() {
    if (this.unit == null || !this.unit.isUsable()) {
      this.goBack()
      return
    }

    this.canSetCurUnit = !this.isHandlerUnitInSlotbar()

    if ((!this.canSetCurUnit && !this.dragAndDropMode) || (this.unitObj != null && !this.unitObj.isValid())) {
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
      tdClone.pos = $"{tdPos[0]}, {tdPos[1]}"
      tdClone["class"] = this.cellClass
      tdClone.position = "root"
      if (this.dragAndDropMode) {
        let shopItemObj = tdClone.getChild()
        shopItemObj.dragging = "yes"
        shopItemObj.actionOnDrag = "no"
      }
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

    let objIdsToDestroy = ["air_item_bottom_buttons", "unlockMarker"]
    if (this.dragAndDropMode)
      objIdsToDestroy.append("inServiceMark")
    objIdsToDestroy.each(function(id) {
      let obj = tdClone.findObject(id)
      if (obj?.isValid())
        this.guiScene.destroyElement(obj)
    }.bindenv(this))

    let crew = getCrewsListByCountry(this.country)?[this.takeCrewIdInCountry]
    this.createSlotbar(
      slotbarBaseCfg.__merge({
        crewId = crew?.id
        shouldSelectCrewRecruit =  this.takeCrewIdInCountry > 0 && !crew
        singleCountry = this.country
        unitForSpecType = this.unit
        selectOnHover = this.dragAndDropMode && this.canSetCurUnit
        highlightSelected = this.dragAndDropMode && !this.canSetCurUnit

        applySlotSelectionOverride = @(_, __) this.onChangeUnit()
        onSlotDblClick = Callback(this.onApplyCrew, this)
        onSlotActivate = Callback(this.onApplyCrew, this)
      }),
      "take-aircraft-slotbar")

    if (this.dragAndDropMode) {
      let curCrew = getCrewByAir(this.unit)
      let crewId = this.canSetCurUnit
        ? -1
        : (curCrew?.idInCountry ?? -1)
      this.guiScene.performDelayed(this, @() this.slotbarWeak?.selectCrew(crewId))
    }

    this.onChangeUnit()
    if (this.canSetCurUnit)
      fillSlotbarLegend(this.scene.findObject("qualification_legend"), this.unit, this)

    move_mouse_on_child_by_value(this.slotbarWeak && this.slotbarWeak.getCurrentAirsTable())

    let textObj = this.scene.findObject("take-aircraft-text")
    textObj.setValue(this.messageText)

    showObjectsByTable(this.scene, {
      set_unit_btns = !this.dragAndDropMode
      set_air_dnd_title = this.dragAndDropMode && this.canSetCurUnit
      vehicle_in_slot_msg = !this.canSetCurUnit
    })

    this.guiScene.setUpdatesEnabled(true, true)

    this.updateObjectsPositions(tdClone, textObj)
    this.checkUseTutorial()
  }

  createSlotbarHandler = @(params) this.isSelectByGroups
    ? slotbarWidget.create(params)
    : gui_handlers.SlotbarWidget.create(params)

  function updateObjectsPositions(tdClone, headerObj) {
    let rootSize = this.guiScene.getRoot().getSize()
    let sh = rootSize[1]
    let bh = toPixels(this.guiScene, "@bh")
    let interval = toPixels(this.guiScene, "@itemsIntervalBig")
    let bottomPanelHeight = toPixels(this.guiScene, "@bottomMenuPanelHeight")

    
    let visTdObj = tdClone.childrenCount() ? tdClone.getChild(0) : tdClone
    let tdPos = visTdObj.getPosRC()
    let tdSize = visTdObj.getSize()

    
    local top = tdPos[1]
    local bottom = tdPos[1] + tdSize[1]

    
    let sbObj = this.scene.findObject("slotbar_with_controls")
    let sbSize = sbObj.getSize()
    let isSlotbarOnTop = bottom + interval + sbSize[1] > sh - bh - bottomPanelHeight
    local sbPosY = 0
    if (isSlotbarOnTop) {
      sbPosY = top - interval - sbSize[1]
      top = sbPosY
    }
    else
      sbPosY = bottom + interval

    sbObj.top = sbPosY

    
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

    let costTable = get_crew_slot_cost(this.country)
    if (!costTable)
      return

    let cost = Cost(costTable.cost, costTable.costGold)
    if (cost.gold > 0)
      return

    this.takeCrewIdInCountry = cost <= get_gui_balance() ? get_crew_count(this.country) : this.takeCrewIdInCountry
  }

  function getCurrentEdiff() {
    return u.isFunction(this.getEdiffFunc) ? this.getEdiffFunc() : getCurrentGameModeEdiff()
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
    this.takeCrewIdInCountry = this.slotbarWeak.curSlotIdInCountry == -1
      ? -1
      : this.getCurCrew()?.idInCountry ?? get_crew_count(this.country)
    this.updateSelectedCrewPriceText()
  }

  onUnitCellDragStart = @(_obj) null

  function onUnitCellDrop(_obj) {
    if (this.takeCrewIdInCountry >= 0 && this.canSetCurUnit)
      this.onApply()
    this.goBack()
  }

  function updateSelectedCrewPriceText() {
    if (this.dragAndDropMode)
      this.updateDndTitle()
    else
      placePriceTextToButton(this.scene, "btn_set_air", loc("mainmenu/btnTakeAircraft"), this.getTakeAirCost())
  }

  function updateDndTitle() {
    if (this.takeCrewIdInCountry != -1)
      placePriceTextToButton(this.scene, "set_air_dnd_title", loc("mainmenu/btnTakeAircraft"), this.getTakeAirCost())
    else
      this.scene.findObject("set_air_dnd_title_text").setValue("")
  }

  function onEventOnlineShopPurchaseSuccessful(_p) {
    this.updateSelectedCrewPriceText()
  }

  function checkUseTutorial() {
    if (this.useTutorial)
      this.startTutorial()
  }

  function startTutorial() {
    let playerBalance = Cost()
    let playerInfo = getProfileInfo()
    playerBalance.wp = playerInfo.balance
    playerBalance.gold = playerInfo.gold

    this.restrictCancel = this.getTakeAirCost() < playerBalance
    showObjById("btn_set_cancel", !this.restrictCancel, this.scene)

    this.guiScene.applyPendingChanges(false)
    let steps = [
      {
        obj = this.getSlotbar() && this.getSlotbar().getBoxOfUnits()
        text = loc("help/takeAircraft", { unitName = getUnitName(this.unit) })
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        shortcut = GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = "btn_set_air"
        text = loc("help/pressOnReady")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = GAMEPAD_ENTER_SHORTCUT
      }
    ]

    gui_modal_tutor(steps, this)
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
      locId = specType.getName()
    })
  }

  function onDestroy() {
    if (this.afterCloseFunc)
      this.afterCloseFunc()
  }

  function onUnitMainFunc(_obj) {}
  function onUnitMainFuncBtnUnHover() {}
  onUnitMarkerClick = @() null
  onNewsMarkerClick = @() null
  onEventMarkerClick = @() null

  function isHandlerUnitInSlotbar() {
    return !this.isSelectByGroups && isUnitInSlotbar(this.unit)
  }
}
