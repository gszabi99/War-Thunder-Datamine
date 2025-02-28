from "%scripts/dagui_library.nut" import *

let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let { ceil } = require("math")
let { getPrizesListView } = require("%scripts/items/prizesView.nut")

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

  function getView(countItemsInRow, collectionNum) {
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
        pos = $"{column}@collectionItemSizeWithIndent, {row}@collectionItemSizeWithIndent"
        tag = "imgSelectable"
        unlocked = true
        image = decoratorType.getImage(decorator)
        imgRatio = decoratorType.getRatio(decorator)
        imgClass = "smallMedals"
        focusBorder = true
        tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decoratorType.unlockedItemType)
        miniIcon = isUnlocked ? "#ui/gameuiskin#check.svg" : "#ui/gameuiskin#locked.svg"
        miniIconColor = isUnlocked ? "@goodTextColor" : "@white"
        miniIconPos = "pw - w, ph - h - 0.75@blockInterval"
        miniIconSize = "1@sIco, 1@sIco"
      }
    }).bindenv(this))

    let decoratorType = this.prize.decoratorType
    let isUnlocked = this.prize.isUnlocked()
    itemsView.append({
      id = $"{collectionNum};{this.prize.id}"
      pos = $"{countItemsInRow}@collectionItemSizeWithIndent + 9@blockInterval, 0"
      tag = "imgSelectable"
      unlocked = true
      image = decoratorType.getImage(this.prize)
      imgRatio = decoratorType.getRatio(this.prize)
      imgClass = "collectionPrize"
      focusBorder = true
      tooltipId = getTooltipType("DECORATION").getTooltipId(this.prize.id, decoratorType.unlockedItemType, {
        additionalDescriptionMarkup = this.getCollectionViewForPrize()
      })
      topLeftText = loc("reward")
      topRightText = isUnlocked ? "" : $"{unlockedItemsCount}/{this.collectionItems.len()}"
      miniIcon = isUnlocked ? "#ui/gameuiskin#check.svg" : "#ui/gameuiskin#locked.svg"
      miniIconColor = isUnlocked ? "@goodTextColor" : "@white"
      miniIconPos = "pw - w, ph - h - 1.5@blockInterval"
      miniIconSize = "1@dIco, 1@dIco"
    })

    let rows = ceil(this.collectionItems.len() / countItemsInRow.tofloat()).tointeger()
    let viewHeight = to_pixels($"{rows}@collectionItemSizeWithIndent")

    return {
      items = itemsView
      viewHeight = max(to_pixels("1@collectionPrizeWidth"), viewHeight)
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

  function getCollectionViewForPrize(params = {}) {
    let { hasHorizontalFlow = false } = params
    return getPrizesListView(
      this.collectionItems.map(@(r) {
        resource = r.id
        resourceType = r.decoratorType.resourceType
      }),
      { receivedPrizes = true, hasHorizontalFlow }, false)
  }
}

return CollectionsSet