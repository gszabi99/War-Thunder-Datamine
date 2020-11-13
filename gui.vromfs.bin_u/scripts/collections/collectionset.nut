local countItemsInRow = 5

local CollectionsSet = class {
  id = "" //name of config blk. not unique
  uid = -1
  reqFeature = null
  locId = ""

  collectionItems = null
  prize = null

  constructor(blk) {
    id = blk.getBlockName() || ""
    reqFeature = blk?.reqFeature
    locId = blk?.locId || id

    local prizeBlk = blk?.prize
    if ((prizeBlk?.paramCount() ?? 0) > 0)
      prize = ::g_decorator.getDecoratorByResource(prizeBlk.getParamValue(0), prizeBlk.getParamName(0))

    collectionItems = []

    local collectionItemsBlk = blk?.collectionItems
    for(local i = 0; i < (collectionItemsBlk?.paramCount() ?? 0); i++) {
      local resource = ::g_decorator.getDecoratorByResource(
        collectionItemsBlk.getParamValue(i), collectionItemsBlk.getParamName(i))
      if (resource != null)
        collectionItems.append(resource)
    }
  }

  isValid    = @() collectionItems.len() > 0 && prize != null
  isVisible  = @() reqFeature == null || ::has_feature(reqFeature)
  getLocName = @() ::loc(locId)
  _tostring  = @() $"CollectionSet {id} (collectionItemsAmount = {collectionItems.len()})"

  function getView(idxOnPage) {
    local collectionNum = uid
    local collectionTopPos = $"{idxOnPage} * (1@collectionHeight + 1@blockInterval)"
    local collectionItemsTopPos = $"{collectionTopPos} + 1@buttonHeight + 1@blockInterval"
    local collectionItemCenterPos = $"{collectionItemsTopPos} + 1@collectionItemSizeWithIndent - 0.5@blockInterval - 0.5h"
    local needPlaceItemsInCenter = collectionItems.len() <= countItemsInRow
    local unlockedItemsCount = 0
    local itemsView = collectionItems.map(function(decorator, idx) {
      local decoratorType = decorator.decoratorType
      decoratorType.updateDownloadableDecoratorsInfo(decorator)
      local column = idx >= countItemsInRow ? idx - countItemsInRow : idx
      local row = idx >= countItemsInRow ? 1 : 0
      local isUnlocked = decorator.isUnlocked()
      if (isUnlocked)
        unlockedItemsCount++
      return {
        id = $"{collectionNum};{decorator.id}"
        pos = "{0}, {1}".subst($"1@blockInterval + {column}@collectionItemSizeWithIndent",
          needPlaceItemsInCenter ? collectionItemCenterPos
            : $"{collectionItemsTopPos} + {row}@collectionItemSizeWithIndent")
        tag = "imgSelectable"
        unlocked = isUnlocked
        image = decoratorType.getImage(decorator)
        imgRatio = decoratorType.getRatio(decorator)
        imgClass = "smallMedals"
        focusBorder = true
        tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(decorator.id, decoratorType.unlockedItemType)
      }
    })

    local decoratorType = prize.decoratorType
    local isUnlocked = prize.isUnlocked()
    itemsView.append({
      id = $"{collectionNum};{prize.id}"
      pos = $"1@blockInterval + {countItemsInRow}@collectionItemSizeWithIndent, {collectionItemCenterPos}"
      tag = "imgSelectable"
      unlocked = isUnlocked
      image = decoratorType.getImage(prize)
      imgRatio = decoratorType.getRatio(prize)
      imgClass = "mediumSize"
      focusBorder = true
      tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(prize.id, decoratorType.unlockedItemType, {
        additionalDescriptionMarkup = getCollectionViewForPrize()
      })
      topRightText = isUnlocked ? "" : $"{unlockedItemsCount}/{collectionItems.len()}"
      miniIcon = isUnlocked ? "#ui/gameuiskin#check.svg" : null
      miniIconColor = "@goodTextColor"
      miniIconPos = "pw - w - 1@blockInterval, 0"
      miniIconSize = "1@dIco, 1@dIco"
    })

    return {
      items = itemsView
      title = ::loc(locId)
      titlePos = $"1@blockInterval, 1@blockInterval + {collectionTopPos}"
    }
  }

  function findDecoratorById(itemId) {
    if (prize.id == itemId)
      return {
        decorator = prize
        isPrize = true
      }

    return {
      decorator = collectionItems.findvalue(@(item) item.id == itemId)
      isPrize = false
    }
  }

  function getCollectionViewForPrize() {
    return ::PrizesView.getPrizesListView(
      collectionItems.map(@(r) {
        resource = r.id
        resourceType = r.decoratorType.resourceType
      }),
      { receivedPrizes = true}, false)
  }
}

return CollectionsSet