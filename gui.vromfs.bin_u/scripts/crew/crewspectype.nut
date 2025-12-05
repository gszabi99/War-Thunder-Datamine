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
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getDiscountByPath } = require("%scripts/discounts/discountUtils.nut")
let { getSkillCrewLevel, getCrewMaxSkillValue, getCrewLevel, unitCrewTrainReq,
  crewSkillPages, loadCrewSkillsOnce } = require("%scripts/crew/crew.nut")

const CREW_BONUS_TO_SKILL_EXPERT = 3
const CREW_BONUS_TO_SKILL_ACE = 2

local crewSpecTypes = null

function getCrewSpecTypeByCode(code) {
  return enums.getCachedType("code", code, crewSpecTypes.cache.byCode,
    crewSpecTypes, crewSpecTypes.UNKNOWN)
}

function getTrainedSpecCodeByUnitName(crew, unitName) {
  return crew?.trainedSpec[unitName] ?? -1
}

function getTrainedCrewSpecCode(crew, unit) {
  if (!unit)
    return -1
  return getTrainedSpecCodeByUnitName(crew, unit.name)
}

function getSpecTypeByCrewAndUnit(crew, unit) {
  let code = getTrainedCrewSpecCode(crew, unit)
  return getCrewSpecTypeByCode(code)
}

function getSpecTypeByCrewAndUnitName(crew, unitName) {
  let code = getTrainedSpecCodeByUnitName(crew, unitName)
  return getCrewSpecTypeByCode(code)
}

crewSpecTypes = {
  types = []
  cache = {
    byCode = {}
  }
  template = {
    code = -1
    specName = ""
    nextCode = -1
    icon = ""
    iconInactive = ""
    iconCanBuy = ""
    trainedIcon = ""
    expUpgradableFeature = null
    nextTypeSkillBonusValue = 0 

    
    
    getButtonLabel = @() loc($"crew/qualifyIncrease{this.code}", "")
    getNextType = @() getCrewSpecTypeByCode(this.nextCode)
    isCrewTrained = @(crew, unit) getTrainedCrewSpecCode(crew, unit) >= this.code
    getName = @() loc(this.getNameLocId(), "")
    hasNextType = @() this.getNextType() != crewSpecTypes.UNKNOWN
    getNameLocId = @() format("crew/qualification/%d", this.code)

    
    hasPrevType = @() this.getPrevType() != crewSpecTypes.UNKNOWN
    isExpUpgradableByUnit = @(_unit) false
    getExpLeftByCrewAndUnit = @(_crew, _unit) -1
    getTotalExpByUnit = @(_unit) -1
    getExpUpgradeDiscountData = @() []
    needShowExpUpgrade = @(_crew, unit) this.isExpUpgradableByUnit(unit)
    getReqCrewLevel = @(unit) this._getReqCrewLevelByCode(unit, this.code - 1)
    getUpgradeReqCrewLevel = @(unit) this._getReqCrewLevelByCode(unit, this.code)

    
    function getUpgradeCostByCrewAndByUnit(crew, unit, upgradeToSpecCode = -1) {
      if (upgradeToSpecCode < 0)
        upgradeToSpecCode = this.code + 1

      let cost = Cost()
      for (local specCode = this.code; specCode < upgradeToSpecCode; specCode++) {
        cost.wp += wp_get_specialization_cost(specCode, unit.name, crew.id, -1)
        cost.gold += wp_get_specialization_cost_gold(specCode, unit.name, crew.id, -1)
      }
      return cost
    }

    function getUpgradeCostByUnitAndExp(unit, exp) {
      return Cost(
        wp_get_specialization_cost(this.code, unit.name, 0, exp),
        wp_get_specialization_cost_gold(this.code, unit.name, 0, exp))
    }

    function getDiscountTooltipByValue(discountValue) {
      if (!u.isString(discountValue))
        discountValue = discountValue.tostring()
      let locId = format("discount/%s/tooltip", this.specName)
      return format(loc(locId), discountValue)
    }

    function getDiscountValueByUnitNames(unitNames) {
      let priceBlk = get_price_blk()
      return getDiscountByPath(["aircrafts", unitNames, "specialization", this.specName], priceBlk)
    }

    
    
    function getPrevType() {
      foreach (t in crewSpecTypes.types)
        if (t.nextCode == this.code)
          return t
      return crewSpecTypes.UNKNOWN
    }

    function getMulValue(prevSpecTypeCode = 0) {
      let skillsBlk = get_skills_blk()
      local addPct = 0.0
      for (local specCode = this.code; specCode > prevSpecTypeCode; specCode--)
        addPct += skillsBlk?[format("specialization%d_add", specCode + 1)] ?? 0
      return 0.01 * addPct
    }

    function getFullBonusesText(crewUnitType, prevSpecTypeCode = -1) {
      loadCrewSkillsOnce()

      if (prevSpecTypeCode < 0)
        prevSpecTypeCode = this.code - 1
      let specMul = this.getMulValue(prevSpecTypeCode)
      let rowsArray = []
      foreach (page in crewSkillPages) {
        if (!page.isVisible(crewUnitType))
          continue

        let textsArray = []
        foreach (item in page.items)
          if (item.isVisible(crewUnitType) && item.useSpecializations) {
            let skillCrewLevel = getSkillCrewLevel(item, specMul * getCrewMaxSkillValue(item))
            let skillText =  " ".concat(loc($"crew/{item.name}"), colorize("goodTextColor",$"+{skillCrewLevel}"))
            textsArray.append(skillText.replace(" ", nbsp))
          }

        if (!textsArray.len())
          continue

        rowsArray.append("".concat(colorize("activeTextColor", loc($"crew/{page.id}")),
          loc("ui/colon"), ", ".join(textsArray, true), loc("ui/dot")))
      }
      return "\n".join(rowsArray, true)
    }

    function _getReqCrewLevelByCode(unit, upgradeFromCode) {
      loadCrewSkillsOnce()
      let crewUnitType = unit?.getCrewUnitType?() ?? CUT_INVALID
      let reqTbl = unitCrewTrainReq?[crewUnitType]
      let ranksTbl = getTblValue(upgradeFromCode, reqTbl)
      return getTblValue(unit.rank, ranksTbl, 0)
    }

    function getNextMaxAvailableType(unit, crewLevel) {
      local resType = this
      local nextType = resType.getNextType()
      while (nextType != crewSpecTypes.UNKNOWN) {
        if (nextType.getReqCrewLevel(unit) <= crewLevel)
          resType = nextType
        else
          break
        nextType = resType.getNextType()
      }
      return resType
    }

    function getIcon(crewTypeCode, crewLevel, unit) {
      if (crewTypeCode >= this.code)
        return this.icon
      if (unit && this.getReqCrewLevel(unit) <= crewLevel && crewTypeCode != -1)
        return this.iconCanBuy
      return this.iconInactive
    }

    function getSkillBonusValueForNextLevel() {
      local qualifyBonusesTotalText = ""
      let nextType = this.getNextType()
      if (nextType == crewSpecTypes.UNKNOWN)
        return qualifyBonusesTotalText

      let bonusValue = this.nextTypeSkillBonusValue
      let reqSpecLevelImg = "".concat("{{img=", nextType.trainedIcon, "}}")
      qualifyBonusesTotalText = loc("crew/qualifyBonuses/total", {
        wantedQualify = "".concat(reqSpecLevelImg, colorize("activeTextColor", nextType.getName()))
        bonusValue = colorize("goodTextColor", $"+{bonusValue}")
      })
      return qualifyBonusesTotalText
    }

    function getReqLevelText(crew, unit) {
      let res = []
      let levels = this.getCurAndReqLevel(crew, unit)
      let reqLevel = levels.reqLevel
      let crewLevel = levels.curLevel

      let reqSpecLevelImg = "".concat("{{img=", this.trainedIcon, "}}")
      let wantedQualify = hasFeature("FullScreenCrewWindow") ? "".concat(reqSpecLevelImg, this.getName())
        : colorize("activeTextColor", this.getName())
      let locParams = {
        wantedQualify
        unitName = colorize("activeTextColor", getUnitName(unit))
      }

      let curSpecType = getSpecTypeByCrewAndUnit(crew, unit)
      let needToTrainUnit = curSpecType == crewSpecTypes.UNKNOWN
      if (needToTrainUnit)
        res.append(colorize("badTextColor", loc("crew/qualifyRequirement/toTrainUnit", locParams)))

      if (reqLevel > crewLevel && reqLevel > 1) {
        if (hasFeature("FullScreenCrewWindow")) {
          let reqLevelLocId = needToTrainUnit ? "crew/qualifyRequirement"
            : "crew/qualifyRequirement/need_level"
          res.append(loc(reqLevelLocId, locParams.__merge({
            reqLevel
            currentLevelText = colorize("badTextColor", loc("crew/currentLevel", { level = crewLevel }))
            trainCost = curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, this.code)
          })))
        }
        else {
          let reqLevelLocId = needToTrainUnit ? "crew/qualifyRequirement" : "crew/qualifyRequirement/full"
          res.append(colorize("badTextColor", loc(reqLevelLocId, locParams.__merge({
            reqLevel = colorize("activeTextColor", reqLevel)
          }))))
        }
      }
      return "\n".join(res, true)
    }

    function getBaseTooltipText(crew, unit) {
      local tooltipText = loc("crew/qualification/tooltip")
      let isShowExpUpgrade = this.needShowExpUpgrade(crew, unit)
      let nextType = this.getNextType()
      if (nextType != crewSpecTypes.UNKNOWN) {
        let nextSpecName = nextType.getName()
        tooltipText = "".concat(tooltipText, "\n\n",
          loc("crew/qualification/nextSpec"), ": ", colorize("activeTextColor", nextSpecName))
        let reqLevelText = nextType.getReqLevelText(crew, unit)
        if (reqLevelText.len())
          tooltipText = "\n".concat(tooltipText, reqLevelText)
        else {
          let specDescriptionPart = isShowExpUpgrade
            ? loc("crew/qualification/specDescriptionPart", {
                expAmount = Cost().setRp(this.getTotalExpByUnit(unit)).tostring()
              })
            : ""
          let specDescription = loc(
            "crew/qualification/specDescriptionMain", {
              specName = colorize("activeTextColor", nextSpecName)
              trainCost = this.getUpgradeCostByCrewAndByUnit(crew, unit).tostring()
              descPart = specDescriptionPart
            })
          tooltipText = "\n".concat(tooltipText, specDescription)
        }
      }
      if (isShowExpUpgrade)
        tooltipText = "".concat(tooltipText, "\n",
          loc("crew/qualification/expUpgradeLabel"), ": ",
          Cost().setRp(this.getExpLeftByCrewAndUnit(crew, unit)).toStringWithParams({ isRpAlwaysShown = true }),
          " / ", Cost().setRp(this.getTotalExpByUnit(unit)).tostring())

      return tooltipText
    }

    function getTooltipContent(crew, unit) {
      let progressBarValue = 1000 * this.getExpLeftByCrewAndUnit(crew, unit)
        / this.getTotalExpByUnit(unit)
      let view = {
        tooltipText = this.getBaseTooltipText(crew, unit)
        hasExpUpgrade = this.needShowExpUpgrade(crew, unit)
        markers = []
        progressBarValue = progressBarValue.tointeger()
      }

      
      let expUpgradeText = []
      let totalExp = this.getTotalExpByUnit(unit)
      foreach (i, dataItem in this.getExpUpgradeDiscountData()) {
        let romanNumeral = get_roman_numeral(i + 1)
        let markerView = {
          markerRatio = dataItem.percent.tofloat() / 100
          markerText = romanNumeral
        }
        view.markers.append(markerView)

        let expAmount = (dataItem.percent * totalExp / 100).tointeger()
        let trainCost = this.getUpgradeCostByUnitAndExp(unit, expAmount)
        let locParams = {
          romanNumeral = romanNumeral
          trainCost = trainCost.tostring()
          expAmount = Cost().setRp(expAmount).toStringWithParams({ isRpAlwaysShown = true })
        }
        expUpgradeText.append(loc("crew/qualification/expUpgradeMarkerCaption", locParams))
      }

      
      let romanNumeral = get_roman_numeral(view.markers.len() + 1)
      view.markers.append({
        markerRatio = 1
        markerText = romanNumeral
      })
      let locParams = {
        romanNumeral = romanNumeral
        specName = colorize("activeTextColor", this.getNextType().getName())
        expAmount = Cost().setRp(this.getTotalExpByUnit(unit)).toStringWithParams({ isRpAlwaysShown = true })
      }
      expUpgradeText.append(loc("crew/qualification/expUpgradeFullUpgrade", locParams))

      view.expUpgradeText <- "\n".join(expUpgradeText)

      return handyman.renderCached("%gui/crew/crewUnitSpecUpgradeTooltip.tpl", view)
    }

    function getBtnBuyTooltipId(crew, unit) {
      return getTooltipType("BUY_CREW_SPEC").getTooltipId(crew.id, unit.name, this.code)
    }

    function getBtnBuyTooltipContent(crew, unit) {
      let view = {
        tooltipText = ""
        tinyTooltipText = ""
      }

      if (this.isCrewTrained(crew, unit) || !this.hasPrevType()) {
        view.tooltipText = "".concat(loc("crew/trained"), loc("ui/colon"),
          colorize("activeTextColor", this.getName()))
      }
      else {
        let curSpecType = getSpecTypeByCrewAndUnit(crew, unit)
        view.tooltipText = this.getReqLevelText(crew, unit)
        if (!view.tooltipText.len())
          view.tooltipText = loc("crew/qualification/buy", {
            qualify = colorize("activeTextColor", this.getName())
            unitName = colorize("activeTextColor", getUnitName(unit))
            cost = colorize("activeTextColor",
              curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, this.code).tostring())
          })

        view.tinyTooltipText = loc("shop/crewQualifyBonuses", {
          qualification = colorize("userlogColoredText", this.getName())
          bonuses = this.getFullBonusesText(unit?.getCrewUnitType?() ?? CUT_INVALID,
            curSpecType.code == -1 ? 0 : curSpecType.code) 
        })
      }
      view.tooltipText = "\n\n".concat(view.tooltipText, loc("crew/qualification/tooltip"))

      return handyman.renderCached("%gui/crew/crewUnitSpecUpgradeTooltip.tpl", view)
    }

    function getCurAndReqLevel(crew, unit) {
      let reqLevel = this.getReqCrewLevel(unit)
      let curLevel = getCrewLevel(crew, unit, unit?.getCrewUnitType?() ?? CUT_INVALID)
      return {reqLevel, curLevel}
    }
  }
}

enums.addTypes(crewSpecTypes, {
  UNKNOWN = {
    specName    = "unknown"
    trainedIcon = "#ui/gameuiskin#spec_icon1_place.svg"
  }

  BASIC = {
    code        = 0
    specName    = "spec_basic"
    nextCode    = 1
    trainedIcon = "#ui/gameuiskin#spec_icon1_can_buy.svg"
    nextTypeSkillBonusValue = CREW_BONUS_TO_SKILL_EXPERT
  }

  EXPERT = {
    code                 = 1
    specName             = "spec_expert"
    nextCode             = 2
    icon                 = "#ui/gameuiskin#spec_icon1.svg"
    iconInactive         = "#ui/gameuiskin#spec_icon1_place.svg"
    iconCanBuy           = "#ui/gameuiskin#spec_icon1_can_buy.svg"
    trainedIcon          = "#ui/gameuiskin#spec_icon1.svg"
    expUpgradableFeature = "ExpertToAce"
    nextTypeSkillBonusValue = CREW_BONUS_TO_SKILL_ACE

    function isExpUpgradableByUnit(unit) {
      if (this.expUpgradableFeature && !hasFeature(this.expUpgradableFeature))
        return false
      return this.getTotalExpByUnit(unit) > 0
    }

    function getExpLeftByCrewAndUnit(crew, unit) {
      let crewId = getTblValue("id", crew)
      let unitName = getTblValue("name", unit)
      return expert_to_ace_get_unit_exp(crewId, unitName)
    }

    function getTotalExpByUnit(unit) {
      let costExp = unit?.train3Cost_exp ?? -1
      return costExp != 0 ? costExp : -1
    }

    function getExpUpgradeDiscountData() {
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
    code         = 2
    specName     = "spec_ace"
    icon         = "#ui/gameuiskin#spec_icon2.svg"
    iconInactive = "#ui/gameuiskin#spec_icon2_place.svg"
    iconCanBuy   = "#ui/gameuiskin#spec_icon2_can_buy.svg"
    trainedIcon  = "#ui/gameuiskin#spec_icon2.svg"
  }
})

crewSpecTypes.types.sort(@(a, b) a.code <=> b.code)

return {
  crewSpecTypes
  getCrewSpecTypeByCode
  getTrainedCrewSpecCode
  getSpecTypeByCrewAndUnit
  getSpecTypeByCrewAndUnitName
}