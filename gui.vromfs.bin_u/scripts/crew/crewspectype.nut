//-file:plus-string
from "%scripts/dagui_natives.nut" import expert_to_ace_get_unit_exp, wp_get_specialization_cost_gold, wp_get_specialization_cost
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_warpoints_blk, get_skills_blk, get_price_blk } = require("blkGetters")

::g_crew_spec_type <- {
  types = []
}

::g_crew_spec_type._getNextType <- function _getNextType() {
  return ::g_crew_spec_type.getTypeByCode(this.nextCode)
}

::g_crew_spec_type._isCrewTrained <- function _isCrewTrained(crew, unit) {
  return ::g_crew_spec_type.getTrainedSpecCode(crew, unit) >= this.code
}

::g_crew_spec_type._getUpgradeCostByCrewAndByUnit <- function _getUpgradeCostByCrewAndByUnit(crew, unit, upgradeToSpecCode = -1) {
  if (upgradeToSpecCode < 0)
    upgradeToSpecCode = this.code + 1

  let cost = Cost()
  for (local specCode = this.code; specCode < upgradeToSpecCode; specCode++) {
    cost.wp += wp_get_specialization_cost(specCode, unit.name, crew.id, -1)
    cost.gold += wp_get_specialization_cost_gold(specCode, unit.name, crew.id, -1)
  }
  return cost
}

::g_crew_spec_type._getUpgradeCostByUnitAndExp <- function _getUpgradeCostByUnitAndExp(unit, exp) {
  return Cost(wp_get_specialization_cost(this.code, unit.name, 0, exp),
                wp_get_specialization_cost_gold(this.code, unit.name, 0, exp))
}

::g_crew_spec_type._getName <- function _getName() {
  return loc(this.getNameLocId(), "")
}

::g_crew_spec_type._hasNextType <- function _hasNextType() {
  return this.getNextType() != ::g_crew_spec_type.UNKNOWN
}

::g_crew_spec_type._getButtonLabel <- function _getButtonLabel() {
  return loc("crew/qualifyIncrease" + this.code, "")
}

::g_crew_spec_type._getDiscountTooltipByValue <- function _getDiscountTooltipByValue(discountValue) {
  if (!u.isString(discountValue))
    discountValue = discountValue.tostring()
  let locId = format("discount/%s/tooltip", this.specName)
  return format(loc(locId), discountValue)
}

::g_crew_spec_type._getNameLocId <- function _getNameLocId() {
  return format("crew/qualification/%d", this.code)
}

::g_crew_spec_type._getDiscountValueByUnitNames <- function _getDiscountValueByUnitNames(unitNames) {
  let priceBlk = get_price_blk()
  return ::getDiscountByPath(["aircrafts", unitNames, "specialization", this.specName], priceBlk)
}

::g_crew_spec_type._getPrevType <- function _getPrevType() {
  foreach (t in ::g_crew_spec_type.types)
    if (t.nextCode == this.code)
      return t
  return ::g_crew_spec_type.UNKNOWN
}

::g_crew_spec_type._hasPrevType <- function _hasPrevType() {
  return this.getPrevType() != ::g_crew_spec_type.UNKNOWN
}

::g_crew_spec_type._getMulValue <- function _getMulValue(prevSpecTypeCode = 0) {
  let skillsBlk = get_skills_blk()
  local addPct = 0.0
  for (local specCode = this.code; specCode > prevSpecTypeCode; specCode--)
    addPct += skillsBlk?[format("specialization%d_add", specCode + 1)] ?? 0
  return 0.01 * addPct
}

::g_crew_spec_type._getFullBonusesText <- function _getFullBonusesText(crewUnitType, prevSpecTypeCode = -1) {
  ::load_crew_skills_once()

  if (prevSpecTypeCode < 0)
    prevSpecTypeCode = this.code - 1
  let specMul = this.getMulValue(prevSpecTypeCode)
  let rowsArray = []
  foreach (page in ::crew_skills) {
    if (!page.isVisible(crewUnitType))
      continue

    let textsArray = []
    foreach (item in page.items)
      if (item.isVisible(crewUnitType) && item.useSpecializations) {
        let skillCrewLevel = ::g_crew.getSkillCrewLevel(item, specMul * ::g_crew.getMaxSkillValue(item))
        let skillText = loc("crew/" + item.name) + " "
                          + colorize("goodTextColor", "+" + skillCrewLevel)
        textsArray.append(::stringReplace(skillText, " ", nbsp))
      }

    if (!textsArray.len())
      continue

    rowsArray.append("".concat(colorize("activeTextColor", loc("crew/" + page.id)),
                          loc("ui/colon"), ", ".join(textsArray, true), loc("ui/dot")))
  }
  return "\n".join(rowsArray, true)
}

::g_crew_spec_type._getReqCrewLevelByCode <- function _getReqCrewLevelByCode(unit, upgradeFromCode) {
  ::load_crew_skills_once()
  let crewUnitType = unit?.getCrewUnitType?() ?? CUT_INVALID
  let reqTbl = ::crew_air_train_req?[crewUnitType]
  let ranksTbl = getTblValue(upgradeFromCode, reqTbl)
  return getTblValue(unit.rank, ranksTbl, 0)
}

::g_crew_spec_type._getReqCrewLevel <- function _getReqCrewLevel(unit) {
  return this._getReqCrewLevelByCode(unit, this.code - 1)
}

::g_crew_spec_type._getUpgradeReqCrewLevel <- function _getUpgradeReqCrewLevel(unit) {
  return this._getReqCrewLevelByCode(unit, this.code)
}

::g_crew_spec_type._getNextMaxAvailableType <- function _getNextMaxAvailableType(unit, crewLevel) {
  local resType = this
  local nextType = resType.getNextType()
  while (nextType != ::g_crew_spec_type.UNKNOWN) {
    if (nextType.getReqCrewLevel(unit) <= crewLevel)
      resType = nextType
    else
      break
    nextType = resType.getNextType()
  }
  return resType
}

::g_crew_spec_type._getIcon <- function _getIcon(crewTypeCode, crewLevel, unit) {
  if (crewTypeCode >= this.code)
    return this.icon

  if (unit && this.getReqCrewLevel(unit) <= crewLevel && crewTypeCode != -1)
    return this.iconCanBuy
  return this.iconInactive
}

::g_crew_spec_type._isExpUpgradableByUnit <- function _isExpUpgradableByUnit(_unit) {
  return false
}


::g_crew_spec_type._getExpLeftByCrewAndUnit <- function _getExpLeftByCrewAndUnit(_crew, _unit) {
  return -1
}

::g_crew_spec_type._getTotalExpByUnit <- function _getTotalExpByUnit(_unit) {
  return -1
}

::g_crew_spec_type._getExpUpgradeDiscountData <- function _getExpUpgradeDiscountData() {
  return []
}

::g_crew_spec_type._needShowExpUpgrade <- function _needShowExpUpgrade(_crew, unit) {
  return this.isExpUpgradableByUnit(unit)
}

//return empty string when level is enough
::g_crew_spec_type._getReqLevelText <- function _getReqLevelText(crew, unit) {
  let res = []
  let reqLevel = this.getReqCrewLevel(unit)
  let crewLevel = ::g_crew.getCrewLevel(crew, unit, unit?.getCrewUnitType?() ?? CUT_INVALID)
  let locParams = {
    wantedQualify = colorize("activeTextColor", this.getName())
    unitName = colorize("activeTextColor", getUnitName(unit))
  }
  let curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
  let needToTrainUnit = curSpecType == ::g_crew_spec_type.UNKNOWN
  if (needToTrainUnit)
    res.append(colorize("badTextColor", loc("crew/qualifyRequirement/toTrainUnit", locParams)))

  if (reqLevel > crewLevel && reqLevel > 1) {
    let reqLevelLocId = needToTrainUnit ? "crew/qualifyRequirement" : "crew/qualifyRequirement/full"
    res.append(colorize("badTextColor", loc(reqLevelLocId, locParams.__merge({
      reqLevel = colorize("activeTextColor", reqLevel)
    }))))
  }

  return "\n".join(res, true)
}

::g_crew_spec_type._getBaseTooltipText <- function _getBaseTooltipText(crew, unit) {
  local tooltipText = loc("crew/qualification/tooltip")
  let isShowExpUpgrade = this.needShowExpUpgrade(crew, unit)
  if (this.hasNextType()) {
    let nextType = this.getNextType()
    let nextSpecName = nextType.getName()
    tooltipText += format(
      "\n\n%s: %s",
      loc("crew/qualification/nextSpec"),
      colorize("activeTextColor", nextSpecName))


    let reqLevelText = nextType.getReqLevelText(crew, unit)
    if (reqLevelText.len())
      tooltipText += "\n" + reqLevelText
    else {
      let specDescriptionPart = isShowExpUpgrade ?
        loc("crew/qualification/specDescriptionPart", {
          expAmount = Cost().setRp(this.getTotalExpByUnit(unit)).tostring()
        })
        : ""
      let specDescription = loc(
        "crew/qualification/specDescriptionMain", {
          specName = colorize("activeTextColor", nextSpecName)
          trainCost = this.getUpgradeCostByCrewAndByUnit(crew, unit).tostring()
          descPart = specDescriptionPart
        })
      tooltipText += "\n" + specDescription
    }
  }
  if (isShowExpUpgrade) {
    tooltipText += format(
      "\n%s: %s / %s",
      loc("crew/qualification/expUpgradeLabel"),
      Cost().setRp(this.getExpLeftByCrewAndUnit(crew, unit)).toStringWithParams({ isRpAlwaysShown = true }),
      Cost().setRp(this.getTotalExpByUnit(unit)).tostring())
  }
  return tooltipText
}

::g_crew_spec_type._getTooltipContent <- function _getTooltipContent(crew, unit) {
  let progressBarValue = 1000 * this.getExpLeftByCrewAndUnit(crew, unit)
    / this.getTotalExpByUnit(unit)
  let view = {
    tooltipText = this.getBaseTooltipText(crew, unit)
    hasExpUpgrade = this.needShowExpUpgrade(crew, unit)
    markers = []
    progressBarValue = progressBarValue.tointeger()
  }

  // Discount markers.
  local expUpgradeText = ""
  let totalExp = this.getTotalExpByUnit(unit)
  foreach (i, dataItem in this.getExpUpgradeDiscountData()) {
    let romanNumeral = get_roman_numeral(i + 1)
    let markerView = {
      markerRatio = dataItem.percent.tofloat() / 100
      markerText = romanNumeral
    }
    view.markers.append(markerView)

    if (expUpgradeText.len() > 0)
      expUpgradeText += "\n"
    let expAmount = (dataItem.percent * totalExp / 100).tointeger()
    let trainCost = this.getUpgradeCostByUnitAndExp(unit, expAmount)
    let locParams = {
      romanNumeral = romanNumeral
      trainCost = trainCost.tostring()
      expAmount = Cost().setRp(expAmount).toStringWithParams({ isRpAlwaysShown = true })
    }
    expUpgradeText += loc("crew/qualification/expUpgradeMarkerCaption", locParams)
  }

  // Marker at 100% progress.
  let romanNumeral = get_roman_numeral(view.markers.len() + 1)
  view.markers.append({
    markerRatio = 1
    markerText = romanNumeral
  })
  if (expUpgradeText.len() > 0)
    expUpgradeText += "\n"
  let locParams = {
    romanNumeral = romanNumeral
    specName = colorize("activeTextColor", this.getNextType().getName())
    expAmount = Cost().setRp(this.getTotalExpByUnit(unit)).toStringWithParams({ isRpAlwaysShown = true })
  }
  expUpgradeText += loc("crew/qualification/expUpgradeFullUpgrade", locParams)

  view.expUpgradeText <- expUpgradeText

  return handyman.renderCached("%gui/crew/crewUnitSpecUpgradeTooltip.tpl", view)
}

::g_crew_spec_type._getBtnBuyTooltipId <- function _getBtnBuyTooltipId(crew, unit) {
  return ::g_tooltip.getIdBuyCrewSpec(crew.id, unit.name, this.code)
}

::g_crew_spec_type._getBtnBuyTooltipContent <- function _getBtnBuyTooltipContent(crew, unit) {
  let view = {
    tooltipText = ""
    tinyTooltipText = ""
  }

  if (this.isCrewTrained(crew, unit) || !this.hasPrevType()) {
    view.tooltipText = loc("crew/trained") + loc("ui/colon")
                     + colorize("activeTextColor", this.getName())
  }
  else {
    let curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    view.tooltipText = this.getReqLevelText(crew, unit)
    if (!view.tooltipText.len())
      view.tooltipText = loc("crew/qualification/buy",
                           {
                             qualify = colorize("activeTextColor", this.getName())
                             unitName = colorize("activeTextColor", getUnitName(unit))
                             cost = colorize("activeTextColor",
                                               curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, this.code).tostring())
                           })

    view.tinyTooltipText = loc("shop/crewQualifyBonuses",
                             {
                               qualification = colorize("userlogColoredText", this.getName())
                               bonuses = this.getFullBonusesText(unit?.getCrewUnitType?() ?? CUT_INVALID,
                                 curSpecType.code == -1 ? 0 : curSpecType.code) //show bonuses relatively basic spec for not trained unit
                             })
  }
  view.tooltipText += "\n\n" + loc("crew/qualification/tooltip")

  return handyman.renderCached("%gui/crew/crewUnitSpecUpgradeTooltip.tpl", view)
}

::g_crew_spec_type.template <- {
  code = -1
  specName = ""
  nextCode = -1
  icon = ""
  iconInactive = ""
  iconCanBuy = ""
  trainedIcon = ""
  expUpgradableFeature = null

  getNextType = ::g_crew_spec_type._getNextType
  isCrewTrained = ::g_crew_spec_type._isCrewTrained

  /**
   * Returns cost of upgrade to next spec type.
   */
  getUpgradeCostByCrewAndByUnit = ::g_crew_spec_type._getUpgradeCostByCrewAndByUnit
  getUpgradeCostByUnitAndExp = ::g_crew_spec_type._getUpgradeCostByUnitAndExp

  getName = ::g_crew_spec_type._getName
  hasNextType = ::g_crew_spec_type._hasNextType

  /**
   * Returns button label about next type upgrade.
   * E.g. "Upgrade qualification to Expert" for BASIC spec type.
   */
  getButtonLabel = ::g_crew_spec_type._getButtonLabel

  getDiscountTooltipByValue = ::g_crew_spec_type._getDiscountTooltipByValue
  getNameLocId = ::g_crew_spec_type._getNameLocId
  getDiscountValueByUnitNames = ::g_crew_spec_type._getDiscountValueByUnitNames

  /**
   * Returns spec type such that type.nextCode == this.code.
   * Returns UNKNOWN spec type if no such type found.
   */
  getPrevType = ::g_crew_spec_type._getPrevType

  /**
   * Returns true if this type can be upgraded from some other type.
   */
  hasPrevType = ::g_crew_spec_type._hasPrevType

  getMulValue = ::g_crew_spec_type._getMulValue
  getFullBonusesText = ::g_crew_spec_type._getFullBonusesText

  _getReqCrewLevelByCode = ::g_crew_spec_type._getReqCrewLevelByCode
  getReqCrewLevel = ::g_crew_spec_type._getReqCrewLevel
  getUpgradeReqCrewLevel = ::g_crew_spec_type._getUpgradeReqCrewLevel
  getNextMaxAvailableType = ::g_crew_spec_type._getNextMaxAvailableType

  getIcon = ::g_crew_spec_type._getIcon
  isExpUpgradableByUnit = ::g_crew_spec_type._isExpUpgradableByUnit
  getExpLeftByCrewAndUnit = ::g_crew_spec_type._getExpLeftByCrewAndUnit
  getTotalExpByUnit = ::g_crew_spec_type._getTotalExpByUnit
  getExpUpgradeDiscountData = ::g_crew_spec_type._getExpUpgradeDiscountData

  needShowExpUpgrade = ::g_crew_spec_type._needShowExpUpgrade
  getReqLevelText = ::g_crew_spec_type._getReqLevelText
  getBaseTooltipText = ::g_crew_spec_type._getBaseTooltipText
  getTooltipContent = ::g_crew_spec_type._getTooltipContent
  getBtnBuyTooltipId = ::g_crew_spec_type._getBtnBuyTooltipId
  getBtnBuyTooltipContent = ::g_crew_spec_type._getBtnBuyTooltipContent
}

enums.addTypesByGlobalName("g_crew_spec_type", {
  UNKNOWN = {
    specName    = "unknown"
    trainedIcon = "#ui/gameuiskin#spec_icon1_place.svg"
  }

  BASIC = {
    code = 0
    specName    = "spec_basic"
    nextCode    = 1
    trainedIcon = "#ui/gameuiskin#spec_icon1_can_buy.svg"
  }

  EXPERT = {
    code = 1
    specName = "spec_expert"
    nextCode = 2
    icon          = "#ui/gameuiskin#spec_icon1.svg"
    iconInactive  = "#ui/gameuiskin#spec_icon1_place.svg"
    iconCanBuy    = "#ui/gameuiskin#spec_icon1_can_buy.svg"
    trainedIcon   = "#ui/gameuiskin#spec_icon1.svg"
    expUpgradableFeature = "ExpertToAce"

    isExpUpgradableByUnit = function (unit) {
      if (this.expUpgradableFeature && !hasFeature(this.expUpgradableFeature))
        return false
      return this.getTotalExpByUnit(unit) > 0
    }

    getExpLeftByCrewAndUnit = function (crew, unit) {
      let crewId = getTblValue("id", crew)
      let unitName = getTblValue("name", unit)
      return expert_to_ace_get_unit_exp(crewId, unitName)
    }

    getTotalExpByUnit = function (unit) {
      return getTblValue("train3Cost_exp", unit) || -1
    }

    getExpUpgradeDiscountData = function () {
      let discountData = []
      if (this.expUpgradableFeature && !hasFeature(this.expUpgradableFeature))
        return discountData

      let warpointsBlk = get_warpoints_blk()
      if (warpointsBlk == null)
        return discountData

      let reduceBlk = warpointsBlk?.expert_to_ace_cost_reduce
      if (reduceBlk == null)
        return discountData

      foreach (stageBlk in reduceBlk % "stage")
        discountData.append(convertBlk(stageBlk))
      discountData.sort(function (a, b) {
        let percentA = getTblValue("percent", a, 0)
        let percentB = getTblValue("percent", b, 0)
        if (percentA != percentB)
          return percentA > percentB ? 1 : -1
        return 0
      })
      return discountData
    }
  }

  ACE = {
    code = 2
    specName = "spec_ace"
    icon          = "#ui/gameuiskin#spec_icon2.svg"
    iconInactive  = "#ui/gameuiskin#spec_icon2_place.svg"
    iconCanBuy    = "#ui/gameuiskin#spec_icon2_can_buy.svg"
    trainedIcon   = "#ui/gameuiskin#spec_icon2.svg"
  }
})

::g_crew_spec_type.types.sort(function(a, b) {
  return a.code < b.code ? -1 : (a.code > b.code ? 1 : 0)
})

::g_crew_spec_type.getTypeByCode <- function getTypeByCode(code) {
  return enums.getCachedType("code", code, ::g_crew_spec_type_cache.byCode,
    ::g_crew_spec_type, ::g_crew_spec_type.UNKNOWN)
}

::g_crew_spec_type.getTrainedSpecCode <- function getTrainedSpecCode(crew, unit) {
  if (!unit)
    return -1

  return this.getTrainedSpecCodeByUnitName(crew, unit.name)
}

::g_crew_spec_type.getTrainedSpecCodeByUnitName <- function getTrainedSpecCodeByUnitName(crew, unitName) {
  return crew?.trainedSpec?[unitName] ?? -1
}

::g_crew_spec_type.getTypeByCrewAndUnit <- function getTypeByCrewAndUnit(crew, unit) {
  let code = this.getTrainedSpecCode(crew, unit)
  return ::g_crew_spec_type.getTypeByCode(code)
}

::g_crew_spec_type.getTypeByCrewAndUnitName <- function getTypeByCrewAndUnitName(crew, unitName) {
  let code = this.getTrainedSpecCodeByUnitName(crew, unitName)
  return ::g_crew_spec_type.getTypeByCode(code)
}

::g_crew_spec_type_cache <- {
  byCode = {}
}
