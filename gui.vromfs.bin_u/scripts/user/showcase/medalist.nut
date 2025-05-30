from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import get_unlock_type

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { openSelectionWindow } = require("%scripts/selectionWindow.nut")
let { getUnlocksByTypeInBlkOrder, getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockableMedalImage, getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isArray } = require("%sqstd/underscore.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { RESET_ID } = require("%scripts/popups/popupFilterWidget.nut")
let { utf8ToLower } = require("%sqstd/string.nut")

const MEDALS_SLOTS_COUNT = 10
const MEDALIST_EDIT_CONTAINER_ID = "medalist_container_edit"
const DEF_MEDAL_SIZE = "166@sf/@pf"

let medalSizeConfig = [
  {
    minCount = 8
    medalSize = "112@sf/@pf"
  },
  {
    minCount = 3
    medalSize = "146@sf/@pf"
  }
]

local filtersData = {}

let getMedalTooltip = @(medalData) getTooltipType("UNLOCK").getTooltipId(medalData.id, {needTitle = false, hideAward = true})

function createMedalViewItem(name) {
  let unlock = getUnlockById(name)
  return {
    id = name
    enabled = true
    lowerName = utf8ToLower(getUnlockNameText(UNLOCKABLE_MEDAL, name))
    country = unlock.country
    image = getUnlockableMedalImage(name)
  }
}

function searchMedal(medals, searchString) {
  let lowerSearchString = searchString.tolower()
  return medals.filter(@(medal) medal.lowerName.contains(lowerSearchString))
}

function onChangeFilterItem(objId, _typeName, value) {
  if (objId == RESET_ID)
    foreach (inst in filtersData.countries)
      inst.value = false
  else
    filtersData.countries[objId].value = value
}

function filterMedal(medal) {
  foreach (country in filtersData.countries)
    if (country.value)
      return filtersData.countries[medal.country].value
  return true
}

function updateMedalsFilter(medals) {
  let filters = {countries = {}}

  foreach (medal in medals) {
    let country = medal.country
    if (country == null || filters.countries?[country] != null)
      continue

    filters.countries[country] <- {
      id = country, value = filtersData?.countries[country].value ?? false,
      text = loc(country), objId = country, image = getCountryIcon(country),
      idx = shopCountriesList.findindex(@(id) id == country) ?? -1
    }
  }
  filtersData = filters
}

function getFiltersView() {
  let res = []
  let view = { checkbox = [] }
  foreach (country in filtersData.countries)
    view.checkbox.append(country)

  view.checkbox.sort(@(a, b) a.idx <=> b.idx)
  if (view.checkbox.len() > 0)
    view.checkbox.top().isLastCheckBox <- true
  res.append(view)
  return res
}

function onMedalChooseApply(slotIdx, medalData, scene, terseInfo) {
  let container = scene.findObject(MEDALIST_EDIT_CONTAINER_ID)
  let slot = container.findObject($"medalist_slot_{slotIdx}")
  slot["background-image"] = medalData ? getUnlockableMedalImage(medalData.id, true) : ""
  slot.medal = medalData?.id ?? ""
  slot["background-color"] = medalData?.image == null ? "#00000000" : "#FFFFFF"
  let slotTooltip = slot.findObject("slot_tooltip")
  slotTooltip.tooltipId = medalData?.id != null ? getMedalTooltip(medalData) : ""

  if (terseInfo.showcase?.medals == null)
    terseInfo.showcase.medals <- []

  local slotsCount = terseInfo.showcase.medals.len()
  while (slotsCount <= slotIdx) {
    terseInfo.showcase.medals.append("")
    slotsCount++
  }
  terseInfo.showcase.medals[slotIdx] = medalData?.id ?? ""
  if (showConsoleButtons.get())
    move_mouse_on_obj(slot)
}

function getMedalsStats(playerStats) {
  let unlockedMedals = playerStats?.unlocks.medal
  let allMedals = getUnlocksByTypeInBlkOrder("medal")

  local totalCount = 0
  if (unlockedMedals != null) {
    foreach (medal in allMedals) {
      if (medal?.hideUntilUnlocked && !isUnlockOpened(medal.id, UNLOCKABLE_MEDAL))
        continue
      totalCount++
    }
    return {totalCount, gained = unlockedMedals.len()}
  }

  local gained = 0
  foreach (medal in allMedals) {
    if (medal?.hideUntilUnlocked && !isUnlockOpened(medal.id, UNLOCKABLE_MEDAL))
      continue
    totalCount++
    if (medal?.country != null && isUnlockOpened(medal.id, UNLOCKABLE_MEDAL))
      gained++
  }

  return {totalCount, gained}
}

function getMedalsForSelect(playerStats, terseInfo) {
  local unlockedMedals = playerStats?.unlocks.medals
  let medalsData = []
  if (unlockedMedals != null) {
    foreach (medal in unlockedMedals)
      if (!terseInfo.showcase?.medals.contains(medal))
        medalsData.append(createMedalViewItem(medal))
    return medalsData
  }

  let allMedals = getUnlocksByTypeInBlkOrder("medal")
  foreach (medal in allMedals)
    if (medal?.country != null && !terseInfo.showcase?.medals.contains(medal.id) && isUnlockOpened(medal.id, UNLOCKABLE_MEDAL))
      medalsData.append(createMedalViewItem(medal.id))

  return medalsData
}

let medalist = {
  hasGameMode = false
  terseName = "medalist"
  locName = "medalist/name"
  hasOnlySecondTitle = true
  getSecondTitle = @(_terseInfo) loc("medalist/name")
  onClickFunction = function(obj, terseInfo, playerStats, scene) {
    let slotIdx = obj.slotId.tointeger()
    let medals = getMedalsForSelect(playerStats, terseInfo)
    updateMedalsFilter(medals)
    let onApplyFunc = @(medalData) (onMedalChooseApply(slotIdx, medalData, scene, terseInfo))

    openSelectionWindow({
      items = medals, itemsCountX = 8, itemsCountY = 6, title = loc("mainmenu/btnMedal")
      hasDeleteBtn = obj.medal != "", getTooltip = getMedalTooltip,
      getFiltersView = medals.len() > 0 ? getFiltersView : null, filterFn = filterMedal,
      sizeX = "100@sf/@pf", sizeY = "100@sf/@pf", spaceX = "10@sf/@pf", spaceY = "10@sf/@pf",
      onChangeFilterItem, searchFn = searchMedal
    }, onApplyFunc)
  }
  canBeSaved = function(terseInfo) {
    let hasSelectedMedal = (terseInfo.showcase?.medals.filter(@(m) m != "").len() ?? 0) > 0
    if (!hasSelectedMedal)
      showInfoMsgBox(loc("msg/warning_select_medal"))

    return hasSelectedMedal
  }
  getSaveData = function(terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "medalist"
    if (terseInfo.showcase?.medals != null)
      foreach (medal in terseInfo.showcase.medals)
        data.medals <- medal

    return data
  }
  getViewData = function(_showcase, playerStats, terseInfo, viewParams = null) {
    let { scale = 1 } = viewParams
    if (terseInfo.showcase?.medals && !isArray(terseInfo.showcase.medals))
      terseInfo.showcase.medals = [terseInfo.showcase.medals]
    if (terseInfo.showcase?.medals == null)
      terseInfo.showcase.medals <- []

    let medals = terseInfo.showcase.medals
    let editableSlots = []
    local medalsCount = 0

    let medalsView = []
    for (local i = 0; i < MEDALS_SLOTS_COUNT; i++) {
      let slot = {slotId = i}
      editableSlots.append(slot)
      let medal = medals?[i]
      if (medal == null || medal == "")
        continue
      let image = getUnlockableMedalImage(medal, true)
      let tooltipId = getMedalTooltip({id = medal})
      medalsView.append({image, tooltipId})
      medalsCount = medalsCount + 1
      slot.image <- getUnlockableMedalImage(medal)
      slot.medal <- medal
      slot.tooltipId <- tooltipId
    }

    let { medalSize = DEF_MEDAL_SIZE } = medalSizeConfig.findvalue(@(v) medalsCount > v.minCount)
    let medalsStats = getMedalsStats(playerStats)
    return handyman.renderCached("%gui/profile/showcase/medalist.tpl", { medalsView, medalSize,
      scale, editableSlots, width = "112@sf/@pf", height = "112@sf/@pf",
      medalsStats = $"{medalsStats.gained}/{medalsStats.totalCount}", containerId = MEDALIST_EDIT_CONTAINER_ID
    })
  }
}

return {
  medalist
}