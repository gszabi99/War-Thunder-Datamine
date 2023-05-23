//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.WwReinforcements <- class extends ::BaseGuiHandler {
  wndType = handlerType.CUSTOM
  sceneTplName = "%gui/worldWar/worldWarMapReinforcementsList.tpl"
  sceneBlkName = null
  reinforcementBlockTplName = "%gui/worldWar/worldWarMapArmyItem.tpl"

  armiesBlocks = null
  readyArmiesNames = null

  timerHandler = null
  updateDelay = 1 //sec

  currentReinforcementName = null
  reinforcementSpeedup = -1

  function getSceneTplView() {
    return {
      consoleButtonsIconName = ::show_console_buttons ? WW_MAP_CONSPLE_SHORTCUTS.MOVE : null
      controlHelpText = ::show_console_buttons ? null : loc("key/RMB")
      controlHelpDesc = loc("worldwar/state/reinforcement_control")
    }
  }

  function getSceneTplContainerObj() {
    return this.scene
  }

  function initScreen() {
    this.readyArmiesNames = []
    this.armiesBlocks = []
    this.updateScene()
  }

  function isValid() {
    return checkObj(this.scene) && checkObj(this.scene.findObject("reinforcements_list"))
  }

  function updateScene() {
    this.fillReinforcementsList()
    this.fillTimer()
  }

  function onEventWWLoadOperation(_params) {
    this.updateScene()
    this.readyArmiesNames.clear()
  }

  function updateReinforcementsList() {
    let playerSide = ::ww_get_player_side()

    this.armiesBlocks.clear()

    let existedArmies = []
    let newArmies = []

    let reinforcementsInfo = ::g_world_war.getReinforcementsInfo()
    if (reinforcementsInfo?.reinforcements == null)
      return

    for (local i = 0; i < reinforcementsInfo.reinforcements.blockCount(); i++) {
      let reinforcement = reinforcementsInfo.reinforcements.getBlock(i)
      let wwReinforcementArmy = ::WwReinforcementArmy(reinforcement)
      if (!hasFeature("worldWarMaster") &&
          (!wwReinforcementArmy.isMySide(playerSide) ||
           !wwReinforcementArmy.hasManageAccess())
          )
        continue

      if (isInArray(wwReinforcementArmy.getView().getId(), this.readyArmiesNames))
        existedArmies.append(wwReinforcementArmy)
      else
        newArmies.append(wwReinforcementArmy)
    }

    existedArmies.sort(::WwReinforcementArmy.sortReadyReinforcements)
    newArmies.sort(::WwReinforcementArmy.sortNewReinforcements)

    this.armiesBlocks.extend(existedArmies)
    this.armiesBlocks.extend(newArmies)
  }

  function showDeployHint(isVisible = false) {
    this.showSceneBtn("deploy_hint_nest", isVisible)
  }

  function onChangeArmyValue(obj) {
    this.updateSelectedArmy(false, false)
    if (this.currentReinforcementName != obj.armyName)
      this.guiScene.playSound("ww_reinforcement_select")

    this.currentReinforcementName = obj.armyName
    this.showDeployHint(obj?.canDeploy == "yes")
    ::ww_event("SelectedReinforcement", { name = this.currentReinforcementName })
  }

  function onEventWWMapRequestReinforcement(params) {
    if (!this.currentReinforcementName)
      return

    let taskId = ::g_world_war.sendReinforcementRequest(
      params.cellIdx, this.currentReinforcementName)
    ::g_tasker.addTask(taskId, null, Callback(this.afterSendReinforcement, this),
      Callback(this.onSendReinforcementError, this))
  }

  function afterSendReinforcement() {
    if (!checkObj(this.scene))
      return

    let mapObj = this.guiScene["worldwar_map"]
    ::ww_gui_bhv.worldWarMapControls.selectArmy.call(::ww_gui_bhv.worldWarMapControls, mapObj, this.currentReinforcementName)
    this.updateSelectedArmy(false, true)

    let selectedArmies = ::ww_get_selected_armies_names()
    if (!selectedArmies.len())
      return

    let wwArmy = ::g_world_war.getArmyByName(selectedArmies[0])
    if (wwArmy)
      ::g_world_war.playArmyActionSound("deploySound", wwArmy)
  }

  function onSendReinforcementError(_err) {
    ::g_world_war.popupCharErrorMsg("reinforcement_deploy_error")
    ::ww_event("ShowRearZones", { name = this.currentReinforcementName })
  }

  function fillReinforcementsList() {
    this.updateReinforcementsList()

    this.showSceneBtn("no_reinforcements_text", this.armiesBlocks.len() == 0)

    let readyArmies = []
    let otherArmies = []
    foreach (army in this.armiesBlocks)
      if (army.isReady())
        readyArmies.append(army.getView())
      else
        otherArmies.append(army.getView())

    this.fillArmiesList(readyArmies, "ready_reinforcements_list", true)
    this.fillArmiesList(otherArmies, "reinforcements_list", false)
    this.showSceneBtn("no_ready_reinforcements_text", readyArmies.len() == 0)
    this.showSceneBtn("ready_label", readyArmies.len() > 0)
    this.showSceneBtn("ready_reinforcements_block", this.armiesBlocks.len() > 0)
    this.showSceneBtn("coming_reinforcements_block", otherArmies.len() > 0)

    this.updateSelectedArmy(true, false)
  }

  function fillReinforcementsSpeed(newSpeedup) {
    if (this.reinforcementSpeedup == newSpeedup)
      return

    let textObj = this.scene.findObject("arrival_speed_text")
    if (!checkObj(textObj))
      return

    local speedText = ""
    if (newSpeedup > 0) {
      speedText = colorize("goodTextColor", loc("keysPlus") + newSpeedup)
      speedText = loc("worldwar/state/reinforcement_arrival_speed", { speedup = speedText })
    }
    else
      speedText = loc("worldwar/state/reinforcement_arrival_basic_speed")

    textObj.setValue(speedText)
    this.reinforcementSpeedup = newSpeedup
  }

  function fillArmiesList(viewsArray, id, isReady) {
    let placeObj = this.scene.findObject(id)
    if (!checkObj(placeObj))
      return

    let view = {
      army = viewsArray
      reqUnitTypeIcon = true
      checkMyArmy = true
      showArmyGroupText = false
      addArmySelectCb = true
      isArmyReady = isReady
    }

    let data = handyman.renderCached(this.reinforcementBlockTplName, view)
    this.guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function onEventWWMapClearSelection(_params) {
    this.updateSelectedArmy(false, false)
  }

  function onEventWWMapClearSelectionBySelectedObject(_params) {
    this.updateSelectedArmy(false, false)
  }

  function onEventWWReinforcementSpeedupUpdated(params) {
    this.fillReinforcementsSpeed(params?.speedup ?? 0)
  }

  function updateSelectedArmy(select, destroy) {
    if (u.isEmpty(this.currentReinforcementName))
      return

    local selectedArmy = u.search(this.armiesBlocks, (@(currentReinforcementName) function(reinf) {
        return reinf.name == currentReinforcementName
      })(this.currentReinforcementName))

    if (!selectedArmy) {
      //search in existed, because army can already be an army, not a reinforcement
      let army = ::g_world_war.getArmyByName(this.currentReinforcementName)
      if (!army.isValid())
        return

      selectedArmy = army
    }

    let obj = this.scene.findObject(selectedArmy.getView().getId())
    if (checkObj(obj)) {
      obj.setValue(select)
      if (destroy) {
        let placeObj = obj.getParent()
        this.guiScene.destroyElement(obj)
        this.showSceneBtn("no_reinforcements_text", placeObj.childrenCount() == 0)
      }
    }

    this.showDeployHint(select)
    if (!select)
      this.currentReinforcementName = null
  }

  function fillTimer() {
    let placeObj = this.scene.findObject("reinforcements_list")
    if (!checkObj(placeObj))
      return

    this.timerHandler = ::Timer(
      placeObj,
      this.updateDelay,
      function() {
        local haveNewReinforcementsReady = false
        foreach (reinforcementHandler in this.armiesBlocks) {
          let id = reinforcementHandler.getView().getId()
          if (reinforcementHandler.isReady() && !isInArray(id, this.readyArmiesNames)) {
            this.readyArmiesNames.append(id)
            haveNewReinforcementsReady = true
          }

          let reinfObj = placeObj.findObject(id)
          if (!checkObj(reinfObj))
            continue

          let timeTextObj = reinfObj.findObject("arrival_time_text")
          timeTextObj.setValue(reinforcementHandler.getArrivalStatusText())
        }
        if (haveNewReinforcementsReady)
          this.updateScene()
      },
      this, true)
  }

  function selectFirstArmyBySide(side) {
    let reinforcementsObj = this.scene.findObject("ready_reinforcements_list")
    if (reinforcementsObj.childrenCount())
      reinforcementsObj.getChild(0).setValue(true)

    foreach (army in this.armiesBlocks)
      if (army.isReady() && ::ww_side_val_to_name(army.getArmySide()) == side) {
        let armyView = army.getView()
        if (!armyView)
          continue

        let reinforcementObj = reinforcementsObj.findObject(armyView.getId())
        if (!checkObj(reinforcementObj))
          continue

        reinforcementObj.setValue(true)
        break
      }
  }
}
