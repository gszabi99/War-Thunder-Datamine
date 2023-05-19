//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.teamUnitsLeftView <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/promo/promoBlocks.tpl"

  blockId = "leftUnits"

  missionRules = null
  isSceneLoaded = false
  isCollapsed = true

  collapsedInfoRefreshDelay = 4.0
  collapsedInfoUnitLimit = null
  collapsedInfoTimer = -1

  function initScreen() {
    this.scene.setUserData(this) //to not unload handler even when scene not loaded
    this.scene.findObject(this.blockId).setUserData(this)

    this.updateInfo()
  }

  function getSceneTplView() {
    if (this.isSceneLoaded)
      return null

    let view = {
      promoButtons = [{
        id = this.blockId
        type = "autoSize"
        show = true
        inputTransparent = true
        needTextShade = true
        showTextShade = true
        hideHeaderBg = true
        collapsed = this.isCollapsed ? "yes" : "no"
        timerFunc = "onUpdate"
        needCollapsedTextAnimSwitch = true
        hasSafeAreaPadding = "no"

        fillBlocks = [{}]
      }]
    }

    this.isSceneLoaded = true
    return view
  }

  function getRespTextByUnitLimit(unitLimit) {
    return unitLimit ? unitLimit.getText() : ""
  }

  function getFullUnitsText() {
    let data = this.missionRules.getFullUnitLimitsData()
    let textsList = u.map(data.unitLimits, this.getRespTextByUnitLimit)
    textsList.insert(0, colorize("activeTextColor", loc(this.missionRules.customUnitRespawnsAllyListHeaderLocId)))

    if (this.missionRules.isEnemyLimitedUnitsVisible()) {
      let enemyData = this.missionRules.getFullEnemyUnitLimitsData()
      if (enemyData.len()) {
        let enemyTextsList = u.map(enemyData.unitLimits, this.getRespTextByUnitLimit)
        textsList.append("\n" + colorize("activeTextColor", loc(this.missionRules.customUnitRespawnsEnemyListHeaderLocId)))
        textsList.extend(enemyTextsList)
      }
    }

    return "\n".join(textsList, true)
  }

  function updateInfo(isJustSwitched = false) {
    if (!this.isSceneLoaded)
      return

    if (this.isCollapsed)
      this.updateCollapsedInfoText(isJustSwitched)
    else
      this.scene.findObject(this.blockId + "_text").setValue(this.getFullUnitsText())
  }

  function updateCollapsedInfoByUnitLimit(unitLimit, needAnim = true) {
    this.collapsedInfoUnitLimit = unitLimit
    let text = this.getRespTextByUnitLimit(unitLimit)
    if (needAnim) {
      ::g_promo_view_utils.animSwitchCollapsedText(this.scene, this.blockId, text)
      return
    }

    let obj = ::g_promo_view_utils.getVisibleCollapsedTextObj(this.scene, this.blockId)
    if (checkObj(obj))
      obj.setValue(text)
  }

  function setNewCollapsedInfo(needAnim = true) {
    let data = this.missionRules.getFullUnitLimitsData()
    local prevIdx = -1
    if (this.collapsedInfoUnitLimit)
      prevIdx = data.unitLimits.findindex(this.collapsedInfoUnitLimit.isSame.bindenv(this.collapsedInfoUnitLimit)) ?? -1

    this.updateCollapsedInfoByUnitLimit(u.chooseRandomNoRepeat(data.unitLimits, prevIdx), needAnim)
    this.collapsedInfoTimer = this.collapsedInfoRefreshDelay
  }

  function updateCollapsedInfoText(isJustSwitched = false) {
    if (isJustSwitched || !this.collapsedInfoUnitLimit)
      return this.setNewCollapsedInfo(!isJustSwitched)

    let data = this.missionRules.getFullUnitLimitsData()
    let newUnitLimit = u.search(data.unitLimits, this.collapsedInfoUnitLimit.isSame.bindenv(this.collapsedInfoUnitLimit))
    if (newUnitLimit)
      this.updateCollapsedInfoByUnitLimit(newUnitLimit, false)
    else
      this.setNewCollapsedInfo()
  }

  function onToggleItem(_obj) {
    this.isCollapsed = !this.isCollapsed
    this.scene.findObject(this.blockId).collapsed = this.isCollapsed ? "yes" : "no"
    this.updateInfo(true)
  }

  function onUpdate(_obj, dt) {
    if (!this.isCollapsed)
      return

    this.collapsedInfoTimer -= dt
    if (this.collapsedInfoTimer < 0)
      this.setNewCollapsedInfo()
  }

  function onEventMissionCustomStateChanged(_p) {
    this.doWhenActiveOnce("updateInfo")
  }

  function onEventMyCustomStateChanged(_p) {
    this.doWhenActiveOnce("updateInfo")
  }
}
