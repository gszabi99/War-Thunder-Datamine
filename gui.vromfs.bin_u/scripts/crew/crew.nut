from "%scripts/dagui_natives.nut" import shop_upgrade_crew, purchase_crew_slot, get_training_cost, get_aircraft_crew_by_id
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let stdMath = require("%sqstd/math.nut")
let { ceil } = require("math")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let { get_skills_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { addTask } = require("%scripts/tasker.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { getUnitTypesInCountries } = require("%scripts/unit/unitInfo.nut")
let { getUnitCrewDataById } = require("%scripts/crew/unitCrewCache.nut")

const UPGR_CREW_TUTORIAL_SKILL_NUMBER = 2

local crewLevelBySkill = 5 
local totalSkillsSteps = 5 

let crewSkillPages = []
let availableCrewSkills = {}
let unseenIconsNeeds = {}
let unitCrewTrainReq = {} 

let minCrewLevel = {
  [CUT_AIRCRAFT] = 1.5,
  [CUT_TANK] = 1,
  [CUT_SHIP] = 1,
  [CUT_HUMAN] = 1
}

let maxCrewLevel = {
  [CUT_AIRCRAFT] = 75,
  [CUT_TANK] = 150,
  [CUT_SHIP] = 100,
  [CUT_HUMAN] = 150
}

function isCountryHasAnyEsUnitType(country, esUnitTypeMask) {
  let typesList = getTblValue(country, getUnitTypesInCountries(), {})
  foreach (esUnitType, isInCountry in typesList)
    if (isInCountry && (esUnitTypeMask & (1 << esUnitType)))
      return true
  return false
}

let getCrew = @(countryId, idInCountry) getCrewsList()?[countryId].crews[idInCountry]

function createCrewBuyPointsHandler(crew) {
  return handlersManager.loadHandler(gui_handlers.CrewBuyPointsHandler, { crew })
}





function getCrewButtonRow(obj, scene, tblObj = null) {
  if (tblObj == null)
    tblObj = scene.findObject("skills_table")
  local curRow = tblObj.getValue()
  if (obj) {
    if (obj?.holderId)
      curRow = obj.holderId.tointeger()
    else {
      let pObj = obj.getParent()
      if (pObj?.id) {
        let row = pObj.id.tointeger()
        if (row >= 0)
          curRow = row
      }
    }
  }
  return curRow
}

function createCrewUnitSpecHandler(containerObj) {
  let scene = containerObj.findObject("specs_table")
  if (!checkObj(scene))
    return null
  return handlersManager.loadHandler(gui_handlers.CrewUnitSpecHandler, { scene })
}

function getCrewSkillItem(memberName, skillName) {
  foreach (page in crewSkillPages)
    if (page.id == memberName) {
      foreach (skillItem in page.items)
        if (skillItem.name == skillName)
          return skillItem
      break
    }
  return null
}

function getCrewSkillValue(crewId, unit, memberName, skillName) {
  let unitCrewData = getUnitCrewDataById(crewId, unit)
  return unitCrewData?[memberName][skillName] ?? 0
}

function getCrewSkillNewValue(skillItem, crew, unit) {
  let res = getTblValue("newValue", skillItem, null)
  if (res != null)
    return res
  return getCrewSkillValue(crew.id, unit, skillItem.memberName, skillItem.name)
}

function getCrewMaxSkillValue(skillItem) {
  return skillItem.costTbl.len()
}

function getCrewSkillCost(skillItem, value, prevValue = -1) {
  let cost = getTblValue(value - 1, skillItem.costTbl, 0)
  if (prevValue < 0)
    prevValue = value - 1
  let prevCost = getTblValue(prevValue - 1, skillItem.costTbl, 0)
  return cost - prevCost
}

function getCrewName(crew) {
  let number =  getTblValue("idInCountry", crew, -1) + 1
  return $"{loc("options/crewName")}{number}"
}

function getCrewUnit(crew) {
  return getAircraftByName(crew?.aircraft ?? "")
}

function getCrewCountry(crew) {
  let countryData = getTblValue(crew.idCountry, getCrewsList())
  return countryData ? countryData.country : ""
}

function getCrewTrainCost(crew, unit) {
  let res = Cost()
  if (!unit)
    return res
  if (crew)
    res.wp = get_training_cost(crew.id, unit.name)?.cost ?? unit.trainCost
  else
    res.wp = unit.trainCost
  return res
}

function getCrewSkillPoints(crew) {
  return getTblValue("skillPoints", crew, 0)
}

function purchaseNewCrewSlot(country, onTaskSuccess, onTaskFail = null) {
  let taskId = purchase_crew_slot(country)
  return addTask(taskId, { showProgressBox = true }, onTaskSuccess, onTaskFail)
}

function getSkillMaxCrewLevel() {
  return crewLevelBySkill
}

function getMinCrewLevel(crewUnitType) {
  return minCrewLevel?[crewUnitType] ?? 0
}

function getMaxCrewLevel(crewUnitType) {
  return maxCrewLevel?[crewUnitType] ?? 0
}

function getSkillCrewLevel(skillItem, newValue, prevValue = 0) {
  let maxValue = getCrewMaxSkillValue(skillItem)
  local level = (newValue.tofloat() - prevValue) / maxValue  * getSkillMaxCrewLevel()
  return stdMath.round_by_value(level, 0.01)
}

function calcCrewLevelsBySkill(blk) {
  crewLevelBySkill = blk?.skill_to_level_ratio ?? crewLevelBySkill
  totalSkillsSteps = blk?.max_skill_level_steps ?? totalSkillsSteps
}







function loadCrewSkills() {
  crewSkillPages.clear()
  unitCrewTrainReq.clear()

  let blk = get_skills_blk()
  calcCrewLevelsBySkill(blk)

  eachBlock(blk?.crew_skills, function(pageBlk, pName) {
    let unitTypeTag = pageBlk?.type ?? ""
    let defaultCrewUnitTypeMask = unitTypes.getTypeMaskByTagsString(unitTypeTag, "; ", "bitCrewType")
    let page = {
      id = pName,
      image = blk?.crew_skills_calc[pName].image ?? ""
      crewUnitTypeMask = defaultCrewUnitTypeMask
      items = []
      isVisible = function(crewUnitType) { return (this.crewUnitTypeMask & (1 << crewUnitType)) != 0 }
    }
    eachBlock(pageBlk, function(itemBlk, sName) {
      let item = {
        name = sName,
        memberName = page.id
        crewUnitTypeMask = unitTypes.getTypeMaskByTagsString(itemBlk?.type ?? "", "; ", "bitCrewType")
                        || defaultCrewUnitTypeMask
        costTbl = []
        isVisible = function(crewUnitType) { return (this.crewUnitTypeMask & (1 << crewUnitType)) != 0 }
      }
      page.crewUnitTypeMask = page.crewUnitTypeMask | item.crewUnitTypeMask

      let costBlk = itemBlk?.skill_level_exp
      local idx = 1
      local totalCost = 0
      while (costBlk?[$"level{idx}"] != null) {
        totalCost += costBlk[$"level{idx}"]
        item.costTbl.append(totalCost)
        idx++
      }
      item.useSpecializations <- itemBlk?.use_specializations ?? false
      item.useLeadership <- itemBlk?.use_leadership ?? false
      page.items.append(item)
    })
    crewSkillPages.append(page)
  })

  broadcastEvent("CrewSkillsReloaded")

  let reqBlk = blk?.train_req
  if (reqBlk == null)
    return

  foreach (t in unitTypes.types) {
    if (!t.isAvailable() || unitCrewTrainReq?[t.crewUnitType] != null)
      continue

    let typeBlk = reqBlk?[t.getCrewTag()]
    if (typeBlk == null)
      continue

    let trainReq = []
    local costBlk = null
    local tIdx = 0
    do {
      tIdx++
      costBlk = typeBlk?[$"train{tIdx}"]
      if (costBlk) {
        trainReq.append([])
        for (local idx = 0; idx <= MAX_COUNTRY_RANK; idx++)
          trainReq[tIdx - 1].append(costBlk?[$"rank{idx}"] ?? 0)
      }
    }
    while (costBlk != null)

    unitCrewTrainReq[t.crewUnitType] <- trainReq
  }
}

function loadCrewSkillsOnce() {
  if (crewSkillPages.len() == 0)
    loadCrewSkills()
}

function getCrewLevel(crew, unit, crewUnitType, countByNewValues = false) {
  loadCrewSkillsOnce()

  local res = 0.0
  foreach (page in crewSkillPages)
    if (page.isVisible(crewUnitType))
      foreach (item in page.items) {
        if (!item.isVisible(crewUnitType))
          continue

        local skill = getCrewSkillValue(crew?.id, unit, page.id, item.name)
        if (countByNewValues)
          skill = getTblValue("newValue", item, skill)
        res += getSkillCrewLevel(item, skill)
      }
  return res
}

function isAllCrewsMinLevel() {
  foreach (checkedCountrys in getCrewsList())
    foreach (crew in checkedCountrys.crews)
      foreach (unitType in unitTypes.types)
        if (unitType.isAvailable()
            && getCrewLevel(crew, getCrewUnit(crew), unitType.crewUnitType) > getMinCrewLevel(unitType.crewUnitType))
          return false

  return true
}


function isCrewMaxLevel(crew, unit, country, crewUnitType = -1) {
  foreach (page in crewSkillPages) {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach (skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && isCountryHasAnyEsUnitType(country,
            unitTypes.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask))
          && getCrewMaxSkillValue(skillItem) > getCrewSkillValue(crew.id, unit, page.id, skillItem.name))
        return false
  }
  return true
}

function getCrewTotalSteps(skillItem) {
  return min(totalSkillsSteps, max(getCrewMaxSkillValue(skillItem), 1))
}

function getSkillStepSize(skillItem) {
  let maxSkill = getCrewMaxSkillValue(skillItem)
  return max(ceil(maxSkill.tofloat() / getCrewTotalSteps(skillItem)).tointeger(), 1)
}

function crewSkillValueToStep(skillItem, value) {
  let step = getSkillStepSize(skillItem)
  return value.tointeger() / step
}

function crewSkillStepToValue(skillItem, curStep) {
  return curStep * getSkillStepSize(skillItem)
}

function getNextCrewSkillStepValue(skillItem, curValue, increment = true, stepsAmount = 1) {
  let step = getSkillStepSize(skillItem)
  if (!increment)
    return max(curValue - step * stepsAmount - (curValue % step), 0)

  let maxSkill = getCrewMaxSkillValue(skillItem)
  return min(curValue + step * stepsAmount - (curValue % step), maxSkill)
}

function getNextCrewSkillStepCost(skillItem, curValue, stepsAmount = 1) {
  let nextValue = getNextCrewSkillStepValue(skillItem, curValue, true, stepsAmount)
  if (nextValue == curValue)
    return 0
  return getCrewSkillCost(skillItem, nextValue, curValue)
}

function getMaxAvailbleCrewStepValue(skillItem, curValue, skillPoints) {
  let maxValue = getCrewMaxSkillValue(skillItem)
  let maxCost = skillPoints + getCrewSkillCost(skillItem, curValue, 0)
  if (getCrewSkillCost(skillItem, maxValue, 0) <= maxCost) 
    return maxValue

  local resValue = curValue
  let step = getSkillStepSize(skillItem)
  for (local i = getNextCrewSkillStepValue(skillItem, curValue); i < maxValue; i += step)
    if (getCrewSkillCost(skillItem, i, 0) <= maxCost)
      resValue = i
  return resValue
}



function doWithAllSkills(crew, crewUnitType, action) {
  let country = getCrewCountry(crew)
  foreach (page in crewSkillPages) {
    if (crewUnitType >= 0 && !page.isVisible(crewUnitType))
      continue

    foreach (skillItem in page.items)
      if ((crewUnitType < 0 || skillItem.isVisible(crewUnitType))
          && isCountryHasAnyEsUnitType(country,
            unitTypes.getEsUnitTypeMaskByCrewUnitTypeMask(skillItem.crewUnitTypeMask)))
        action(page, skillItem)
  }
}


function getCrewSkillPointsToMaxAllSkills(crew, unit, crewUnitType = -1) {
  local res = 0
  doWithAllSkills(crew, crewUnitType,
    function(page, skillItem) {
      let maxValue = getCrewMaxSkillValue(skillItem)
      let curValue = getCrewSkillValue(crew.id, unit, page.id, skillItem.name)
      if (curValue < maxValue)
        res += getCrewSkillCost(skillItem, maxValue, curValue)
    }
  )
  return res
}

function hasSkillPointsToRunTutorial(crew, unit, crewUnitType, skillPage) {
  local skillCount = 0
  local skillPointsNeeded = 0
  foreach (_idx, item in skillPage.items)
    if (item.isVisible(crewUnitType)) {
      let itemSkillValue = getCrewSkillValue(crew.id, unit, skillPage.id, item.name)
      skillPointsNeeded += getNextCrewSkillStepCost(item, itemSkillValue)
      ++skillCount
      if (skillCount >= UPGR_CREW_TUTORIAL_SKILL_NUMBER)
        break
    }

  if (skillCount < UPGR_CREW_TUTORIAL_SKILL_NUMBER)
    return false

  return getCrewSkillPoints(crew) >= skillPointsNeeded
}

function getCrewSkillPageIdToRunTutorial(crew) {
  let unit = getCrewUnit(crew)
  if (!unit)
    return null

  let crewUnitType = unit.getCrewUnitType()
  foreach (skillPage in crewSkillPages)
    if (skillPage.isVisible(crewUnitType))
      if (hasSkillPointsToRunTutorial(crew, unit, crewUnitType, skillPage))
        return skillPage.id

  return null
}

let minStepsForCrewStatus = [1, 2, 3]

function count_available_skills(crew, crewUnitType) { 
  let curPoints = ("skillPoints" in crew) ? crew.skillPoints : 0
  if (!curPoints)
    return {needUnseenIcon = false, count = 0}

  let crewSkills = get_aircraft_crew_by_id(crew.id)
  local notMaxTotal = 0
  let available = [0, 0, 0]
  local maxStepCost = 0

  foreach (page in crewSkillPages)
    foreach (item in page.items) {
      if (!item.isVisible(crewUnitType))
        continue

      let totalSteps = getCrewTotalSteps(item)
      let crewSkillValue = crewSkills?[page.id][item.name] ?? 0
      let curStep = crewSkillValueToStep(item, crewSkillValue)
      if (curStep == totalSteps)
        continue

      notMaxTotal++
      foreach (idx, amount in minStepsForCrewStatus) {
        if (curStep + amount > totalSteps)
          continue

        let stepCost = getNextCrewSkillStepCost(item, crewSkillValue, amount)
        if (amount == 1
          && item?.memberName != "groundService" && (item?.memberName != "gunner" || item?.name != "members"))
          maxStepCost = max(stepCost, maxStepCost)

        if (stepCost <= curPoints)
          available[idx]++
      }
    }

  let needUnseenIcon = !(maxStepCost == 0 || maxStepCost > curPoints)

  if (notMaxTotal == 0)
    return {needUnseenIcon, count = 0}

  for (local i = 2; i >= 0; i--)
    if (available[i] >= 0.5 * notMaxTotal)
      return {needUnseenIcon, count = i + 1}
  return {needUnseenIcon, count = 0}
}

function isCrewNeedUnseenIcon(crew, unit) {
  unit = unit ?? getAircraftByName(crew?.aircraft ?? "")
  if (unit == null)
    return false
  let crewUnitType = unit.getCrewUnitType()
  return unseenIconsNeeds?[crew.id][crewUnitType] ?? false
}

local isCrewSkillsAvailableInited = false

function updateCrewSkillsAvailable(forceUpdate = false) {
  if (isCrewSkillsAvailableInited && !forceUpdate)
    return
  isCrewSkillsAvailableInited = true

  loadCrewSkillsOnce()
  availableCrewSkills.clear()
  unseenIconsNeeds.clear()
  foreach (cList in getCrewsList())
    foreach (_idx, crew in (cList?.crews ?? [])) {
      let data = {}
      let unseenIconsData = {}
      foreach (unitType in unitTypes.types) {
        let crewUnitType = unitType.crewUnitType
        if (!data?[crewUnitType]) {
          let skillsAvailable = count_available_skills(crew, crewUnitType)
          data[crewUnitType] <- skillsAvailable.count
          unseenIconsData[crewUnitType] <- skillsAvailable.needUnseenIcon
        }
      }
      availableCrewSkills[crew.id] <- data
      unseenIconsNeeds[crew.id] <- unseenIconsData
    }
}

function onEventCrewSkillsChanged(params) {
  if (!params?.isOnlyPointsChanged) {
    let unit = params?.unit ?? getCrewUnit(params.crew)
    if (unit)
      unit.invalidateModificators()
  }
  updateCrewSkillsAvailable(true)
}

function getCrewStatus(crew, unit) {
  local status = ""
  if (isInFlight())
    return status
  foreach (id, data in availableCrewSkills) {
    if (id != crew.id)
      continue
    unit = unit ?? getAircraftByName(crew?.aircraft ?? "")
    if (unit == null)
      break
    let crewUnitType = unit.getCrewUnitType()
    if (!(crewUnitType in data))
      break

    let res = data[crewUnitType]
    if (res == 3)
      status = "full"
    else if (res == 2)
      status = "ready"
    else if (res == 1)
      status = "show"
    else
      status = ""
    break
  }
  return status
}

addListenersWithoutEnv({
  CrewSkillsChanged = onEventCrewSkillsChanged
}, g_listener_priority.UNIT_CREW_CACHE_UPDATE)

return {
  getCrew
  crewSkillPages
  unitCrewTrainReq
  maxCrewLevel
  createCrewBuyPointsHandler
  getCrewButtonRow
  createCrewUnitSpecHandler
  getCrewSkillValue
  getCrewSkillItem
  getCrewSkillNewValue
  getCrewMaxSkillValue
  getCrewSkillCost
  getCrewName
  getCrewUnit
  getCrewCountry
  getCrewTrainCost
  getCrewSkillPoints
  purchaseNewCrewSlot
  getSkillMaxCrewLevel
  getMinCrewLevel
  getMaxCrewLevel
  isAllCrewsMinLevel
  isCrewMaxLevel
  getCrewLevel
  getCrewTotalSteps
  crewSkillValueToStep
  crewSkillStepToValue
  getNextCrewSkillStepValue
  getNextCrewSkillStepCost
  getMaxAvailbleCrewStepValue
  getCrewSkillPointsToMaxAllSkills
  getCrewSkillPageIdToRunTutorial
  getSkillCrewLevel
  loadCrewSkills
  loadCrewSkillsOnce
  updateCrewSkillsAvailable
  getCrewStatus
  isCrewNeedUnseenIcon
  doWithAllSkills
}
