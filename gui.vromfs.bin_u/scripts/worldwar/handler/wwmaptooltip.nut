from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

local { WW_MAP_TOOLTIP_TYPE_BATTLE, WW_MAP_TOOLTIP_TYPE_ARMY
} = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


global enum WW_MAP_TOOLTIP_TYPE
{
  BATTLE,
  ARMY,
  NONE,
  TOTAL
}

const SHOW_TOOLTIP_DELAY_TIME = 0.35

::gui_handlers.wwMapTooltip <- class extends ::gui_handlers.BaseGuiHandlerWT
{
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

  function initScreen()
  {
    this.scene.setUserData(this) //to not unload handler even when scene not loaded
    updateScreen(getUpdatedSpecs())
  }

  function updateScreen(newSpecs)
  {
    specs = newSpecs
    if (specs.currentType == WW_MAP_TOOLTIP_TYPE.NONE)
      return hideTooltip()

    startShowTooltipTimer()
  }

  function onEventWWMapUpdateCursorByTimer(p)
  {
    let newSpecs = getUpdatedSpecs(p)
    if (::u.isEqual(specs, newSpecs))
      return

    updateScreen(newSpecs)
  }

  function onEventWWLoadOperation(_params = {})
  {
    this.scene.lastCurrentId = ""
    if (specs.currentType != WW_MAP_TOOLTIP_TYPE.NONE)
      show()
  }

  function getUpdatedSpecs(p = null)
  {
    let res = {
      currentType = WW_MAP_TOOLTIP_TYPE.NONE
      currentId = ""
    }
    for (local i = 0; i < WW_MAP_TOOLTIP_TYPE.TOTAL; i++)
    {
      let key = getTblValue("paramsKey", specifyTypeOrder[i])
      if (key in p)
      {
        res.currentType = i
        res.currentId = p[key]
        break
      }
    }
    return res
  }

  function hideTooltip()
  {
    specs = getUpdatedSpecs()
    this.onTooltipObjClose(this.scene)
  }

  function startShowTooltipTimer()
  {
    this.onTooltipObjClose(this.scene)
    if (!checkObj(controllerScene))
      return

    if (showTooltipTimer)
      showTooltipTimer.destroy()

    showTooltipTimer = ::Timer(controllerScene, SHOW_TOOLTIP_DELAY_TIME,
      function()
      {
        show()
      }, this, false)
  }

  function show()
  {
    if (!checkObj(this.scene))
      return

    let isShow = specs.currentType != WW_MAP_TOOLTIP_TYPE.NONE && this.isSceneActiveNoModals()

    this.scene.show(isShow)
    if (!isShow)
      return

    if (this.scene.lastCurrentId == specs.currentId)
      return

    this.scene.lastCurrentId = specs.currentId
    this.scene.tooltipId = getWWMapIdHoveredObjectId()
    this.onGenericTooltipOpen(this.scene)
    updatePos()

    if (specs.currentType == WW_MAP_TOOLTIP_TYPE.ARMY)
    {
      let hoveredArmy = ::g_world_war.getArmyByName(specs.currentId)
      destroyDescriptionTimer()

      descriptionTimer = ::Timer(
        this.scene, 1, @() updateSelectedArmy(hoveredArmy), this, true
      )
    }

    if (specs.currentType == WW_MAP_TOOLTIP_TYPE.BATTLE)
    {
      let battleDescObj = this.scene.findObject("battle_desc")
      if (checkObj(battleDescObj))
      {
        local maxTeamContentWidth = 0
        foreach(teamName in ["teamA", "teamB"])
        {
          let teamInfoObj = this.scene.findObject(teamName)
          if (checkObj(teamInfoObj))
            maxTeamContentWidth = max(teamInfoObj.getSize()[0], maxTeamContentWidth)
        }

        battleDescObj.width = (2*maxTeamContentWidth) + "+4@framePadding"

        let hoveredBattle = ::g_world_war.getBattleById(specs.currentId)
        destroyDescriptionTimer()

        descriptionTimer = ::Timer(
          this.scene, 1, @() updateSelectedBattle(hoveredBattle), this, true
        )
        updateSelectedBattle(hoveredBattle)
      }
    }
  }

  function destroyDescriptionTimer()
  {
    if (descriptionTimer)
    {
      descriptionTimer.destroy()
      descriptionTimer = null
    }
  }

  function updateSelectedArmy(hoveredArmy)
  {
    if (!checkObj(this.scene) || !hoveredArmy)
      return

    hoveredArmy.update(hoveredArmy.name)
    let armyView = hoveredArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData())
    {
      let redrawFieldObj = this.scene.findObject(fieldId)
      if (checkObj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView))
    }
  }

  function updateSelectedBattle(hoveredBattle)
  {
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

  function getWWMapIdHoveredObjectId()
  {
    if (specs.currentType == WW_MAP_TOOLTIP_TYPE.BATTLE)
      return WW_MAP_TOOLTIP_TYPE_BATTLE.getTooltipId(specs.currentId, specs)

    if (specs.currentType == WW_MAP_TOOLTIP_TYPE.ARMY)
      return WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(specs.currentId, specs)

    return ""
  }

  function onUpdateTooltip(_obj, _dt)
  {
    if (!this.isSceneActiveNoModals())
      return

    updatePos()
  }

  function updatePos()
  {
    let cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    cursorPos[0] = cursorPos[0]  + "+1@wwMapTooltipOffset"
    ::g_dagui_utils.setObjPosition(this.scene, cursorPos, ["@bw", "@bh"])
  }
}
