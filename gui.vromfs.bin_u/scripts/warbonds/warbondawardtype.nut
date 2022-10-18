from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { getPurchaseLimitWb } = require("%scripts/warbonds/warbondShopState.nut")
let { DECORATION, SPECIAL_TASK } = require("%scripts/utils/genericTooltipTypes.nut")
let { getFullUnlockDescByName, getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")

let enums = require("%sqStdLibs/helpers/enums.nut")
::g_wb_award_type<- {
  types = []
}

let function requestBuyByName(warbond, blk)
{
  let reqBlk = ::DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.name = blk?.name ?? ""

  return ::char_send_blk("cln_exchange_warbonds", reqBlk)
}

let function requestBuyByAmount(warbond, blk)
{
  let reqBlk = ::DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.amount = blk?.amount ?? 1

  return ::char_send_blk("cln_exchange_warbonds", reqBlk)
}

let getBoughtCountByName = @(warbond, blk)
  ::get_warbond_item_bought_count_with_name(warbond.id, warbond.listId, blk?.type, blk?.name ?? "")
local getBoughtCountByAmount = @(warbond, blk)
  ::get_warbond_item_bought_count_with_amount(warbond.id, warbond.listId, blk?.type, blk?.amount ?? 1)


::g_wb_award_type.template <- {
  id = EWBAT_INVALID //filled by type id.used from code enum EWBAT
  getLayeredImage = function(_blk, _warbond) { return "" }
  getContentIconData = function(_blk) { return null } //{ contentIcon, [contentType] }
  getIconHeaderText = function(_blk) { return null }
  getTooltipId = @(_blk, _warbond) null //string

  hasCommonDesc = true
  getNameText = function(_blk) { return "" }
  getDescText = function(_blk) { return "" }
  getDescriptionImage = function(blk, warbond) { return getLayeredImage(blk, warbond) }
  getDescItem = function(_blk) { return null } //show description as item description

  canPreview = @(_blk) false
  doPreview = @(_blk) null

  requestBuy = requestBuyByName //warbond, blk
  getBoughtCount = getBoughtCountByName //warbond, blk
  canBuy = @(_warbond, _blk) true
  getMaxBoughtCount = @(_warbond, blk) blk?.maxBoughtCount ?? 0
  showAvailableAmount = true

  isReqSpecialTasks = false
  hasIncreasingLimit = @() false
  canBuyReasonLocId = @(_warbond, _blk) isReqSpecialTasks? "item/specialTasksPersonalUnlocks/purchaseRestriction" : ""
  userlogResourceTypeText = ""
  getUserlogBuyText = function(blk, priceText)
  {
    if (priceText != "")
      priceText = loc("ui/parentheses/space", { text = priceText })
    return getUserlogBuyTextBase(blk) + priceText
  }
  getUserlogBuyTextBase = function(blk)
  {
    return format(loc("userlog/buy_resource/" + userlogResourceTypeText), getNameText(blk))
  }
}

let makeWbAwardItem = function(changesTbl = null)
{
  let res = {
    hasCommonDesc = false

    getItem = @(blk) ::ItemsManager.findItemById(blk.name)
    getDescItem = @(blk) getItem(blk)

    getNameText = function(blk)
    {
      let item = getItem(blk)
      return item ? item.getName() : ""
    }

    getLayeredImage = function(blk, _warbond)
    {
      let item = getItem(blk)
      return item ? item.getIcon() : ""
    }

    getContentIconData = function(blk)
    {
      let item = getItem(blk)
      return item ? item.getContentIconData() : ""
    }

    getTooltipId = @(blk, warbond)
      ::g_tooltip.getIdItem(blk?.name ?? "", { wbId = warbond.id, wbListId = warbond.listId })

    getUserlogBuyText = function(blk, priceText)
    {
      let item = getItem(blk)
      return loc("userlog/buy_item",
        {
          itemName = colorize("userlogColoredText", item ? item.getName() : "")
          price = priceText
        })
    }
  }

  if (changesTbl)
    foreach(key, value in changesTbl)
      res[key] <- value
  return res
}

enums.addTypesByGlobalName("g_wb_award_type", {
  [EWBAT_INVALID] = {
    requestBuy = function(...) { return -1 }
  },

  [EWBAT_UNIT] = {
    getLayeredImage = function(blk, _warbond)
    {
      let unit = ::getAircraftByName(blk.name)
      let unitType = ::get_es_unit_type(unit)
      let style = "reward_unit_" + ::getUnitTypeText(unitType).tolower()
      return ::LayersIcon.getIconData(style)
    }
    getContentIconData = function(blk)
    {
      return {
        contentType = "unit"
        contentIcon = ::image_for_air(blk.name)
      }
    }
    getIconHeaderText = function(blk) { return getNameText(blk) }
    getTooltipId = @(blk, warbond) ::g_tooltip.getIdUnit(blk?.name ?? "", { wbId = warbond.id, wbListId = warbond.listId })
    getNameText = function(blk) { return ::getUnitName(blk?.name ?? "") }

    getDescriptionImage = function(blk, _warbond)
    {
      let unit = ::getAircraftByName(blk.name)
      if (!unit)
        return ""

      let blockFormat = "rankUpList { halign:t='center'; holdTooltipChildren:t='yes'; %s }"
      return format(blockFormat, ::build_aircraft_item(unit.name, unit, {
        hasActions = true,
        status = ::isUnitBought(unit) ? "owned" : "canBuy",
        showAsTrophyContent = true
      }))
    }

    canPreview = @(blk) ::getAircraftByName(blk.name)?.canPreview() ?? false
    doPreview  = @(blk) ::getAircraftByName(blk.name)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      let unit = ::getAircraftByName(blk.name)
      return (unit && ::isUnitBought(unit)) ? 1 : 0
    }
    showAvailableAmount = false

    getUserlogBuyTextBase = function(blk)
    {
      return format(loc("userlog/buy_aircraft"), getNameText(blk))
    }
  },

  [EWBAT_ITEM]                 = makeWbAwardItem(),
  [EWBAT_TROPHY]               = makeWbAwardItem(),
  [EWBAT_EXT_INVENTORY_ITEM]   = makeWbAwardItem({
    getItem = @(blk) ::ItemsManager.findItemById(::to_integer_safe(blk.name))
  }),

  [EWBAT_SKIN] = {
    userlogResourceTypeText = "skin"
    getLayeredImage = function(_blk, _warbond)
    {
      return ::LayersIcon.getIconData(::g_decorator_type.SKINS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) DECORATION.getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_SKIN,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return getUnlockNameText(UNLOCKABLE_SKIN, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.SKINS)?.canPreview() ?? false
    doPreview  = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.SKINS)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = @(_warbond, blk) ::g_decorator_type.SKINS.isPlayerHaveDecorator(blk?.name ?? "") ? 1 : 0
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_DECAL] = {
    userlogResourceTypeText = "decal"
    getLayeredImage = function(blk, _warbond)
    {
      let decorator = ::g_decorator.getDecorator(blk.name, ::g_decorator_type.DECALS)
      if (decorator)
        return ::LayersIcon.getIconData(null, ::g_decorator_type.DECALS.getImage(decorator))
      return ::LayersIcon.getIconData(::g_decorator_type.DECALS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) DECORATION.getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_DECAL,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return getUnlockNameText(UNLOCKABLE_DECAL, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.DECALS)?.canPreview() ?? false
    doPreview  = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.DECALS)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      return ::player_have_decal(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_ATTACHABLE] = {
    userlogResourceTypeText = "attachable"
    getLayeredImage = function(blk, _warbond)
    {
      let decorator = ::g_decorator.getDecorator(blk?.name ?? "", ::g_decorator_type.ATTACHABLES)
      if (decorator)
        return ::LayersIcon.getIconData(null, ::g_decorator_type.ATTACHABLES.getImage(decorator))
      return ::LayersIcon.getIconData(::g_decorator_type.ATTACHABLES.defaultStyle)
    }
    getTooltipId = @(blk, warbond) DECORATION.getTooltipId(blk?.name ?? "",
                                                                            UNLOCKABLE_ATTACHABLE,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return getUnlockNameText(UNLOCKABLE_ATTACHABLE, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return getFullUnlockDescByName(blk?.name ?? "")
    }

    canPreview = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.ATTACHABLES)?.canPreview() ?? false
    doPreview  = @(blk) ::g_decorator.getDecorator(blk.name, ::g_decorator_type.ATTACHABLES)?.doPreview()

    getMaxBoughtCount = @(_warbond, _blk) 1
    getBoughtCount = function(_warbond, blk) {
      return ::player_have_attachable(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [EWBAT_WP] = {
    getLayeredImage = function(blk, _warbond)
    {
      let wp = blk?.amount ?? 0
      return ::trophyReward.getFullWPIcon(wp)
    }
    getNameText = function(blk)
    {
      return ::Balance(blk?.amount ?? 0).tostring()
    }
    requestBuy = requestBuyByAmount
    getBoughtCount = getBoughtCountByAmount
  },

  [EWBAT_GOLD] = {
    getLayeredImage = function(_blk, _warbond)
    {
      return ::LayersIcon.getIconData("reward_gold")
    }
    getNameText = function(blk)
    {
      return ::Balance(0, blk?.amount ?? 0).tostring()
    }
    requestBuy = requestBuyByAmount
    getBoughtCount = getBoughtCountByAmount
  },

  [EWBAT_BATTLE_TASK] = {
    getLayeredImage = @(_blk, warbond) warbond.getLayeredIconStyle()
    getNameText = @(blk) loc("item/" + blk.name)
    getDescText = @(blk) loc("item/" + blk.name + "/desc")
    hasIncreasingLimit = @() hasFeature("BattlePass")
    canBuy = @(warbond, blk) ::warbonds_can_buy_battle_task(blk.name)
      && (!hasIncreasingLimit() || getPurchaseLimitWb(warbond) > this.getBoughtCount(warbond, blk))
    getMaxBoughtCount = @(warbond, blk) hasIncreasingLimit() ? getPurchaseLimitWb(warbond) : blk?.maxBoughtCount ?? 0
    isReqSpecialTasks = true
    canBuyReasonLocId = @(warbond, blk)
      ::g_battle_tasks.hasInCompleteHardTask.value
        ? "item/specialTasksPersonalUnlocks/purchaseRestriction"
        : hasIncreasingLimit() && (getPurchaseLimitWb(warbond) <= this.getBoughtCount(warbond, blk))
           ? "item/specialTasksPersonalUnlocks/limitRestriction"
           : ""
    getTooltipId = @(blk, warbond) SPECIAL_TASK.getTooltipId(blk.name,
                                                                              {
                                                                                wbId = warbond.id,
                                                                                wbListId = warbond.listId
                                                                              })
  },
},
null, "id")

::g_wb_award_type.getTypeByBlk <- function getTypeByBlk(blk)
{
  let typeInt = ::warbond_get_type_by_name(blk?.type ?? "invalid")
  return getTblValue(typeInt, this, this[EWBAT_INVALID])
}
