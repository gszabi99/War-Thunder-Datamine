function addClanTagToNameInLeaderbord(lbNest, clansInfoList) {
  if (!::check_obj(lbNest) || clansInfoList.len() == 0)
    return

  local lbTable = lbNest.findObject("lb_table")
  if (!::check_obj(lbTable))
    return

  for (local i = 0; i < lbTable.childrenCount(); i++) {
    local obj = lbTable.getChild(i)
    local clanId = obj?.clanId ?? ""
    if (clanId == "" || clansInfoList?[clanId] == null)
      continue

    obj.clanId = ""
    local nameTxtObj = obj.findObject("txt_name")
    nameTxtObj.setValue(::g_contacts.getPlayerFullName(nameTxtObj.text, clansInfoList[clanId].tag))
  }
}

return {
  addClanTagToNameInLeaderbord = addClanTagToNameInLeaderbord
}