from "%scripts/dagui_natives.nut" import toggle_freecam
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let enums = require("%sqStdLibs/helpers/enums.nut")
let { canRestart, canBailout } = require("%scripts/flightMenu/flightMenuState.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { is_replay_playing } = require("replays")
let { is_benchmark_game_mode, get_game_mode } = require("mission")
let { get_mission_restore_type, get_num_attempts_left, get_mission_status } = require("guiMission")

let buttons = {
  types = []

  template = {
    idx = -1
    name = ""
    buttonId = ""
    labelText = ""
    onClickFuncName = ""
    brAfter = false
    isAvailableInMission = @() true
    canShowOnMissionFailed = false
    isVisible = @() this.canShowOnMissionFailed || get_mission_status() != MISSION_STATUS_FAIL
    getUpdatedLabelText = @() "" // Unchangable buttons returns empty string.
  }
}

function typeConstructor() {
  this.buttonId = $"btn_{this.name.tolower()}"
  this.labelText = $"#flightmenu/btn{this.name}"
  this.onClickFuncName = $"on{this.name}"
}

local idx = 0
enums.addTypes(buttons, {
  RESUME = {
    idx = idx++
    name = "Resume"
    brAfter = true
  }
  OPTIONS = {
    idx = idx++
    name = "Options"
    isAvailableInMission = @() !is_benchmark_game_mode()
  }
  CONTROLS = {
    idx = idx++
    name = "Controls"
    isAvailableInMission = @() !is_benchmark_game_mode() && hasFeature("ControlsAdvancedSettings")
  }
  STATS = {
    idx = idx++
    name = "Stats"
    isAvailableInMission = @() is_multiplayer()
  }
  CONTROLS_HELP = {
    idx = idx++
    name = "ControlsHelp"
    isAvailableInMission = @() !is_benchmark_game_mode() && hasFeature("ControlsHelp")
  }
  RESTART = {
    idx = idx++
    name = "Restart"
    canShowOnMissionFailed = true
    isVisible = canRestart
  }
  BAILOUT = {
    idx = idx++
    name = "Bailout"
    isVisible = canBailout
    getUpdatedLabelText = function getUpdatedLabelText() {
      local txt = getPlayerCurUnit()?.unitType.getBailoutButtonText() ?? ""
      if (!is_multiplayer() && get_mission_restore_type() == ERT_ATTEMPTS) {
        local attemptsTxt
        let numLeft = get_num_attempts_left()
        if (numLeft < 0)
          attemptsTxt = loc("options/attemptsUnlimited")
        else {
          local attempts = loc(numLeft == 1 ? "options/attemptLeft" : "options/attemptsLeft")
          attemptsTxt = $"{numLeft} {attempts}"
        }
        txt = "".concat(txt, loc("ui/parentheses/space", { text = attemptsTxt }))
      }
      return txt
    }
  }
  QUIT_MISSION = {
    idx = idx++
    name = "QuitMission"
    canShowOnMissionFailed = true
    getUpdatedLabelText = function getUpdatedLabelText() {
      return loc(
        is_replay_playing() ? "flightmenu/btnQuitReplay"
        : (get_mission_status() == MISSION_STATUS_SUCCESS
            && get_game_mode() == GM_DYNAMIC) ? "flightmenu/btnCompleteMission"
        : "flightmenu/btnQuitMission"
      )
    }
  }
  FREECAM = {
    idx = idx++
    name = "Freecam"
    isVisible = @() toggle_freecam!=null
  }
}, typeConstructor)

buttons.types.sort(@(a, b) a.idx <=> b.idx)
return buttons
