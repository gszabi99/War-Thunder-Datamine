from "%scripts/dagui_natives.nut" import get_game_mode_name, get_mission_progress
from "%scripts/dagui_library.nut" import *

let { get_meta_missions_info_by_chapters } = require("guiMission")
let { set_game_mode, get_game_mode } = require("mission")
let { saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")

let skipTutorialBitmaskId = "skip_tutorial_bitmask"

let reqTutorial = {
  [ES_UNIT_TYPE_AIRCRAFT] = "tutorialB_takeoff_and_landing",
  //[ES_UNIT_TYPE_TANK] = "",
}

function resetTutorialSkip() {
  saveLocalByAccount(skipTutorialBitmaskId, 0)
}

let getReqTutorial = @(unitType) reqTutorial?[unitType] ?? ""

let reqTimeInMode = 60 //req time in mode when no need check tutorial
function isDiffUnlocked(diff, checkUnitType) {
  //check played before
  for (local d = diff; d < 3; d++)
    if (::my_stats.getTimePlayed(checkUnitType, d) >= reqTimeInMode)
      return true

  let reqName = getReqTutorial(checkUnitType)
  if (reqName == "")
    return true

  let mainGameMode = get_game_mode()
  set_game_mode(GM_TRAINING)  //req to check progress

  let chapters = get_meta_missions_info_by_chapters(GM_TRAINING)
  foreach (chapter in chapters)
    foreach (m in chapter)
      if (reqName == m.name) {
        let fullMissionName = $"{m.getStr("chapter", get_game_mode_name(GM_TRAINING))}/{m.name}"
        let progress = get_mission_progress(fullMissionName)
        if (mainGameMode >= 0)
          set_game_mode(mainGameMode)
        return (progress < 3 && progress >= diff) // 3 == unlocked, 0-2 - completed at difficulty
      }
  assert(false, $"Error: Not found mission req_tutorial_name = {reqName}")
  set_game_mode(mainGameMode)
  return true
}

return {
  isDiffUnlocked
  getReqTutorial
  skipTutorialBitmaskId
  resetTutorialSkip
  reqTutorial
}