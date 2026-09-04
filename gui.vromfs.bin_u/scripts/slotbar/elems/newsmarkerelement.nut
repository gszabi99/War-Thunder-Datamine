from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let elemModelType = require("%scripts/sqDagui/elemUpdater/elemModelType.nut")
let elemViewType = require("%scripts/sqDagui/elemUpdater/elemViewType.nut")
let { hasUnitNews, getUnitNewsId } = require("%scripts/unit/unitNews.nut")
let { unitNews } = require("%scripts/changelog/changeLogState.nut")

elemModelType.addTypes({
  NEWS_MARKER = {
    function init() {
      subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    }
    isVisible = @() true
    onEventShopWndSwitched = @(_p) this.notify([])
  }
})

elemViewType.addTypes({
  SHOP_SLOT_NEWS_UNIT = {
    model = elemModelType.NEWS_MARKER

    updateView = function(obj, params) {
      let unitName = params?.unitName
      if (unitName == null || !hasUnitNews(unitName)) {
        obj.show(false)
        return
      }
      obj.show(true)

      let newsId = getUnitNewsId(unitName)
      let isActive = unitNews.get().findindex(@(v) v.titleshort == newsId) != null
      obj["isActive"] = isActive ? "yes" : "no"
      obj["newsId"] = isActive ? newsId : ""

      let tooltipParts = [loc($"shop/news/{newsId}")]
      if (isActive)
        tooltipParts.append(loc("mainmenu/clickOnLabel"))
      obj.tooltip = "\n".join(tooltipParts)
    }
  }
})


return {}