//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { rnd } = require("dagor.random")
let { isIPoint2 } = require("%sqStdLibs/helpers/u.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { getRoleText } = require("%scripts/unit/unitInfoTexts.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")

let class TrophyMultiAward {
  blk = null
  trophyWeak = null //req to generate tooltip id, and search trophy by award
  idxInTrophy = 0

  static listDiv = "\n * "
  static headerColor = "activeTextColor"
  static headerActiveColor = "userlogColoredText"
  static goodsColor  = "userlogColoredText"
  static condColor   = "activeTextColor"
  static typesBlocks = { //not array only to fast check key
    unlocks = 0
    spare = 1
    modification = 2
    premExpMul = 3
    specialization = 4
    modificationsList = 5
    resource = 6
    skin = 7
  }

  static maxRouletteIcons = 5
  static maxRouletteIconsSingleType = 3
  static rouletteIcons = {
    decal          = ["#ui/gameuiskin#item_type_decal.svg"]
    skin           = ["#ui/gameuiskin#itemtype_skin.svg"]
    spare          = ["#ui/gameuiskin#double.png"]
    modification   = ["#ui/gameuiskin#item_type_modification_aircraft.svg", "#ui/gameuiskin#item_type_modification_tank.svg"]
    premExpMul     = ["#ui/gameuiskin#talisman.png"]
    specialization = ["#ui/gameuiskin#item_type_crew_experts.svg", "#ui/gameuiskin#item_type_crew_aces.svg"]
  }

  constructor(v_blk, trophy = null, idx_in_trophy = 0) {
    this.blk = v_blk
    if (trophy) {
      this.trophyWeak = trophy.weak()
      this.idxInTrophy = idx_in_trophy
    }
  }

  function getCost() {
    return ::Cost(0, this.blk?.multiAwardsOnWorthGold ?? 0)
  }

  function getName() {
    let awardType = this.getAwardsType()
    let showCount = this.haveCount()
    local key = ""
    if (showCount)
      key = (awardType == "") ? "multiAward/name/count" : "multiAward/name/count/singleType"
    else
      key = (awardType == "") ? "multiAward/name" : "multiAward/name/singleType"
    return loc(key,
                 {
                   awardType = loc("multiAward/type/" + awardType)
                   awardCost = this.getCost().tostring()
                   awardCount = showCount ? colorize(this.headerActiveColor, this.getCount()) : ""
                 })
  }

  function getDescription(useBoldAsSmaller = false) {
    let resDesc = this.getResultDescription()
    if (resDesc != "")
      return resDesc

    local header = colorize(this.headerColor, this.getName())
    if (this.blk?.fromLastBattle) {
      local text = loc("multiAward/fromLastBattle")
      if (useBoldAsSmaller)
        text = "<b>" + text + "</b>"
      header += "\n" + text
    }

    let textList = []
    let skipUnconditional = this.getAwardsType() != ""
    let count = this.blk.blockCount()
    for (local i = 0; i < count; i++) {
      let text = this.getAwardText(this.blk.getBlock(i), skipUnconditional, useBoldAsSmaller)
      if (text.len())
        textList.append(text)
    }
    if (!textList.len())
      return header

    textList.insert(0, header + loc("ui/colon"))
    return ::g_string.implode(textList, (skipUnconditional && count == 1) ? "\n" : this.listDiv)
  }

  function getAwardText(awardBlk, skipUnconditional = false, useBoldAsSmaller = false) {
    local curAwardType = awardBlk.getBlockName()
    if (curAwardType == "resource" && awardBlk?.resourceType == "skin")
      curAwardType = "skin"

    if (curAwardType == "unlocks") {
      if (skipUnconditional)
        return ""

      let uTypes = ::u.map(awardBlk % "type",
                                 function(t) { return colorize(this.goodsColor, loc("multiAward/type/" + t)) }.bindenv(this))
      return ::g_string.implode(uTypes, this.listDiv)
    }

    if (curAwardType == "modificationsList") {
      if (skipUnconditional)
        return ""

      local res = colorize(this.goodsColor, loc("multiAward/type/modification"))
      res += colorize(this.condColor, " x" + awardBlk.paramCount())
      return res
    }

    if (curAwardType == "resource") {
      if (skipUnconditional)
        return ""

      let uTypes = ::u.map(awardBlk % "resourceType",
                                 function(t) { return colorize(this.goodsColor, loc("multiAward/type/" + t)) }.bindenv(this))
      return ::g_string.implode(uTypes, this.listDiv)
    }

    local res = ""
    if (!skipUnconditional && this.haveCount()) {
      let count = awardBlk?.count ?? 1
      res = "".concat(
        colorize(this.goodsColor, loc("multiAward/type/" + curAwardType)),
        colorize(this.condColor, " x" + count))
    }

    local conditions = this.getConditionsText(awardBlk)
    if (conditions == "")
      return skipUnconditional ? "" : res

    if (!skipUnconditional)
      conditions = " (" + conditions + ")"

    if (useBoldAsSmaller)
      conditions = "<b>" + conditions + "</b>"
    return res + conditions
  }

  function getConditionsText(awardBlk) {
    let condList = []
    this._addCondSpecialization(awardBlk, condList)
    this._addCondCountries(awardBlk, condList)
    this._addCondRanks(awardBlk, condList)
    this._addCondUnitClass(awardBlk, condList)
    this._addCondExistingUnit(awardBlk, condList)
    return ::g_string.implode(condList, "; ")
  }

  function _addCondExistingUnit(awardBlk, condList) {
    if (awardBlk?.forExistingUnits)
      condList.append(loc("conditions/unitExists"))
  }

  function _addCondSpecialization(awardBlk, condList) {
    if ((awardBlk?.specAce ?? false) == (awardBlk?.aceExpert ?? false))
      return

    let text = loc(this.blk?.specAce ? "crew/qualification/1" : "crew/qualification/2")
    condList.append(colorize(this.condColor, text))
  }

  function _addCondCountries(awardBlk, condList) {
    local countries = awardBlk % "country"
    if (!countries.len())
      return

    local text = loc("options/country") + loc("ui/colon")
    countries = ::u.map(countries,
                            function(val) { return colorize(this.condColor loc(val)) }.bindenv(this))
    text += ::g_string.implode(countries, ", ")
    condList.append(text)
  }

  function _addCondRanks(awardBlk, condList) {
    local ranks = awardBlk % "ranksRange"
    if (!ranks.len())
      return

    local text = loc("shop/age") + loc("ui/colon")
    ranks = ::u.map(ranks,
      function(val) {
        if (!isIPoint2(val))
          return ""

        let res = colorize(this.condColor, ::get_roman_numeral(val.x))
        if (val.x == val.y)
          return res

        let div = (val.y - val.x == 1) ? ", " : "-"
        return res + div + colorize(this.condColor, ::get_roman_numeral(val.y))
      }.bindenv(this))

    text += ::g_string.implode(ranks, ", ")
    condList.append(text)
  }

  function _addCondUnitClass(awardBlk, condList) {
    local classes = processUnitTypeArray(awardBlk % "unitClass")
    if (!classes.len())
      return

    local text = loc("unit_type") + loc("ui/colon")
    classes = ::u.map(classes,
                          function(val) {
                            local role = val.tolower()
                            role = ::g_string.cutPrefix(role, "exp_", role)
                            if (role == "aircraft")
                              return colorize(this.condColor, loc("unlockTag/unit_aircraft"))
                            return colorize(this.condColor, getRoleText(role))
                          }.bindenv(this))

    text += ::g_string.implode(classes, ", ")
    condList.append(text)
  }

  function getResultDescription() {
    let resList = this.getResultPrizesList()
    if (!resList || !resList.len())
      return ""

    return ::PrizesView.getPrizesListText(resList)
  }

  function getResultPrizesList() {
    let res = []
    let resBlk = this.blk?.result
    if (!isDataBlock(resBlk))
      return res

    this._addResUnlocks(resBlk, res)
    this._addResModifications(resBlk, res)
    this._addResSpare(resBlk, res)
    this._addResSpecialization(resBlk, res)
    this._addResUCurrency(resBlk, res)
    this._addResResources(resBlk, res)
    return res
  }

  function _addResUnlocks(resBlk, resList) {
    let unlocksBlk = resBlk?.unlocks
    if (!isDataBlock(unlocksBlk))
      return

    for (local i = 0; ; i++) {
      let unlockName = unlocksBlk?["unlock" + i]
      if (!unlockName)
        break

      resList.append(DataBlockAdapter({
        unlock = unlockName
        gold = unlocksBlk?["gold" + i] ?? 0
      }))
    }
  }

  function _addResModifications(resBlk, resList) {
    this._addResModificationsFromBlock(resBlk?.modification, resList)
    this._addResModificationsFromBlock(resBlk?.premExpMul, resList)
  }

  function _addResModificationsFromBlock(resModBlk, resList) {
    if (!resModBlk)
      return

    for (local i = 0; ; i++) {
      let unitName = resModBlk?["unit" + i]
      let modName = resModBlk?["mod" + i]
      if (!unitName || !modName)
        break

      resList.append(DataBlockAdapter({
        unit = unitName
        mod = modName
        gold = resModBlk?["gold" + i] ?? 0
      }))
    }
  }

  function _addResSpare(resBlk, resList) {
    let spareBlk = resBlk?.spare
    if (!isDataBlock(spareBlk))
      return

    local list = []
    for (local i = 0; ; i++) {
      let unitName = spareBlk?["unit" + i]
      if (!unitName)
        break

      list.append({
        spare = unitName
        gold = spareBlk?["gold" + i] ?? 0
        count = spareBlk?["count" + i] ?? 1
      })
    }

    if (!list.len())
      list = this.getSpareListFromOldUserlogFormat(spareBlk)

    list.sort(function(a, b) { return a.spare > b.spare ? 1 : (a.spare < b.spare ? -1 : 0) })
    foreach (data in list)
      resList.append(DataBlockAdapter(data))
  }

  //version 1.49.7.X  15.05.2015  - new userlogs still not on production, but soon they will come.
  //we need to support old userlogs at least month after new will come.
  function getSpareListFromOldUserlogFormat(spareBlk) {
    let list = []
    let namesMap = {} //for faster search
    let count = spareBlk.paramCount()
    for (local i = 0; i < count; i++) {
      let name = spareBlk.getParamName(i)
      let gold = spareBlk.getParamValue(i)
      if (name in namesMap) {
        let data = namesMap[name]
        data.count++
        data.gold += gold
        continue
      }

      let data = {
        spare = name
        gold = gold
        count = 1
      }
      list.append(data)
      namesMap[name] <- data
    }
    return list
  }

  function _addResSpecialization(resBlk, resList) {
    let qBlk = resBlk?.specialization
    if (!isDataBlock(qBlk))
      return

    let list = {}
    for (local i = 0; ; i++) {
      let unitName = qBlk?["unit" + i]
      if (!unitName)
        break
      let unit = ::getAircraftByName(unitName)
      if (!unit)
        continue

      let country = unit.shopCountry
      if (!(country in list))
        list[country] <- []

      list[country].append({
        specialization = qBlk?["spec" + i] ?? 2
        unitName = unitName
        crew = qBlk?["crew" + i] ?? 0
        gold = qBlk?["gold" + i] ?? 0
      })
    }

    foreach (country in shopCountriesList) {
      if (!(country in list))
        continue

      let prizesList = list[country]
      prizesList.sort(this._resSpecializationSort)
      foreach (data in prizesList)
        resList.append(DataBlockAdapter(data))
    }
  }

  function _resSpecializationSort(a, b) {
    if (a.specialization != b.specialization)
      return a.specialization > b.specialization ? -1 : 1
    if (a.crew != b.crew)
      return a.crew > b.crew ? 1 : -1
    if (a.unitName != b.unitName)
      return a.unitName > b.unitName ? 1 : -1
    return 0
  }

  function _addResUCurrency(_resBlk, resList) {
    let gold = this.blk?.gold //not mistake, it in the root now.
    if (!gold)
      return
    resList.append(DataBlockAdapter({ gold = gold }))
  }

  function _addResResources(resBlk, resList) {
    let resourcesBlk = resBlk?.resource
    if (!isDataBlock(resourcesBlk))
      return

    for (local i = 0; ; i++) {
      let resName = resourcesBlk?["resource" + i]
      if (!resName)
        break

      resList.append(DataBlockAdapter({
        resource = resName
        resourceType = resourcesBlk?["resourceType" + i] ?? ""
        gold = resourcesBlk?["gold" + i] ?? 0
      }))
    }
  }

  function haveCount() {
    return !this.blk?.multiAwardsOnWorthGold
  }

  _count = -1
  function getCount() {
    if (!this.haveCount())
      return 0

    if (this._count < 0)
      this.initParams()
    return this._count
  }

  _awardType = null
  function getAwardsType() { //return "" when multitype
    if (!this._awardType)
      this.initParams()
    return this._awardType
  }

  function initParams() {
    let count = this.blk.blockCount()
    local multiType = false
    let needCount = this.haveCount()
    local awardsCount = 0
    for (local i = 0; i < count; i++) {  //country
      let awardBlk = this.blk.getBlock(i)
      local awardType = awardBlk.getBlockName()
      if (!(awardType in this.typesBlocks))
        continue

      if (awardType == "modificationsList") {
        awardsCount += awardBlk.paramCount()
        awardType = "modification"
      }
      else
        awardsCount += awardBlk?.count ?? 0

      if (awardType == "unlocks" || awardType == "resource") {
        let typesKey = (awardType == "resource") ?  "resourceType" : "type"
        let uTypes = awardBlk % typesKey
        if (uTypes.len() == 1)
          awardType = uTypes[0]
        else if (uTypes.len() > 1) {
          multiType = true
          if (!needCount)
            break
          continue
        }
      }

      if (!this._awardType)
        this._awardType = awardType
      else if (this._awardType != awardType) {
        multiType = true
        if (!needCount)
          break
      }
    }

    if (multiType || !this._awardType)
      this._awardType = ""
    this._count = awardsCount
  }

  function getFullTypesList() {
    if (this._awardType && this._awardType != "") //to not force recount awardType if it not counted yet.
      return [this._awardType]

    let res = []
    let count = this.blk.blockCount()
    for (local i = 0; i < count; i++) {  //country
      let awardBlk = this.blk.getBlock(i)
      let awardType = awardBlk.getBlockName()
      if (!(awardType in this.typesBlocks))
        continue

      if (awardType == "unlocks" || awardType == "resource") {
        let typesKey = (awardType == "resource") ?  "resourceType" : "type"
        let uTypes = awardBlk % typesKey
        foreach (uType in uTypes)
          ::u.appendOnce(uType, res)
        continue
      }

      ::u.appendOnce(awardType, res)
    }
    return res
  }

  function getTypeIcon() {
    let awardType = this.getAwardsType()
    if (awardType == "decal")
      return "#ui/gameuiskin#item_type_decal.svg"
    if (awardType == "skin")
      return "#ui/gameuiskin#item_type_skin.svg"
    if (awardType == "spare")
      return "#ui/gameuiskin#item_type_spare.svg"
    if (awardType == "modification")
      return "#ui/gameuiskin#item_type_modifications.svg"
    if (awardType == "premExpMul")
      return "#ui/gameuiskin#item_type_talisman.svg"
    if (awardType == "specialization")
      return "#ui/gameuiskin#item_type_crew_aces.svg"
    return "#ui/gameuiskin#log_online_shop.png"
  }

  function getAvailRouletteIcons() {
    let res = []
    let typesList = this.getFullTypesList()
    foreach (t in typesList)
      if (t in this.rouletteIcons)
        res.extend(this.rouletteIcons[t])
    return res
  }

  function getRewardImage() {
    local res = this._getIconsLayer()
    res += this._getTextLayer()
    return res
  }

  function getOnlyRewardImage() {
    return this._getIconsLayer()
  }

  function _chooseIconsForLayer(iconsList, total) {
    let res = []
    let totalIcons = iconsList.len()
    for (local i = 0; i < total; i++)
      if (iconsList.len())
        res.append(iconsList.remove(rnd() % iconsList.len()))
      else
        res.append(res[rnd() % totalIcons])
    return res
  }

  function _getIconsLayer() {
    let awardsType = this.getAwardsType()
    let iconsList = this.getAvailRouletteIcons()
    if (!iconsList.len())
      return ""

    local res = ""
    let singleType = awardsType != ""
    let layerName = singleType ? "item_multiaward_single" : "item_multiaward"
    let chosen = this._chooseIconsForLayer(iconsList, singleType ? this.maxRouletteIconsSingleType : this.maxRouletteIcons)
    for (local idx = chosen.len() - 1; idx >= 0; idx--) {
      let layerCfg = ::LayersIcon.findLayerCfg(layerName + idx)
      if (!layerCfg)
        continue

      layerCfg.img = chosen[idx]
      res += ::LayersIcon.genDataFromLayer(layerCfg)
    }
    return res
  }

  function _getTextLayer() {
    let layerCfg = ::LayersIcon.findLayerCfg("item_multiaward_text")
    if (!layerCfg)
      return ""

    layerCfg.text <- this.haveCount() ? "x" + this.getCount() : this.getCost().tostring()
    return ::LayersIcon.getTextDataFromLayer(layerCfg)
  }
}

return TrophyMultiAward
