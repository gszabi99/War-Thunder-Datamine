//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { setObjPosition } = require("%sqDagui/daguiUtil.nut")
let { WW_MAP_TOOLTIP_TYPE_BATTLE, WW_MAP_TOOLTIP_TYPE_ARMY
} = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")


const SHOW_TOOLTIP_DELAY_TIME = 0.35

gui_handlers.wwMapTooltip <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  controllerScene = null

  specifyTypeOrder = {
    [WW_MAP_TOOLTIP_TYPE.BATTLE] = { paramsKey = "battleName" },
    [WW_MAP_TOOLTIP_TYPE.ARMY]   = { paramsKey = "armyName" },
    [WW_MAP_TOOLTIP_TYPE.NONE]   = {}
  }

  specs = null
  showTooltipTimer = null
  descriptionTimer = null

  function initScreen() {
    this.scene.setUserData(this) //to not unload handler even when scene not loaded
    this.updateScreen(this.getUpdatedSpecs())
  }

  function updateScreen(newSpecs) {
    this.specs = newSpecs
    if (this.specs.currentType == WW_MAP_TOOLTIP_TYPE.NONE)
      return this.hideTooltip()

    this.startShowTooltipTimer()
  }

  function onEventWWMapUpdateCursorByTimer(p) {
    let newSpecs = this.getUpdatedSpecs(p)
    if (u.isEqual(this.specs, newSpecs))
      return

    this.updateScreen(newSpecs)
  }

  function onEventWWLoadOperation(_params = {}) {
    this.scene.lastCurrentId = ""
    if (this.specs.currentType != WW_MAP_TOOLTIP_TYPE.NONE)
      this.show()
  }

  function getUpdatedSpecs(p = null) {
    let res = {
      currentType = WW_MAP_TOOLTIP_TYPE.NONE
      currentId = ""
    }
    for (local i = 0; i < WW_MAP_TOOLTIP_TYPE.TOTAL; i++) {
      let key = getTblValue("paramsKey", this.specifyTypeOrder[i])
      if (key in p) {
        res.currentType = i
        res.currentId = p[key]
        break
      }
    }
    return res
  }

  function hideTooltip() {
    this.specs = this.getUpdatedSpecs()
    this.onTooltipObjClose(this.scene)
  }

  function startShowTooltipTimer() {
    this.onTooltipObjClose(this.scene)
    if (!checkObj(this.controllerScene))
      return

    if (this.showTooltipTimer)
      this.showTooltipTimer.destroy()

    this.showTooltipTimer = Timer(this.controllerScene, SHOW_TOOLTIP_DELAY_TIME,
      function() {
        this.show()
      }, this, false)
  }

  function show() {
    if (!checkObj(this.scene))
      return

    let isShow = this.specs.currentType != WW_MAP_TOOLTIP_TYPE.NONE && this.isSceneActiveNoModals()

    this.scene.show(isShow)
    if (!isShow)
      return

    if (this.scene.lastCurrentId == this.specs.currentId)
      return

    this.scene.lastCurrentId = this.specs.currentId
    this.scene.tooltipId = this.getWWMapIdHoveredObjectId()
    this.onGenericTooltipOpen(this.scene)
    this.updatePos()

    if (this.specs.currentType == WW_MAP_TOOLTIP_TYPE.ARMY) {
      let hoveredArmy = ::g_world_war.getArmyByName(this.specs.currentId)
      this.destroyDescriptionTimer()

      this.descriptionTimer = Timer(
        this.scene, 1, @() this.updateSelectedArmy(hoveredArmy), this, true
      )
    }

    if (this.specs.currentType == WW_MAP_TOOLTIP_TYPE.BATTLE) {
      let battleDescObj = this.scene.findObject("battle_desc")
      if (checkObj(battleDescObj)) {
        local maxTeamContentWidth = 0
        foreach (teamName in ["teamA", "teamB"]) {
          let teamInfoObj = this.scene.findObject(teamName)
          if (checkObj(teamInfoObj))
            maxTeamContentWidth = max(teamInfoObj.getSize()[0], maxTeamContentWidth)
        }

        battleDescObj.width = (2 * maxTeamContentWidth) + "+4@framePadding"

        let hoveredBattle = ::g_world_war.getBattleById(this.specs.currentId)
        this.destroyDescriptionTimer()

        this.descriptionTimer = Timer(
          this.scene, 1, @() this.updateSelectedBattle(hoveredBattle), this, true
        )
        this.updateSelectedBattle(hoveredBattle)
      }
    }
  }

  function destroyDescriptionTimer() {
    if (this.descriptionTimer) {
      this.descriptionTimer.destroy()
      this.descriptionTimer = null
    }
  }

  function updateSelectedArmy(hoveredArmy) {
    if (!checkObj(this.scene) || !hoveredArmy)
      return

    hoveredArmy.update(hoveredArmy.name)
    let armyView = hoveredArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData()) {
      let redrawFieldObj = this.scene.findObject(fieldId)
      if (checkObj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView))
    }
  }

  function updateSelectedBattle(hoveredBattle) {
    if (!checkObj(this.scene) || !hoveredBattle)
      return

    let battleTimerObj = this.scene.findObject("battle_timer")
    if (!checkObj(battleTimerObj))
      return
    let battleTimerDescObj = battleTimerObj.findObject("battle_timer_desc")
    if (!checkObj(battleTimerDescObj))
      return
    let battleTimerValueObj = battleTimerObj.findObject("battle_timer_value")
    if (!checkObj(battleTimerValueObj))
      return

    let battleView = hoveredBattle.getView()
    let hasDurationTime = battleView.hasBattleDurationTime()
    let hasActivateLeftTime = battleView.hasBattleActivateLeftTime()
    let timeStartAutoBattle = battleView.getTimeStartAutoBattle()

    let descText = hasDurationTime ? loc("debriefing/BattleTime")
      : hasActivateLeftTime ? loc("worldWar/can_join_countdown")
      : timeStartAutoBattle != "" ? loc("worldWar/will_start_auto_battle")
      : ""
    let descValue = hasDurationTime ? battleView.getBattleDurationTime()
      : hasActivateLeftTime ? battleView.getBattleActivateLeftTime()
      : timeStartAutoBattle

    battleTimerDescObj.setValue(descText + loc("ui/colon"))
    battleTimerValueObj.setValue(descValue)
    battleTimerObj.show(hasDurationTime || hasActivateLeftTime || timeStartAutoBattle != "")

    let statusObj = this.scene.findObject("battle_status_text")
    if (checkObj(statusObj))
      statusObj.setValue(battleView.getBattleStatusWithCanJoinText())

    let needShowWinChance = battleView.needShowWinChance()
    let winCahnceObj = this.showSceneBtn("win_chance", needShowWinChance)
    if (!needShowWinChance || !winCahnceObj)
      return
    let winCahnceTextObj = winCahnceObj.findObject("win_chance_text")
    let percent = battleView.getAutoBattleWinChancePercentText()
    if (checkObj(winCahnceTextObj) && percent != "")
      winCahnceTextObj.setValue(percent)
    else
      winCahnceObj.show(false)
  }

  function getWWMapIdHoveredObjectId() {
    if (this.specs.currentType == WW_MAP_TOOLTIP_TYPE.BATTLE)
      return WW_MAP_TOOLTIP_TYPE_BATTLE.getTooltipId(this.specs.currentId, this.specs)

    if (this.specs.currentType == WW_MAP_TOOLTIP_TYPE.ARMY)
      return WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(this.specs.currentId, this.specs)

    return ""
  }

  function onUpdateTooltip(_obj, _dt) {
    if (!this.isSceneActiveNoModals())
      return

    this.updatePos()
  }

  function updatePos() {
    let cursorPos = get_dagui_mouse_cursor_pos_RC()
    cursorPos[0] = cursorPos[0]  + "+1@wwMapTooltipOffset"
    setObjPosition(this.scene, cursorPos, ["@bw", "@bh"])
  }
}
