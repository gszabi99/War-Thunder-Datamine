from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { scan_folder } = require("dagor.fs")
let { generateListTree, getBranchDataByPath } = require("%scripts/utils/listTreeUtils.nut")
let { blkFromPath, eachBlock } = require("%sqstd/datablock.nut")
let { copyFromDataBlock, setBlkValueByPath } = require("%globalScripts/dataBlockExt.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { convertFromTemplateName } = require("%scripts/customization/infantryCamouflageUtils.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { frnd } = require("dagor.random")
let DataBlock = require("DataBlock")
let { get_charserver_time_sec } = require("chard")
let seenList = require("%scripts/seen/seenList.nut")

const SKINS_DEEP_IN_TREE = 5

local cachedSkinFileList = null
local skinListTree = null
let branchesNeedMerge = ["infantry_equipment__teamSkins"]
let pathToSaveData = "infantry_skins/selected_skins"
let pathToSaveDataByWeapon = "infantry_skins/units"
local internalSkinsSeenList = null

const DEFAULT_SKINS = {
  default = "default"
  random = "random"
  randomNotDefault = "random_not_default"
}

const skinSortId = {
  [DEFAULT_SKINS.default] = 1,
  [DEFAULT_SKINS.random] = 2,
  [DEFAULT_SKINS.randomNotDefault] = 3,
}

local cachedSaveData = null
local cachedSaveDataByWeapon = DataBlock()

let innerSkinNames = [
  DEFAULT_SKINS.random,
  DEFAULT_SKINS.randomNotDefault
]

let sortSkinsFn = @(a, b)
  (skinSortId?[a?.id ?? a] ?? -1) <=> (skinSortId?[b?.id ?? b] ?? -1)

function getBranchName(location, team = -1, tier = -1) {
  return "".concat($"{location}_infantry_skins",
    team >= 0 ? $"/team_{team}" : "",
    tier >= 0 ? $"/tier_{tier}_squad" : ""
  )
}

function insertAdditionalButtons(blkData, deep) {
  let nextDeep = deep - 1
  let self = callee()
  eachBlock(blkData, function(data, _id) {
    if (nextDeep > 1)
      self(data, nextDeep)
    else {
      data[DEFAULT_SKINS.random] <- true
      data[DEFAULT_SKINS.randomNotDefault] <- true
    }
  }, this)
}

function getSaveData() {
  if (cachedSaveData == null) {
    cachedSaveData = DataBlock()
    copyFromDataBlock(loadLocalAccountSettings(pathToSaveData, null) ?? DataBlock(), cachedSaveData)
  }
  return cachedSaveData
}

function getApplyToAllState(location, team, tier) {
  team = $"{team}"
  tier = $"{tier}"
  let saveData = getSaveData()
  return saveData?[location][team][tier].applyToAll ?? false
}

function getSaveDataByWeapon(unitName) {
  if (cachedSaveDataByWeapon?[unitName] == null) {
    cachedSaveDataByWeapon[unitName] <- DataBlock()
    let savePath = $"{pathToSaveDataByWeapon}/{unitName}"
    copyFromDataBlock(loadLocalAccountSettings(savePath, null) ?? DataBlock(), cachedSaveDataByWeapon[unitName])
  }
  return cachedSaveDataByWeapon?[unitName]
}

function getInfantrySkinsLocationsList() {
  if (cachedSkinFileList == null) {
    let pathToConfigs = "%gameBase/templates/infantry_skins/"
    cachedSkinFileList = scan_folder({ root = pathToConfigs, vromfs = true, realfs = true, recursive = false, files_suffix = "*.blk" })
  }
  return cachedSkinFileList
}

function getInfantrySkinOnLocation(location, team, tier, unitName = "") {
  team = $"{team}"
  tier = $"{tier}"
  let saveDataByWeapon = unitName == "" ? null : getSaveDataByWeapon(unitName)
  let saveData = getSaveData()

  let saveTime = saveData?[location][team][tier].time ?? 1
  let saveTimeByWeapon = saveDataByWeapon?[location][team][tier].time ?? 0

  let usedSaveData = saveTime > saveTimeByWeapon ? saveData : saveDataByWeapon
  return usedSaveData?[location][team][tier].skin ?? DEFAULT_SKINS.default
}

function parseSkinPathArr(pathArr) {
  let location = convertFromTemplateName.location(pathArr[0])
  let team = convertFromTemplateName.team(pathArr[1])
  let tier = convertFromTemplateName.tier(pathArr[2])
  let skin = pathArr[3]
  return {location, team, tier, skin}
}

function getSavedSkinByPatchArr(pathArr, unitName = "") {
  let {location, team, tier} = parseSkinPathArr(pathArr)
  return getInfantrySkinOnLocation(location, team, tier, unitName)
}

function getDataForTreeItem(id, _data, _path, deep) {
  if (deep == 1)
    return { isTier = true, tier = id.split("_")[1].tointeger() }

  if (deep != 0)
    return {}

  return { isSkin = true, skinName = id }
}

function addSkinsFromBlk(blkData) {
  if (!skinListTree)
    skinListTree = { branches = {}, path = "" }
  let params = { getData = getDataForTreeItem, mergeBranches = branchesNeedMerge }
  generateListTree(skinListTree, blkData, SKINS_DEEP_IN_TREE, params)
}

function getInfantrySkinsTree() {
  if (!skinListTree) {
    let locationFilesList = getInfantrySkinsLocationsList()
    foreach (fileName in locationFilesList) {
      let blk = blkFromPath(fileName)
      insertAdditionalButtons(blk, SKINS_DEEP_IN_TREE)
      addSkinsFromBlk(blk)
    }
  }
  return skinListTree
}

function hasSkinsForLocation(location) {
  let skinsTree = getInfantrySkinsTree()
  let branchName = getBranchName(location)
  let branchData = getBranchDataByPath(skinsTree, branchName)
  return branchData != null
}

function getLocationInfantrySkins(location, team, tier) {
  let skinsTree = getInfantrySkinsTree()
  let branchName = getBranchName(location, team, tier)
  let branchData = getBranchDataByPath(skinsTree, branchName)
  if (branchData == null) {
    logerr($"getLocationInfantrySkins: not found skins branch {branchName}")
    return null
  }
  let skins = []
  foreach (idx, branch in branchData.branches)
    if (branch?.data.isSkin)
      skins.append(idx)

  return skins.sort(sortSkinsFn)
}

function saveInfantrySkin(skin, location, teamNum, tier, unitName = "") {
  let saveData = unitName == "" ? getSaveData() : getSaveDataByWeapon(unitName)

  teamNum = $"{teamNum}"
  tier = $"{tier}"
  if (saveData?[location] == null)
    saveData[location] <- DataBlock()

  let locationData = saveData[location]
  if (locationData?[teamNum] == null)
    locationData[teamNum] <- DataBlock()

  locationData[teamNum].removeBlock(tier)
  locationData[teamNum][tier] <- DataBlock()
  locationData[teamNum][tier].skin <- skin
  locationData[teamNum][tier].time <- get_charserver_time_sec()
  if (unitName == "") {
    locationData[teamNum][tier].applyToAll <- true
  } else {
    let currentApplyToAllState = getApplyToAllState(location, teamNum, tier)
    if (currentApplyToAllState) {
      setBlkValueByPath(getSaveData(), $"{location}/{teamNum}/{tier}/applyToAll", false)
      saveLocalAccountSettings($"{pathToSaveData}/{location}/{teamNum}/{tier}/applyToAll", false)
    }
  }
  let savePath = unitName == "" ? $"{pathToSaveData}/{location}" : $"{pathToSaveDataByWeapon}/{unitName}/{location}"
  saveLocalAccountSettings(savePath, locationData)
}

function saveInfantrySkinByPath(path, unitName = "") {
  let pathArr = path.split("/")
  let {location, team, tier} = parseSkinPathArr(pathArr)
  let skin = pathArr[3]
  saveInfantrySkin(skin, location, team, tier, unitName)
}

function getRandomSkin(location, team, tier, notDefaultSkin = false) {
  let allSkins = getLocationInfantrySkins(location, team, tier)
  let skins = allSkins.filter(@(skin)
    !innerSkinNames.contains(skin)
      && (!notDefaultSkin || !skin.contains(DEFAULT_SKINS.default))
  )
  let randomIndex = (frnd() * skins.len()).tointeger()
  return skins[randomIndex]
}

function getReleasedLocationSkin(location, team, tier, unitName = "") {
  local skinName = getInfantrySkinOnLocation(location, team, tier, unitName)
  let isRandomNotDefault = skinName == DEFAULT_SKINS.randomNotDefault
  if (skinName == DEFAULT_SKINS.random || isRandomNotDefault)
    skinName = getRandomSkin(location, team, tier, isRandomNotDefault)
  return skinName
}

function getTierByMrank(location, team, mRank) {
  let skinsTree = getInfantrySkinsTree()
  let branchName = getBranchName(location, team)
  let branchData = getBranchDataByPath(skinsTree, branchName)
  if (branchData == null)
    return -1

  local maxTier = 0
  foreach (branch in branchData.branches) {
    if (!branch.data?.isTier)
      continue
    if (mRank <= branch.data.tier)
      return branch.data.tier
    maxTier = branch.data.tier
  }
  return maxTier
}

function getTiersRangeOnLocation(location) {
  location = convertFromTemplateName.location(location)
  let branchName = getBranchName(location, 1)
  let branch = getBranchDataByPath(getInfantrySkinsTree(), branchName)
  let tiers = []
  foreach (tierId, _tierData in branch.branches)
    tiers.append(to_integer_safe(convertFromTemplateName.tier(tierId)))
  return tiers.sort(@(a, b) a <=> b)
}

let isSkinCanBeNew = @(skinId) !([DEFAULT_SKINS.random, DEFAULT_SKINS.randomNotDefault].contains(skinId))

function getSeenListForAll() {
  let skinsTree = getInfantrySkinsTree()
  let skinsList = []
  if (skinsTree == null)
    return skinsList
  foreach (locationData in skinsTree.branches)
    foreach (teamData in locationData.branches)
      foreach (tierData in teamData.branches)
        foreach (skinId, skinData in tierData.branches)
          if (isSkinCanBeNew(skinId))
            skinsList.append(skinData.path)
  return skinsList
}

function getSeenListSubset(skinSeenList, location, seenTier = -1) {
  let skinsTree = getInfantrySkinsTree()
  let branchName = getBranchName(location)
  let branch = getBranchDataByPath(skinsTree, branchName)
  let subset = []
  if (branch == null)
    return subset
  foreach (teamData in branch.branches)
    foreach (tierId, tierData in teamData.branches) {
      if (seenTier != -1 && seenTier != convertFromTemplateName.tier(tierId))
        continue

      foreach (skinId, skinData in tierData.branches)
        if (isSkinCanBeNew(skinId) && skinSeenList.isNew(skinData.path))
          subset.append(skinData.path)
    }
  return subset
}

function getSkinsSeenList() {
  if (internalSkinsSeenList != null)
    return internalSkinsSeenList
  internalSkinsSeenList = seenList.get(SEEN.INFANTRY_CAMOUFLAGE)
  internalSkinsSeenList.setListGetter(@() getSeenListForAll())
  return internalSkinsSeenList
}

function onLogout() {
  cachedSaveData = null
  cachedSaveDataByWeapon = DataBlock()
  internalSkinsSeenList = null
}

addListenersWithoutEnv({
  SignOut = @(_) onLogout()
} g_listener_priority.CONFIG_VALIDATION)

return {
  getInfantrySkinsTree
  getInfantrySkinOnLocation
  getLocationInfantrySkins
  saveInfantrySkin
  saveInfantrySkinByPath
  getReleasedLocationSkin
  getTierByMrank
  DEFAULT_SKINS
  getRandomSkin
  getApplyToAllState
  sortSkinsFn
  getBranchName
  getTiersRangeOnLocation
  getSavedSkinByPatchArr
  hasSkinsForLocation
  getSeenListSubset
  getSkinsSeenList
  isSkinCanBeNew
  parseSkinPathArr
}