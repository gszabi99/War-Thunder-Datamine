//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")

gui_handlers.WwAirfieldsList <- class extends ::BaseGuiHandler {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/airfieldObject.tpl"
  sceneBlkName = null
  airfieldBlockTplName = "%gui/worldWar/worldWarMapArmyItem.tpl"

  airfieldIdPrefix = "airfield_"

  side = SIDE_NONE

  ownedAirfieldsNumber = -1
  updateTimer = null
  updateDelay = 1
  selectedGroupAirArmiesNumber = { cur = 0 max = 0 }

  function getSceneTplView() {
    return {
      isControlHelpCentered = true
      consoleButtonsIconName = showConsoleButtons.value ? WW_MAP_CONSPLE_SHORTCUTS.MOVE : null
      controlHelpText = showConsoleButtons.value ? null : loc("key/RMB")
      controlHelpDesc = loc("worldwar/state/air_fly_out_control")
    }
  }

  function initScreen() {
    this.updateAirfields()
    if (::ww_get_selected_airfield() >= 0) {
      this.updateSelectedAirfield(::ww_get_selected_airfield())
      this.selectDefaultFormation()
    }
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function isValid() {
    return checkObj(this.scene) && checkObj(this.scene.findObject("airfields_list"))
  }

  function getAirfields() {
    let selAirfield = ::ww_get_selected_airfield()
    let airfields = []
    let fieldsArray = ::g_world_war.getAirfieldsArrayBySide(this.side)
    foreach (idx, field in fieldsArray) {
      airfields.append({
        id = this.getAirfieldId(field.index)
        text = (idx + 1)
        selected = selAirfield == field.index
        type = "".concat("ww_", field.airfieldType.objName)
      })
    }

    return airfields
  }

  function updateAirfields() {
    let airfields = this.getAirfields()
    let placeObj = this.scene.findObject("airfields_list")
    let view = { airfields = airfields }
    let data = handyman.renderCached("%gui/worldWar/wwAirfieldsList.tpl", view)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    this.ownedAirfieldsNumber = airfields.len()
  }

  function fillTimer(airfieldIdx, cooldownView) {
    let placeObj = this.scene.findObject("airfield_object")
    if (!checkObj(placeObj))
      return

    if (this.updateTimer)
      this.updateTimer.destroy()

    this.updateTimer = Timer(placeObj, this.updateDelay,
      function() {
        this.onUpdateTimer(placeObj, airfieldIdx, cooldownView)
      }, this, true)

    this.onUpdateTimer(placeObj, airfieldIdx, cooldownView)
  }

  function onUpdateTimer(placeObj, airfieldIdx, cooldownView) {
    if (!getTblValue("army", cooldownView))
      return

    let airfield = ::g_world_war.getAirfieldByIndex(airfieldIdx)
    if (!airfield)
      return

    if (cooldownView.army.len() != airfield.getCooldownsWithManageAccess().len()) {
      this.updateSelectedAirfield(airfieldIdx)
      return
    }

    foreach (_idx, item in cooldownView.army) {
      let blockObj = placeObj.findObject(item.getId())
      if (!checkObj(blockObj))
        return
      let timerObj = blockObj.findObject("arrival_time_text")
      if (!checkObj(timerObj))
        return

      let timerText = airfield.cooldownFormations[item.getFormationID()].getCooldownText()
      timerObj.setValue(timerText)
    }
  }

  function updateAirfieldFormation(index = -1) {
    let blockObj = this.scene.findObject("airfield_block")
    if (!checkObj(blockObj))
      return
    let placeObj = blockObj.findObject("free_formations")
    if (!checkObj(placeObj))
      return

    if (index < 0) {
      blockObj.show(false)
      this.guiScene.replaceContentFromText(placeObj, "", 0, this)
      return
    }

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let formationView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeFormationValue"
      formationType = "formation"
    }

    foreach (_i, formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation) {
        let wwFormationView = formation.getView()
        if (wwFormationView && wwFormationView.unitsCount() > 0)
          formationView.army.append(formation.getView())
      }

    let data = handyman.renderCached(this.airfieldBlockTplName, formationView)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    blockObj.show(true)
  }

  function hasFormationsForFly(airfield) {
    if (!airfield)
      return false

    foreach (formation in [airfield.clanFormation, airfield.allyFormation])
      if (formation)
        if (wwActionsWithUnitsList.unitsCount(formation.getUnits()))
          return true

    return false
  }

  function updateAirfieldCooldownList(index = -1) {
    let placeObj = this.scene.findObject("cooldowns_list")
    if (index < 0)
      this.guiScene.replaceContentFromText(placeObj, "", 0, this)

    let cooldownView = {
      army = []
      showArmyGroupText = false
      hasFormationData = true
      reqUnitTypeIcon = true
      addArmySelectCb = true
      checkMyArmy = true
      customCbName = "onChangeCooldownValue"
      formationType = "cooldown"
    }

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let cooldownFormations = airfield.getCooldownsWithManageAccess()
    foreach (_i, cooldown in cooldownFormations)
      cooldownView.army.append(cooldown.getView())

    let data = handyman.renderCached(this.airfieldBlockTplName, cooldownView)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
    this.fillTimer(index, cooldownView)
  }

  function hasArmyOnCooldown(airfield) {
    if (!airfield)
      return false

    let cooldownFormations = airfield.getCooldownsWithManageAccess()
    return cooldownFormations.len() > 0
  }

  function calcGroupAirArmiesNumber(index) {
    let airfield = ::g_world_war.getAirfieldByIndex(index)
    if (!airfield.isValid())
      return

    this.selectedGroupAirArmiesNumber.cur = this.calcSelectedGroupAirArmiesNumber(airfield)
    this.selectedGroupAirArmiesNumber.max = ::g_operations.getCurrentOperation().getGroupAirArmiesLimit(airfield.airfieldType.name)
  }

  function fillArmyLimitDescription(index) {
    let textObj = this.scene.findObject("armies_limit_text")
    if (!checkObj(textObj))
      return

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let isAirfielValid = airfield.isValid()
    if (!isAirfielValid)
      return

    textObj.setValue(
      loc($"worldwar/group_{airfield.airfieldType.locId}_armies_limit",
        { cur = this.selectedGroupAirArmiesNumber.cur,
          max = this.selectedGroupAirArmiesNumber.max }))
  }

  function calcSelectedGroupAirArmiesNumber(airfield) {
    let availableArmiesArray = airfield.getAvailableFormations()
    let selectedGroupIdx = availableArmiesArray?[0].getArmyGroupIdx() ?? 0
    local armyCount = ::g_operations.getAirArmiesNumberByGroupIdx(selectedGroupIdx,
      airfield.airfieldType.overrideUnitType)
    for (local idx = 0; idx < ::g_world_war.getAirfieldsCount(); idx++) {
      let af = ::g_world_war.getAirfieldByIndex(idx)
      if (airfield.airfieldType == af.airfieldType)
        armyCount += af.getCooldownArmiesNumberByGroupIdx(selectedGroupIdx)
    }
    return armyCount
  }

  function updateAirfieldDescription(index = -1) {
    let airfieldBlockObj = this.scene.findObject("airfield_block")
    if (!checkObj(airfieldBlockObj))
      return

    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let isAirfielValid = airfield.isValid()

    airfieldBlockObj.show(isAirfielValid)
    if (!isAirfielValid)
      return

    let airfieldInfoObj = airfieldBlockObj.findObject("airfield_info_text")
    if (!checkObj(airfieldInfoObj))
      return

    let airfieldUnitsText = "".concat(
      loc("".concat("worldwar/", airfield.airfieldType.objName, "_units")),
        loc("ui/colon"))
    let airfieldInFlyText = loc("worldwar/airfield_in_fly") + loc("ui/colon")
    let airfieldCapacityText = "".concat(
      loc("".concat("worldwar/", airfield.airfieldType.objName, "_capacity")),
        loc("ui/colon"))
    let iconText = airfield.airfieldType.unitType.fontIcon

    let airfieldUnitsNumber = airfield.getUnitsNumber()
    let inFlyUnitsNumber = airfield.getUnitsInFlyNumber()
    let airfieldCapacityNumber = airfield.getSize()
    let isFull = airfieldUnitsNumber + inFlyUnitsNumber >= airfieldCapacityNumber

    local airfieldInfoValue = airfieldUnitsNumber
    local airfieldTooltip = airfieldUnitsText +
      colorize("@white", airfieldUnitsNumber + " " + iconText)
    if (inFlyUnitsNumber > 0) {
      airfieldInfoValue += "+" + inFlyUnitsNumber
      airfieldTooltip += "\n" + airfieldInFlyText +
        colorize("@white", inFlyUnitsNumber + " " + iconText)
    }
    airfieldInfoValue += "/" + airfieldCapacityNumber + " " + iconText
    airfieldTooltip += "\n" + airfieldCapacityText +
      colorize("@white", airfieldCapacityNumber + " " + iconText)
    if (isFull)
      airfieldTooltip += "\n" + colorize("@badTextColor", loc("worldwar/airfield_is_full"))

    airfieldInfoObj.setValue(airfieldCapacityText +
      colorize(isFull ? "@badTextColor" : "@white", airfieldInfoValue))
    airfieldInfoObj.tooltip = airfieldTooltip

    let hasFormationUnits = this.hasFormationsForFly(airfield)
    let hasCooldownUnits = this.hasArmyOnCooldown(airfield)
    let formationTextObj = airfieldBlockObj.findObject("free_formations_text")
    if (!checkObj(formationTextObj))
      return

    let text = hasFormationUnits ? loc("worldwar/state/ready_to_fly") + loc("ui/colon")
      : hasCooldownUnits ? loc("worldwar/state/no_units_to_fly")
      : loc($"worldwar/state/{airfield.airfieldType.objName}_empty")
    formationTextObj.setValue(text)

    let hasEnoughToFly = airfield.hasEnoughUnitsToFly()
    let limitReached = this.selectedGroupAirArmiesNumber.cur == this.selectedGroupAirArmiesNumber.max

    this.showSceneBtn("control_help", hasEnoughToFly && !limitReached)
    let isVisibleAlertText = limitReached || !hasEnoughToFly
    let alertObj = this.showSceneBtn("alert_text", isVisibleAlertText)
    if (isVisibleAlertText && alertObj != null)
      alertObj.setValue(limitReached ? loc($"worldwar/reached_{airfield.airfieldType.locId}_armies_limit")
      : loc("worldwar/airfield/not_enough_units_to_send"))

    if (!hasFormationUnits && !hasCooldownUnits)
      wwEvent("MapClearSelection", {})
  }

  function getAirfieldId(index) {
    return this.airfieldIdPrefix + index
  }

  function selectRadioButtonBlock(rbObj, idx) {
    if (checkObj(rbObj))
      if (rbObj.childrenCount() > idx && idx >= 0)
        if (rbObj.getChild(idx))
          rbObj.getChild(idx).setValue(true)
  }

  function deselectRadioButtonBlocks(rbObj) {
    if (checkObj(rbObj))
      for (local i = 0; i < rbObj.childrenCount(); i++)
        rbObj.getChild(i).setValue(false)
  }

  function onChangeFormationValue(obj) {
    this.deselectRadioButtonBlocks(this.scene.findObject("cooldowns_list"))
    wwEvent("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "formation",
      formationId = obj.formationId.tointeger() })
  }

  function onChangeCooldownValue(obj) {
    this.deselectRadioButtonBlocks(this.scene.findObject("free_formations"))
    wwEvent("MapAirfieldFormationSelected", {
      airfieldIdx = ::ww_get_selected_airfield(),
      formationType = "cooldown",
      formationId = obj.formationId.tointeger() })
  }

  function onAirfieldClick(obj) {
    let index = to_integer_safe(obj.id.slice(this.airfieldIdPrefix.len()), -1)
    let mapObj = get_cur_gui_scene()["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectAirfield.call(
      ::ww_gui_bhv.worldWarMapControls, mapObj, { airfieldIdx = index })
  }

  onHoverAirfieldItem = @(obj)
    wwEvent("HoverAirfieldItem",
      { airfieldIndex = cutPrefix(obj.id, this.airfieldIdPrefix).tointeger() })

  onHoverLostAirfieldItem = @(_obj) wwEvent("HoverLostAirfieldItem", { airfieldIndex = -1 })

  function selectDefaultFormation() {
    let placeObj = this.scene.findObject("free_formations")
    this.selectRadioButtonBlock(placeObj, 0)
  }

  function updateSelectedAirfield(selectedAirfield = -1) {
    if (this.ownedAirfieldsNumber != this.getAirfields().len())
      this.updateAirfields()

    for (local index = 0; index < ::ww_get_airfields_count(); index++) {
      let airfieldObj = this.scene.findObject(this.getAirfieldId(index))
      if (checkObj(airfieldObj))
        airfieldObj.selected = selectedAirfield == index ? "yes" : "no"
    }
    this.updateAirfieldFormation(selectedAirfield)
    this.updateAirfieldCooldownList(selectedAirfield)
    this.calcGroupAirArmiesNumber(selectedAirfield)
    this.fillArmyLimitDescription(selectedAirfield)
    this.updateAirfieldDescription(selectedAirfield)
    this.selectDefaultFormation()
  }

  function onEventWWMapAirfieldSelected(_params) {
    if (!checkObj(this.scene))
      return

    this.updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapAirfieldCleared(_params) {
    this.updateSelectedAirfield()
  }

  function onEventWWLoadOperation(_params = {}) {
    this.updateSelectedAirfield(::ww_get_selected_airfield())
  }

  function onEventWWMapClearSelectionBySelectedObject(params) {
    if (params.objSelected != mapObjectSelect.AIRFIELD)
      this.updateSelectedAirfield()
  }
}
