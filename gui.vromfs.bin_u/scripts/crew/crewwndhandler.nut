from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { getPageStatus } = require("%scripts/crew/skillsPageStatus.nut")
let { getCrewSpText } = require("%scripts/crew/crewPointsText.nut")
let { crewSpecTypes, getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let crewSkillsPageHandler = require("%scripts/crew/crewSkillsPageHandler.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getCrewLevel, getCrewSkillCost, isCrewMaxLevel, getCrewSkillValue,
  crewSkillPages, getMaxCrewLevel } = require("%scripts/crew/crew.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { Cost } = require("%scripts/money.nut")
let { deep_clone } = require("%sqstd/underscore.nut")

const CREW_MAX_PROGRESS_BAR_VALUE = 1000

let crewHelpPageLinks = [
  { obj = "btn_apply"
    msgId = "hint_btn_apply"
  }
  { obj = "btn_buy"
    msgId = "hint_btn_buy"
  }
  { obj = "crew_cur_points_block"
    msgId = "hint_crew_cur_points_block"
  }
  { obj = "crew_pages_help"
    msgId = "hint_crew_pages_list"
  }
  { obj = "table_row_dec_buttons"
    msgId = "hint_table_row_dec_buttons"
  }
  { obj = "table_row_progressbar"
    msgId = "hint_table_row_progressbar"
  }
  { obj = "table_row_inc_buttons"
    msgId = "hint_table_row_inc_buttons"
  }
]

gui_handlers.CrewHandler <- class (gui_handlers.CrewModalHandler) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/crew/crewWndow.blk"
  slotbarNestId = "nav-slotbar"
  visibleSkillsIdx = 0

  function updateCrewInfo() {
    local text = ""
    if (this.curUnit != null && this.curUnit.getCrewUnitType() == this.curCrewUnitType) {
      text = "".concat(loc("crew/currentAircraft"), loc("ui/colon"), getUnitName(this.curUnit))
    }
    this.scene.findObject("crew-info-text").setValue(text)
  }

  updateUnitTypeRadioButtons = @() null

  function countSkills() {
    this.curPoints = ("skillPoints" in this.crew) ? this.crew.skillPoints : 0
    this.crewCurLevel = getCrewLevel(this.crew, this.curUnit, this.curCrewUnitType)
    this.crewLevelInc = getCrewLevel(this.crew, this.curUnit, this.curCrewUnitType, true) - this.crewCurLevel
    foreach (page in crewSkillPages)
      foreach (item in page.items) {
        let value = getCrewSkillValue(this.crew.id, this.curUnit, page.id, item.name)
        let newValue = item?.newValue ?? value
        if (newValue > value)
          this.curPoints -= getCrewSkillCost(item, newValue, value) 
      }
    this.updateSkillsHandlerPoints()

    let isMaxLevel = isCrewMaxLevel(this.crew, this.curUnit, this.getCurCountryName(), this.curCrewUnitType)
    this.scene.findObject("crew_cur_skills").setValue(
      isMaxLevel ? "" : round_by_value(this.crewCurLevel, 0.01).tostring())
    this.scene.findObject("crew_max_skills").setValue(
      $"{isMaxLevel ? "" : loc("ui/slash")}{getMaxCrewLevel(this.curCrewUnitType)}")

    
    this.scene.findObject("progressOld").setValue(this.getCrewLevelToProgressValue(this.crewCurLevel))
    this.updatePointsText()
    this.updateBuyAllButton()
    this.updateAvailableSkillsIcons()
  }

  function initPages() {
    this.updateDiscountInfo()

    this.pages = []
    foreach (page in crewSkillPages)
      if (page.isVisible(this.curCrewUnitType))
        this.pages.append(page)

    this.curPage = 0
    let view = {
      tabs = []
    }
    foreach (index, page in this.pages) {
      if (page.id == this.curPageId)
        this.curPage = index

      let tabData = {
        id = page.id
        tabName = loc($"crew/{page.id}")
        navImagesText = getNavigationImagesText(index, this.pages.len())
        tabImage = page?.image
        tabImageParam = "size:t='ph,ph';background-svg-size:t='ph,ph'"
        noPaddingMargin = true
      }

      if (this.isSkillsPage(page))
        tabData.cornerImg <- { cornerImg = "", cornerImgId = this.getCornerImgId(page) }

      view.tabs.append(tabData)
    }

    let pagesObj = this.scene.findObject("crew_pages_list")
    let data = handyman.renderCached("%gui/crewSkillTab.tpl", view)
    this.guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    pagesObj.setValue(this.curPage)
    this.updateAvailableSkillsIcons()
    this.updateUpgradeBlock()
  }

  function updatePointsText() {
    let isMaxLevel = isCrewMaxLevel(this.crew, this.curUnit, this.getCurCountryName(), this.curCrewUnitType)
    let curPointsText = getCrewSpText(this.curPoints)
    this.scene.findObject("crew_cur_points").setValue(isMaxLevel ? "" : curPointsText)

    local levelIncText = ""
    local levelIncTooltip = loc("crew/usedSkills/tooltip")
    if (isMaxLevel) {
      levelIncText = loc("ui/parentheses/space", { text = loc("options/quality_max") })
      levelIncTooltip = "".concat(levelIncTooltip, $"\n{loc("crew/availablePoints")}{curPointsText}")
    }
    else if (this.crewLevelInc > 0.005)
      levelIncText = $"+{round_by_value(this.crewLevelInc, 0.01)}"

    this.scene.findObject("crew_new_skills").setValue(levelIncText)
    this.scene.findObject("crew_level_block").tooltip = levelIncTooltip
    this.scene.findObject("btn_apply").enable(this.crewLevelInc > 0)
    showObjById("crew_cur_points_block", !isMaxLevel, this.scene)
    showObjById("btn_buy", hasFeature("SpendGold") && !isMaxLevel && this.crew.id != -1, this.scene)

    this.scene.findObject("progressNew").setValue(
      this.getCrewLevelToProgressValue(this.crewCurLevel + this.crewLevelInc)
    )
  }

  function getCrewLevelToProgressValue(level) {
    let progressValue =
      round_by_value(level * CREW_MAX_PROGRESS_BAR_VALUE / getMaxCrewLevel(this.curCrewUnitType), 0.01)
    return progressValue
  }

  function updatePointsAdvice() {
    let page = this.pages[this.curPage]
    let isSkills = this.isSkillsPage(page)
    let needShowAdvice = isSkills
      ? getPageStatus(this.crew, this.curUnit, page, this.curCrewUnitType, this.curPoints).needShowAdvice
      : false
    this.scene.findObject("crew_points_advice_block").show(needShowAdvice)
  }

  function updateUpgradeBlock() {
    if (this.curUnit == null)
      return

    let needShowUpgradeBlock = this.needShowUpgradeBlock()
    let upgradeBlock = showObjById("upgrade_qualification_block", needShowUpgradeBlock, this.scene)

    let crewSpecType = getSpecTypeByCrewAndUnit(this.crew, this.curUnit)
    upgradeBlock.findObject("current_qualification").setValue(
      "".concat(loc("crew/trained_current"), loc("ui/colon")))
    upgradeBlock.findObject("current_qualification_icon")["background-image"]
      = crewSpecType.trainedIcon
    upgradeBlock.findObject("current_qualification_desc").setValue(crewSpecType.getName())

    let nextSpecType = crewSpecType.getNextType()
    let levels = nextSpecType.getCurAndReqLevel(this.crew, this.curUnit)
    let isShowExpUpgrade = crewSpecType.needShowExpUpgrade(this.crew, this.curUnit) && levels.reqLevel <= levels.curLevel
    let isMaxQualification = nextSpecType == crewSpecTypes.UNKNOWN

    let progressBarDiv = showObjById("expProgressBar", isShowExpUpgrade && !isMaxQualification, upgradeBlock)
    let qualificationReqObj = showObjById("qualification_requirement", !isMaxQualification, upgradeBlock)

    let upgradeBtnObj = upgradeBlock.findObject("upgrade_button")
    upgradeBtnObj.show(!isMaxQualification)

    if (isMaxQualification)
      return

    upgradeBtnObj.visualStyle = nextSpecType.code == crewSpecTypes.EXPERT.code ? "" : "purchase"
    local crewReqLevelText = nextSpecType.getReqLevelText(this.crew, this.curUnit)

    let nextSpecTypeImg = "".concat("{{img=", nextSpecType.trainedIcon, "}}")
    if (crewReqLevelText.len() == 0) {
      let trainCostInstance = crewSpecType.getUpgradeCostByCrewAndByUnit(this.crew, this.curUnit, nextSpecType.code)
      crewReqLevelText = loc("crew/qualification/specAvailableToPurchase", {
        specName = $"{nextSpecTypeImg}{colorize("activeTextColor", nextSpecType.getName())}"
        trainCost = colorize("activeTextColor", trainCostInstance.tostring())
      })
      placePriceTextToButton(this.scene, "upgrade_button", loc("crew/qualifyIncrease"), trainCostInstance)
    }
    let bonusValueText = crewSpecType.getSkillBonusValueForNextLevel()
    if (bonusValueText.len())
      crewReqLevelText = "\n".concat(crewReqLevelText, bonusValueText)

    if (isShowExpUpgrade) {
      let earnRPtext = loc("crew/qualification/earnResearchPoints", {
        specName = $"{nextSpecTypeImg}{colorize("activeTextColor", nextSpecType.getName())}"
        rpIcon = colorize("@currencyRpColor", loc("experience/short"))
      })
      crewReqLevelText = "\n".concat(crewReqLevelText, earnRPtext)
    }

    qualificationReqObj.setValue(crewReqLevelText)

    if (!isShowExpUpgrade)
      return

    
    let unitExpLeft = crewSpecType.getExpLeftByCrewAndUnit(this.crew, this.curUnit)
    let totalUnitExp = crewSpecType.getTotalExpByUnit(this.curUnit)

    let view = {
      markers = []
      progressBarValue = (CREW_MAX_PROGRESS_BAR_VALUE * unitExpLeft / totalUnitExp).tointeger()
    }

    
    local expUpgradeText = ""
    let totalExp = crewSpecType.getTotalExpByUnit(this.curUnit)
    let discountData = crewSpecType.getExpUpgradeDiscountData()
    foreach (i, dataItem in discountData) {
      let romanNumeral = get_roman_numeral(i + 1)
      let expAmountValue = (dataItem.percent * totalExp / 100).tointeger()
      let expAmountText = Cost().setRp(expAmountValue).toStringWithParams({ isRpAlwaysShown = true })
      let trainCost = crewSpecType.getUpgradeCostByUnitAndExp(this.curUnit, expAmountValue).tostring()
      let markerView = {
        markerRatio = dataItem.percent.tofloat() / 100
        markerPriceText = trainCost
        markerRPText = expAmountText
        alignRight = true
      }
      view.markers.append(markerView)

      if (expUpgradeText.len() > 0)
        expUpgradeText = "".concat(expUpgradeText, "\n")

      let locParams = {
        romanNumeral = romanNumeral
        trainCost
        expAmount = expAmountText
      }
      expUpgradeText = "".concat(expUpgradeText, loc("crew/qualification/expUpgradeMarkerCaption", locParams))
    }

    if (expUpgradeText.len() > 0)
      expUpgradeText = "".concat(expUpgradeText, "\n")

    let romanNumeral = get_roman_numeral(view.markers.len() + 1)
    let locParams = {
      romanNumeral = romanNumeral
      specName = colorize("activeTextColor", crewSpecType.getNextType().getName())
      expAmount = Cost().setRp(crewSpecType.getTotalExpByUnit(this.curUnit)).toStringWithParams({ isRpAlwaysShown = true })
    }
    expUpgradeText = "".concat(expUpgradeText, loc("crew/qualification/expUpgradeFullUpgrade", locParams))

    view.markers.append({
      markerRatio = 1
      markerPriceText = loc("shop/free")
      markerRPText = Cost().setRp(totalExp).toStringWithParams({ isRpAlwaysShown = true })
      alignRight = true
    })

    view.markers.insert(0, {
      markerRatio = 0
      markerPriceText = crewSpecType.getUpgradeCostByUnitAndExp(this.curUnit, 0).tostring()
      markerRPText = Cost().setRp(0).toStringWithParams({ isRpAlwaysShown = true })
    })

    view.hintText <- expUpgradeText
    let content = handyman.renderCached("%gui/crew/crewUnitExpToAceProgressBar.tpl", view)
    this.guiScene.replaceContentFromText(progressBarDiv, content, content.len(), this)
  }

  function updatePage() {
    let page = this.pages[this.curPage]
    if (this.isSkillsPage(page)) {
      let skillsHandlerParams = {
        scene = this.scene.findObject("skills_table")
        curPage = page
        crew = this.crew
        curCrewUnitType = this.curCrewUnitType
        curPoints = this.curPoints
        onSkillRowChangeCb = Callback(this.onSkillRowChange, this)
        unit = this.curUnit
      }
      if (this.unitSpecHandler != null)
        this.unitSpecHandler.setHandlerVisible(false)
      if (this.skillsPageHandler == null)
        this.skillsPageHandler = crewSkillsPageHandler(skillsHandlerParams)
      else
        this.skillsPageHandler.updateHandlerData(skillsHandlerParams)
      if (this.skillsPageHandler != null)
        this.skillsPageHandler.setHandlerVisible(true)
    }
    this.updatePointsAdvice()
    showObjById("upgrade_qualification_block", this.needShowUpgradeBlock(), this.scene)
  }

  function getHelpPageLinks() {
    return deep_clone(crewHelpPageLinks)
  }

  function calcSizeForDynamicElements() {
    
    let crewPagesList = this.scene.findObject("crew_pages_list")
    let lastPageLink = crewPagesList.getChild(crewPagesList.childrenCount() - 1)
    let pageListHeight = lastPageLink.getPos()[1] + lastPageLink.getSize()[1] - crewPagesList.getPos()[1]
    let crewPagesHelpObj = this.scene.findObject("crew_pages_help")
    crewPagesHelpObj.height = $"{pageListHeight}"

    
    let page = this.pages[this.curPage]
    let skillsTable = this.scene.findObject("skills_table")
    let skillsTablePos = skillsTable.getPos()
    let maxHelptableHeight = skillsTable.getParent().getSize()[1]
    local helpTableHeight = 0
    this.visibleSkillsIdx = 0
    foreach (skill in page.items) {
      if (!skill.isVisible(this.curCrewUnitType))
        continue
      let skillObj = skillsTable.getChild(this.visibleSkillsIdx)
      if (!skillObj?.isValid())
        break
      let currHeight = skillObj.getPos()[1] + skillObj.getSize()[1] - skillsTablePos[1]
      if (currHeight > maxHelptableHeight) {
        this.visibleSkillsIdx--
        break
      }
      helpTableHeight = min(currHeight, maxHelptableHeight)
      if (this.visibleSkillsIdx == skillsTable.childrenCount() - 1)
        break
      this.visibleSkillsIdx++
    }

    let skills_help_table = this.scene.findObject("skills_help_table")
    skills_help_table.height = $"{helpTableHeight}"
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/crew/crewWindowHelp.blk"
      objContainer = this.scene.findObject("wnd_frame")
      links = this.getHelpPageLinks()
    }

    let page = this.pages[this.curPage]
    let isSkillPage = this.isSkillsPage(page)
    if (!isSkillPage)
      return res

    this.calcSizeForDynamicElements()

    let lastSkillProgressVisibleObjId = $"crewSpecs_{this.visibleSkillsIdx}"
    res.links.append({ obj = [lastSkillProgressVisibleObjId], msgId = "hint_trained" })

    let isMaxLevel = isCrewMaxLevel(this.crew, this.curUnit, this.getCurCountryName(), this.curCrewUnitType)
    if (isMaxLevel)
      return res

    res.links.append({ obj = "table_row_price", msgId = "hint_table_row_price" })
    return res
  }

  prepareHelpPage = @(_handler) null
}