from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { ceil } = require("math")
let { getArmiesByStatus } = require("%scripts/worldWar/inOperation/wwOperations.nut")

let g_ww_map_armies_status_tab_type = {
  types = []
  cache = {
    byStatus = {}
  }

  template = {
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
      let armies = getArmiesByStatus(this.status)

      let countText = [armies.common.len()]
      if (armies.surrounded.len() > 0)
        countText.append("+", colorize("armySurroundedColor", armies.surrounded.len()))

      return loc("ui/parentheses/space", { text = "".join(countText) })
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
      let armies = getArmiesByStatus(this.status)

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
      let armies = getArmiesByStatus(this.status)
      return ceil((armies.surrounded.len() + armies.common.len()) / itemsPerPage.tofloat())
    }
  }

}

enumsAddTypes(g_ww_map_armies_status_tab_type, {
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


g_ww_map_armies_status_tab_type.getTypeByStatus <- function getTypeByStatus(status) {
  return enumsGetCachedType(
    "status",
    status,
    this.cache.byStatus,
    this,
    this.UNKNOWN
  )
}

return {
  g_ww_map_armies_status_tab_type
}