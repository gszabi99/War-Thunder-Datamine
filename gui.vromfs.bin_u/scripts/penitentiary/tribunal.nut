//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
::tribunal <- {
  maxComplaintCount = 10
  minComplaintCount = 5
  maxDaysToCheckComplains = 10

  maxComplaintsFromMe = 5

  complaintsData = null
  lastDaySaveParam = "tribunalLastCheckDay"

  function init() {
    let blk = ::get_game_settings_blk()?.tribunal
    if (!blk)
      return

    foreach (p in ["maxComplaintCount", "minComplaintCount", "maxDaysToCheckComplains", "maxComplaintsFromMe"])
      if (blk?[p] != null)
        ::tribunal[p] = blk[p]
  }

  function checkComplaintCounts() {
    if (!hasFeature("Tribunal"))
      return

    ::tribunal.complaintsData = ::get_player_complaint_counts()
    if (::tribunal.complaintsData?.is_need_complaint_notify)
      ::tribunal.showComplaintMessageBox(::tribunal.complaintsData)
  }

  function canComplaint() {
    if (!hasFeature("Tribunal"))
      return true

    ::tribunal.complaintsData = ::get_player_complaint_counts()
    if (this.complaintsData && this.complaintsData.complaint_count_own >= this.maxComplaintsFromMe) {
      let text = format(loc("charServer/complaintsLimitExpired"), this.maxComplaintsFromMe)
      ::showInfoMsgBox(text, "tribunal_msg_box")
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
      if (!count)
        continue

      complaintsCount += count
      let reasonText = loc("charServer/ban/reason/" + reason)
      if (reason == "OTHER")
        reasonsList.append(reasonText)
      else
        reasonsList.insert(0, reasonText)
    }

    if (!complaintsCount)
      return

    let textReasons = "\n".join(reasonsList, true)
    local text = loc("charServer/complaintToYou"
      + (complaintsCount >= this.maxComplaintCount ? "MoreThen" : ""))

    text = format(text, min(complaintsCount, this.maxComplaintCount)) + "\n" + textReasons

    ::showInfoMsgBox(text, "tribunal_msg_box")
  }
}
