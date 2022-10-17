from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let stdMath = require("%sqstd/math.nut")
let { getSkillDescriptionView } = require("%scripts/crew/crewSkillParameters.nut")
let { getSkillValue } = require("%scripts/crew/crewSkills.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

local class CrewSkillsPageHandler extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/empty.blk"
  sceneTplName = "%gui/crew/crewSkillRow"
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

  function initScreen()
  {
    if (!curPage || !crew)
    {
      scene = null //make handler invalid to unsubscribe from events.
      ::script_net_assert_once("failed load crewSkillsPage", format("Error: try to init CrewSkillsPageHandler without page data (%s) or crew (%s)",
                                   toString(curPage), toString(crew)))
      return
    }

    pageBonuses = getItemsBonuses(curPage)
    pageOnInit = true
    updateSkills()

    pageOnInit = false
  }

  function loadSceneTpl(row = null)
  {
    let rows = []
    local obj = scene
    if (row != null)
    {
       obj = scene.findObject(getRowName(row))
       let item = curPage.items?[row]
       if (!checkObj(obj) || !item)
         return

       rows.append(getSkillRowConfig(row))
    }
    else
      foreach(idx, item in curPage.items)
        if (item.isVisible(curCrewUnitType))
          rows.append(getSkillRowConfig(idx))

    let view = { rows = rows, needAddRow = row == null }
    if (unit != null)
    {
      view.buySpecTooltipId1 <- ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(crew, unit)
      view.buySpecTooltipId2 <- ::g_crew_spec_type.ACE.getBtnBuyTooltipId(crew, unit)
    }

    let data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    if (row != null)
      return

    let totalRows = scene.childrenCount()
    if (totalRows > 0 && totalRows <= scene.getValue())
      scene.setValue(0)
  }

  function setHandlerVisible(value)
  {
    isHandlerVisible = value
    scene.show(value)
    scene.enable(value)
  }

  function updateHandlerData(params)
  {
    curPage = params.curPage
    crew = params.crew
    curCrewUnitType = params.curCrewUnitType
    curPoints = params.curPoints
    unit = params.unit
    pageBonuses = getItemsBonuses(curPage)
    if (!curPage)
      return

    updateSkills()
  }

  function getItemsBonuses(page)
  {
    let bonuses = []
    local curGunnersMul = 1.0
    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    let curSpecMul = specType.getMulValue()
    if (page.id=="gunner")
    {
      let airGunners = getTblValue("gunnersCount", unit, 0)
      local curGunners = getSkillValue(crew.id, unit, "gunner", "members")
      foreach (item in page.items)
        if(item.name == "members" && "newValue" in item)
        {
          curGunners = item.newValue
          break
        }

      if (airGunners > curGunners)
        curGunnersMul = curGunners.tofloat() / airGunners
    }

    foreach(item in page.items)
    {
      let hasSpecMul = item.useSpecializations && item.isVisible(curCrewUnitType)
      bonuses.append({
        add =  hasSpecMul ? curSpecMul * ::g_crew.getMaxSkillValue(item) : 0.0
        mul = (item.name == "members") ? 1.0 : curGunnersMul
        haveSpec = item.useSpecializations
        specType = specType
      })
    }

    return bonuses
  }

  function getRowName(rowIndex)
  {
    return format("skill_row%d", rowIndex)
  }

  function getCurPoints()
  {
    return curPoints
  }

  function updateIncButtons(items)
  {
    foreach(idx, item in items)
    {
      if (!item.isVisible(curCrewUnitType))
        continue
      let rowObj = scene.findObject(getRowName(idx))
      if (!checkObj(rowObj))
        continue

      let newCost = ::g_crew.getNextSkillStepCost(item, item?.newValue ?? getSkillValue(crew.id, unit, curPage.id, item.name))
      rowObj.findObject("buttonInc").inactiveColor = (newCost > 0 && newCost <= getCurPoints()) ? "no" : "yes"
      rowObj.findObject("availableSkillProgress").setValue(::g_crew.skillValueToStep(item, getSkillMaxAvailable(item)))
    }
  }

  function applySkillRowChange(row, item, newValue)
  {
    onSkillRowChangeCb?(item, newValue)
    guiScene.performDelayed(this, function() {
      if (isValid())
        updateSkills(row)
    })
  }

  function onProgressButton(obj, inc, isRepeat = false, limit = false)
  {
    if (!isRecrutedCurCrew())
      return

    let row = ::g_crew.getButtonRow(obj, scene, scene)
    if (curPage.items.len() > 0 && (!repeatButton || isRepeat))
    {
      let item = curPage.items[row]
      let value = getSkillValue(crew.id, unit, curPage.id, item.name)
      local newValue = item.newValue
      if (limit)
        newValue += inc ? getSkillMaxAvailable(item) : item.value
      else
        newValue = ::g_crew.getNextSkillStepValue(item, newValue, inc)
      newValue = clamp(newValue, value, ::g_crew.getMaxSkillValue(item))
      if (newValue == item.newValue)
        return
      let changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
      if (getCurPoints() - changeCost < 0)
      {
        if (isRepeat)
          needAskBuySkills = true
        else
          askBuySkills()
        return
      }

      applySkillRowChange(row, item, newValue)
    }
    repeatButton = isRepeat
  }

  function onButtonInc(obj)
  {
    onProgressButton(obj, true)
  }

  function onButtonDec(obj)
  {
    onProgressButton(obj, false)
  }

  function onButtonIncRepeat(obj)
  {
    onProgressButton(obj, true, true)
  }

  function onButtonDecRepeat(obj)
  {
    onProgressButton(obj, false, true)
  }

  function onButtonMax(obj)
  {
    // onProgressButton(obj, true, true)
  }

  function getSkillMaxAvailable(skillItem)
  {
    return ::g_crew.getMaxAvailbleStepValue(skillItem, skillItem.newValue, getCurPoints())
  }

  function updateSkills(row = null, needUpdateIncButton = true)
  {
    if(row == null || (curPage.items[row].name == "members" && curPage.id == "gunner"))
      loadSceneTpl()
    else
      loadSceneTpl(row)

    if (needUpdateIncButton)
      updateIncButtons(curPage.items)
  }

  function onSkillChanged(obj)
  {
    if (pageOnInit || !obj || !isRecrutedCurCrew())
      return

    let row = ::g_crew.getButtonRow(obj, scene, scene)
    if (curPage.items.len() == 0)
      return

    let item = curPage.items[row]
    let newStep = obj.getValue()
    if (newStep == ::g_crew.skillValueToStep(item, item.newValue))
      return

    local newValue = ::g_crew.skillStepToValue(item, newStep)
    let value = getSkillValue(crew.id, unit, curPage.id, item.name)
    let maxValue = getSkillMaxAvailable(item)
    if (newValue < value)
      newValue = value
    if (newValue > maxValue)
    {
      newValue = maxValue
      if (item.newValue == maxValue)
        askBuySkills()
    }
    if (newValue == item.newValue)
    {
      guiScene.performDelayed(this, function() {
        if (isValid())
          updateSkills(row, false)
      })
      return
    }
    let changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
    if (getCurPoints() - changeCost < 0)
    {
      askBuySkills()
      return
    }

    applySkillRowChange(row, item, newValue)
  }

  function askBuySkills()
  {
    needAskBuySkills = false

    // Duplicate check.
    if (checkObj(guiScene["buySkillPoints"]))
      return

    let spendGold = hasFeature("SpendGold")
    local text = loc("shop/notEnoughSkillPoints")
    let cancelButtonName = spendGold? "no" : "ok"
    let buttonsArray = [[cancelButtonName, function(){}]]
    local defaultButton = "ok"
    if (spendGold)
    {
      text += "\n" + loc("shop/purchaseMoreSkillPoints")
      buttonsArray.insert(0,["yes", (@(crew) function() { ::g_crew.createCrewBuyPointsHandler(crew) })(crew)])
      defaultButton = "yes"
    }
    this.msgBox("buySkillPoints", text, buttonsArray, defaultButton)
  }

  function onSpecIncrease(nextSpecType)
  {
    ::g_crew.upgradeUnitSpec(crew, unit, curCrewUnitType, nextSpecType)
  }

  function onSpecIncrease1()
  {
    onSpecIncrease(::g_crew_spec_type.EXPERT)
  }

  function onSpecIncrease2()
  {
    onSpecIncrease(::g_crew_spec_type.ACE)
  }

  function onSkillRowTooltipOpen(obj)
  {
    let memberName = obj?.memberName ?? ""
    let skillName = obj?.skillName ?? ""
    let difficulty = ::get_current_shop_difficulty()
    let view = getSkillDescriptionView(
      crew, difficulty, memberName, skillName, curCrewUnitType, unit)
    let data = ::handyman.renderCached("%gui/crew/crewSkillParametersTooltip", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function getSkillRowConfig(idx)
  {
    let item = curPage.items?[idx]
    if (!item)
      return null

    let value = getSkillValue(crew.id, unit, curPage.id, item.name)
    if (!("newValue" in item))
      item.newValue <- value

    let newProgressValue = ::g_crew.skillValueToStep(item, item.newValue)
    let bonusData = pageBonuses?[idx]
    local bonusText = ""
    local bonusOverlayTextColor = "good"
    local bonusTooltip = ""
    if (bonusData)
    {
      let totalSkill = bonusData.mul * item.newValue + bonusData.add
      let bonusLevel = ::g_crew.getSkillCrewLevel(item, totalSkill, item.newValue)
      let addLevel   = ::g_crew.getSkillCrewLevel(item, totalSkill, totalSkill - bonusData.add)

      if ((totalSkill - item.newValue).tointeger() != 0 && bonusData.add != 0)
        bonusText = ((bonusLevel >= 0) ? "+" : "") + stdMath.round_by_value(bonusLevel, 0.01)
      bonusOverlayTextColor = (bonusLevel < 0) ? "bad" : "good"

      if (bonusData.add > 0)
        bonusTooltip = loc("crew/qualifyBonus") + loc("ui/colon")
                  + colorize("goodTextColor", "+" + stdMath.round_by_value(addLevel, 0.01))

      let lvlDiffByGunners = stdMath.round_by_value(bonusLevel - addLevel, 0.01)
      if (lvlDiffByGunners < 0)
        bonusTooltip += ((bonusTooltip != "") ? "\n" : "") + loc("crew/notEnoughGunners") + loc("ui/colon")
          + "<color=@badTextColor>" + lvlDiffByGunners + "</color>"
    }

    let level = ::g_crew.getCrewLevel(crew, unit, unit?.getCrewUnitType?() ?? CUT_INVALID)
    let isRecrutedCrew = isRecrutedCurCrew()
    return {
      id = getRowName(idx)
      rowIdx = idx
      even = idx % 2 == 0
      skillName = item.name
      memberName = curPage.id
      name = loc("crew/" + item.name)
      progressMax = ::g_crew.getTotalSteps(item)
      maxSkillCrewLevel = ::g_crew.getSkillMaxCrewLevel(item)
      maxValue = ::g_crew.getMaxSkillValue(item)
      havePageBonuses = pageBonuses != null
      bonusText = bonusText
      bonusOverlayTextColor = bonusOverlayTextColor
      bonusTooltip = bonusTooltip
      progressEnable = isRecrutedCrew ? "yes" : "no"
      skillProgressValue = value
      shadeSkillProgressValue = value
      newSkillProgressValue = newProgressValue
      glowSkillProgressValue = newProgressValue
      skillSliderValue = ::g_crew.skillValueToStep(item, item.newValue)
      curValue = ::g_crew.getSkillCrewLevel(item, item.newValue).tostring()
      visibleButtonDec = (item.newValue > value && isRecrutedCrew)
        ? "show" : "hide"
      visibleButtonInc = (item.newValue < item.costTbl.len() && isRecrutedCrew)
        ? "show" : "hide"
      incCost = ::get_crew_sp_text(::g_crew.getNextSkillStepCost(item, item.newValue), false)

      btnSpec = [
        getRowSpecButtonConfig(::g_crew_spec_type.EXPERT, level, bonusData),
        getRowSpecButtonConfig(::g_crew_spec_type.ACE, level, bonusData)
      ]
    }
  }

  function getRowSpecButtonConfig(specType, crewLvl, bonusData)
  {
    local icon = ""
    let curSpecCode = bonusData.specType.code
    if (bonusData && bonusData.haveSpec)
      icon = specType.getIcon(curSpecCode, crewLvl, unit)
    return {
      id = specType.code
      icon = icon
      enable = (icon != "" && curSpecCode < specType.code) ? "yes" : "no"
      display = (icon != "") ? "show" : "none" //"none" - hide but not affect button place
      isExpertSpecType = specType == ::g_crew_spec_type.EXPERT
    }
  }

  setCurPoints = @(newPoints) curPoints = newPoints
  isRecrutedCurCrew = @() crew.id != -1
}

::gui_handlers.CrewSkillsPageHandler <- CrewSkillsPageHandler

return @(params) ::handlersManager.loadHandler(CrewSkillsPageHandler, params)
