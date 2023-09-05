//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let { updateModItem, createModItem } = require("%scripts/weaponry/weaponryVisual.nut")
let wwUnitClassParams = require("%scripts/worldWar/inOperation/wwUnitClassParams.nut")
let { getMaxFlyTime } = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { getGroupUnitMarkUp } = require("%scripts/unit/groupUnit.nut")
let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
let airfieldTypes = require("%scripts/worldWar/inOperation/model/airfieldTypes.nut")

let unitsTypesList = {
  [airfieldTypes.AT_HELIPAD] = [
    {
      unitType = WW_UNIT_CLASS.HELICOPTER
      classIcons = [{ name = "Helicopter", type = "helicopter" }]
    }
  ],
  [airfieldTypes.AT_RUNWAY] = [
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

local armyIdByMask = {
  [WW_UNIT_CLASS.FIGHTER]    = "fighter",
  [WW_UNIT_CLASS.HELICOPTER] = "helicopter",
  [WW_UNIT_CLASS.COMBINED]   = "combined"
}

gui_handlers.WwAirfieldFlyOut <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptySceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/airfieldFlyOut.tpl"

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
  iconAir = loc("worldwar/iconAir")

  unitsGroups = null

  static function open(index, position, armyTargetName, onSuccessfullFlyoutCb = null) {
    let airfield = ::g_world_war.getAirfieldByIndex(index)
    let availableArmiesArray = airfield.getAvailableFormations()
    if (!availableArmiesArray.len())
      return

    handlersManager.loadHandler(gui_handlers.WwAirfieldFlyOut,
      {
        airfield = airfield,
        availableArmiesArray = availableArmiesArray
        position = position,
        armyTargetName = armyTargetName,
        onSuccessfullFlyoutCb = onSuccessfullFlyoutCb
      }
    )
  }

  function getSceneTplContainerObj() { return this.scene.findObject("root-box") }

  function getSceneTplView() {
    this.accessList = ::g_world_war.getMyAccessLevelListForCurrentBattle()
    this.currentOperation = ::g_operations.getCurrentOperation()
    this.unitsGroups = wwOperationUnitsGroups.getUnitsGroups()

    return {
      unitString = this.getUnitsList()
      headerTabs = this.getHeaderTabs()
      unitTypes = unitsTypesList[this.airfield.airfieldType]
      hintText = this.airfield.airfieldType != airfieldTypes.AT_HELIPAD
        ? "\n".concat(loc("worldwar/airfield/armies_hint_title"),
          loc("worldwar/airfield/fighter_armies_hint", this.getAirsTypeViewParams()),
            loc("worldwar/airfield/combined_armies_hint", this.getAirsTypeViewParams()))
        : null
      hasUnitsGroups = this.unitsGroups != null
    }
  }

  function getUnitsList() {
    let flightTimeFactor = ::g_world_war.getWWConfigurableValue("maxFlightTimeMinutesMul", 1.0)
    this.unitsList = []
    foreach (airfieldFormation in this.availableArmiesArray)
      foreach (unit in airfieldFormation.units) {
        let name = unit.name
        let group = this.unitsGroups?[name]
        let displayUnit = group?.defaultUnit ?? unit.unit
        let unitWeapon = ::g_world_war.get_last_weapon_preset(name)
        let unitClassData = wwUnitClassParams.getUnitClassData(unit, unitWeapon)
        let maxFlyTime = (getMaxFlyTime(displayUnit) * flightTimeFactor).tointeger()
        let value = 0
        let maxValue = unit.count
        let maxUnitClassValue = this.getUnitClassMaxValue(unitClassData.flyOutUnitClass)
        let unitClass = unitClassData.unitClass
        let isUnitsGroup = group != null
        this.unitsList.append({
          armyGroupIdx = airfieldFormation.getArmyGroupIdx()
          unit = unit
          unitName = name
          unitItem = getGroupUnitMarkUp(name, displayUnit, group,
            { nameLoc = loc(group?.name ?? "") })
          unitClassIconText = wwUnitClassParams.getIconText(unitClass)
          unitClassName = wwUnitClassParams.getText(unitClass)
          unitClassTooltipText = loc(unitClassData.tooltipTextLocId)
          unitClass = unitClassData.flyOutUnitClass
          unitClassesView = isUnitsGroup ? this.getUnitClassesView(unit, unitClass) : null
          maxValue = min(maxUnitClassValue, maxValue)
          maxUnitClassValue = maxUnitClassValue
          totalValue = maxValue
          value = value
          maxFlyTime = maxFlyTime
          maxFlyTimeText = this.getFlyTimeText(maxFlyTime)
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
            sliderButtonText = this.getSliderButtonText(value, maxValue)
          }
        })
      }

    this.unitsList.sort(@(a, b) a.expClassSortIdx <=> b.expClassSortIdx || a.unitName <=> b.unitName)

    return this.unitsList
  }

  function getAirsTypeViewParams() {
    return {
      fighterIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.FIGHTER, true)
      assaultIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.ASSAULT, true)
      bomberIcon = wwUnitClassParams.getIconText(WW_UNIT_CLASS.BOMBER, true)
    }
  }

  function getFlyTimeText(timeInSeconds) {
    return time.hoursToString(time.secondsToHours(timeInSeconds), false, true) + " " + loc("icon/timer")
  }

  function getHeaderTabs() {
    let view = { tabs = [] }
    let selectedId = 0
    foreach (idx, airfieldFormation in this.availableArmiesArray) {
      view.tabs.append({
        tabName = airfieldFormation.getClanTag()
        navImagesText = ::get_navigation_images_text(idx, this.airfield.formations.len())
        selected = false
      })
    }
    if (view.tabs.len() > 0)
      view.tabs[selectedId].selected = true

    return handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
  }

  function getNavbarTplView() {
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
          shortcut = "X"
          button = true
          type = "wwArmyFlyOut"
        },
      ]
    }
  }

  function initScreen() {
    ::g_world_war_render.setCategory(ERC_AIRFIELD_ARROW, false)

    this.sendButtonObj = this.scene.findObject("send_aircrafts_button")
    this.updateVisibleUnits()

    //--- After all units filled ---
    this.fillFlyOutDescription(true)
    this.fillArmyLimitDescription()
  }

  function onTabSelect(obj) {
    this.updateVisibleUnits(obj.getValue())
    this.fillFlyOutDescription(true)
  }

  function updateVisibleUnits(tabVal = -1) {
    if (!this.availableArmiesArray.len())
      return

    if (tabVal < 0) {
      let listObj = this.scene.findObject("armies_tabs")
      if (checkObj(listObj))
        tabVal = listObj.getValue()
    }

    if (tabVal < 0)
      tabVal = 0

    this.selectedGroupIdx = getTblValue(tabVal, this.availableArmiesArray, this.availableArmiesArray[0]).getArmyGroupIdx()
    this.selectedGroupFlyArmies = this.calcSelectedGroupAirArmiesNumber()

    let formation = this.airfield.getFormationByGroupIdx(this.selectedGroupIdx)
    this.hasUnitsToFly = this.airfield.hasFormationEnoughUnitsToFly(formation)

    let selUnitsInfo = this.getSelectedUnitsInfo()
    foreach (_idx, unitTable in this.unitsList) {
      let unitSliderObj = this.showSceneBtn(unitTable.unitName + "_" + unitTable.armyGroupIdx,
        unitTable.armyGroupIdx == this.selectedGroupIdx)

      this.setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      this.fillUnitWeaponPreset(unitTable)
    }

    this.setupSendButton()
  }

  function canSendToFlyMoreArmy() {
    return this.selectedGroupFlyArmies < this.currentOperation.getGroupAirArmiesLimit(this.airfield.airfieldType.name)
  }

  function calcSelectedGroupAirArmiesNumber() {
    local armyCount = ::g_operations.getAirArmiesNumberByGroupIdx(this.selectedGroupIdx,
      this.airfield.airfieldType.overrideUnitType)
    for (local idx = 0; idx < ::g_world_war.getAirfieldsCount(); idx++) {
      let af = ::g_world_war.getAirfieldByIndex(idx)
      if (this.airfield.airfieldType == af.airfieldType)
        armyCount += af.getCooldownArmiesNumberByGroupIdx(this.selectedGroupIdx)
    }

    return armyCount
  }

  function setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable) {
    let unitsArray = this.getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitTable.unitClass, "names", [])
    let isReachedMaxUnitsLimit = this.isMaxUnitsNumSet(selUnitsInfo)

    let isSetSomeUnits = isInArray(unitTable.unitName, unitsArray)

    let isEnabled = this.hasUnitsToFly
                      && (isSetSomeUnits
                          || (stdMath.number_of_set_bits(this.maxChoosenUnitsMask) <= 1 && !isReachedMaxUnitsLimit)
                      )

    foreach (buttonId in ["btn_max", "btn_inc", "btn_dec"]) {
      let buttonObj = unitSliderObj.findObject(buttonId)
      if (!checkObj(buttonObj))
        return

      if (buttonId != "btn_dec")
        buttonObj.enable(isEnabled
          && unitTable.value < unitTable.maxValue
          && (this.maxChoosenUnitsMask & unitTable.unitClass) == 0)
      else
        buttonObj.enable(isEnabled && unitTable.value > 0)
    }
    unitSliderObj.enable(isEnabled)
  }

  function onChangeSliderValue(sliderObj) {
    let value = sliderObj.getValue()
    let unitIndex = this.getUnitIndex(sliderObj)
    if (unitIndex < 0)
      return

    this.updateUnitValue(unitIndex, value)
  }

  function getSelectedUnitsInfo() {
    let selUnitsInfo = {
      selectedUnitsMask = WW_UNIT_CLASS.NONE
      classes = {}
    }

    foreach (unitTable in this.unitsList)
      if (unitTable.armyGroupIdx == this.selectedGroupIdx) {
        let utClass = unitTable.unitClass
        if (!(utClass in selUnitsInfo.classes)) {
          selUnitsInfo.classes[utClass] <- {
            amount = 0
            names = []
          }
        }

        if (unitTable.value > 0) {
          selUnitsInfo.classes[utClass].amount += unitTable.value
          selUnitsInfo.classes[utClass].names.append(unitTable.unitName)
          selUnitsInfo.selectedUnitsMask = selUnitsInfo.selectedUnitsMask
            | utClass | this.airfield.airfieldType.wwUnitClass
        }
      }

    return selUnitsInfo
  }

  function getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitClass, param, defValue) {
    if (unitClass in selUnitsInfo.classes)
      return selUnitsInfo.classes[unitClass][param]
    return defValue
  }

  function setupSendButton() {
    if (!checkObj(this.sendButtonObj))
      return

    let selUnitsInfo = this.getSelectedUnitsInfo()
    local isEnable = !!selUnitsInfo.selectedUnitsMask
    foreach (unitClass, cl in selUnitsInfo.classes) {
      let range = this.currentOperation.getQuantityToFlyOut(unitClass, selUnitsInfo.selectedUnitsMask)
      let clamped = clamp(cl.amount, range.x, range.y)
      isEnable = isEnable && clamped == cl.amount
    }

    let canSendArmy = this.canSendToFlyMoreArmy()
    this.sendButtonObj.enable(isEnable && canSendArmy)

    local cantSendText = ""
    if (!canSendArmy)
      cantSendText = loc($"worldwar/reached_{this.airfield.airfieldType.locId}_armies_limit")
    else if (this.hasUnitsToFly)
      cantSendText = isEnable ? this.getSelectedUnitsFlyTimeText(this.selectedGroupIdx) :
        loc("worldwar/airfield/army_not_equipped")

    let cantSendTextObj = this.scene.findObject("cant_send_reason")
    if (checkObj(cantSendTextObj))
      cantSendTextObj.setValue(cantSendText)
  }

  function fillArmyLimitDescription() {
    let textObj = this.scene.findObject("armies_limit_text")
    if (!checkObj(textObj))
      return

    let armiesLimit = this.currentOperation.getGroupAirArmiesLimit(this.airfield.airfieldType.name)
    textObj.setValue(
      loc("".concat("worldwar/group_", this.airfield.airfieldType.locId, "_armies_limit"),
        { cur = this.selectedGroupFlyArmies,
          max = armiesLimit }))
  }

  function fillFlyOutDescription(needFullUpdate = false) {
    let selUnitsInfo = this.getSelectedUnitsInfo()
    let bomberAmount = this.getReqDataFromSelectedUnitsInfo(selUnitsInfo, WW_UNIT_CLASS.BOMBER, "amount", 0)
    let formedArmyMask = bomberAmount > 0
      ? WW_UNIT_CLASS.COMBINED
      : this.airfield.airfieldType.wwUnitClass
    let formedArmyId = armyIdByMask[formedArmyMask]

    this.updateFormedArmyTitle(formedArmyId, selUnitsInfo, needFullUpdate)
    this.updateFormedArmyInfo(formedArmyMask, selUnitsInfo, needFullUpdate)
  }

  function updateFormedArmyTitle (formedArmyId, selUnitsInfo, needFullUpdate) {
    if (needFullUpdate || !this.hasUnitsToFly || this.isMaxUnitsNumSet(selUnitsInfo)) {
      let armyTypeTextObj = this.scene.findObject("army_info_text")
      if (!checkObj(armyTypeTextObj))
        return

      local armyInfoText = ""
      if (!this.hasUnitsToFly)
        armyInfoText = colorize("warningTextColor", loc("worldwar/airfield/not_enough_units_to_send"))
      else {
        armyInfoText = loc("worldwar/airfield/army_type_" + formedArmyId)
        if (this.isMaxUnitsNumSet(selUnitsInfo)) {
          let maxValue = this.currentOperation.maxUniqueUnitsOnFlyout
          let maxValueText = colorize("white", loc("worldwar/airfield/unit_various_limit",
            { types = maxValue }))
          armyInfoText += loc("ui/parentheses/space", { text = maxValueText })
        }
        armyTypeTextObj.tooltip = loc(
          "worldwar/airfield/" + formedArmyId + "_armies_hint", this.getAirsTypeViewParams(), "")
      }
      armyTypeTextObj.setValue(armyInfoText)
    }
  }

  function updateFormedArmyInfo (formedArmyMask, selUnitsInfo, needFullUpdate) {
    foreach (classMask, _bitsList in this.currentOperation.getUnitsFlyoutRange()) {
      let unitClassBlockObj = this.scene.findObject("unit_class_" + classMask)
      if (!checkObj(unitClassBlockObj))
        continue

      let isUnitClassEnabled = (formedArmyMask & classMask) > 0
      unitClassBlockObj.isEnabled = isUnitClassEnabled ? "yes" : "no"

      let amountRange = this.currentOperation.getQuantityToFlyOut(classMask, formedArmyMask)
      let unitClassAmountTextObj = unitClassBlockObj.findObject("amount_text")
      if (checkObj(unitClassAmountTextObj)) {
        let unitsAmount = this.getReqDataFromSelectedUnitsInfo(selUnitsInfo, classMask, "amount", 0)
        unitClassAmountTextObj.setValue(this.getUnitTypeAmountText(unitsAmount, amountRange))
      }

      if (!needFullUpdate)
        continue

      let unitClassRequiredTextObj = unitClassBlockObj.findObject("required_text")
      if (checkObj(unitClassRequiredTextObj))
        unitClassRequiredTextObj.setValue(this.getUnitTypeRequirementText(amountRange))
    }
  }

  function getUnitTypeAmountText(amount, range) {
    if (!amount)
      return loc("worldwar/airfield/selectedZero")

    let color = (amount >= range.x && amount <= range.y) ? "goodTextColor" : "badTextColor"
    let text = colorize(color, amount + " " + this.iconAir)

    return loc("worldwar/airfield/selected", { amountText = text })
  }

  function getUnitTypeRequirementText(range) {
    if (range.y <= 0)
      return ""

    return range.x == range.y
      ? loc("worldwar/airfield/required_number", { numb = range.y })
      : loc("worldwar/airfield/required_range",  { min = range.x, max = range.y })
  }

  function isMaxUnitsNumSet(selUnitsInfo) {
    local totalUnitsLen = 0
    foreach (cl in selUnitsInfo.classes)
      totalUnitsLen += cl.names.len()

    return totalUnitsLen >= this.currentOperation.maxUniqueUnitsOnFlyout
  }

  function setupQuantityManageButtons(selectedUnitsInfo, unitTable) {
    let unitsClassMaxValue = unitTable.maxUnitClassValue

    let amount = this.getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitTable.unitClass, "amount", 0)
    let isMaxSelUnitsSet = amount >= unitsClassMaxValue && amount > 0

    let prevMaxChoosenUnitsMask = this.maxChoosenUnitsMask
    this.maxChoosenUnitsMask = stdMath.change_bit_mask(this.maxChoosenUnitsMask, unitTable.unitClass, isMaxSelUnitsSet ? 1 : 0)

    if (this.maxChoosenUnitsMask != prevMaxChoosenUnitsMask || this.isMaxUnitsNumSet(selectedUnitsInfo))
      this.configureMaxUniqueUnitsChosen(selectedUnitsInfo)
  }

  function configureMaxUniqueUnitsChosen(selUnitsInfo) {
    let blockObj = this.scene.findObject("unit_blocks_place")
    if (!checkObj(blockObj))
      return

    foreach (unitTable in this.unitsList)
      if (unitTable.armyGroupIdx == this.selectedGroupIdx) {
        let unitSliderObj = blockObj.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
        if (!checkObj(unitSliderObj))
          return

        this.setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      }
  }

  function getUnitIndex(obj) {
    let blockObj = obj.getParent()
    let unitName = blockObj.unitName
    let armyGroupIdx = blockObj.armyGroupIdx.tointeger()
    return this.unitsList.findindex(@(unitTable) unitTable.unitName == unitName && unitTable.armyGroupIdx == armyGroupIdx) ?? -1
  }

  function updateUnitValue(unitIndex, value) {
    let curValue = clamp(value, 0, this.unitsList[unitIndex].maxValue)
    if (curValue == this.unitsList[unitIndex].value)
      return

    this.unitsList[unitIndex].value = value

    local needDescriptionFullUpdate = false
    let selectedUnitsInfo = this.getSelectedUnitsInfo()
    if (this.prevSelectedUnitsMask != selectedUnitsInfo.selectedUnitsMask) {
      this.prevSelectedUnitsMask = selectedUnitsInfo.selectedUnitsMask
      foreach (unitTable in this.unitsList)
        if (unitTable.armyGroupIdx == this.selectedGroupIdx)
          this.setupQuantityManageButtons(selectedUnitsInfo, unitTable)
      needDescriptionFullUpdate = true
    }

    let unitClass = this.unitsList[unitIndex].unitClass
    let unitsClassValue = this.getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitClass, "amount", 0)
    let unitsClassMaxValue = this.unitsList[unitIndex].maxUnitClassValue
    let excess = max(unitsClassValue - unitsClassMaxValue, 0)
    if (excess)
      this.unitsList[unitIndex].value = value - excess

    this.setupQuantityManageButtons(selectedUnitsInfo, this.unitsList[unitIndex])
    this.updateSlider(this.unitsList[unitIndex], selectedUnitsInfo)
    this.setupSendButton()
    this.fillFlyOutDescription(needDescriptionFullUpdate)
  }

  function updateSlider(unitTable, selUnitsInfo) {
    let blockObj = this.scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!checkObj(blockObj))
      return

    let sliderObj = blockObj.findObject("progress_slider")
    let newProgressOb = sliderObj.findObject("new_progress")
    newProgressOb.setValue(unitTable.value)
    if (sliderObj.getValue() != unitTable.value)
      sliderObj.setValue(unitTable.value)

    this.setUnitSliderEnable(blockObj, selUnitsInfo, unitTable)
    this.updateSliderText(sliderObj, unitTable)
  }

  function updateSliderText(sliderObj, unitTable) {
    let sliderTextObj = sliderObj.findObject("slider_button_text")
    if (checkObj(sliderTextObj))
      sliderTextObj.setValue(this.getSliderButtonText(
        unitTable.value, unitTable.totalValue))
  }

  function getSliderButtonText(value, totalValue) {
    return format("%d/%d", value, totalValue)
  }

  function onButtonDec(obj) {
    this.onButtonChangeValue(obj, -1)
  }

  function onButtonInc(obj) {
    this.onButtonChangeValue(obj, 1)
  }

  function getSelectedItemObj() {
    let itemsContainerObj = this.scene.findObject("unit_blocks_place")
    if (!checkObj(itemsContainerObj))
      return null

    let itemObjIdx = itemsContainerObj.getValue()
    return itemsContainerObj.getChild(itemObjIdx)
  }

  function onUnitAmountDec(_obj) {
    let itemObj = this.getSelectedItemObj()
    if (!checkObj(itemObj))
      return

    this.onButtonDec(itemObj.findObject("btn_dec"))
  }

  function onUnitAmountInc(_obj) {
    let itemObj = this.getSelectedItemObj()
    if (!checkObj(itemObj))
      return

    this.onButtonInc(itemObj.findObject("btn_inc"))
  }

  function onButtonChangeValue(obj, diff) {
    let unitIndex = this.getUnitIndex(obj)
    if (unitIndex < 0)
      return

    let value = this.unitsList[unitIndex].value + diff
    this.updateUnitValue(unitIndex, value)
  }

  function onButtonMax(obj) {
    let unitIndex = this.getUnitIndex(obj)
    if (unitIndex < 0)
      return

    let value = this.unitsList[unitIndex].maxValue
    this.updateUnitValue(unitIndex, value)
  }

  function onUnitAmountMax(_obj) {
    let itemObj = this.getSelectedItemObj()
    if (!checkObj(itemObj))
      return

    this.onButtonMax(itemObj.findObject("btn_max"))
  }

  function onDestroy() {
    ::g_world_war_render.setCategory(ERC_AIRFIELD_ARROW, true)
  }

  function fillUnitWeaponPreset(unitTable) {
    if (unitTable.isUnitsGroup)
      return
    let selectedWeaponName = unitTable.unitWeapon
    let unit = getAircraftByName(unitTable.unitName)
    let weapon = unit.getWeapons().findvalue(@(w) w.name == selectedWeaponName)
    if (!weapon)
      return

    let blockObj = this.scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!checkObj(blockObj))
      return
    let containerObj = blockObj.findObject("secondary_weapon")
    if (!checkObj(containerObj))
      return

    local modItemObj = containerObj.findObject(unit.name)
    let params = {
      canShowStatusImage = false
      canShowResearch = false
      canShowPrice = false
      isForceHidePlayerInfo = true
      hasMenu = this.hasPresetToChoose(unit)
      curEdiff = ::g_world_war.defaultDiffCode
    }
    if (!checkObj(modItemObj))
      modItemObj = createModItem(
        unit.name, unit, weapon, weapon.type, containerObj, this,
        params.__merge({ shortcutIcon = "X" }))
    else
      updateModItem(
        unit, weapon, modItemObj, false, this, params)
    modItemObj.pos = "0, 2"

    let centralBlockObj = modItemObj.findObject("centralBlock")
    if (checkObj(centralBlockObj))
      centralBlockObj.unitName = unitTable.unitName
  }

  function updateUnitClass(idx, unitTable) {
    let unit = unitTable.unit
    let unitClassData = wwUnitClassParams.getUnitClassData(unit, unitTable.unitWeapon)
    if (unitTable.unitClass == unitClassData.flyOutUnitClass)
      return

    this.updateUnitValue(idx, 0)
    let selectedUnitsInfo = this.getSelectedUnitsInfo()
    this.setupQuantityManageButtons(selectedUnitsInfo, unitTable)
    unitTable.unitClass = unitClassData.flyOutUnitClass
    this.updateSlider(unitTable, selectedUnitsInfo)
    let unitClass = unitClassData.unitClass
    let unitBlockObj = this.scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    let unitClassObj = unitBlockObj.findObject("unit_class_icon_text")
    unitClassObj.unitType = wwUnitClassParams.getText(unitClass)
    unitClassObj.tooltip = loc(unitClassData.tooltipTextLocId)
    unitClassObj.setValue(wwUnitClassParams.getIconText(unitClass))
  }

  function hasPresetToChoose(unit) {
    return (unit?.getWeapons().len() ?? 0) > 1
  }

  function onModItemClick(obj) {
    let unit = getAircraftByName(obj.unitName)
    if (!this.hasPresetToChoose(unit))
      return

    let cb = Callback(function (unitName, weaponName) {
      this.changeUnitWeapon(unitName, weaponName)
    }, this)
    ::gui_start_choose_unit_weapon(unit, cb, {
      alignObj = obj
      align = "right"
      isForcedAvailable = true
      setLastWeapon = @(unitName, weaponName) ::g_world_war.set_last_weapon_preset(unitName, weaponName)
      getLastWeapon = @(unitName) ::g_world_war.get_last_weapon_preset(unitName)
      itemParams = {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHidePlayerInfo = true
        curEdiff = ::g_world_war.defaultDiffCode
      }
    })
  }

  function onOpenPresetsList(_obj) {
    let itemObj = this.getSelectedItemObj()
    if (this.unitsGroups != null || !checkObj(itemObj))
      return

    this.onModItemClick(itemObj.findObject("centralBlock"))
  }

  function changeUnitWeapon(unitName, weaponName) {
    foreach (idx, unitTable in this.unitsList)
      if (unitTable.armyGroupIdx == this.selectedGroupIdx && unitTable.unitName == unitName) {
        unitTable.unitWeapon = weaponName
        this.fillUnitWeaponPreset(unitTable)
        this.updateUnitClass(idx, unitTable)
        break
      }
  }

  function getAvailableGroup(armyGroupIdx) {
    return u.search(this.airfield.formations, @(group) group.owner.armyGroupIdx == armyGroupIdx)
  }

  function getSelectedUnitsFlyTimeText(_armyGroupIdx) {
    local minTime = 0
    foreach (unitTable in this.unitsList)
      if (unitTable.armyGroupIdx == this.selectedGroupIdx && unitTable.value > 0)
        minTime = minTime <= 0 ? unitTable.maxFlyTime : min(minTime, unitTable.maxFlyTime)

    return loc("worldwar/airfield/army_fly_time") + loc("ui/colon") + this.getFlyTimeText(minTime)
  }

  function getUnitClassMaxValue(unitClass) {
    return max(this.currentOperation.getQuantityToFlyOut(unitClass, unitClass).y,
                 this.currentOperation.getQuantityToFlyOut(unitClass, WW_UNIT_CLASS.COMBINED).y)
  }

  function sendAircrafts() {
    let listObj = this.scene.findObject("armies_tabs")
    if (!checkObj(listObj))
      return

    local isAircraftsChoosen = false
    let armyGroupIdx = getTblValue(listObj.getValue(), this.availableArmiesArray, -1).getArmyGroupIdx()
    let units = {}
    foreach (unitTable in this.unitsList)
      if (unitTable.armyGroupIdx == armyGroupIdx) {
        isAircraftsChoosen = isAircraftsChoosen || unitTable.value > 0
        units[unitTable.unitName] <- {
          count = unitTable.value
          weapon = unitTable.unitWeapon
        }
      }

    local errorLocId = ""
    if (!isAircraftsChoosen)
      errorLocId = "worldWar/error/noUnitChoosen"

    let group = this.getAvailableGroup(armyGroupIdx)
    if (!group || !::g_world_war.isGroupAvailable(group, this.accessList))
      errorLocId = "worldWar/error/uncontrollableArmyGroup"

    if (errorLocId != "") {
      ::g_popups.add("", loc(errorLocId), null, null, null, "WwFlyoutError")
      return
    }

    let cellIdx = ::ww_get_map_cell_by_coords(this.position.x, this.position.y)
    let taskId = ::g_world_war.moveSelectedAircraftsToCell(
      cellIdx, units, group.owner, this.armyTargetName)
    if (this.onSuccessfullFlyoutCb)
      ::add_bg_task_cb(taskId, this.onSuccessfullFlyoutCb)
    this.goBack()
  }

  function getUnitClassesView(unit, curUnitClass) {
    let unitClassesDataArray = wwUnitClassParams.getAvailableClasses(unit)
    return {
      id = unit.name
      funcName = "onUnitClassChange"
      values = unitClassesDataArray.map(@(unitClassData) {
        valueId = unitClassData.expClass
        text = loc(unitClassData.tooltipTextLocId)
        isSelected = unitClassData.unitClass == curUnitClass
      })
    }
  }

  function onUnitClassChange(obj) {
    let unit = getAircraftByName(obj.id)
    if (!this.hasPresetToChoose(unit))
      return

    let value = getObjValidIndex(obj)
    if (value < 0)
      return

    let optionsObj = obj.getChild(value)
    let weaponName = wwUnitClassParams.getWeaponNameByExpClass(unit, optionsObj.id)

    ::g_world_war.set_last_weapon_preset(unit.name, weaponName)
    this.changeUnitWeapon(unit.name, weaponName)
  }
}
