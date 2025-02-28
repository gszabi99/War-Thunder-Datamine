from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { openSelectionWindow } = require("%scripts/selectionWindow.nut")
let { getUnlocksByTypeInBlkOrder, getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { buildConditionsConfig, getUnlockNameText, getUnlockImageConfig
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { isArray } = require("%sqstd/underscore.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { utf8ToLower } = require("%sqstd/string.nut")

const ACHIEVEMENTS_SLOTS_COUNT = 10
const ACHIEV_HUNTER_EDIT_CONTAINER_ID = "achiev_hunter_container_edit"
const DEF_ACHIEV_SIZE = "166@sf/@pf"

let achievSizeConfig = [
  {
    minCount = 8
    achievSize = "112@sf/@pf"
  },
  {
    minCount = 3
    achievSize = "146@sf/@pf"
  }
]

let getTrophyTooltip = @(trophy) getTooltipType("UNLOCK").getTooltipId(trophy.id, {needTitle = false, hideAward = true})

function createAchievViewItem(name) {
  let unlock = getUnlockById(name)
  let achievConf = buildConditionsConfig(unlock)
  let imgConfig = getUnlockImageConfig(achievConf)

  return {
    id = name
    enabled = true
    image = imgConfig.image
    lowerName =  utf8ToLower(getUnlockNameText(UNLOCKABLE_TROPHY_STEAM, name))
  }
}

function searchAchiev(achievs, searchString) {
  let lowerSearchString = searchString.tolower()
  return achievs.filter(@(achiev) achiev.lowerName.contains(lowerSearchString))
}

function onAchievChooseApply(slotIdx, achievData, scene, terseInfo) {
  let container = scene.findObject(ACHIEV_HUNTER_EDIT_CONTAINER_ID)
  let slot = container.findObject($"hunter_slot_{slotIdx}")
  slot["background-image"] = achievData?.image ?? ""
  slot.achiev = achievData?.id ?? ""
  slot["background-color"] = achievData?.image == null ? "#00000000" : "#FFFFFF"
  let slotTooltip = slot.findObject("slot_tooltip")
  slotTooltip.tooltipId = achievData?.id != null ? getTrophyTooltip(achievData) : ""

  if (terseInfo.showcase?.achievements == null)
    terseInfo.showcase.achievements <- []

  local slotsCount = terseInfo.showcase.achievements.len()
  while (slotsCount <= slotIdx) {
    terseInfo.showcase.achievements.append("")
    slotsCount++
  }
  terseInfo.showcase.achievements[slotIdx] = achievData?.id ?? ""
  if (showConsoleButtons.get())
    move_mouse_on_obj(slot)
}

function getAchievStats(_terseInfo, playerStats) {
  let allSteamTrophyes = getUnlocksByTypeInBlkOrder("trophy_steam")
  let gained = playerStats?.unlocks.trophy_steam
    ? playerStats.unlocks.trophy_steam.len()
    : allSteamTrophyes.filter(@(a) isUnlockOpened(a.id, UNLOCKABLE_TROPHY_STEAM)).len()

  return {totalCount = allSteamTrophyes.len(), gained}
}

function getAchievsForSelect(playerStats, terseInfo) {
  local unlockedAchiev = playerStats?.unlocks.trophy_steam
  let achievsData = []
  if (unlockedAchiev != null) {
    foreach (achiev, val in unlockedAchiev)
      if (val > 0 && !terseInfo.showcase?.achievements.contains(achiev))
        achievsData.append(createAchievViewItem(achiev))
    return achievsData
  }

  let allSteamTrophy = getUnlocksByTypeInBlkOrder("trophy_steam")
  foreach (achiev in allSteamTrophy)
    if (!terseInfo.showcase?.achievements.contains(achiev.id) && isUnlockOpened(achiev.id, UNLOCKABLE_TROPHY_STEAM))
      achievsData.append(createAchievViewItem(achiev.id))

  return achievsData
}

let achivHunter = {
  hasGameMode = false
  terseName = "achievement_hunter"
  locName = "achievement_hunter/name"
  hasOnlySecondTitle = true
  getSecondTitle = @(_terseInfo) loc("achievement_hunter/name")
  onClickFunction = function(obj, terseInfo, playerStats, scene) {
    let slotIdx = obj.slotId.tointeger()
    let achievs = getAchievsForSelect(playerStats, terseInfo)
    let onApplyFunc = @(achievData) (onAchievChooseApply(slotIdx, achievData, scene, terseInfo))

    openSelectionWindow({
      items = achievs, itemsCountX = 8, itemsCountY = 6, title = loc("unlocks/chapter/achievements")
      hasDeleteBtn = obj.achiev != "", getTooltip = getTrophyTooltip,
      sizeX = "100@sf/@pf", sizeY = "100@sf/@pf", spaceX = "20@sf/@pf", spaceY = "20@sf/@pf",
      searchFn = searchAchiev
    }, onApplyFunc)
  }
  canBeSaved = function(terseInfo) {
    let hasSelectedAchiev = (terseInfo.showcase?.achievements.filter(@(m) m != "").len() ?? 0) > 0
    if (!hasSelectedAchiev)
      showInfoMsgBox(loc("msg/warning_select_achievement"))

    return hasSelectedAchiev
  }
  getSaveData = function(terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "achievement_hunter"
    if (terseInfo.showcase?.achievements != null)
      foreach (achievement in terseInfo.showcase.achievements)
        data.achievements <- achievement

    return data
  }
  getViewData = function(_showcase, playerStats, terseInfo, viewParams = null) {
    let { scale = 1 } = viewParams
    if (terseInfo.showcase?.achievements && !isArray(terseInfo.showcase.achievements))
      terseInfo.showcase.achievements = [terseInfo.showcase.achievements]
    if (terseInfo.showcase?.achievements == null)
      terseInfo.showcase.achievements <- []

    let achievements = terseInfo.showcase.achievements
    let editableSlots = []
    local achievCount = 0

    let achievementsView = []
    for (local i = 0; i < ACHIEVEMENTS_SLOTS_COUNT; i++) {
      let slot = {slotId = i}
      editableSlots.append(slot)
      let achievement = achievements?[i]
      if (achievement == null || achievement == "")
        continue

      let unlockBlk = getUnlockById(achievement)
      let achievData = buildConditionsConfig(unlockBlk)
      let imgConfig = getUnlockImageConfig(achievData)

      let tooltipId = getTrophyTooltip({id = achievement})
      achievementsView.append({image = imgConfig.image, tooltipId})
      achievCount = achievCount + 1
      slot.image <- imgConfig.image
      slot.achiev <- achievement
      slot.tooltipId <- tooltipId
    }

    let { achievSize = DEF_ACHIEV_SIZE } = achievSizeConfig.findvalue(@(v) achievCount > v.minCount)
    let achievStats = getAchievStats(terseInfo, playerStats)
    return handyman.renderCached("%gui/profile/showcase/achievementHunter.tpl", { achievementsView, achievSize,
      scale, editableSlots, width = "112@sf/@pf", height = "112@sf/@pf",
      achievStats = $"{achievStats.gained}/{achievStats.totalCount}", containerId = ACHIEV_HUNTER_EDIT_CONTAINER_ID
    })
  }
}

return {
  achivHunter
}