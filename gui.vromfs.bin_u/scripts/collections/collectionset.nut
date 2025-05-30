from "%scripts/dagui_library.nut" import *

let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getDecoratorByResource } = require("%scripts/customization/decorCache.nut")
let { getPrizesListViewData, getPrizesListMarkupByData } = require("%scripts/items/prizesView.nut")
let { utf8ToLower } = require("%sqstd/string.nut")

local CollectionsSet = class {
  id = "" 
  uid = -1
  reqFeature = null
  locId = ""
  searchName = ""
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

    this.searchName = utf8ToLower(this.getLocName())
  }

  getDecoratorObjId = @(collectionIdx, decoratorId) $"{collectionIdx};{decoratorId}"
  isValid           = @() this.collectionItems.len() > 0 && this.prize != null
  isVisible         = @() this.reqFeature == null || hasFeature(this.reqFeature)
  getLocName        = @() loc(this.locId)
  _tostring         = @() $"CollectionSet {this.id} (collectionItemsAmount = {this.collectionItems.len()})"

  function getView(collectionNum) {
    local unlockedItemsCount = 0
    let itemsView = this.collectionItems.map((function(decorator) {
      let decoratorType = decorator.decoratorType
      decoratorType.updateDownloadableDecoratorsInfo(decorator)
      let isUnlocked = decorator.isUnlocked()
      if (isUnlocked)
        unlockedItemsCount++
      return {
        id = this.getDecoratorObjId(collectionNum, decorator.id)
        tag = "imgSelectable"
        unlocked = isUnlocked ? "yes" : null
        image = decoratorType.getImage(decorator)
        imgRatio = decoratorType.getRatio(decorator)
        imgClass = "profileCollection"
        focusBorder = true
        tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decoratorType.unlockedItemType)
      }
    }).bindenv(this))

    let decoratorType = this.prize.decoratorType
    let isUnlocked = this.prize.isUnlocked()
    let mainPrize = {
      id = $"{collectionNum};{this.prize.id}"
      tag = "imgSelectable"
      unlocked = true
      image = decoratorType.getImage(this.prize)
      imgRatio = decoratorType.getRatio(this.prize)
      imgClass = "collectionPrize"
      focusBorder = true
      tooltipId = getTooltipType("DECORATION").getTooltipId(this.prize.id, decoratorType.unlockedItemType, {
        additionalDescriptionMarkup = this.getCollectionViewMarkup()
      })
      topLeftText = loc("reward")
      topRightText = isUnlocked ? "" : $"{unlockedItemsCount}/{this.collectionItems.len()}"
      miniIcon = isUnlocked ? "#ui/gameuiskin#check.svg" : "#ui/gameuiskin#locked.svg"
      miniIconColor = isUnlocked ? "@goodTextColor" : "@white"
      miniIconPos = "pw - w, ph - h - 1.5@blockInterval"
      miniIconSize = "1@dIco, 1@dIco"
    }

    return {
      items = itemsView
      mainPrize
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

  function getCollectionViewMarkup(params = {}) {
    let { hasHorizontalFlow = false, fixedTitleWidth = null } = params
    let data = getPrizesListViewData(
      this.collectionItems.map(@(r) {
        resource = r.id
        resourceType = r.decoratorType.resourceType
      }),
      { receivedPrizes = true, hasHorizontalFlow }, false
    )
    data.fixedTitleWidth <- fixedTitleWidth
    return getPrizesListMarkupByData(data)
  }
}

return CollectionsSet