local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local string = require("std/string.nut")
local guidParser = require("scripts/guidParser.nut")
local stdMath = require("std/math.nut")

const MAX_LOCATION_TYPES = 64

local locationTypeNameToId = {} //forest = 1, bitId to easy use in mask
local skinsMask = {} //<skinName> = <locationTypeMask>
local levelsMask = {} //<levelName> = <locationTypeMask>
local camoTypesVisibleList = []
local camoTypesIconPriority = []

local function getLocationTypeId(typeName)
{
  if (typeName in locationTypeNameToId)
    return locationTypeNameToId[typeName]

  local idx = locationTypeNameToId.len()
  if (idx > MAX_LOCATION_TYPES)
  {
    ::script_net_assert_once("too much locTypes", "Error: too much location type names in skins")
    idx = MAX_LOCATION_TYPES
  }

  local res = 1 << idx
  locationTypeNameToId[typeName] <- res
  return res
}

local function getLocationsLoc(mask)
{
  local list = []
  if (!mask)
    return list
  foreach(name in camoTypesVisibleList)
    if (mask & getLocationTypeId(name))
      list.append(::loc("camoType/" + name))
  return list
}

local function debugLocationMask(mask)
{
  local list = []
  foreach(name, bit in locationTypeNameToId)
    if (bit & mask)
      list.append(name)
  return mask + ": " + string.implode(list, ", ")
}

local function getLocationMaskByNamesArray(namesList)
{
  local res = 0
  foreach(typeName in namesList)
    res = res | getLocationTypeId(typeName)
  return res
}

local isMasksLoaded = false
local function loadSkinMasksOnce()
{
  if (isMasksLoaded)
    return false
  isMasksLoaded = true

  local skinsBlk = ::DataBlock()
  skinsBlk.load("config/skinsLocations.blk")

  for(local i = 0; i < skinsBlk.blockCount(); i++)
  {
    local blk = skinsBlk.getBlock(i)
    skinsMask[blk.getBlockName()] <- getLocationMaskByNamesArray(blk % "camoType")
  }
  camoTypesVisibleList = []
  if (skinsBlk?.camo_type_visible)
    foreach(b in skinsBlk.camo_type_visible % "camoType")
      camoTypesVisibleList.append(b.name)
  camoTypesIconPriority = []
  if (skinsBlk?.camo_type_icons)
    foreach(b in skinsBlk.camo_type_icons % "camoType")
      camoTypesIconPriority.append(b.name)
}

local function getSkinLocationsMaskByDecoratorTags(id)
{
  local res = 0
  local decorator = ::g_decorator.getDecorator(id, ::g_decorator_type.SKINS)
  if (!decorator || !decorator.tags)
    return res
  foreach (t in camoTypesVisibleList)
    if (decorator.tags?[t])
      res = res | getLocationTypeId(t)
  return res
}

local function getSkinLocationsMaskByFullIdAndSkinId(id, skinId, canBeEmpty)
{
  if (!(id in skinsMask) && !(skinId in skinsMask) && guidParser.isGuid(skinId))
    skinsMask[id] <- getSkinLocationsMaskByDecoratorTags(id)
  return skinsMask?[id] || skinsMask?[skinId] || (canBeEmpty ? 0  : getLocationTypeId("forest"))
}

local function getSkinLocationsMask(skinId, unitId, canBeEmpty = true)
{
  loadSkinMasksOnce()
  return getSkinLocationsMaskByFullIdAndSkinId(unitId + "/" + skinId, skinId, canBeEmpty)
}

local function getSkinLocationsMaskBySkinId(id, canBeEmpty = true)
{
  loadSkinMasksOnce()
  return getSkinLocationsMaskByFullIdAndSkinId(id, ::g_unlocks.getSkinNameBySkinId(id), canBeEmpty)
}

local function getMaskByLevel(level)
{
  if (level in  levelsMask)
    return levelsMask[level]

  local res = 0
  local levelBlk = blkFromPath($"{string.slice(level, 0, -3)}blk")
  local vehiclesSkinsBlk = levelBlk?.technicsSkins
  if (::u.isDataBlock(vehiclesSkinsBlk))
    res = getLocationMaskByNamesArray(vehiclesSkinsBlk % "groundSkin")

  levelsMask[level] <- res
  return res
}

local function getBestSkinsList(skinsList, unitName, level)
{
  local res = []
  local bestMatch = 0
  local locationMask = getMaskByLevel(level)
  foreach(skin in skinsList)
  {
    local match = stdMath.number_of_set_bits(locationMask & getSkinLocationsMask(skin, unitName))
    if (!match)
      continue
    if (match > bestMatch)
    {
      bestMatch = match
      res.clear()
    }
    if (match == bestMatch)
      res.append(skin)
  }
  return res
}

local function getIconTypeByMask(mask)
{
  if (mask)
    foreach (name in camoTypesIconPriority)
      if (mask & getLocationTypeId(name))
        return name
  return "forest"
}

return {
  getSkinLocationsMask = getSkinLocationsMask
  getSkinLocationsMaskBySkinId = getSkinLocationsMaskBySkinId
  getMaskByLevel = getMaskByLevel
  getLocationMaskByNamesArray = getLocationMaskByNamesArray
  getBestSkinsList = getBestSkinsList
  getLocationsLoc = getLocationsLoc
  getIconTypeByMask = getIconTypeByMask
  debugLocationMask = debugLocationMask
}