local { leftSpecialTasksBoughtCount } = require("scripts/warbonds/warbondShopState.nut")

local enums = require("sqStdLibs/helpers/enums.nut")
::g_wb_award_type<- {
  types = []
}

local function requestBuyByName(warbond, blk)
{
  local reqBlk = ::DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.name = blk?.name ?? ""

  return ::char_send_blk("cln_exchange_warbonds", reqBlk)
}

local function requestBuyByAmount(warbond, blk)
{
  local reqBlk = ::DataBlock()
  reqBlk.warbond = warbond.id
  reqBlk.stage = warbond.listId
  reqBlk.type = blk?.type
  reqBlk.amount = blk?.amount ?? 1

  return ::char_send_blk("cln_exchange_warbonds", reqBlk)
}

local getBoughtCountByName = @(warbond, blk)
  ::get_warbond_item_bought_count_with_name(warbond.id, warbond.listId, blk?.type, blk?.name ?? "")
local getBoughtCountByAmount = @(warbond, blk)
  ::get_warbond_item_bought_count_with_amount(warbond.id, warbond.listId, blk?.type, blk?.amount ?? 1)


::g_wb_award_type.template <- {
  id = ::EWBAT_INVALID //filled by type id.used from code enum EWBAT
  getLayeredImage = function(blk, warbond) { return "" }
  getContentIconData = function(blk) { return null } //{ contentIcon, [contentType] }
  getIconHeaderText = function(blk) { return null }
  getTooltipId = @(blk, warbond) null //string

  hasCommonDesc = true
  getNameText = function(blk) { return "" }
  getDescText = function(blk) { return "" }
  getDescriptionImage = function(blk, warbond) { return getLayeredImage(blk, warbond) }
  getDescItem = function(blk) { return null } //show description as item description

  requestBuy = requestBuyByName //warbond, blk
  getBoughtCount = getBoughtCountByName //warbond, blk

  canBuy = @(blk) true
  getMaxBoughtCount = @(blk) blk?.maxBoughtCount ?? 0
  showAvailableAmount = true
  isAvailableForCurrentShop = @(warbond) true

  isReqSpecialTasks = false
  canBuyReasonLocId = @() isReqSpecialTasks? "item/specialTasksPersonalUnlocks/purchaseRestriction" : ""
  userlogResourceTypeText = ""
  getUserlogBuyText = function(blk, priceText)
  {
    if (priceText != "")
      priceText = ::loc("ui/parentheses/space", { text = priceText })
    return getUserlogBuyTextBase(blk) + priceText
  }
  getUserlogBuyTextBase = function(blk)
  {
    return ::format(::loc("userlog/buy_resource/" + userlogResourceTypeText), getNameText(blk))
  }
}

local makeWbAwardItem = function(changesTbl = null)
{
  local res = {
    hasCommonDesc = false

    getItem = @(blk) ::ItemsManager.findItemById(blk.name)
    getDescItem = @(blk) getItem(blk)

    getNameText = function(blk)
    {
      local item = getItem(blk)
      return item ? item.getName() : ""
    }

    getLayeredImage = function(blk, warbond)
    {
      local item = getItem(blk)
      return item ? item.getIcon() : ""
    }

    getContentIconData = function(blk)
    {
      local item = getItem(blk)
      return item ? item.getContentIconData() : ""
    }

    getTooltipId = @(blk, warbond)
      ::g_tooltip.getIdItem(blk?.name ?? "", { wbId = warbond.id, wbListId = warbond.listId })

    getUserlogBuyText = function(blk, priceText)
    {
      local item = getItem(blk)
      return ::loc("userlog/buy_item",
        {
          itemName = ::colorize("userlogColoredText", item ? item.getName() : "")
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
  [::EWBAT_INVALID] = {
    requestBuy = function(...) { return -1 }
  },

  [::EWBAT_UNIT] = {
    getLayeredImage = function(blk, warbond)
    {
      local unit = ::getAircraftByName(blk.name)
      local unitType = ::get_es_unit_type(unit)
      local style = "reward_unit_" + ::getUnitTypeText(unitType).tolower()
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

    getDescriptionImage = function(blk, warbond)
    {
      local unit = ::getAircraftByName(blk.name)
      if (!unit)
        return ""

      local blockFormat = "rankUpList { halign:t='center'; interactiveChildren:t='yes'; %s }"
      return ::format(blockFormat, ::build_aircraft_item(unit.name, unit, {
        hasActions = true,
        status = ::isUnitBought(unit) ? "owned" : "canBuy",
        showAsTrophyContent = true
      }))
    }

    getMaxBoughtCount = function(blk) { return 1 }
    getBoughtCount = function(warbond, blk) {
      local unit = ::getAircraftByName(blk.name)
      return (unit && ::isUnitBought(unit)) ? 1 : 0
    }
    showAvailableAmount = false

    getUserlogBuyTextBase = function(blk)
    {
      return ::format(::loc("userlog/buy_aircraft"), getNameText(blk))
    }
  },

  [::EWBAT_ITEM]                 = makeWbAwardItem(),
  [::EWBAT_TROPHY]               = makeWbAwardItem(),
  [::EWBAT_EXT_INVENTORY_ITEM]   = makeWbAwardItem({
    getItem = @(blk) ::ItemsManager.findItemById(::to_integer_safe(blk.name))
  }),

  [::EWBAT_SKIN] = {
    userlogResourceTypeText = "skin"
    getLayeredImage = function(blk, warbond)
    {
      return ::LayersIcon.getIconData(::g_decorator_type.SKINS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) ::g_tooltip_type.DECORATION.getTooltipId(blk?.name ?? "",
                                                                            ::UNLOCKABLE_SKIN,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return ::get_unlock_name_text(::UNLOCKABLE_SKIN, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return ::get_unlock_description(blk?.name ?? "")
    }

    getMaxBoughtCount = @(blk) 1
    getBoughtCount = @(warbond, blk) ::g_decorator_type.SKINS.isPlayerHaveDecorator(blk?.name ?? "") ? 1 : 0
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [::EWBAT_DECAL] = {
    userlogResourceTypeText = "decal"
    getLayeredImage = function(blk, warbond)
    {
      local decorator = ::g_decorator.getDecorator(blk.name, ::g_decorator_type.DECALS)
      if (decorator)
        return ::LayersIcon.getIconData(null, ::g_decorator_type.DECALS.getImage(decorator))
      return ::LayersIcon.getIconData(::g_decorator_type.DECALS.defaultStyle)
    }
    getTooltipId = @(blk, warbond) ::g_tooltip_type.DECORATION.getTooltipId(blk?.name ?? "",
                                                                            ::UNLOCKABLE_DECAL,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return ::get_unlock_name_text(::UNLOCKABLE_DECAL, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return ::get_unlock_description(blk?.name ?? "")
    }

    getMaxBoughtCount = function(blk) { return 1 }
    getBoughtCount = function(warbond, blk) {
      return ::player_have_decal(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [::EWBAT_ATTACHABLE] = {
    userlogResourceTypeText = "attachable"
    getLayeredImage = function(blk, warbond)
    {
      local decorator = ::g_decorator.getDecorator(blk?.name ?? "", ::g_decorator_type.ATTACHABLES)
      if (decorator)
        return ::LayersIcon.getIconData(null, ::g_decorator_type.ATTACHABLES.getImage(decorator))
      return ::LayersIcon.getIconData(::g_decorator_type.ATTACHABLES.defaultStyle)
    }
    getTooltipId = @(blk, warbond) ::g_tooltip_type.DECORATION.getTooltipId(blk?.name ?? "",
                                                                            ::UNLOCKABLE_ATTACHABLE,
                                                                            {
                                                                              wbId = warbond.id,
                                                                              wbListId = warbond.listId
                                                                            })
    getNameText = function(blk)
    {
      return ::get_unlock_name_text(::UNLOCKABLE_ATTACHABLE, blk?.name ?? "")
    }
    getDescText = function(blk)
    {
      return ::get_unlock_description(blk?.name ?? "")
    }

    getMaxBoughtCount = function(blk) { return 1 }
    getBoughtCount = function(warbond, blk) {
      return ::player_have_attachable(blk?.name ?? "") ? 1 : 0
    }
    showAvailableAmount = false
    imgNestDoubleSize = "yes"
  },

  [::EWBAT_WP] = {
    getLayeredImage = function(blk, warbond)
    {
      local wp = blk?.amount ?? 0
      return ::trophyReward.getFullWPIcon(wp)
    }
    getNameText = function(blk)
    {
      return ::Balance(blk?.amount ?? 0).tostring()
    }
    requestBuy = requestBuyByAmount
    getBoughtCount = getBoughtCountByAmount
  },

  [::EWBAT_GOLD] = {
    getLayeredImage = function(blk, warbond)
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

  [::EWBAT_BATTLE_TASK] = {
    getLayeredImage = @(blk, warbond) ::LayersIcon.getIconData("reward_battle_task_" + warbond.medalIcon)
    getNameText = @(blk) ::loc("item/" + blk.name)
    getDescText = @(blk) ::loc("item/" + blk.name + "/desc")
    needCheckLimit = @() ::has_feature("BattlePass")
    canBuy = @(blk) ::warbonds_can_buy_battle_task(blk.name) && (!needCheckLimit() || leftSpecialTasksBoughtCount.value > 0)
    getBoughtCount = @(warbond, blk) needCheckLimit() ? 0 : getBoughtCountByName(warbond, blk)
    getMaxBoughtCount = @(blk) needCheckLimit() ? leftSpecialTasksBoughtCount.value : blk?.maxBoughtCount ?? 0
    isReqSpecialTasks = true
    isAvailableForCurrentShop = @(warbond) warbond.isCurrent()
    canBuyReasonLocId = @() ::g_battle_tasks.hasInCompleteHardTask.value ? "item/specialTasksPersonalUnlocks/purchaseRestriction"
      : needCheckLimit() && leftSpecialTasksBoughtCount.value == 0 ? "item/specialTasksPersonalUnlocks/limitRestriction"
      : ""
    getTooltipId = @(blk, warbond) ::g_tooltip_type.SPECIAL_TASK.getTooltipId(blk.name,
                                                                              {
                                                                                wbId = warbond.id,
                                                                                wbListId = warbond.listId
                                                                              })
  },
},
null, "id")

g_wb_award_type.getTypeByBlk <- function getTypeByBlk(blk)
{
  local typeInt = ::warbond_get_type_by_name(blk?.type ?? "invalid")
  return ::getTblValue(typeInt, this, this[::EWBAT_INVALID])
}
