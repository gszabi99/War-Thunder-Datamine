from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")












gui_handlers.ChooseMissionsListWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName   = "%gui/missions/chooseMissionsListWnd.blk"

  headerText = ""
  missionsList = null
  selMissions = null
  onApplyListCb = null
  choosenIcon = "#ui/gameuiskin#favorite"

  misListObj = null
  selMissionsMap = null  
  initialSelMissionsMap = null
  missionDescWeak = null
  curMission = null

  static function open(config) {
    let misList = getTblValue("missionsList", config)
    if (!u.isArray(misList) || !misList.len()) {
      script_net_assert_once(" bad_missions_list",
        $"Bad missions list to choose: {toString(misList)}")
      return
    }
    handlersManager.loadHandler(gui_handlers.ChooseMissionsListWnd, config)
  }

  function initScreen() {
    this.misListObj = this.scene.findObject("items_list")
    this.scene.findObject("wnd_title").setValue(this.headerText)

    this.selMissionsMap = this.selMissionsToMap(this.missionsList, this.selMissions)
    this.initialSelMissionsMap = clone this.selMissionsMap
    this.initDescHandler()
    this.fillMissionsList()

    move_mouse_on_child_by_value(this.scene.findObject("items_list"))
  }

  function initDescHandler() {
    let descHandler = gui_handlers.MissionDescription.create(this.getObj("mission_desc"), this.curMission)
    this.registerSubHandler(descHandler)
    this.missionDescWeak = descHandler.weakref()
  }

  function selMissionsToMap(fullList, selList) {
    let res = {}
    foreach (mission in fullList)
      res[mission.id] <- false
    foreach (mission in selList)
      res[mission.id] <- true
    return res
  }

  function mapToSelectedMissions(fullList, misMap) {
    let res = []
    foreach (mission in fullList)
      if (getTblValue(mission.id, misMap, false))
        res.append(mission)
    return res
  }

  function isMissionSelected(mission) {
    return getTblValue(mission.id, this.selMissionsMap, false)
  }

  function isAllMissionsSelected() {
    foreach (value in this.selMissionsMap)
      if (!value)
        return false
    return true
  }

  function fillMissionsList() {
    let view = { items = [] }
    foreach (mission in this.missionsList)
      view.items.append({
        id = mission.id
        itemText = mission.getNameText()
        checkBoxActionName = "onMissionCheckBox"
        isChosen = this.isMissionSelected(mission) ? "yes" : "no"
      })

    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(this.misListObj, data, data.len(), this)
    this.misListObj.setValue(0)
  }

  function updateButtons() {
    let chooseBtn = showObjById("btn_choose", !!this.curMission, this.scene)
    if (this.curMission)
      chooseBtn.setValue(this.isMissionSelected(this.curMission) ? loc("misList/unselectMission") : loc("misList/selectMission"))

    let chooseAllText = this.isAllMissionsSelected() ? loc("misList/unselectAll") : loc("misList/selectAll")
    this.scene.findObject("btn_choose_all").setValue(chooseAllText)
  }

  function markSelected(mission, isSelected) {
    if (isSelected == this.isMissionSelected(mission))
      return

    this.selMissionsMap[mission.id] <- isSelected
    let checkBoxObj = this.misListObj.findObject($"checkbox_{mission.id}")
    if (checkObj(checkBoxObj) && checkBoxObj.getValue() != isSelected)
      checkBoxObj.setValue(isSelected)
  }

  function onMissionSelect(obj) {
    let mission = getTblValue(obj.getValue(), this.missionsList)
    if (mission == this.curMission)
      return

    this.curMission = mission
    if (this.missionDescWeak)
      this.missionDescWeak.setMission(this.curMission)
    this.updateButtons()
  }

  function onChooseMission() {
    if (!this.curMission)
      return

    this.markSelected(this.curMission, !this.isMissionSelected(this.curMission))
    this.updateButtons()
  }

  function onChooseAll() {
    let needSelect = !this.isAllMissionsSelected()
    foreach (mission in this.missionsList)
      this.markSelected(mission, needSelect)
    this.updateButtons()
  }

  function onMissionCheckBox(obj) {
    let id = getObjIdByPrefix(obj, "checkbox_")
    if (!id)
      return

    if (!this.curMission || this.curMission.id != id) {
      let idx = this.missionsList.findindex(@(m) m.id == id)
      if (idx == null)
        return

      this.misListObj.setValue(idx)
    }

    let value = obj.getValue()
    if (this.isMissionSelected(this.curMission) != obj.getValue()) {
      this.markSelected(this.curMission, value)
      this.updateButtons()
    }
  }

  function afterModalDestroy() {
    if (this.onApplyListCb && !u.isEqual(this.selMissionsMap, this.initialSelMissionsMap))
      this.onApplyListCb(this.mapToSelectedMissions(this.missionsList, this.selMissionsMap))
  }
}
