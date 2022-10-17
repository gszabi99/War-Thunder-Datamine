from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let function addClanTagToNameInLeaderbord(lbNest, clansInfoList) {
  if (!checkObj(lbNest) || clansInfoList.len() == 0)
    return

  let lbTable = lbNest.findObject("lb_table")
  if (!checkObj(lbTable))
    return

  for (local i = 0; i < lbTable.childrenCount(); i++) {
    let obj = lbTable.getChild(i)
    let clanId = obj?.clanId ?? ""
    if (clanId == "" || clansInfoList?[clanId] == null)
      continue

    obj.clanId = ""
    let nameTxtObj = obj.findObject("txt_name")
    nameTxtObj.setValue(::g_contacts.getPlayerFullName(nameTxtObj.text, clansInfoList[clanId].tag))
  }
}

return {
  addClanTagToNameInLeaderbord
}