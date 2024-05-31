from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team

let { format } = require("string")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES } = require("%scripts/options/optionsExtNames.nut")
let { set_option, create_options_container } = require("%scripts/options/optionsExt.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { getCurrentGameMode, getGameModeById} = require("%scripts/gameModes/gameModeManagerState.nut")
let { hasSmallTeamsGameModes } = require("%scripts/events/eventInfo.nut")
let { getGameModeWithTagContains, SMALL_TEAMS_GAME_MODE_TAG_PREFIX } = require("%scripts/matching/matchingGameModes.nut")


let optionItems = [[USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES, "switchbox"]]

let class SmallTeamsOptionsWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/events/gameModeOptionsWnd.tpl"
  wndOptionsMode = OPTIONS_MODE_GAMEPLAY

  curEvent = null
  optionsContainer = null

  function getSceneTplView() {
    let container = create_options_container("optionslist", optionItems,
      true, 0.5, false, { containerCb = "onChangeOptionValue" })
    this.optionsContainer = container.descr

    local smallTeamEvent = getGameModeWithTagContains(SMALL_TEAMS_GAME_MODE_TAG_PREFIX)
    let usualTeamsCount = $"{::events.getMinTeamSize(this.curEvent)} - {::events.getTeamData(this.curEvent, Team.A).maxTeamSize}"

    return {
      titleText = loc("ui/colon").concat(::events.getEventNameText(this.curEvent), loc("game_mode_settings"))
      descText = loc("small_teams/desc", {
        smallTeamsCount = smallTeamEvent != null
          ? $"{::events.getMinTeamSize(smallTeamEvent)} - {::events.getTeamData(smallTeamEvent, Team.A).maxTeamSize}"
          : usualTeamsCount
        usualTeamsCount
        optionName = loc("options/can_queue_to_small_teams")
        minMRankForSmallTeamsBattles = format("%.1f",
          calcBattleRatingFromRank(this.curEvent.minMRankForSmallTeamsBattles))
      })
      optionsContainer = container.tbl
      wndHeight="370@sf/@pf"
    }
  }

  function getOptionById(id) {
    foreach (option in this.optionsContainer.data)
      if (option?.id == id)
        return option
    return null
  }

  function onChangeOptionValue(obj) {
    let option = this.getOptionById(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
  }
}

gui_handlers.SmallTeamsOptionsWnd <- SmallTeamsOptionsWnd

function openSmallTeamsOptionsWnd(modeId = null) {
  let curEvent = modeId != null
    ? getGameModeById(modeId)?.getEvent()
    : getCurrentGameMode()?.getEvent()
  if (hasSmallTeamsGameModes(curEvent))
    checkSquadUnreadyAndDo(@() handlersManager.loadHandler(SmallTeamsOptionsWnd, { curEvent }))
}

return openSmallTeamsOptionsWnd
