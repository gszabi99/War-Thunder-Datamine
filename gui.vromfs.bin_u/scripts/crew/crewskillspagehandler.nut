local stdMath = require("std/math.nut")
local { getSkillDescriptionView } = require("scripts/crew/crewSkillParameters.nut")
local { getSkillValue } = require("scripts/crew/crewSkills.nut")

local class CrewSkillsPageHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/empty.blk"
  sceneTplName = "gui/crew/crewSkillRow"
  isPrimaryFocus = false
  pageBonuses = null
  repeatButton = false
  needAskBuySkills = false
  pageOnInit = false
  isHandlerVisible = true

  crew = null
  curPage = null
  curCrewUnitType = ::CUT_INVALID
  curPoints = 0
  onSkillRowChangeCb = null
  unit = null

  function initScreen()
  {
    if (!curPage || !crew)
    {
      scene = null //make handler invalid to unsubscribe from events.
      ::script_net_assert_once("failed load crewSkillsPage", ::format("Error: try to init CrewSkillsPageHandler without page data (%s) or crew (%s)",
                                   ::toString(curPage), ::toString(crew)))
      return
    }

    pageBonuses = getItemsBonuses(curPage)
    pageOnInit = true
    updateSkills()

    initFocusArray()
    pageOnInit = false
  }

  function loadSceneTpl(row = null)
  {
    local rows = []
    local obj = scene
    if (row != null)
    {
       obj = scene.findObject(getRowName(row))
       local item = curPage.items?[row]
       if (!::checkObj(obj) || !item)
         return

       rows.append(getSkillRowConfig(row))
    }
    else
      foreach(idx, item in curPage.items)
        if (item.isVisible(curCrewUnitType))
          rows.append(getSkillRowConfig(idx))

    local view = { rows = rows, needAddRow = row == null }
    if (unit != null)
    {
      view.buySpecTooltipId1 <- ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(crew, unit)
      view.buySpecTooltipId2 <- ::g_crew_spec_type.ACE.getBtnBuyTooltipId(crew, unit)
    }

    local data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    if (row != null)
      return

    local totalRows = scene.childrenCount()
    if (totalRows > 0 && totalRows <= scene.getValue())
      scene.setValue(0)
    else
      ::selectTableNavigatorObj(scene)
  }

  function getMainFocusObj()
  {
    return scene
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
    local bonuses = []
    local curGunnersMul = 1.0
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    local curSpecMul = specType.getMulValue()
    if (page.id=="gunner")
    {
      local airGunners = ::getTblValue("gunnersCount", unit, 0)
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
      local hasSpecMul = item.useSpecializations && item.isVisible(curCrewUnitType)
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
    return ::format("skill_row%d", rowIndex)
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
      local rowObj = scene.findObject(getRowName(idx))
      if (!::checkObj(rowObj))
        continue

      local newCost = ::g_crew.getNextSkillStepCost(item, item?.newValue ?? getSkillValue(crew.id, unit, curPage.id, item.name))
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

    local row = ::g_crew.getButtonRow(obj, scene, scene)
    if (curPage.items.len() > 0 && (!repeatButton || isRepeat))
    {
      local item = curPage.items[row]
      local value = getSkillValue(crew.id, unit, curPage.id, item.name)
      local newValue = item.newValue
      if (limit)
        newValue += inc ? getSkillMaxAvailable(item) : item.value
      else
        newValue = ::g_crew.getNextSkillStepValue(item, newValue, inc)
      newValue = ::clamp(newValue, value, ::g_crew.getMaxSkillValue(item))
      if (newValue == item.newValue)
        return
      local changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
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

    local row = ::g_crew.getButtonRow(obj, scene, scene)
    if (curPage.items.len() == 0)
      return

    local item = curPage.items[row]
    local newStep = obj.getValue()
    if (newStep == ::g_crew.skillValueToStep(item, item.newValue))
      return

    local newValue = ::g_crew.skillStepToValue(item, newStep)
    local value = getSkillValue(crew.id, unit, curPage.id, item.name)
    local maxValue = getSkillMaxAvailable(item)
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
    local changeCost = ::g_crew.getSkillCost(item, newValue, item.newValue)
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
    if (::checkObj(guiScene["buySkillPoints"]))
      return

    local spendGold = ::has_feature("SpendGold")
    local text = ::loc("shop/notEnoughSkillPoints")
    local cancelButtonName = spendGold? "no" : "ok"
    local buttonsArray = [[cancelButtonName, function(){}]]
    local defaultButton = "ok"
    if (spendGold)
    {
      text += "\n" + loc("shop/purchaseMoreSkillPoints")
      buttonsArray.insert(0,["yes", (@(crew) function() { ::g_crew.createCrewBuyPointsHandler(crew) })(crew)])
      defaultButton = "yes"
    }
    msgBox("buySkillPoints", text, buttonsArray, defaultButton)
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
    local memberName = obj?.memberName ?? ""
    local skillName = obj?.skillName ?? ""
    local difficulty = ::get_current_shop_difficulty()
    local view = getSkillDescriptionView(
      crew, difficulty, memberName, skillName, curCrewUnitType, unit)
    local data = ::handyman.renderCached("gui/crew/crewSkillParametersTooltip", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function getSkillRowConfig(idx)
  {
    local item = curPage.items?[idx]
    if (!item)
      return null

    local value = getSkillValue(crew.id, unit, curPage.id, item.name)
    if (!("newValue" in item))
      item.newValue <- value

    local newProgressValue = ::g_crew.skillValueToStep(item, item.newValue)
    local bonusData = pageBonuses?[idx]
    local bonusText = ""
    local bonusOverlayTextColor = "good"
    local bonusTooltip = ""
    if (bonusData)
    {
      local totalSkill = bonusData.mul * item.newValue + bonusData.add
      local bonusLevel = ::g_crew.getSkillCrewLevel(item, totalSkill, item.newValue)
      local addLevel   = ::g_crew.getSkillCrewLevel(item, totalSkill, totalSkill - bonusData.add)

      if ((totalSkill - item.newValue).tointeger() != 0 && bonusData.add != 0)
        bonusText = ((bonusLevel >= 0) ? "+" : "") + stdMath.round_by_value(bonusLevel, 0.01)
      bonusOverlayTextColor = (bonusLevel < 0) ? "bad" : "good"

      if (bonusData.add > 0)
        bonusTooltip = ::loc("crew/qualifyBonus") + ::loc("ui/colon")
                  + ::colorize("goodTextColor", "+" + stdMath.round_by_value(addLevel, 0.01))

      local lvlDiffByGunners = stdMath.round_by_value(bonusLevel - addLevel, 0.01)
      if (lvlDiffByGunners < 0)
        bonusTooltip += ((bonusTooltip != "") ? "\n" : "") + ::loc("crew/notEnoughGunners") + ::loc("ui/colon")
          + "<color=@badTextColor>" + lvlDiffByGunners + "</color>"
    }

    local level = ::g_crew.getCrewLevel(crew, unit, unit?.getCrewUnitType?() ?? ::CUT_INVALID)
    local isRecrutedCrew = isRecrutedCurCrew()
    return {
      id = getRowName(idx)
      rowIdx = idx
      even = idx % 2 == 0
      skillName = item.name
      memberName = curPage.id
      name = ::loc("crew/" + item.name)
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
    local curSpecCode = bonusData.specType.code
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
