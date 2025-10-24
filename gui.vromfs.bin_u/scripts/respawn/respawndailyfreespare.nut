from "%scripts/dagui_library.nut" import *
let { hasDailyFreeSpares, getDailyFreeSparesLeftCount } = require("%scripts/respawn/respawnState.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { getTooltipType, addTooltipTypes  } = require("%scripts/utils/genericTooltipTypes.nut")
let { buildTimeStr, getUtcMidnight } = require("%scripts/time.nut")
let { getNumFreeSparesPerDay } = require("guiRespawn")

const DAILY_FREE_SPARE_UID = "daily_free_spare"

let getDailyFreeSpareIcon = @() "".concat(
  LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("universal_spare_base")),
  LayersIcon.genDataFromLayer(LayersIcon.findLayerCfg("universal_spare_daily"))
)


let createDailyFreeSpareItem = @() {
  getName = @(_p = null) loc("item/dailyUniversalSpare")
  id = DAILY_FREE_SPARE_UID
  uids = [DAILY_FREE_SPARE_UID]
  isExpired = @() false
  hasTimer = @() false
  getViewData = @(_) {
    enableBackground = true
    hasFocusBorder = true
    tooltipId = getTooltipType("DAILY_FREE_SPARE").getTooltipId(this.id)
    isItemLocked = !hasDailyFreeSpares()
    layered_image = getDailyFreeSpareIcon()
  }
}

addTooltipTypes({
  DAILY_FREE_SPARE = {
    isCustomTooltipFill = true

    function fillTooltip(obj, handler, _id, _params) {
      if (!obj?.isValid())
        return false
      obj.getScene().replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      obj.findObject("item_name").setValue(loc("item/dailyUniversalSpare"))

      let iconObj = obj.findObject("item_icon")
      let icon = getDailyFreeSpareIcon()
      obj.getScene().replaceContentFromText(iconObj, icon, icon.len(), null)
      iconObj.doubleSize = "no"

      let maxSpares = getNumFreeSparesPerDay()
      let descTxt = loc("items/dailyUniversalSpare/description", { max_count = maxSpares })

      let remainingCount = getDailyFreeSparesLeftCount()
      local remainingCountTxt = remainingCount > 0 ? $"{remainingCount}" : colorize("badTextColor", remainingCount)
      remainingCountTxt = colorize("activeTextColor", $"{remainingCountTxt}/{maxSpares}")
      remainingCountTxt = "".concat(loc("items/dailyUniversalSpare/remaining"), loc("ui/colon"),
        remainingCountTxt, loc("ui/dot"))

      local updateTimeTxt = buildTimeStr(getUtcMidnight(), false, false)
      updateTimeTxt = loc("items/dailyUniversalSpare/updateTime", { time = updateTimeTxt })

      let fullDesc = "\n".join([descTxt, remainingCountTxt, updateTimeTxt])
      let descObj = obj.findObject("item_desc")
      descObj.setValue(fullDesc)

      return true
    }
  }
})

return {
  createDailyFreeSpareItem
  DAILY_FREE_SPARE_UID
}