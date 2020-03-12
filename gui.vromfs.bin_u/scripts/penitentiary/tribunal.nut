::tribunal <- {
  maxComplaintCount = 10
  minComplaintCount = 5
  maxDaysToCheckComplains = 10

  maxComplaintsFromMe = 5

  complaintsData = null
  lastDaySaveParam = "tribunalLastCheckDay"

  function init()
  {
    local blk = ::get_game_settings_blk()?.tribunal
    if (!blk)
      return

    foreach(p in ["maxComplaintCount", "minComplaintCount", "maxDaysToCheckComplains", "maxComplaintsFromMe"])
      if (blk?[p] != null)
        ::tribunal[p] = blk[p]
  }

  function checkComplaintCounts()
  {
    if (!::has_feature("Tribunal"))
      return

    ::tribunal.complaintsData = get_player_complaint_counts()
    if (::tribunal.complaintsData?.is_need_complaint_notify)
      ::tribunal.showComplaintMessageBox(::tribunal.complaintsData)
  }

  function canComplaint()
  {
    if (!::has_feature("Tribunal"))
      return true

    ::tribunal.complaintsData = get_player_complaint_counts()
    if (complaintsData && complaintsData.complaint_count_own >= maxComplaintsFromMe)
    {
      local text = ::format(::loc("charServer/complaintsLimitExpired"), maxComplaintsFromMe)
      ::showInfoMsgBox(text, "tribunal_msg_box")
      return false
    }
    return true
  }

  function showComplaintMessageBox(data)
  {
    if (!data)
      return

    local complaintsToMe = data?.complaint_count_other
    if (!complaintsToMe || !complaintsToMe.len())
      return

    local reasonsList = []
    local complaintsCount = 0
    foreach(reason, count in complaintsToMe)
    {
      if (!count)
        continue

      complaintsCount += count
      local reasonText = ::loc("charServer/ban/reason/" + reason)
      if (reason == "OTHER")
        reasonsList.append(reasonText)
      else
        reasonsList.insert(0, reasonText)
    }

    if (!complaintsCount)
      return

    local textReasons = ::g_string.implode(reasonsList, "\n")
    local text = ::loc("charServer/complaintToYou"
      + (complaintsCount >= maxComplaintCount ? "MoreThen" : ""))

    text = ::format(text, min(complaintsCount, maxComplaintCount)) + "\n" + textReasons

    ::showInfoMsgBox(text, "tribunal_msg_box")
  }
}
