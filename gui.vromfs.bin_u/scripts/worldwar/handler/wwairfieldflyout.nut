local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local wwUnitClassParams = require("scripts/worldWar/inOperation/wwUnitClassParams.nut")
local wwActionsWithUnitsList = require("scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
local wwOperationUnitsGroups = require("scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")

class ::gui_handlers.WwAirfieldFlyOut extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptySceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/airfieldFlyOut"

  position = null //receives as Point2()
  armyTargetName = null
  onSuccessfullFlyoutCb = null

  airfield = null
  currentOperation = null

  accessList = null
  unitsList = null

  availableArmiesArray = null

  sendButtonObj = null
  selectedGroupIdx = null
  selectedGroupFlyArmies = 0
  isArmyComboValue = false

  maxChoosenUnitsMask = WW_UNIT_CLASS.NONE //bitMask

  hasUnitsToFly = false
  prevSelectedUnitsMask = WW_UNIT_CLASS.NONE
  iconAir = ::loc("worldwar/iconAir")

  unitsGroups = null

  static function open(index, position, armyTargetName, onSuccessfullFlyoutCb = null)
  {
    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local availableArmiesArray = airfield.getAvailableFormations()
    if (!availableArmiesArray.len())
      return

    ::handlersManager.loadHandler(::gui_handlers.WwAirfieldFlyOut,
      {
        airfield = airfield,
        availableArmiesArray = availableArmiesArray
        position = position,
        armyTargetName = armyTargetName,
        onSuccessfullFlyoutCb = onSuccessfullFlyoutCb
      }
    )
  }

  function getSceneTplContainerObj() { return scene.findObject("root-box") }

  function getSceneTplView()
  {
    accessList = ::g_world_war.getMyAccessLevelListForCurrentBattle()
    currentOperation = ::g_operations.getCurrentOperation()
    unitsGroups = wwOperationUnitsGroups.getUnitsGroups()

    return {
      unitString = getUnitsList()
      headerTabs = getHeaderTabs()
      unitTypes = getUnitsTypesList()
      hintText = ::loc("worldwar/airfield/armies_hint_title")
        + "\n" + ::loc("worldwar/airfield/fighter_armies_hint", getAirsTypeViewParams())
        + "\n" + ::loc("worldwar/airfield/combined_armies_hint", getAirsTypeViewParams())
      hasUnitsGroups = unitsGroups != null
    }
  }

  function getUnitsList()
  {
    local flightTimeFactor = ::g_world_war.getWWConfigurableValue("maxFlightTimeMinutesMul", 1.0)
    unitsList = []
    foreach (airfieldFormation in availableArmiesArray)
      foreach (unit in airfieldFormation.units)
      {
        local name = unit.name
        local group = unitsGroups?[name]
        local displayUnit = group?.defaultUnit ?? unit.unit
        local unitWeapon = ::g_world_war.get_last_weapon_preset(name)
        local unitClassData = wwUnitClassParams.getUnitClassData(unit, unitWeapon)
        local maxFlyTime = (wwActionsWithUnitsList.getMaxFlyTime(displayUnit) * flightTimeFactor).tointeger()
        local value = 0
        local maxValue = unit.count
        local maxUnitClassValue = getUnitClassMaxValue(unitClassData.flyOutUnitClass)
        local unitClass = unitClassData.unitClass
        local isUnitsGroup = group != null
        unitsList.append({
          armyGroupIdx = airfieldFormation.getArmyGroupIdx()
          unit = unit
          unitName = name
          unitItem = wwActionsWithUnitsList.getUnitMarkUp(name, displayUnit, group,
            {nameLoc = ::loc(group?.name ?? "")})
          unitClassIconText = wwUnitClassParams.getIconText(unitClass)
          unitClassName = wwUnitClassParams.getText(unitClass)
          unitClassTooltipText = ::loc(unitClassData.tooltipTextLocId)
          unitClass = unitClassData.flyOutUnitClass
          unitClassesView = isUnitsGroup ? getUnitClassesView(unit, unitClass) : null
          maxValue = ::min(maxUnitClassValue, maxValue)
          maxUnitClassValue = maxUnitClassValue
          totalValue = maxValue
          value = value
          maxFlyTime = maxFlyTime
          maxFlyTimeText = getFlyTimeText(maxFlyTime)
          unitWeapon = unitWeapon
          btnOnDec = "onButtonDec"
          btnOnInc = "onButtonInc"
          btnOnMax = "onButtonMax"
          shortcutIcon = "Y"
          onChangeSliderValue = "onChangeSliderValue"
          needOldSlider = true
          needNewSlider = true
          isUnitsGroup  = isUnitsGroup
          expClassSortIdx = wwUnitClassParams.getSortIdx(unit.expClass)
          sliderButton = {
            type = "various"
            showWhenSelected = true
            sliderButtonText = getSliderButtonText(value, maxValue)
          }
        })
      }

    unitsList.sort(@(a, b) a.expClassSortIdx <=> b.expClassSortIdx || a.unitName <=> b.unitName)

    return unitsList
  }

  function getAirsTypeViewParams()
  {
    return {
      fighterIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.FIGHTER, true)
      assaultIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.ASSAULT, true)
      bomberIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.BOMBER, true)
    }
  }

  function getUnitsTypesList()
  {
    return [
      {
        unitType = WW_UNIT_CLASS.FIGHTER
        classIcons = [{ name = "Fighter", type = "fighter" }]
      },
      {
        unitType = WW_UNIT_CLASS.BOMBER
        classIcons = [
          { name = "Assault", type = "assault" },
          { name = "Bomber", type = "bomber", hasSeparator = true }
        ]
      }
    ]
  }

  function getFlyTimeText(timeInSeconds)
  {
    return time.hoursToString(time.secondsToHours(timeInSeconds), false, true) + " " + ::loc("icon/timer")
  }

  function getHeaderTabs()
  {
    local view = { tabs = [] }
    local selectedId = 0
    foreach (idx, airfieldFormation in availableArmiesArray)
    {
      view.tabs.append({
        tabName = airfieldFormation.getClanTag()
        navImagesText = ::get_navigation_images_text(idx, airfield.formations.len())
        selected = false
      })
    }
    if (view.tabs.len() > 0)
      view.tabs[selectedId].selected = true

    return ::handyman.renderCached("gui/frameHeaderTabs", view)
  }

  function getNavbarTplView()
  {
    return {
      right = [
        {
          id = "cant_send_reason"
          textField = true
        },
        {
          id = "send_aircrafts_button"
          funcName = "sendAircrafts"
          text = "#mainmenu/btnSend"
          isToBattle = true
          titleButtonFont = false
          shortcut = "A"
          button = true
          type = "wwArmyFlyOut"
        },
      ]
    }
  }

  function initScreen()
  {
    ::g_world_war_render.setCategory(::ERC_AIRFIELD_ARROW, false)

    sendButtonObj = scene.findObject("send_aircrafts_button")
    updateVisibleUnits()

    //--- After all units filled ---
    fillFlyOutDescription(true)
    fillArmyLimitDescription()
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene.findObject("unit_blocks_place")
  }

  function onTabSelect(obj)
  {
    updateVisibleUnits(obj.getValue())
    fillFlyOutDescription(true)
  }

  function updateVisibleUnits(tabVal = -1)
  {
    if (!availableArmiesArray.len())
      return

    if (tabVal < 0)
    {
      local listObj = scene.findObject("armies_tabs")
      if (::checkObj(listObj))
        tabVal = listObj.getValue()
    }

    if (tabVal < 0)
      tabVal = 0

    selectedGroupIdx = ::getTblValue(tabVal, availableArmiesArray, availableArmiesArray[0]).getArmyGroupIdx()
    selectedGroupFlyArmies = calcSelectedGroupAirArmiesNumber()

    local formation = airfield.getFormationByGroupIdx(selectedGroupIdx)
    hasUnitsToFly = airfield.hasFormationEnoughUnitsToFly(formation)

    local selUnitsInfo = getSelectedUnitsInfo()
    foreach (idx, unitTable in unitsList)
    {
      local unitSliderObj = showSceneBtn(unitTable.unitName + "_" + unitTable.armyGroupIdx,
        unitTable.armyGroupIdx == selectedGroupIdx)

      setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      fillUnitWeaponPreset(unitTable)
    }

    setupSendButton()
  }

  function canSendToFlyMoreArmy()
  {
    return selectedGroupFlyArmies < currentOperation.getGroupAirArmiesLimit()
  }

  function calcSelectedGroupAirArmiesNumber()
  {
    local armyCount = ::g_operations.getAirArmiesNumberByGroupIdx(selectedGroupIdx)
    for (local idx = 0; idx < ::g_world_war.getAirfieldsCount(); idx++)
    {
      local af = ::g_world_war.getAirfieldByIndex(idx)
      armyCount += af.getCooldownArmiesNumberByGroupIdx(selectedGroupIdx)
    }

    return armyCount
  }

  function setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
  {
    local unitsArray = getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitTable.unitClass, "names", [])
    local isReachedMaxUnitsLimit = isMaxUnitsNumSet(selUnitsInfo)

    local isSetSomeUnits = ::isInArray(unitTable.unitName, unitsArray)

    local isEnabled = hasUnitsToFly
                      && (isSetSomeUnits
                          || (stdMath.number_of_set_bits(maxChoosenUnitsMask) <= 1 && !isReachedMaxUnitsLimit)
                      )

    foreach (buttonId in ["btn_max", "btn_inc", "btn_dec"])
    {
      local buttonObj = unitSliderObj.findObject(buttonId)
      if (!::checkObj(buttonObj))
        return

      if (buttonId != "btn_dec")
        buttonObj.enable(isEnabled
          && unitTable.value < unitTable.maxValue
          && (maxChoosenUnitsMask & unitTable.unitClass) == 0)
      else
        buttonObj.enable(isEnabled && unitTable.value > 0)
    }
    unitSliderObj.enable(isEnabled)
  }

  function onChangeSliderValue(sliderObj)
  {
    local value = sliderObj.getValue()
    local unitIndex = getUnitIndex(sliderObj)
    if (unitIndex < 0)
      return

    updateUnitValue(unitIndex, value)
  }

  function getSelectedUnitsInfo()
  {
    local selUnitsInfo = {
      selectedUnitsMask = WW_UNIT_CLASS.NONE
      classes = {}
    }

    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx)
      {
        local utClass = unitTable.unitClass
        if (!(utClass in selUnitsInfo.classes))
        {
          selUnitsInfo.classes[utClass] <- {
            amount = 0
            names = []
          }
        }

        if (unitTable.value > 0)
        {
          selUnitsInfo.classes[utClass].amount += unitTable.value
          selUnitsInfo.classes[utClass].names.append(unitTable.unitName)
          selUnitsInfo.selectedUnitsMask = selUnitsInfo.selectedUnitsMask |
                                           utClass | WW_UNIT_CLASS.FIGHTER
        }
      }

    return selUnitsInfo
  }

  function getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitClass, param, defValue)
  {
    if (unitClass in selUnitsInfo.classes)
      return selUnitsInfo.classes[unitClass][param]
    return defValue
  }

  function setupSendButton()
  {
    if (!::checkObj(sendButtonObj))
      return

    local selUnitsInfo = getSelectedUnitsInfo()
    local isEnable = !!selUnitsInfo.selectedUnitsMask
    foreach (unitClass, cl in selUnitsInfo.classes)
    {
      local range = currentOperation.getQuantityToFlyOut(unitClass, selUnitsInfo.selectedUnitsMask)
      local clamped = ::clamp(cl.amount, range.x, range.y)
      isEnable = isEnable && clamped == cl.amount
    }

    local canSendArmy = canSendToFlyMoreArmy()
    sendButtonObj.enable(isEnable && canSendArmy)

    local cantSendText = ""
    if (!canSendArmy)
      cantSendText = ::loc("worldwar/reached_air_armies_limit")
    else if (hasUnitsToFly)
      cantSendText = isEnable ? getSelectedUnitsFlyTimeText(selectedGroupIdx) :
        ::loc("worldwar/airfield/army_not_equipped")

    local cantSendTextObj = scene.findObject("cant_send_reason")
    if (::checkObj(cantSendTextObj))
      cantSendTextObj.setValue(cantSendText)
  }

  function fillArmyLimitDescription()
  {
    local textObj = scene.findObject("armies_limit_text")
    if (!::checkObj(textObj))
      return

    textObj.setValue(::loc("worldwar/group_air_armies_limit",
      { cur = selectedGroupFlyArmies,
        max = currentOperation.getGroupAirArmiesLimit() }))
  }

  function fillFlyOutDescription(needFullUpdate = false)
  {
    local selUnitsInfo = getSelectedUnitsInfo()
    local bomberAmount = getReqDataFromSelectedUnitsInfo(selUnitsInfo, WW_UNIT_CLASS.BOMBER, "amount", 0)
    local formedArmyId = bomberAmount > 0 ? "combined" : "fighter"
    local formedArmyMask = bomberAmount > 0 ? WW_UNIT_CLASS.COMBINED : WW_UNIT_CLASS.FIGHTER

    updateFormedArmyTitle(formedArmyId, selUnitsInfo, needFullUpdate)
    updateFormedArmyInfo(formedArmyMask, selUnitsInfo, needFullUpdate)
  }

  function updateFormedArmyTitle (formedArmyId, selUnitsInfo, needFullUpdate)
  {
    if (needFullUpdate || !hasUnitsToFly || isMaxUnitsNumSet(selUnitsInfo))
    {
      local armyTypeTextObj = scene.findObject("army_info_text")
      if (!::check_obj(armyTypeTextObj))
        return

      local armyInfoText = ""
      if (!hasUnitsToFly)
        armyInfoText = ::colorize("warningTextColor", ::loc("worldwar/airfield/not_enough_units_to_send"))
      else
      {
        armyInfoText = ::loc("worldwar/airfield/army_type_" + formedArmyId)
        if (isMaxUnitsNumSet(selUnitsInfo))
        {
          local maxValue = currentOperation.maxUniqueUnitsOnFlyout
          local maxValueText = ::colorize("white", ::loc("worldwar/airfield/unit_various_limit",
            { types = maxValue }))
          armyInfoText += ::loc("ui/parentheses/space", { text = maxValueText })
        }
        armyTypeTextObj.tooltip = ::loc("worldwar/airfield/" + formedArmyId + "_armies_hint",
          getAirsTypeViewParams())
      }
      armyTypeTextObj.setValue(armyInfoText)
    }
  }

  function updateFormedArmyInfo (formedArmyMask, selUnitsInfo, needFullUpdate)
  {
    foreach (classMask, bitsList in currentOperation.getUnitsFlyoutRange())
    {
      local unitClassBlockObj = scene.findObject("unit_class_" + classMask)
      if (!::check_obj(unitClassBlockObj))
        continue

      local isUnitClassEnabled = (formedArmyMask & classMask) > 0
      unitClassBlockObj.isEnabled = isUnitClassEnabled ? "yes" : "no"

      local amountRange = currentOperation.getQuantityToFlyOut(classMask, formedArmyMask)
      local unitClassAmountTextObj = unitClassBlockObj.findObject("amount_text")
      if (::check_obj(unitClassAmountTextObj))
      {
        local unitsAmount = getReqDataFromSelectedUnitsInfo(selUnitsInfo, classMask, "amount", 0)
        unitClassAmountTextObj.setValue(getUnitTypeAmountText(unitsAmount, amountRange))
      }

      if (!needFullUpdate)
        continue

      local unitClassRequiredTextObj = unitClassBlockObj.findObject("required_text")
      if (::check_obj(unitClassRequiredTextObj))
        unitClassRequiredTextObj.setValue(getUnitTypeRequirementText(amountRange))
    }
  }

  function getUnitTypeAmountText(amount, range)
  {
    if (!amount)
      return ::loc("worldwar/airfield/selectedZero")

    local color = (amount >= range.x && amount <= range.y) ? "goodTextColor" : "badTextColor"
    local text = ::colorize(color, amount + " " + iconAir)

    return ::loc("worldwar/airfield/selected", { amountText = text })
  }

  function getUnitTypeRequirementText(range)
  {
    if (range.y <= 0)
      return ""

    return range.x == range.y
      ? ::loc("worldwar/airfield/required_number", { numb = range.y })
      : ::loc("worldwar/airfield/required_range",  { min = range.x, max = range.y })
  }

  function isMaxUnitsNumSet(selUnitsInfo)
  {
    local totalUnitsLen = 0
    foreach (cl in selUnitsInfo.classes)
      totalUnitsLen += cl.names.len()

    return totalUnitsLen >= currentOperation.maxUniqueUnitsOnFlyout
  }

  function setupQuantityManageButtons(selectedUnitsInfo, unitTable)
  {
    local unitsClassMaxValue = unitTable.maxUnitClassValue

    local amount = getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitTable.unitClass, "amount", 0)
    local isMaxSelUnitsSet = amount >= unitsClassMaxValue && amount > 0

    local prevMaxChoosenUnitsMask = maxChoosenUnitsMask
    maxChoosenUnitsMask = stdMath.change_bit_mask(maxChoosenUnitsMask, unitTable.unitClass, isMaxSelUnitsSet? 1 : 0)

    if (maxChoosenUnitsMask != prevMaxChoosenUnitsMask || isMaxUnitsNumSet(selectedUnitsInfo))
      configureMaxUniqueUnitsChosen(selectedUnitsInfo)
  }

  function configureMaxUniqueUnitsChosen(selUnitsInfo)
  {
    local blockObj = scene.findObject("unit_blocks_place")
    if (!::checkObj(blockObj))
      return

    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx)
      {
        local unitSliderObj = blockObj.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
        if (!::checkObj(unitSliderObj))
          return

        setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      }
  }

  function getUnitIndex(obj)
  {
    local blockObj = obj.getParent()
    local unitName = blockObj.unitName
    local armyGroupIdx = blockObj.armyGroupIdx.tointeger()
    return unitsList.findindex(@(unitTable) unitTable.unitName == unitName && unitTable.armyGroupIdx == armyGroupIdx) ?? -1
  }

  function updateUnitValue(unitIndex, value)
  {
    local curValue = ::clamp(value, 0, unitsList[unitIndex].maxValue)
    if (curValue == unitsList[unitIndex].value)
      return

    unitsList[unitIndex].value = value

    local needDescriptionFullUpdate = false
    local selectedUnitsInfo = getSelectedUnitsInfo()
    if (prevSelectedUnitsMask != selectedUnitsInfo.selectedUnitsMask)
    {
      prevSelectedUnitsMask = selectedUnitsInfo.selectedUnitsMask
      foreach (unitTable in unitsList)
        if (unitTable.armyGroupIdx == selectedGroupIdx)
          setupQuantityManageButtons(selectedUnitsInfo, unitTable)
      needDescriptionFullUpdate = true
    }

    local unitClass = unitsList[unitIndex].unitClass
    local unitsClassValue = getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitClass, "amount", 0)
    local unitsClassMaxValue = unitsList[unitIndex].maxUnitClassValue
    local excess = max(unitsClassValue - unitsClassMaxValue, 0)
    if (excess)
      unitsList[unitIndex].value = value - excess

    setupQuantityManageButtons(selectedUnitsInfo, unitsList[unitIndex])
    updateSlider(unitsList[unitIndex], selectedUnitsInfo)
    setupSendButton()
    fillFlyOutDescription(needDescriptionFullUpdate)
  }

  function updateSlider(unitTable, selUnitsInfo)
  {
    local blockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!::checkObj(blockObj))
      return

    local sliderObj = blockObj.findObject("progress_slider")
    local newProgressOb = sliderObj.findObject("new_progress")
    newProgressOb.setValue(unitTable.value)
    if (sliderObj.getValue() != unitTable.value)
      sliderObj.setValue(unitTable.value)

    setUnitSliderEnable(blockObj, selUnitsInfo, unitTable)
    updateSliderText(sliderObj, unitTable)
  }

  function updateSliderText(sliderObj, unitTable)
  {
    local sliderTextObj = sliderObj.findObject("slider_button_text")
    if (::checkObj(sliderTextObj))
      sliderTextObj.setValue(getSliderButtonText(
        unitTable.value, unitTable.totalValue))
  }

  function getSliderButtonText(value, totalValue)
  {
    return ::format("%d/%d", value, totalValue)
  }

  function onButtonDec(obj)
  {
    onButtonChangeValue(obj, -1)
  }

  function onButtonInc(obj)
  {
    onButtonChangeValue(obj, 1)
  }

  function getSelectedItemObj()
  {
    local itemsContainerObj = scene.findObject("unit_blocks_place")
    if (!::check_obj(itemsContainerObj))
      return null

    local itemObjIdx = itemsContainerObj.getValue()
    return itemsContainerObj.getChild(itemObjIdx)
  }

  function onUnitAmountDec(obj)
  {
    local itemObj = getSelectedItemObj()
    if (!::check_obj(itemObj))
      return

    onButtonDec(itemObj.findObject("btn_dec"))
  }

  function onUnitAmountInc(obj)
  {
    local itemObj = getSelectedItemObj()
    if (!::check_obj(itemObj))
      return

    onButtonInc(itemObj.findObject("btn_inc"))
  }

  function onButtonChangeValue(obj, diff)
  {
    local unitIndex = getUnitIndex(obj)
    if (unitIndex < 0)
      return

    local value = unitsList[unitIndex].value + diff
    updateUnitValue(unitIndex, value)
  }

  function onButtonMax(obj)
  {
    local unitIndex = getUnitIndex(obj)
    if (unitIndex < 0)
      return

    local value = unitsList[unitIndex].maxValue
    updateUnitValue(unitIndex, value)
  }

  function onUnitAmountMax(obj)
  {
    local itemObj = getSelectedItemObj()
    if (!::check_obj(itemObj))
      return

    onButtonMax(itemObj.findObject("btn_max"))
  }

  function onDestroy()
  {
    ::g_world_war_render.setCategory(::ERC_AIRFIELD_ARROW, true)
  }

  function fillUnitWeaponPreset(unitTable)
  {
    if (unitTable.isUnitsGroup)
      return
    local selectedWeaponName = unitTable.unitWeapon
    local unit = ::getAircraftByName(unitTable.unitName)
    local weapon = ::u.search(unit.weapons, (@(selectedWeaponName) function(weapon) {
        return weapon.name == selectedWeaponName
      })(selectedWeaponName))
    if (!weapon)
      return

    local blockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!::check_obj(blockObj))
      return
    local containerObj = blockObj.findObject("secondary_weapon")
    if (!::check_obj(containerObj))
      return

    local modItemObj = containerObj.findObject(unit.name)
    if (!::check_obj(modItemObj))
      modItemObj = ::weaponVisual.createItem(
        unit.name, weapon, weapon.type, containerObj, this, {
          useGenericTooltip = true
          shortcutIcon = "X"
        })

    ::weaponVisual.updateItem(
      unit, weapon, modItemObj, false, this, {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHidePlayerInfo = true
        useGenericTooltip = true
        hasMenu = hasPresetToChoose(unit)
      })
    modItemObj.pos = "0, 2"

    local centralBlockObj = modItemObj.findObject("centralBlock")
    if (::checkObj(centralBlockObj))
      centralBlockObj.unitName = unitTable.unitName
  }

  function updateUnitClass(idx, unitTable)
  {
    local unit = unitTable.unit
    local unitClassData = wwUnitClassParams.getUnitClassData(unit, unitTable.unitWeapon)
    if (unitTable.unitClass == unitClassData.flyOutUnitClass)
      return

    updateUnitValue(idx, 0)
    local selectedUnitsInfo = getSelectedUnitsInfo()
    setupQuantityManageButtons(selectedUnitsInfo, unitTable)
    unitTable.unitClass = unitClassData.flyOutUnitClass
    updateSlider(unitTable, selectedUnitsInfo)
    local unitClass = unitClassData.unitClass
    local unitBlockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    local unitClassObj = unitBlockObj.findObject("unit_class_icon_text")
    unitClassObj.unitType = wwUnitClassParams.getText(unitClass)
    unitClassObj.tooltip = ::loc(unitClassData.tooltipTextLocId)
    unitClassObj.setValue(wwUnitClassParams.getIconText(unitClass))
  }

  function hasPresetToChoose(unit)
  {
    return (unit?.weapons.len() ?? 0) > 1
  }

  function onModItemClick(obj)
  {
    local unit = ::getAircraftByName(obj.unitName)
    if (!hasPresetToChoose(unit))
      return

    local cb = ::Callback(function (unitName, weaponName) {
      changeUnitWeapon(unitName, weaponName)
    }, this)
    local params = {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHidePlayerInfo = true
        useGenericTooltip = true
      }
    ::gui_start_choose_unit_weapon(unit, cb, {
      itemParams = params, alignObj = obj, align = "right", isWorldWarUnit = true
    })
  }

  function onOpenPresetsList(obj)
  {
    local itemObj = getSelectedItemObj()
    if (unitsGroups != null || !::check_obj(itemObj))
      return

    onModItemClick(itemObj.findObject("centralBlock"))
  }

  function changeUnitWeapon(unitName, weaponName)
  {
    foreach (idx, unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx && unitTable.unitName == unitName)
      {
        unitTable.unitWeapon = weaponName
        fillUnitWeaponPreset(unitTable)
        updateUnitClass(idx, unitTable)
        break
      }
  }

  function getAvailableGroup(armyGroupIdx)
  {
    return u.search(airfield.formations, @(group) group.owner.armyGroupIdx == armyGroupIdx)
  }

  function getSelectedUnitsFlyTimeText(armyGroupIdx)
  {
    local minTime = 0
    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx && unitTable.value > 0)
        minTime = minTime <= 0 ? unitTable.maxFlyTime : min(minTime, unitTable.maxFlyTime)

    return ::loc("worldwar/airfield/army_fly_time") + ::loc("ui/colon") + getFlyTimeText(minTime)
  }

  function getUnitClassMaxValue(unitClass)
  {
    return ::max(currentOperation.getQuantityToFlyOut(unitClass, unitClass).y,
                 currentOperation.getQuantityToFlyOut(unitClass, WW_UNIT_CLASS.COMBINED).y)
  }

  function sendAircrafts()
  {
    local listObj = scene.findObject("armies_tabs")
    if (!::checkObj(listObj))
      return

    local isAircraftsChoosen = false
    local armyGroupIdx = ::getTblValue(listObj.getValue(), availableArmiesArray, -1).getArmyGroupIdx()
    local units = {}
    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == armyGroupIdx)
      {
        isAircraftsChoosen = isAircraftsChoosen || unitTable.value > 0
        units[unitTable.unitName] <- {
          count = unitTable.value
          weapon = unitTable.unitWeapon
        }
      }

    local errorLocId = ""
    if (!isAircraftsChoosen)
      errorLocId = "worldWar/error/noUnitChoosen"

    local group = getAvailableGroup(armyGroupIdx)
    if (!group || !::g_world_war.isGroupAvailable(group, accessList))
      errorLocId = "worldWar/error/uncontrollableArmyGroup"

    if (errorLocId != "")
    {
      ::g_popups.add("", ::loc(errorLocId), null, null, null, "WwFlyoutError")
      return
    }

    local cellIdx = ::ww_get_map_cell_by_coords(position.x, position.y)
    local taskId = ::g_world_war.moveSelectedAircraftsToCell(
      cellIdx, units, group.owner, armyTargetName)
    if (onSuccessfullFlyoutCb)
      ::add_bg_task_cb(taskId, onSuccessfullFlyoutCb)
    goBack()
  }

  function getUnitClassesView(unit, curUnitClass)
  {
    local unitClassesDataArray = wwUnitClassParams.getAvailableClasses(unit)
    return {
      id = unit.name
      funcName = "onUnitClassChange"
      values = unitClassesDataArray.map(@(unitClassData) {
        valueId = unitClassData.expClass
        text = ::loc(unitClassData.tooltipTextLocId)
        isSelected = unitClassData.unitClass == curUnitClass
      })
    }
  }

  function onUnitClassChange(obj)
  {
    local unit = ::getAircraftByName(obj.id)
    if (!hasPresetToChoose(unit))
      return

    local value = ::get_obj_valid_index(obj)
    if (value < 0)
      return

    local optionsObj = obj.getChild(value)
    local weaponName = wwUnitClassParams.getWeaponNameByExpClass(unit, optionsObj.id)

    ::g_world_war.set_last_weapon_preset(unit.name, weaponName)
    changeUnitWeapon(unit.name, weaponName)
  }
}
