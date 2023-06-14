//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { DECORATION } = require("%scripts/utils/genericTooltipTypes.nut")
let { ceil } = require("math")
let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")

local CollectionsSet = class {
  id = "" //name of config blk. not unique
  uid = -1
  reqFeature = null
  locId = ""

  collectionItems = null
  prize = null

  constructor(blk) {
    this.id = blk.getBlockName() || ""
    this.reqFeature = blk?.reqFeature
    this.locId = blk?.locId || this.id

    let prizeBlk = blk?.prize
    if ((prizeBlk?.paramCount() ?? 0) > 0)
      this.prize = getDecoratorByResource(prizeBlk.getParamValue(0), prizeBlk.getParamName(0))

    this.collectionItems = []

    let collectionItemsBlk = blk?.collectionItems
    for (local i = 0; i < (collectionItemsBlk?.paramCount() ?? 0); i++) {
      let resource = getDecoratorByResource(
        collectionItemsBlk.getParamValue(i), collectionItemsBlk.getParamName(i))
      if (resource != null)
        this.collectionItems.append(resource)
    }
  }

  getDecoratorObjId = @(collectionIdx, decoratorId) $"{collectionIdx};{decoratorId}"
  isValid           = @() this.collectionItems.len() > 0 && this.prize != null
  isVisible         = @() this.reqFeature == null || hasFeature(this.reqFeature)
  getLocName        = @() loc(this.locId)
  _tostring         = @() $"CollectionSet {this.id} (collectionItemsAmount = {this.collectionItems.len()})"

  function getView(countItemsInRow, collectionTopPos, collectionHeight, collectionNum) {
    let collectionItemsTopPos = $"{collectionTopPos} + 1@buttonHeight + 1@blockInterval"
    let rowCount = ceil(this.collectionItems.len() / (countItemsInRow * 1.0))
    let deltaTopPos = "".concat("0.5*(", collectionHeight, "-1@buttonHeight+1@blockInterval-",
      rowCount, "@collectionItemSizeWithIndent)")
    local unlockedItemsCount = 0
    let itemsView = this.collectionItems.map((function(decorator, idx) {
      let decoratorType = decorator.decoratorType
      decoratorType.updateDownloadableDecoratorsInfo(decorator)
      let column = idx - countItemsInRow * (idx / countItemsInRow)
      let row = idx / countItemsInRow
      let isUnlocked = decorator.isUnlocked()
      if (isUnlocked)
        unlockedItemsCount++
      return {
        id = this.getDecoratorObjId(collectionNum, decorator.id)
        pos = "{0}, {1}".subst($"1@blockInterval + {column}@collectionItemSizeWithIndent",
          $"{collectionItemsTopPos} + {deltaTopPos} + {row}@collectionItemSizeWithIndent")
        tag = "imgSelectable"
        unlocked = isUnlocked
        image = decoratorType.getImage(decorator)
        imgRatio = decoratorType.getRatio(decorator)
        imgClass = "smallMedals"
        focusBorder = true
        tooltipId = DECORATION.getTooltipId(decorator.id, decoratorType.unlockedItemType)
      }
    }).bindenv(this))

    let decoratorType = this.prize.decoratorType
    let isUnlocked = this.prize.isUnlocked()
    itemsView.append({
      id = $"{collectionNum};{this.prize.id}"
      pos = "{0}, {1}".subst("1@collectionWidth-1@collectionPrizeWidth",
        $"{collectionItemsTopPos}+0.5*({collectionHeight}-1@buttonHeight+1@blockInterval-h)")
      tag = "imgSelectable"
      unlocked = isUnlocked
      image = decoratorType.getImage(this.prize)
      imgRatio = decoratorType.getRatio(this.prize)
      imgClass = "collectionPrize"
      focusBorder = true
      tooltipId = DECORATION.getTooltipId(this.prize.id, decoratorType.unlockedItemType, {
        additionalDescriptionMarkup = this.getCollectionViewForPrize()
      })
      topRightText = isUnlocked ? "" : $"{unlockedItemsCount}/{this.collectionItems.len()}"
      miniIcon = isUnlocked ? "#ui/gameuiskin#check.svg" : null
      miniIconColor = "@goodTextColor"
      miniIconPos = "pw - w - 1@blockInterval, 0"
      miniIconSize = "1@dIco, 1@dIco"
    })

    return {
      items = itemsView
      title = loc(this.locId)
      titlePos = $"1@blockInterval, 1@blockInterval + {collectionTopPos}"
    }
  }

  function findDecoratorById(itemId) {
    if (this.prize.id == itemId)
      return {
        decorator = this.prize
        isPrize = true
      }

    return {
      decorator = this.collectionItems.findvalue(@(item) item.id == itemId)
      isPrize = false
    }
  }

  function getCollectionViewForPrize() {
    return ::PrizesView.getPrizesListView(
      this.collectionItems.map(@(r) {
        resource = r.id
        resourceType = r.decoratorType.resourceType
      }),
      { receivedPrizes = true }, false)
  }
}

return CollectionsSet