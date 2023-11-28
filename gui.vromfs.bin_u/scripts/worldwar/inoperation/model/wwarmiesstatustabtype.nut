//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *


let enums = require("%sqStdLibs/helpers/enums.nut")
let { ceil } = require("math")

::g_ww_map_armies_status_tab_type <- {
  types = []
  cache = {
    byStatus = {}
  }
}

::g_ww_map_armies_status_tab_type.template <- {
  status = null
  iconText = null
  text = null

  getEmptyContentViewData = function() {
    return {
      army = []
      reqUnitTypeIcon = true
      addArmyClickCb = true
      isGroupItem = true
      hideTooltip = true
      markSurrounded = true
    }
  }

  getArmiesCountText = function() {
    let armies = ::g_operations.getArmiesByStatus(this.status)

    local countText = armies.common.len()
    if (armies.surrounded.len() > 0)
      countText += "+" + colorize("armySurroundedColor", armies.surrounded.len())

    return loc("ui/parentheses/space", { text = countText })
  }

  getTitleViewData = function() {
    return {
      id = this.status
      tabIconText = loc(this.iconText)
      tabText = loc(this.text)
      armiesCountText = this.getArmiesCountText()
    }
  }

  getContentViewData = function(itemsPerPage, currentPage) {
    let armies = ::g_operations.getArmiesByStatus(this.status)

    local firstItemIndex = currentPage * itemsPerPage
    let viewsArray = []
    for (local i = firstItemIndex; i < armies.surrounded.len() && viewsArray.len() < itemsPerPage; i++)
      viewsArray.append(armies.surrounded[i].getView())

    firstItemIndex = max(firstItemIndex - armies.surrounded.len(), 0)
    for (local i = firstItemIndex; i < armies.common.len() && viewsArray.len() < itemsPerPage; i++)
      viewsArray.append(armies.common[i].getView())

    let viewData = this.getEmptyContentViewData()
    viewData.army = viewsArray

    return viewData
  }

  getTotalPageCount = function(itemsPerPage) {
    let armies = ::g_operations.getArmiesByStatus(this.status)
    return ceil((armies.surrounded.len() + armies.common.len()) / itemsPerPage.tofloat())
  }
}

enums.addTypesByGlobalName("g_ww_map_armies_status_tab_type", {
  UNKNOWN = {
    status = WW_ARMY_ACTION_STATUS.UNKNOWN
  }

  IDLE = {
    status = WW_ARMY_ACTION_STATUS.IDLE
    iconText = "worldWar/iconIdle"
    text = "worldwar/armiesInfo/idle"
  }

  IN_MOVE = {
    status = WW_ARMY_ACTION_STATUS.IN_MOVE
    iconText = "worldWar/iconMove"
    text = "worldwar/armiesInfo/onMove"
  }

  ENTRENCHED = {
    status = WW_ARMY_ACTION_STATUS.ENTRENCHED
    iconText = "worldWar/iconEntrenched"
    text = "worldwar/armiesInfo/entrenched"
  }

  IN_BATTLE = {
    status = WW_ARMY_ACTION_STATUS.IN_BATTLE
    iconText = "worldWar/iconBattle"
    text = "worldwar/armiesInfo/inBattle"
  }
}, null, "name")


::g_ww_map_armies_status_tab_type.getTypeByStatus <- function getTypeByStatus(status) {
  return enums.getCachedType(
    "status",
    status,
    this.cache.byStatus,
    this,
    this.UNKNOWN
  )
}
