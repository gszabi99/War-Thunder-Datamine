from "%scripts/dagui_natives.nut" import player_have_attachable, player_have_decal, warbonds_can_buy_battle_task, warbond_get_type_by_name, get_warbond_item_bought_count_with_amount, char_send_blk, get_warbond_item_bought_count_with_name
from "%scripts/dagui_library.nut" import *

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { isHardTaskIncomplete } = require("%scripts/unlocks/battleTasks.nut")
let DataBlock = require("DataBlock")
let { Balance } = require("%scripts/money.nut")
let { format } = require("string")
let { getPurchaseLimitWb } = require("%scripts/warbonds/warbondShopState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getFullUnlockDescByName, getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getUnitTypeText, image_for_air, getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { isUnitBought } = require("%scripts/unit/unitShopInfo.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { decoratorTypes } = require("%scripts/customization/types.nut")
let { buildUnitSlot } = require("%scripts/slotbar/slotbarView.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { getFullWPIcon } = require("%scripts/items/prizesView.nut")

function requestBuyByName(warbond, blk) {
  let reqBlk = DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.name = blk?.name ?? ""

  return char_send_blk("cln_exchange_warbonds", reqBlk)
}

function requestBuyByAmount(warbond, blk) {
  let reqBlk = DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.amount = blk?.amount ?? 1

  return char_send_blk("cln_exchange_warbonds", reqBlk)
}

let getBoughtCountByName = @(warbond, blk)
  get_warbond_item_bought_count_with_name(warbond.id, warbond.listId, blk?.type, blk?.name ?? "")
local getBoughtCountByAmount = @(warbond, blk)
  get_warbond_item_bought_count_with_amount(warbond.id, warbond.listId, blk?.type, blk?.amount ?? 1)

let makeWbAwardItem = function(changesTbl = null) {
  let res = {
    hasCommonDesc = false

    getItem = @(blk) findItemById(blk.name)
    getDescItem = @(blk) this.getItem(blk)

    getNameText = function(blk) {
      let item = this.getItem(blk)
      return item ? item.getName() : ""
    }

    getLayeredImage = function(blk, _warbond) {
      let item = this.getItem(blk)
      return item ? item.getIcon() : ""
    }

    getContentIconData = function(blk) {
      let item = this.getItem(blk)
      return item ? item.getContentIconData() : ""
    }

    getTooltipId = @(blk, warbond)
      getTooltipType("ITEM").getTooltipId(blk?.name ?? "", { wbId = warbond.id, wbListId = warbond.listId })

    getUserlogBuyText = function(blk, priceText) {
      let item = this.getItem(blk)
      return loc("userlog/buy_item",
        {
          itemName = colorize("userlogColoredText", item ? item.getName() : "")
          price = priceText
        })
    }
  }

  if (changesTbl)
    foreach (key, value in changesTbl)
      res[key] <- value
  return res
}

let warBondAwardType = {
  types = []

  template = {
    id = EWBAT_INVALID 
    getLayeredImage = function(_blk, _warbond) { return "" }
    getContentIconData = function(_blk) { return null } 
    getIconHeaderText = function(_blk) { return null }
    getTooltipId = @(_blk, _warbond) null 

    hasCommonDesc = true
    getNameText = function(_blk) { return "" }
    getDescText = function(_blk) { return "" }
    getDescriptionImage = function(blk, warbond) { return this.getLayeredImage(blk, warbond) }
    getDescItem = function(_blk) { return null } 

    canPreview = @(_blk) false
    doPreview = @(_blk) null

    requestBuy = requestBuyByName 
    getBoughtCount = getBoughtCountByName 
    canBuy = @(_warbond, _blk) true
    getMaxBoughtCount = @(_warbond, blk) blk?.maxBoughtCount ?? 0
    showAvailableAmount = true

    isReqSpecialTasks = false
    hasIncreasingLimit = false
    canBuyReasonLocId = @(_warbond, _blk) this.isReqSpecialTasks ? "item/specialTasksPersonalUnlocks/purchaseRestriction" : ""
    userlogResourceTypeText = ""
    getUserlogBuyText = function(blk, priceText) {
      if (priceText != "")
        priceText = loc("ui/parentheses/space", { text = priceText })
      return "".concat(this.getUserlogBuyTextBase(blk), priceText)
    }
    getUserlogBuyTextBase = function(blk) {
      return format("".concat(loc("userlog/buy_resource/", this.userlogResourceTypeText)), this.getNameText(blk))
    }
  }

  function getTypeByBlk(blk) {
    let typeInt = warbond_get_type_by_name(blk?.type ?? "invalid")
    return getTblValue(typeInt, this, this[EWBAT_INVALID])
  }
}

enums.addTypes(warBondAwardType, {
  [EWBAT_INVALID] = {
    requestBuy = function(...) { return -1 }
  },

  [EWBAT_UNIT] = {
    getLayeredImage = function(blk, _warbond) {
      let unit = getAircraftByName(blk.name)
      let unitType = getEsUnitType(unit)
      let style = "".concat("reward_unit_", getUnitTypeText(unitType).tolower())
      return LayersIcon.getIconData(style)
    }
    getContentIconData = function(blk) {
      return {
        contentType = "unit"
        contentIcon = image_for_air(blk.name)
      }
    }
    getIconHeaderText = function(blk) { return this.getNameText(blk) }
    getTooltipId = @(blk, warbond) getTooltipType("UNIT").getTooltipId(blk?.name ?? "",
      { wbId = warbond.id, wbListId = warbond.listId })
    getNameText = function(blk) { return getUnitName(blk?.name ?? "") }

    getDescriptionImage = function(blk, _warbond) {
      let unit = getAircraftByName(blk.name)
      if (!unit)
        return ""

      let blockFormat = "rankUpList { halign:t='center'; holdTooltipChildren:t='yes'; %s }"
      return format(blockFormat, buildUnitSlot(unit.name, unit, {
        status = isUnitBought(unit) ? "owned" : "canBuy",
        showAsTrophyContent = true
        isLocalState = false
        tooltipParams = { showLocalState = false }
      }))
    }

    canPreview = @(blk) getAircraftByName(blk.name)?.canPreview() ?? false
    doPreview  = @(blk) getAircraftByName(blk.name)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      let unit = getAircraftByName(blk.name)
      return (unit && isUnitBought(unit)) ? 1 : 0
    }
    showAvailableAmount = false

    getUserlogBuyTextBase = function(blk) {
      return format(loc("userlog/buy_aircraft"), this.getNameText(blk))
    }
  },

  [EWBAT_ITEM]                 = makeWbAwardItem(),
  [EWBAT_TROPHY]               = makeWbAwardItem(),
  [EWBAT_EXT_INVENTORY_ITEM]   = makeWbAwardItem({
    getItem = @(blk) findItemById(to_integer_safe(blk.name))
  }),

  [EWBAT_SKIN] = {
    userlogResourceTypeText = "skin"
    getLayeredImage = function(_blk, _warbond) {
      return LayersIcon.getIconData(decoratorTypes.SKINS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) getTooltipType("DECORATION").getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_SKIN,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk) {
      return getUnlockNameText(UNLOCKABLE_SKIN, blk?.name ?? "")
    }
    getDescText = function(blk) {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) getDecorator(blk.name, decoratorTypes.SKINS)?.canPreview() ?? false
    doPreview  = @(blk) getDecorator(blk.name, decoratorTypes.SKINS)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = @(_warbond, blk) decoratorTypes.SKINS.isPlayerHaveDecorator(blk?.name ?? "") ? 1 : 0
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_DECAL] = {
    userlogResourceTypeText = "decal"
    getLayeredImage = function(blk, _warbond) {
      let decorator = getDecorator(blk.name, decoratorTypes.DECALS)
      if (decorator)
        return LayersIcon.getIconData(null, decoratorTypes.DECALS.getImage(decorator))
      return LayersIcon.getIconData(decoratorTypes.DECALS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) getTooltipType("DECORATION").getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_DECAL,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk) {
      return getUnlockNameText(UNLOCKABLE_DECAL, blk?.name ?? "")
    }
    getDescText = function(blk) {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) getDecorator(blk.name, decoratorTypes.DECALS)?.canPreview() ?? false
    doPreview  = @(blk) getDecorator(blk.name, decoratorTypes.DECALS)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      return player_have_decal(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_ATTACHABLE] = {
    userlogResourceTypeText = "attachable"
    getLayeredImage = function(blk, _warbond) {
      let decorator = getDecorator(blk?.name ?? "", decoratorTypes.ATTACHABLES)
      if (decorator)
        return LayersIcon.getIconData(null, decoratorTypes.ATTACHABLES.getImage(decorator))
      return LayersIcon.getIconData(decoratorTypes.ATTACHABLES.defaultStyle)
    }
    getTooltipId = @(blk, warbond) getTooltipType("DECORATION").getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_ATTACHABLE,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk) {
      return getUnlockNameText(UNLOCKABLE_ATTACHABLE, blk?.name ?? "")
    }
    getDescText = function(blk) {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) getDecorator(blk.name, decoratorTypes.ATTACHABLES)?.canPreview() ?? false
    doPreview  = @(blk) getDecorator(blk.name, decoratorTypes.ATTACHABLES)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      return player_have_attachable(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_WP] = {
    getLayeredImage = function(blk, _warbond) {
      let wp = blk?.amount ?? 0
      return getFullWPIcon(wp)
    }
    getNameText = function(blk) {
      return Balance(blk?.amount ?? 0).tostring()
    }
    requestBuy = requestBuyByAmount
    getBoughtCount = getBoughtCountByAmount
  },

  [EWBAT_GOLD] = {
    getLayeredImage = function(_blk, _warbond) {
      return LayersIcon.getIconData("reward_gold")
    }
    getNameText = function(blk) {
      return Balance(0, blk?.amount ?? 0).tostring()
    }
    requestBuy = requestBuyByAmount
    getBoughtCount = getBoughtCountByAmount
  },

  [EWBAT_BATTLE_TASK] = {
    getLayeredImage = @(_blk, warbond) warbond.getLayeredIconStyle()
    getNameText = @(blk) loc($"item/{blk.name}")
    getDescText = @(blk) loc($"item/{blk.name}/desc")
    hasIncreasingLimit = true
    canBuy = @(warbond, blk) warbonds_can_buy_battle_task(blk.name)
      && (getPurchaseLimitWb(warbond) > this.getBoughtCount(warbond, blk))
    getMaxBoughtCount = @(warbond, _blk) getPurchaseLimitWb(warbond)
    isReqSpecialTasks = true
    canBuyReasonLocId = @(warbond, blk)
      isHardTaskIncomplete.value
        ? "item/specialTasksPersonalUnlocks/purchaseRestriction"
        : (getPurchaseLimitWb(warbond) <= this.getBoughtCount(warbond, blk))
           ? "item/specialTasksPersonalUnlocks/limitRestriction"
           : ""
    getTooltipId = @(blk, warbond) getTooltipType("SPECIAL_TASK").getTooltipId(blk.name, {
      wbId = warbond.id,
      wbListId = warbond.listId
    })
  },
},
null, "id")

return warBondAwardType