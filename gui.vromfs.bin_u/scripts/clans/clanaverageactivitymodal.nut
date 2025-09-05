from "%scripts/dagui_natives.nut" import clan_get_exp_boost
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { round } = require("math")
let { isAllClanUnitsResearched } = require("%scripts/unit/squadronUnitAction.nut")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let time = require("%scripts/time.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { shortTextFromNum } = require("%scripts/langUtils/textFormat.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { measureType } = require("%scripts/measureType.nut")

let PROGRESS_PARAMS = {
  type = "old"
  rotation = 0
  markerPos = 100
  progressDisplay = "show"
  markerDisplay = "show"
  textType = "activeText"
  textPos = "0.5pw - 0.5w"
  tooltip = ""
}

gui_handlers.clanAverageActivityModal <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  clanData = null

  static function open(clanData) {
    loadHandler(gui_handlers.clanAverageActivityModal, { clanData = clanData })
  }

  function initScreen() {
    local view = {
      clan_activity_header_text = loc("clan/activity")
      clan_activity_description = loc("clan/activity/progress/desc_no_progress")
    }
    let maxMemberActivity = max(this.clanData.maxActivityPerPeriod, 1)
    if (this.clanData.maxClanActivity > 0) {
      let maxActivity = maxMemberActivity * this.clanData.members.len()
      let limitClanActivity = min(maxActivity, this.clanData.maxClanActivity)
      let myActivity = u.search(this.clanData.members,
        @(member) member.uid == userIdStr.get())?.curPeriodActivity ?? 0
      let clanActivity = this.getClanActivity()

      if (clanActivity > 0) {
        let percentMemberActivity = min(100.0 * myActivity / maxMemberActivity, 100)
        let percentClanActivity = min(100.0 * clanActivity / maxActivity, 100)
        let myExp = min(min(1, 1.0 * percentMemberActivity / percentClanActivity) * clanActivity,
          this.clanData.maxClanActivity)
        let roundMyExp = round(myExp)
        let limit = min(100.0 * limitClanActivity / maxActivity, 100)
        let isAllVehiclesResearched = isAllClanUnitsResearched()
        let expBoost = clan_get_exp_boost() / 100.0
        let hasBoost = expBoost > 0
        let descrArray = this.clanData.nextRewardDayId != null
          ? ["".concat( loc("clan/activity_period_end", { date = colorize("activeTextColor",
              time.buildDateTimeStr(this.clanData.nextRewardDayId, false, false)) }), "\n")]
          : []
        if (hasBoost)
          descrArray.append(loc("clan/activity_reward/nowBoost",
            { bonus = colorize("goodTextColor",
              $"+{measureType.PERCENT_FLOAT.getMeasureUnitsText(expBoost)}") }))
        descrArray.append(isAllVehiclesResearched
          ? loc("clan/activity/progress/desc_all_researched")
          : loc("clan/activity/progress/desc"))

        let markerPosMyExp = min(100 * myExp / limitClanActivity, 100)

        let pxCountToEdgeWnd = to_pixels($"{1 - markerPosMyExp / 100.0}*0.4@scrn_tgt + 1@tablePad + 5@blockInterval")
        let expBoostedShortText = shortTextFromNum((roundMyExp * expBoost).tointeger())
        let myExpText = $"{shortTextFromNum(roundMyExp)}{hasBoost ? $" + {expBoostedShortText}" : ""}"
        let myExpTextSize = daguiFonts.getStringWidthPx(myExpText, "fontNormal", this.guiScene)
        let offsetMyExpText = min(pxCountToEdgeWnd - myExpTextSize / 2, 0)
        let myExpShortText = colorize("activeTextColor",
          $"{shortTextFromNum(roundMyExp)}{hasBoost ? $" + {colorize("goodTextColor", expBoostedShortText)}" : ""}")
        let expBoostStr = hasBoost ? $" + {colorize("goodTextColor", round((roundMyExp * expBoost).tointeger()))}" : ""
        let myExpFullText = colorize("activeTextColor", $"{roundMyExp}{expBoostStr}")

        view = {
          clan_activity_header_text = loc("clan/my_activity_in_period",
            { activity = "".concat(myActivity.tostring(), loc("ui/slash"), maxMemberActivity.tostring()) })
          clan_activity_description = "\n".join(descrArray, true)
          rows = [
            {
              title = loc("clan/squadron_activity")
              progress = [
                PROGRESS_PARAMS.__merge({ type = "new", markerDisplay = "hide" })
                PROGRESS_PARAMS.__merge({
                  type = "inactive"
                  value = percentClanActivity * 10
                  markerDisplay = "hide"
                })
                PROGRESS_PARAMS.__merge({
                  value = min(limit, percentClanActivity) * 10
                  markerPos = min(limit, percentClanActivity)
                  text = $"{round(min(limit, percentClanActivity))}%"
                })
              ]
            }
            {
              title = loc("clan/activity_reward")
              widthPercent = limit
              progressDisplay = isAllVehiclesResearched ? "hide" : "show"
              progress = [
                PROGRESS_PARAMS.__merge({ type = "new", markerDisplay = "hide" })
                PROGRESS_PARAMS.__merge({
                  text = shortTextFromNum(limitClanActivity)
                  rotation = 180
                  tooltip = shortTextFromNum(limitClanActivity) != limitClanActivity.tostring()
                    ? "".concat(loc("leaderboards/exactValue"), loc("ui/colon"), limitClanActivity)
                    : ""
                })
                PROGRESS_PARAMS.__merge({
                  value = min(100 * myExp / limitClanActivity, 100) * 10
                  markerPos = markerPosMyExp
                  textType = "textAreaCentered"
                  textPos = $"0.5pw - 0.5w + {offsetMyExpText}"
                  text = myExpShortText
                  tooltip = myExpFullText != myExpShortText
                    ? "".concat(loc("leaderboards/exactValue"), loc("ui/colon"), myExpFullText)
                    : ""
                })
              ]
            }
            {
              title = loc("clan/my_activity"),
              progress = [
                PROGRESS_PARAMS.__merge({ type = "new", markerDisplay = "hide" })
                PROGRESS_PARAMS.__merge({
                  type = "inactive"
                  value = percentMemberActivity * 10
                  markerDisplay = "hide"
                })
                PROGRESS_PARAMS.__merge({
                  value = min(limit, percentMemberActivity) * 10
                  markerPos = min(limit, percentMemberActivity)
                  text = $"{round(min(limit, percentMemberActivity))}%"
                })
              ]
            }
          ]
        }
      }
    }

    let data = handyman.renderCached("%gui/clans/clanAverageActivityModal.tpl", view)
    this.guiScene.replaceContentFromText(this.scene, data, data.len(), this)
  }

  function getClanActivity() {
    local res = 0
    foreach (member in this.clanData.members)
      res += member.curPeriodActivity

    return res
  }
}
