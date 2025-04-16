from "%scripts/dagui_natives.nut" import get_player_complaint_counts
from "%scripts/dagui_library.nut" import *


let { format } = require("string")
let { get_game_settings_blk } = require("blkGetters")

let complaintCategories = freeze(["FOUL", "ABUSE", "HATE", "TEAMKILL", "BOT", "BOT2", "NICK_HATESPEECH", "SPAM", "OTHER"])

let tribunal = {
  maxComplaintCount = 10
  minComplaintCount = 5
  maxDaysToCheckComplains = 10

  maxComplaintsFromMe = 5

  complaintsData = null
  lastDaySaveParam = "tribunalLastCheckDay"

  function init() {
    let blk = get_game_settings_blk()?.tribunal
    if (!blk)
      return

    foreach (p in ["maxComplaintCount", "minComplaintCount", "maxDaysToCheckComplains", "maxComplaintsFromMe"])
      if (blk?[p] != null)
        this[p] = blk[p]
  }

  function checkComplaintCounts() {
    if (!hasFeature("Tribunal"))
      return

    this.complaintsData = get_player_complaint_counts()
    if (this.complaintsData?.is_need_complaint_notify)
     this.showComplaintMessageBox(this.complaintsData)
  }

  function canComplaint() {
    if (!hasFeature("Tribunal"))
      return true

    this.complaintsData = get_player_complaint_counts()
    if (this.complaintsData && this.complaintsData.complaint_count_own >= this.maxComplaintsFromMe) {
      let text = format(loc("charServer/complaintsLimitExpired"), this.maxComplaintsFromMe)
      showInfoMsgBox(text, "tribunal_msg_box")
      return false
    }
    return true
  }

  function showComplaintMessageBox(data) {
    if (!data)
      return

    let complaintsToMe = data?.complaint_count_other
    if (!complaintsToMe || !complaintsToMe.len())
      return

    let reasonsList = []
    local complaintsCount = 0
    foreach (reason, count in complaintsToMe) {
      if (!count || !complaintCategories.contains(reason))
        continue

      complaintsCount += count
      let reasonText = loc($"charServer/ban/reason/{reason}")
      if (reason == "OTHER")
        reasonsList.append(reasonText)
      else
        reasonsList.insert(0, reasonText)
    }

    if (!complaintsCount)
      return

    let textReasons = "\n".join(reasonsList, true)
    local text = loc("".concat("charServer/complaintToYou",
      (complaintsCount >= this.maxComplaintCount ? "MoreThen" : "")))

    text = "".concat(format(text, min(complaintsCount, this.maxComplaintCount)),"\n", textReasons)

    showInfoMsgBox(text, "tribunal_msg_box")
  }
}

return {
  complaintCategories
  tribunal
}
