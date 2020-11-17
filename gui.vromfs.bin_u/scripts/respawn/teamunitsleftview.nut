class ::gui_handlers.teamUnitsLeftView extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/promo/promoBlocks"

  blockId = "leftUnits"

  missionRules = null
  isSceneLoaded = false
  isCollapsed = true

  collapsedInfoRefreshDelay = 4.0
  collapsedInfoUnitLimit = null
  collapsedInfoTimer = -1

  function initScreen()
  {
    scene.setUserData(this) //to not unload handler even when scene not loaded
    scene.findObject(blockId).setUserData(this)

    updateInfo()
  }

  function getSceneTplView()
  {
    if (isSceneLoaded)
      return null

    local view = {
      promoButtons = [{
        id = blockId
        type = "autoWidth"
        show = true
        inputTransparent = true
        needTextShade = true
        showTextShade = true
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
    local data = missionRules.getFullUnitLimitsData()
    local textsList = ::u.map(data.unitLimits, getRespTextByUnitLimit)
    textsList.insert(0, ::colorize("activeTextColor", ::loc(missionRules.customUnitRespawnsAllyListHeaderLocId)))

    if (missionRules.isEnemyLimitedUnitsVisible())
    {
      local enemyData = missionRules.getFullEnemyUnitLimitsData()
      if (enemyData.len())
      {
        local enemyTextsList = ::u.map(enemyData.unitLimits, getRespTextByUnitLimit)
        textsList.append("\n" + ::colorize("activeTextColor", ::loc(missionRules.customUnitRespawnsEnemyListHeaderLocId)))
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
      scene.findObject(blockId + "_text").setValue(getFullUnitsText())
  }

  function updateCollapsedInfoByUnitLimit(unitLimit, needAnim = true)
  {
    collapsedInfoUnitLimit = unitLimit
    local text = getRespTextByUnitLimit(unitLimit)
    if (needAnim)
    {
      ::g_promo_view_utils.animSwitchCollapsedText(scene, blockId, text)
      return
    }

    local obj = ::g_promo_view_utils.getVisibleCollapsedTextObj(scene, blockId)
    if (::checkObj(obj))
      obj.setValue(text)
  }

  function setNewCollapsedInfo(needAnim = true)
  {
    local data = missionRules.getFullUnitLimitsData()
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

    local data = missionRules.getFullUnitLimitsData()
    local newUnitLimit = ::u.search(data.unitLimits, collapsedInfoUnitLimit.isSame.bindenv(collapsedInfoUnitLimit))
    if (newUnitLimit)
      updateCollapsedInfoByUnitLimit(newUnitLimit, false)
    else
      setNewCollapsedInfo()
  }

  function onToggleItem(obj)
  {
    isCollapsed = !isCollapsed
    scene.findObject(blockId).collapsed = isCollapsed ? "yes" : "no"
    updateInfo(true)
  }

  function onUpdate(obj, dt)
  {
    if (!isCollapsed)
      return

    collapsedInfoTimer -= dt
    if (collapsedInfoTimer < 0)
      setNewCollapsedInfo()
  }

  function onEventMissionCustomStateChanged(p)
  {
    doWhenActiveOnce("updateInfo")
  }

  function onEventMyCustomStateChanged(p)
  {
    doWhenActiveOnce("updateInfo")
  }
}
