//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let stdMath = require("%sqstd/math.nut")
let { getSkillDescriptionView } = require("%scripts/crew/crewSkillParameters.nut")
let { getSkillValue } = require("%scripts/crew/crewSkills.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getCrewSpTextIfNotZero } = require("%scripts/crew/crewPoints.nut")
let { upgradeUnitSpec } = require("%scripts/crew/crewActionsWithMsgBox.nut")

local class CrewSkillsPageHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"
  sceneTplName = "%gui/crew/crewSkillRow.tpl"
  pageBonuses = null
  repeatButton = false
  needAskBuySkills = false
  pageOnInit = false
  isHandlerVisible = true

  crew = null
  curPage = null
  curCrewUnitType = CUT_INVALID
  curPoints = 0
  onSkillRowChangeCb = null
  unit = null

  function initScreen() {
    if (!this.curPage || !this.crew) {
      this.scene = null //make handler invalid to unsubscribe from events.
      script_net_assert_once("failed load crewSkillsPage", format("Error: try to init CrewSkillsPageHandler without page data (%s) or crew (%s)",
                                   toString(this.curPage), toString(this.crew)))
      return
    }

    this.pageBonuses = this.getItemsBonuses(this.curPage)
    this.pageOnInit = true
    this.updateSkills()

    this.pageOnInit = false
  }

  function loadSceneTpl(row = null) {
    let rows = []
    local obj = this.scene
    if (row != null) {
       obj = this.scene.findObject(this.getRowName(row))
       let item = this.curPage.items?[row]
       if (!checkObj(obj) || !item)
         return

       rows.append(this.getSkillRowConfig(row))
    }
    else
      foreach (idx, item in this.curPage.items)
        if (item.isVisible(this.curCrewUnitType))
          rows.append(this.getSkillRowConfig(idx))

    let view = { rows = rows, needAddRow = row == null }
    if (this.unit != null) {
      view.buySpecTooltipId1 <- ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(this.crew, this.unit)
      view.buySpecTooltipId2 <- ::g_crew_spec_type.ACE.getBtnBuyTooltipId(this.crew, this.unit)
    }

    let data = handyman.renderCached(this.sceneTplName, view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)

    if (row != null)
      return

    let totalRows = this.scene.childrenCount()
    if (totalRows > 0 && totalRows <= this.scene.getValue())
      this.scene.setValue(0)
  }

  function setHandlerVisible(value) {
    this.isHandlerVisible = value
    this.scene.show(value)
    this.scene.enable(value)
  }

  function updateHandlerData(params) {
    this.curPage = params.curPage
    this.crew = params.crew
    this.curCrewUnitType = params.curCrewUnitType
    this.curPoints = params.curPoints
    this.unit = params.unit
    this.pageBonuses = this.getItemsBonuses(this.curPage)
    if (!this.curPage)
      return

    this.updateSkills()
  }

  function getItemsBonuses(page) {
    let bonuses = []
    local curGunnersMul = 1.0
    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(this.crew, this.unit)
    let curSpecMul = specType.getMulValue()
    if (page.id == "gunner") {
      let airGunners = getTblValue("gunnersCount", this.unit, 0)
      local curGunners = getSkillValue(this.crew.id, this.unit, "gunner", "members")
      foreach (item in page.items)
        if (item.name == "members" && "newValue" in item) {
          curGunners = item.newValue
          break
        }

      if (airGunners > curGunners)
        curGunnersMul = curGunners.tofloat() / airGunners
    }

    foreach (item in page.items) {
      let hasSpecMul = item.useSpecializations && item.isVisible(this.curCrewUnitType)
      bonuses.append({
        add =  hasSpecMul ? curSpecMul * ::g_crew.getMaxSkillValue(item) : 0.0
        mul = (item.name == "members") ? 1.0 : curGunnersMul
        haveSpec = item.useSpecializations
        specType = specType
      })
    }

    return bonuses
  }

  function getRowName(rowIndex) {
    return format("skill_row%d", rowIndex)
  }

  function getCurPoints() {
    return this.curPoints
  }

  function updateIncButtons(items) {
    foreach (idx, item in items) {
      if (!item.isVisible(this.curCrewUnitType))
        continue
      let rowObj = this.scene.findObject(this.getRowName(idx))
      if (!checkObj(rowObj))
        continue

      let newCost = ::g_crew.getNextSkillStepCost(item, item?.newValue ?? getSkillValue(this.crew.id, this.unit, this.curPage.id, item.name))
      rowObj.findObject($"buttonInc_{idx}").inactiveColor = (newCost > 0 && newCost <= this.getCurPoints()) ? "no" : "yes"
      rowObj.findObject("availableSkillProgress").setValue(::g_crew.skillValueToStep(item, this.getSkillMaxAvailable(item)))
    }
  }

  function applySkillRowChange(row, item, newValue) {
    this.onSkillRowChangeCb?(item, newValue)
    this.guiScene.performDelayed(this, function() {
      if (this.isValid())
        this.updateSkills(row)
    })
  }

  function onProgressButton(obj, inc, isRepeat = false, limit = false) {
    if (!this.isRecrutedCurCrew())
      return

    let row = ::g_crew.getButtonRow(obj, this.scene, this.scene)
    if (this.curPage.items.len() > 0 && (!this.repeatButton || isRepeat)) {
      let item = this.curPage.items[row]
      let value = getSkillValue(this.crew.id, this.unit, this.curPage.id, item.name)
      local newValue = item.newValue
      if (limit)
        newValue += inc ? this.getSkillMaxAvailable(item) : item.value
      else
        newValue = ::g_crew.getNextSkillStepValue(item, newValue, inc)
      newValue = clamp(newValue, value, ::g_crew.getMaxSkillValue(item))
      if (newValue == item.newValue)
        return
      let changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
      if (this.getCurPoints() - changeCost < 0) {
        if (isRepeat)
          this.needAskBuySkills = true
        else
          this.askBuySkills()
        return
      }

      this.applySkillRowChange(row, item, newValue)
    }
    this.repeatButton = isRepeat
  }

  function onButtonInc(obj) {
    this.onProgressButton(obj, true)
  }

  function onButtonDec(obj) {
    this.onProgressButton(obj, false)
  }

  function onButtonIncRepeat(obj) {
    this.onProgressButton(obj, true, true)
  }

  function onButtonDecRepeat(obj) {
    this.onProgressButton(obj, false, true)
  }

  function onButtonMax(_obj) {
    // onProgressButton(obj, true, true)
  }

  function getSkillMaxAvailable(skillItem) {
    return ::g_crew.getMaxAvailbleStepValue(skillItem, skillItem.newValue, this.getCurPoints())
  }

  function updateSkills(row = null, needUpdateIncButton = true) {
    if (row == null || (this.curPage.items[row].name == "members" && this.curPage.id == "gunner"))
      this.loadSceneTpl()
    else
      this.loadSceneTpl(row)

    if (needUpdateIncButton)
      this.updateIncButtons(this.curPage.items)
  }

  function onSkillChanged(obj) {
    if (this.pageOnInit || !obj || !this.isRecrutedCurCrew())
      return

    let row = ::g_crew.getButtonRow(obj, this.scene, this.scene)
    if (this.curPage.items.len() == 0)
      return

    let item = this.curPage.items[row]
    let newStep = obj.getValue()
    if (newStep == ::g_crew.skillValueToStep(item, item.newValue))
      return

    local newValue = ::g_crew.skillStepToValue(item, newStep)
    let value = getSkillValue(this.crew.id, this.unit, this.curPage.id, item.name)
    let maxValue = this.getSkillMaxAvailable(item)
    if (newValue < value)
      newValue = value
    if (newValue > maxValue) {
      newValue = maxValue
      if (item.newValue == maxValue)
        this.askBuySkills()
    }
    if (newValue == item.newValue) {
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.updateSkills(row, false)
      })
      return
    }
    let changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
    if (this.getCurPoints() - changeCost < 0) {
      this.askBuySkills()
      return
    }

    this.applySkillRowChange(row, item, newValue)
  }

  function askBuySkills() {
    this.needAskBuySkills = false

    // Duplicate check.
    if (checkObj(this.guiScene["buySkillPoints"]))
      return

    let spendGold = hasFeature("SpendGold")
    local text = loc("shop/notEnoughSkillPoints")
    let cancelButtonName = spendGold ? "no" : "ok"
    let buttonsArray = [[cancelButtonName, function() {}]]
    local defaultButton = "ok"
    if (spendGold) {
      text += "\n" + loc("shop/purchaseMoreSkillPoints")
      buttonsArray.insert(0, ["yes", (@(crew) function() { ::g_crew.createCrewBuyPointsHandler(crew) })(this.crew)]) //-ident-hides-ident
      defaultButton = "yes"
    }
    this.msgBox("buySkillPoints", text, buttonsArray, defaultButton)
  }

  function onSpecIncrease(nextSpecType) {
    upgradeUnitSpec(this.crew, this.unit, this.curCrewUnitType, nextSpecType)
  }

  function onSpecIncrease1() {
    this.onSpecIncrease(::g_crew_spec_type.EXPERT)
  }

  function onSpecIncrease2() {
    this.onSpecIncrease(::g_crew_spec_type.ACE)
  }

  function onSkillRowTooltipOpen(obj) {
    let memberName = obj?.memberName ?? ""
    let skillName = obj?.skillName ?? ""
    let difficulty = ::get_current_shop_difficulty()
    let view = getSkillDescriptionView(
      this.crew, difficulty, memberName, skillName, this.curCrewUnitType, this.unit)
    let data = handyman.renderCached("%gui/crew/crewSkillParametersTooltip.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function getSkillRowConfig(idx) {
    let item = this.curPage.items?[idx]
    if (!item)
      return null

    let value = getSkillValue(this.crew.id, this.unit, this.curPage.id, item.name)
    if (!("newValue" in item))
      item.newValue <- value
    local curValue = ::g_crew.getSkillCrewLevel(item, item.newValue)
    let newProgressValue = ::g_crew.skillValueToStep(item, item.newValue)
    let bonusData = this.pageBonuses?[idx]
    local bonusTooltip = ""
    if (bonusData) {
      let totalSkill = bonusData.mul * item.newValue + bonusData.add
      let bonusLevel = ::g_crew.getSkillCrewLevel(item, totalSkill, item.newValue)
      let addLevel   = ::g_crew.getSkillCrewLevel(item, totalSkill, totalSkill - bonusData.add)

      if ((totalSkill - item.newValue).tointeger() != 0 && bonusData.add != 0)
        curValue += stdMath.round_by_value(bonusLevel, 0.01)

      if (bonusData.add > 0)
        bonusTooltip = loc("crew/qualifyBonus") + loc("ui/colon")
                  + colorize("goodTextColor", "+" + stdMath.round_by_value(addLevel, 0.01))

      let lvlDiffByGunners = stdMath.round_by_value(bonusLevel - addLevel, 0.01)
      if (lvlDiffByGunners < 0)
        bonusTooltip += ((bonusTooltip != "") ? "\n" : "") + loc("crew/notEnoughGunners") + loc("ui/colon")
          + "<color=@badTextColor>" + lvlDiffByGunners + "</color>"
    }

    let level = ::g_crew.getCrewLevel(this.crew, this.unit, this.unit?.getCrewUnitType?() ?? CUT_INVALID)
    let isRecrutedCrew = this.isRecrutedCurCrew()

    return {
      id = this.getRowName(idx)
      rowIdx = idx
      even = idx % 2 == 0
      skillName = item.name
      memberName = this.curPage.id
      name = loc("crew/" + item.name)
      progressMax = ::g_crew.getTotalSteps(item)
      maxSkillCrewLevel = ::g_crew.getSkillMaxCrewLevel(item)
      maxValue = ::g_crew.getMaxSkillValue(item)
      bonusTooltip = bonusTooltip
      progressEnable = isRecrutedCrew ? "yes" : "no"
      skillProgressValue = value
      shadeSkillProgressValue = value
      newSkillProgressValue = newProgressValue
      glowSkillProgressValue = newProgressValue
      skillSliderValue = ::g_crew.skillValueToStep(item, item.newValue)
      curValue = curValue.tostring()
      visibleButtonDec = (item.newValue > value && isRecrutedCrew)
        ? "show" : "hide"
      visibleButtonInc = (item.newValue < item.costTbl.len() && isRecrutedCrew)
        ? "show" : "hide"
      incCost = getCrewSpTextIfNotZero(::g_crew.getNextSkillStepCost(item, item.newValue))

      btnSpec = [
        this.getRowSpecButtonConfig(::g_crew_spec_type.EXPERT, level, bonusData),
        this.getRowSpecButtonConfig(::g_crew_spec_type.ACE, level, bonusData)
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, bonusData) {
    local icon = ""
    let curSpecCode = bonusData.specType.code
    if (bonusData && bonusData.haveSpec)
      icon = specType.getIcon(curSpecCode, crewLvl, this.unit)

    let isExpertSpecType = specType == ::g_crew_spec_type.EXPERT
    let isEnabled = icon != "" && curSpecCode < specType.code
    let barsCount = isExpertSpecType ? 3 : 2
    return {
      id = specType.code
      icon = icon
      enable = isEnabled ? "yes" : "no"
      display = (icon != "") ? "show" : "none" //"none" - hide but not affect button place
      isExpertSpecType
      bars = array(barsCount)
      barsCount
      barsType = isEnabled ? "#ui/gameuiskin#skill_star_place.svg" : "#ui/gameuiskin#skill_star_1.svg"
    }
  }

  setCurPoints = @(newPoints) this.curPoints = newPoints
  isRecrutedCurCrew = @() this.crew.id != -1
}

gui_handlers.CrewSkillsPageHandler <- CrewSkillsPageHandler

return @(params) handlersManager.loadHandler(CrewSkillsPageHandler, params)
