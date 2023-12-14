from "%scripts/dagui_library.nut" import *
let { get_meta_mission_info_by_name, select_training_mission } = require("guiMission")
let { isModResearched } = require("%scripts/weaponry/modificationInfo.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { register_command } = require("console")
let { set_gui_option, get_gui_option } = require("guiOptions")
let { set_game_mode } = require("mission")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { USEROPT_DIFFICULTY, USEROPT_WEAPONS, USEROPT_AIRCRAFT
} = require("%scripts/options/optionsExtNames.nut")
let DataBlock = require("DataBlock")
let { set_last_called_gui_testflight } = require("%scripts/missionBuilder/testFlightState.nut")

const SEEN_MOD_TUTORIAL_PREFIX = "seen/modification_tutorial"

let seenTutorialStatuses = {
}

let function getSeenTutorialId(missionName) {
  return $"{SEEN_MOD_TUTORIAL_PREFIX}/{missionName}"
}

let function isSeenTutorial(missionName) {
  let id = getSeenTutorialId(missionName)
  if (seenTutorialStatuses?[id] != null)
    return seenTutorialStatuses[id]

  let res = loadLocalAccountSettings(id, false)
  seenTutorialStatuses[id] <- res
  return res
}

let function saveSeenTutorialStatus(missionName, isSeen) {
  let id = getSeenTutorialId(missionName)
  saveLocalAccountSettings(id, isSeen)
  if (seenTutorialStatuses?[id] == null)
    seenTutorialStatuses[id] <- isSeen
  seenTutorialStatuses[id] = isSeen

  broadcastEvent("MarkSeenModTutorial", { missionName })
}

let function hasAvailableModTutorial(unit, mod) {
  return mod?.tutorialMission != null
    && isModResearched(unit, mod)
    && get_meta_mission_info_by_name(mod.tutorialMission) != null
}

let function needShowUnseenModTutorialForUnit(unit) {
  return unit.modifications
    .findvalue(@(mod) hasAvailableModTutorial(unit, mod) && !isSeenTutorial(mod?.tutorialMission))
}

let function needShowUnseenModTutorialForUnitMod(unit, mod) {
  return hasAvailableModTutorial(unit, mod) && !isSeenTutorial(mod?.tutorialMission)
}

let function startModTutorialMission(unit, tutorialMission, tutorialMissionWeapon = null) {
  let misInfo = get_meta_mission_info_by_name(tutorialMission)

  ::cur_aircraft_name = unit.name
  ::aircraft_for_weapons = unit.name
  set_last_called_gui_testflight(handlersManager.getLastBaseHandlerStartParams())

  set_game_mode(GM_TRAINING)
  set_gui_option(USEROPT_AIRCRAFT, unit.name)
  if (tutorialMissionWeapon)
    set_gui_option(USEROPT_WEAPONS, tutorialMissionWeapon)

  let missInfoWithDiff = DataBlock()
  missInfoWithDiff.setFrom(misInfo)
  missInfoWithDiff.difficulty = get_gui_option(USEROPT_DIFFICULTY)

  select_training_mission(missInfoWithDiff)
}

addListenersWithoutEnv({
  SignOut = @(_) seenTutorialStatuses.clear()
})

register_command(saveSeenTutorialStatus, "debug.set_seen_mod_tutor")

return {
  hasAvailableModTutorial
  needShowUnseenModTutorialForUnit
  needShowUnseenModTutorialForUnitMod
  markSeenModTutorial = @(mod) saveSeenTutorialStatus(mod.tutorialMission, true)
  startModTutorialMission
}