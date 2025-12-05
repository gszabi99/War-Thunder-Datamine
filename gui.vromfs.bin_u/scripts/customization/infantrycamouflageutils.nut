from "%scripts/dagui_library.nut" import *

let templateLevelNameSuffix = "_infantry_skins"


let localizationKeys = {
  team_2       = @() loc("events/teamB")
  team_1       = @() loc("events/teamA")
  tier_1_squad = @() $"{loc("guiHints/chooseUnitsMMRank")} \"1.0-5.0\""
  tier_2_squad = @() $"{loc("guiHints/chooseUnitsMMRank")} \"5.0-8.0\""
  random       = @() loc("options/random")
  default      = @() loc("default_skin_loc")
}

function getCamoNameById(id) {
  return localizationKeys?[id]() ?? loc($"skin_infantry/{id}/name")
}


let convertFromTemplateName = {
  location = @(val) val.slice(0, val.indexof(templateLevelNameSuffix) ?? 0)
  team = @(val) val.split("_")[1].tointeger()
  tier = @(val) val.split("_")[1].tointeger()
}

function convertLevelNameToLocation(levelFileName) {
  local levelName = levelFileName.slice((levelFileName.indexof("_") ?? - 1) + 1, levelFileName.len())
  return levelName.slice(0, levelName.indexof("."))
}

function getInfantrySkinTooltip(skin) {
  return "".concat(loc("userSkin/custom/desc"), " \"",
    colorize("userlogColoredText", getCamoNameById(skin)),
    "\"\n", loc("userSkin/custom/note"))
}

return {
  convertLevelNameToLocation
  getInfantrySkinTooltip
  convertFromTemplateName
  getCamoNameById
}