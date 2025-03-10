from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *

let { get_game_mode } = require("mission")
let { get_cd_preset, set_cd_preset } = require("guiOptions")

function isGameModeCoop(gm) {
  return gm == -1 || gm == GM_SINGLE_MISSION || gm == GM_BUILDER
}

function isGameModeVersus(gm) {
  return gm == -1 || gm == GM_SKIRMISH || gm == GM_DOMINATION
}

function getCustomDifficultyOptions() {
  let gm = get_game_mode()
  let canChangeTpsViews = isGameModeCoop(gm) || isGameModeVersus(gm) || gm == GM_TEST_FLIGHT

  return [
      [USEROPT_CD_ENGINE],
      [USEROPT_CD_GUNNERY],
      [USEROPT_CD_DAMAGE],
      [USEROPT_CD_STALLS],
      [USEROPT_CD_BOMBS],
      [USEROPT_CD_FLUTTER],
      [USEROPT_CD_REDOUT],
      [USEROPT_CD_MORTALPILOT],
      [USEROPT_CD_BOOST],
      [USEROPT_CD_TPS, null, canChangeTpsViews],
      [USEROPT_CD_AIR_HELPERS],
      [USEROPT_CD_ALLOW_CONTROL_HELPERS],
      [USEROPT_CD_FORCE_INSTRUCTOR],
      [USEROPT_CD_WEB_UI],
      [USEROPT_CD_COLLECTIVE_DETECTION],
      [USEROPT_CD_DISTANCE_DETECTION],
      [USEROPT_CD_AIM_PRED],
      
      [USEROPT_CD_MARKERS],
      [USEROPT_CD_ARROWS],
      [USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST],
      [USEROPT_CD_ROCKET_SPOTTING],
      [USEROPT_CD_INDICATORS],
      [USEROPT_CD_TANK_DISTANCE],
      [USEROPT_CD_MAP_AIRCRAFT_MARKERS],
      [USEROPT_CD_MAP_GROUND_MARKERS],
      [USEROPT_CD_MARKERS_BLINK],
      [USEROPT_CD_RADAR],
      [USEROPT_CD_DAMAGE_IND],
      [USEROPT_CD_LARGE_AWARD_MESSAGES],
      [USEROPT_CD_WARNINGS],      


    ]
}

function getCustomDifficultyTooltipText(custDifficulty) {
  let wasDiff = get_cd_preset(DIFFICULTY_CUSTOM)
  set_cd_preset(custDifficulty)

  local text = ""
  let options = getCustomDifficultyOptions()
  foreach (o in options) {
    let opt = ::get_option(o[0])
    let valueText = opt.items ?
      loc(opt.items[opt.value]) :
      loc(opt.value ? "options/yes" : "options/no")
    text = "".concat(text, (text != "") ? "\n" : "", loc($"options/{opt.id}"), loc("ui/colon"), colorize("userlogColoredText", valueText))
  }

  set_cd_preset(wasDiff)
  return text
}

return {
  isGameModeCoop
  isGameModeVersus
  getCustomDifficultyTooltipText
  getCustomDifficultyOptions
}
