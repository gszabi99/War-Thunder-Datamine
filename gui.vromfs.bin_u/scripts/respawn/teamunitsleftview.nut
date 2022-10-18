from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.teamUnitsLeftView <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/promo/promoBlocks"

  blockId = "leftUnits"

  missionRules = null
  isSceneLoaded = false
  isCollapsed = true

  collapsedInfoRefreshDelay = 4.0
  collapsedInfoUnitLimit = null
  collapsedInfoTimer = -1

  function initScreen()
  {
    this.scene.setUserData(this) //to not unload handler even when scene not loaded
    this.scene.findObject(blockId).setUserData(this)

    updateInfo()
  }

  function getSceneTplView()
  {
    if (isSceneLoaded)
      return null

    let view = {
      promoButtons = [{
        id = blockId
        type = "autoSize"
        show = true
        inputTransparent = true
        needTextShade = true
        showTextShade = true
        hideHeaderBg = true
        collapsed = isCollapsed ? "yes" : "no"
        timerFunc = "onUpdate"
        needCollapsedTextAnimSwitch = true
        hasSafeAreaPadding = "no"

        fillBlocks = [{}]
      }]
    }

    isSceneLoaded = true
    return view
  }

  function getRespTextByUnitLimit(unitLimit)
  {
    return unitLimit ? unitLimit.getText() : ""
  }

  function getFullUnitsText()
  {
    let data = missionRules.getFullUnitLimitsData()
    let textsList = ::u.map(data.unitLimits, getRespTextByUnitLimit)
    textsList.insert(0, colorize("activeTextColor", loc(missionRules.customUnitRespawnsAllyListHeaderLocId)))

    if (missionRules.isEnemyLimitedUnitsVisible())
    {
      let enemyData = missionRules.getFullEnemyUnitLimitsData()
      if (enemyData.len())
      {
        let enemyTextsList = ::u.map(enemyData.unitLimits, getRespTextByUnitLimit)
        textsList.append("\n" + colorize("activeTextColor", loc(missionRules.customUnitRespawnsEnemyListHeaderLocId)))
        textsList.extend(enemyTextsList)
      }
    }

    return ::g_string.implode(textsList, "\n")
  }

  function updateInfo(isJustSwitched = false)
  {
    if (!isSceneLoaded)
      return

    if (isCollapsed)
      updateCollapsedInfoText(isJustSwitched)
    else
      this.scene.findObject(blockId + "_text").setValue(getFullUnitsText())
  }

  function updateCollapsedInfoByUnitLimit(unitLimit, needAnim = true)
  {
    collapsedInfoUnitLimit = unitLimit
    let text = getRespTextByUnitLimit(unitLimit)
    if (needAnim)
    {
      ::g_promo_view_utils.animSwitchCollapsedText(this.scene, blockId, text)
      return
    }

    let obj = ::g_promo_view_utils.getVisibleCollapsedTextObj(this.scene, blockId)
    if (checkObj(obj))
      obj.setValue(text)
  }

  function setNewCollapsedInfo(needAnim = true)
  {
    let data = missionRules.getFullUnitLimitsData()
    local prevIdx = -1
    if (collapsedInfoUnitLimit)
      prevIdx = data.unitLimits.findindex(collapsedInfoUnitLimit.isSame.bindenv(collapsedInfoUnitLimit)) ?? -1

    updateCollapsedInfoByUnitLimit(::u.chooseRandomNoRepeat(data.unitLimits, prevIdx), needAnim)
    collapsedInfoTimer = collapsedInfoRefreshDelay
  }

  function updateCollapsedInfoText(isJustSwitched = false)
  {
    if (isJustSwitched || !collapsedInfoUnitLimit)
      return setNewCollapsedInfo(!isJustSwitched)

    let data = missionRules.getFullUnitLimitsData()
    let newUnitLimit = ::u.search(data.unitLimits, collapsedInfoUnitLimit.isSame.bindenv(collapsedInfoUnitLimit))
    if (newUnitLimit)
      updateCollapsedInfoByUnitLimit(newUnitLimit, false)
    else
      setNewCollapsedInfo()
  }

  function onToggleItem(_obj)
  {
    isCollapsed = !isCollapsed
    this.scene.findObject(blockId).collapsed = isCollapsed ? "yes" : "no"
    updateInfo(true)
  }

  function onUpdate(_obj, dt)
  {
    if (!isCollapsed)
      return

    collapsedInfoTimer -= dt
    if (collapsedInfoTimer < 0)
      setNewCollapsedInfo()
  }

  function onEventMissionCustomStateChanged(_p)
  {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventMyCustomStateChanged(_p)
  {
    this.doWhenActiveOnce("updateInfo")
  }
}
