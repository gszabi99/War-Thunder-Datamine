from "%scripts/dagui_natives.nut" import get_cur_warpoints, shop_upgrade_crew
from "%scripts/dagui_library.nut" import *
from "%scripts/crew/skillsPageStatus.nut" import g_skills_page_status

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let stdMath = require("%sqstd/math.nut")
let crewSkillsPageHandler = require("%scripts/crew/crewSkillsPageHandler.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopUnitsInfo.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { scene_msg_boxes_list } = require("%sqDagui/framework/msgBox.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getCrewSpText } = require("%scripts/crew/crewPointsText.nut")
let { addTask } = require("%scripts/tasker.nut")
let { updateHintPosition } = require("%scripts/help/helpInfoHandlerModal.nut")
let { upgradeUnitSpec } = require("%scripts/crew/crewActionsWithMsgBox.nut")
let { Cost } = require("%scripts/money.nut")
let { showCurBonus } = require("%scripts/bonusModule.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { isAllCrewsMinLevel, getCrewName, getCrewLevel,
  getCrewSkillNewValue, getCrewSkillCost, getSkillCrewLevel, isCrewMaxLevel,
  getCrewSkillPointsToMaxAllSkills, buyAllCrewSkills, createCrewUnitSpecHandler,
  createCrewBuyPointsHandler, getCrewUnit, getCrew, getCrewSkillValue, crewSkillPages,
  loadCrewSkills
} = require("%scripts/crew/crew.nut")
let { crewSpecTypes, getSpecTypeByCrewAndUnit, getSpecTypeByCrewAndUnitName
} = require("%scripts/crew/crewSpecType.nut")
let { getCrewDiscountInfo, getCrewMaxDiscountByInfo, getCrewDiscountsTooltipByInfo
} = require("%scripts/crew/crewDiscount.nut")
let { flushSlotbarUpdate, suspendSlotbarUpdates, getCrewsList
} = require("%scripts/slotbar/crewsList.nut")

::gui_modal_crew <- function gui_modal_crew(params = {}) {
  if (hasFeature("CrewSkills"))
    loadHandler(gui_handlers.CrewModalHandler, params)
  else
    showInfoMsgBox(loc("msgbox/notAvailbleYet"))
}

function isAllCrewsHasBasicSpec() {
  let basicCrewSpecType = crewSpecTypes.BASIC
  foreach (checkedCountrys in getCrewsList())
    foreach (crew in checkedCountrys.crews)
      foreach (unitName, _value in crew.trainedSpec) {
        let crewUnitSpecType = getSpecTypeByCrewAndUnitName(crew, unitName)
        if (crewUnitSpecType != basicCrewSpecType)
          return false
      }

  return true
}

gui_handlers.CrewModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/crew/crew.blk"

  slotbarActions = ["aircraft", "sec_weapons", "weapons", "showroom", "repair" ]

  countryId = -1
  idInCountry = -1
  showTutorial = false
  crew = null
  curCrewUnitType = CUT_INVALID
  curPage = 0
  curPageId = null
  pageBonuses = 0

  pages = null
  airList = null

  crewCurLevel = 0
  crewLevelInc = 0
  curPoints = 0

  discountInfo = null

  afterApplyAction = null
  updateAfterApplyAction = true

  unitSpecHandler = null
  skillsPageHandler = null
  curEdiff = -1

  curUnit = null
  isCrewUpgradeInProgress = false

  function initScreen() {
    if (!this.scene)
      return this.goBack()
    this.crew = this.getSlotCrew()
    if (!this.crew)
      return this.goBack()

    let country = getCrewsList()?[this.countryId].country
    if (country)
      switchProfileCountry(country)

    this.initMainParams(true, true)

    if (this.showTutorial)
      this.onUpgrCrewSkillsTutorial()
    else if (!loadLocalByAccount("upgradeCrewSpecTutorialPassed", false)
          && !isAllCrewsMinLevel()
          && isAllCrewsHasBasicSpec()
          && this.canUpgradeCrewSpec(this.crew))
      this.onUpgrCrewSpec1Tutorial()

    this.alignWndIfSlotbarOverlapping()
    this.createSlotbar({
      emptyText = "#shop/aircraftNotSelected",
      beforeSlotbarSelect = @(onOk, onCancel, _slotData) this.checkSkillPointsAndDo(onOk, onCancel)
      afterSlotbarSelect = this.openSelectedCrew
      onSlotDblClick = this.onSlotDblClick
    }.__update(this.getSlotbarParams()))
  }

  function alignWndIfSlotbarOverlapping() {
    let wnd = this.scene.findObject("wnd_frame")
    let size = wnd.getSize()
    let pos = wnd.getPos()
    let slotBarPosY = to_pixels("sh-1@slotbarOffset-1@slotbarTop-1@slotbarHeight")
    let isOverlappingSlotbar = pos[1] + size[1] >= slotBarPosY

    if (isOverlappingSlotbar) {
      let topMarginFotCornerImgs = "2@blockInterval"
      let topPos = $"1@titleLogoPlateHeight+{topMarginFotCornerImgs}+1@bh"
      let bottomMargin ="1@blockInterval"
      wnd.pos = $"{pos[0]}, {topPos}"
      wnd.height = slotBarPosY - to_pixels($"{topPos}+{bottomMargin}")
    }
  }

  getSlotbarParams = @() {
    crewId = this.crew.id
    showNewSlot = false
  }

  function updateCrewInfo() {
    local text = ""
    if (this.curUnit != null && this.curUnit.getCrewUnitType() == this.curCrewUnitType) {
      text = loc("ui/comma").concat(
        "".concat(loc("crew/currentAircraft"), loc("ui/colon"), colorize("activeTextColor", getUnitName(this.curUnit)))
        "".concat(loc("crew/totalCrew"), loc("ui/colon"), colorize("activeTextColor", this.curUnit.getCrewTotalCount()))
      )
      if (this.curUnit.unitType.hasAiGunners && (this.curUnit?.gunnersCount ?? 0) > 0)
        text = "".concat(text, "\n", loc("crew/numDefensiveArmamentTurrets"), loc("ui/colon"),
          colorize("activeTextColor", this.curUnit.gunnersCount))
    }
    this.scene.findObject("crew-info-text").setValue(text)
  }

  function initMainParams(reloadSkills = true, reinitUnitType = false) {
    if (!this.scene?.isValid())
      return

    this.curUnit = this.getCurCrewUnit(this.crew)
    this.curCrewUnitType = reinitUnitType ? (this.curUnit?.getCrewUnitType?() ?? this.curCrewUnitType) : this.curCrewUnitType

    ::update_gamercards()
    if (reloadSkills)
      loadCrewSkills()

    this.scene.findObject("crew_name").setValue(getCrewName(this.crew))

    this.updateUnitTypeRadioButtons()
    this.updateButtons()
  }

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
    this.scene.findObject("crew_cur_skills").setValue(stdMath.round_by_value(this.crewCurLevel, 0.01).tostring())
    this.updatePointsText()
    this.updateBuyAllButton()
    this.updateAvailableSkillsIcons()
  }

  function onSkillRowChange(item, newValue) {
    let wasValue = getCrewSkillNewValue(item, this.crew, this.curUnit)
    let changeCost = getCrewSkillCost(item, newValue, wasValue)
    let crewLevelChange = getSkillCrewLevel(item, newValue, wasValue)
    item.newValue <- newValue //!!FIX ME: this code must be in g_crew too
    this.curPoints -= changeCost
    this.updateSkillsHandlerPoints()
    this.crewLevelInc += crewLevelChange

    this.updatePointsText()
    this.updateBuyAllButton()
    this.updatePointsAdvice()
    this.updateAvailableSkillsIcons()
    broadcastEvent("CrewNewSkillsChanged", { crew = this.crew })
  }

  function getCurCountryName() {
    return getCrewsList()[this.countryId].country
  }

  function updateUnitTypeRadioButtons() {
    let rbObj = this.scene.findObject("rb_unit_type")
    if (!rbObj?.isValid())
      return

    local data = ""
    let crewUnitTypes = []
    local isVisibleCurCrewTypeButton = false
    foreach (unitType in unitTypes.types) {
      if (!unitType.isVisibleInShop())
        continue

      let crewUnitType = unitType.crewUnitType
      if (isInArray(crewUnitType, crewUnitTypes))
        continue

      if (!isCountryHaveUnitType(this.getCurCountryName(), unitType.esUnitType))
        continue

      crewUnitTypes.append(crewUnitType)
      let isCurrent = this.curCrewUnitType == crewUnitType
      isVisibleCurCrewTypeButton = isVisibleCurCrewTypeButton || isCurrent
      data = "".concat(
        data,
        format(
          "RadioButton { id:t='%s'; text:t='%s'; %s RadioButtonImg{} }",
          $"unit_type_{crewUnitType}",
          unitType.getCrewArmyLocName(),
          isCurrent ? "selected:t='yes';" : ""
        )
      )
    }
    this.guiScene.replaceContentFromText(rbObj, data, data.len(), this)
    if (!isVisibleCurCrewTypeButton) //need switch unit type if cur type not visible
      rbObj.setValue(0)
    this.updateUnitType()
  }

  function updateUnitType() {
    this.countSkills()
    this.updateCrewInfo()
    this.initPages()
  }

  function initPages() {
    this.updateDiscountInfo()

    this.pages = []
    foreach (page in crewSkillPages)
      if (page.isVisible(this.curCrewUnitType))
        this.pages.append(page)
    this.pages.append({ id = "trained" })

    let maxDiscount = getCrewMaxDiscountByInfo(this.discountInfo, false)
    let discountText = maxDiscount > 0 ? ($"-{maxDiscount}%") : ""
    let discountTooltip = getCrewDiscountsTooltipByInfo(this.discountInfo, false)

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
        navImagesText = ::get_navigation_images_text(index, this.pages.len())
      }

      if (this.isSkillsPage(page))
        tabData.cornerImg <- {
          cornerImg = ""
          cornerImgId = this.getCornerImgId(page)
        }
      else if (page.id == "trained")
        tabData.discount <- {
          text = discountText
          tooltip = discountTooltip
        }

      view.tabs.append(tabData)
    }
    let pagesObj = this.scene.findObject("crew_pages_list")
    pagesObj.smallFont = this.needSmallerHeaderFont(pagesObj.getSize(), view.tabs) ? "yes" : "no"
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    pagesObj.setValue(this.curPage)
    this.updateAvailableSkillsIcons()
    this.updateUpgradeBlock()
  }

  function needSmallerHeaderFont(targetSize, viewTabs) {
    local width = 0
    foreach (tab in viewTabs)
      width += daguiFonts.getStringWidthPx(tab.tabName, "fontNormal", this.guiScene)

    width += viewTabs.len() * to_pixels("2@listboxHPadding + 1@listboxItemsInterval")
    if (showConsoleButtons.value)
      width += 2 * targetSize[1] //gamepad navigation icons width = ph

    return width > targetSize[0]
  }

  function onChangeUnitType(obj) {
    this.curCrewUnitType = obj.getValue()
    this.updateUnitType()
  }

  function onCrewPage(obj) {
    if (!obj)
      return
    let value = obj.getValue()
    if (value in this.pages) {
      this.curPage = value
      this.curPageId = obj.getChild(value).id
      this.fillPage()
    }
  }

  function getCrewSkillTooltipLocId(skillName, pageName) {
    return $"crew/{pageName}/{skillName}/tooltip"
  }

  function isSkillsPage(page) {
    return "items" in page
  }

  function fillPage() {
    this.updatePage()
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
      levelIncText = $"+{stdMath.round_by_value(this.crewLevelInc, 0.01)}"

    this.scene.findObject("crew_new_skills").setValue(levelIncText)
    this.scene.findObject("crew_level_block").tooltip = levelIncTooltip
    this.scene.findObject("btn_apply").enable(this.crewLevelInc > 0)
    showObjById("crew_cur_points_block", !isMaxLevel, this.scene)
    showObjById("btn_buy", hasFeature("SpendGold") && !isMaxLevel && this.crew.id != -1, this.scene)
  }

  function updatePointsAdvice() {
    let page = this.pages[this.curPage]
    let isSkills = this.isSkillsPage(page)
    this.scene.findObject("crew_points_advice_block").show(isSkills)
    if (!isSkills)
      return
    let statusType = g_skills_page_status.getPageStatus(this.crew, this.curUnit, page, this.curCrewUnitType, this.curPoints)
    this.scene.findObject("crew_points_advice").show(statusType.show)
    this.scene.findObject("crew_points_advice_text")["crewStatus"] = statusType.style
  }

  function updateBuyAllButton() {
    if (!hasFeature("CrewBuyAllSkills"))
      return

    let totalPointsToMax = getCrewSkillPointsToMaxAllSkills(this.crew, this.curUnit, this.curCrewUnitType)
    showObjById("btn_buy_all", totalPointsToMax > 0 && this.crew.id != -1, this.scene)
    let text = loc("mainmenu/btnBuyAll") + loc("ui/parentheses/space", { text = getCrewSpText(totalPointsToMax) })
    setColoredDoubleTextToButton(this.scene, "btn_buy_all", text)
  }


  function needShowUpgradeBlock() {
    return this.curUnit != null && this.isSkillsPage(this.pages[this.curPage])
      && this.curUnit.getCrewUnitType() == this.curCrewUnitType
  }


  function updateUpgradeBlock() {
    if (this.curUnit == null)
      return

    let needShowUpgradeBlock = this.needShowUpgradeBlock()
    let upgradeBlock = showObjById("upgrade_qualification_block", needShowUpgradeBlock, this.scene)

    let crewSpecType = getSpecTypeByCrewAndUnit(this.crew, this.curUnit)
    upgradeBlock.findObject("current_qualification").setValue( "".concat(loc("crew/trained"), $": {crewSpecType.getName()}"))

    let nextSpecType = crewSpecType.getNextType()
    let levels = nextSpecType.getCurAndReqLevel(this.crew, this.curUnit)
    let isShowExpUpgrade = crewSpecType.needShowExpUpgrade(this.crew, this.curUnit) && levels.reqLevel <= levels.curLevel
    let isMaxQualification = nextSpecType == crewSpecTypes.UNKNOWN

    let progressBarDiv = showObjById("expProgressBar", isShowExpUpgrade && !isMaxQualification, upgradeBlock)
    let expTextObj = showObjById("expText", isShowExpUpgrade && !isMaxQualification, upgradeBlock)
    let qualificationReqObj = showObjById("qualification_requirement", !isMaxQualification, upgradeBlock)
    showObjById("upgrade_button", !isMaxQualification, upgradeBlock)

    if (isMaxQualification)
      return

    let inactiveIcon = levels.reqLevel > levels.curLevel ? "_place" : ""

    if (nextSpecType.code == crewSpecTypes.EXPERT.code) {
      upgradeBlock.findObject("upgrade_button").visualStyle = ""
      upgradeBlock.findObject("upgrade_button_icon")["background-image"] = $"#ui/gameuiskin#spec_icon1{inactiveIcon}.svg"
    } else {
      upgradeBlock.findObject("upgrade_button").visualStyle = "purchase"
      upgradeBlock.findObject("upgrade_button_icon")["background-image"] = $"#ui/gameuiskin#spec_icon2{inactiveIcon}.svg"
    }

    local crewLvlText = nextSpecType.getReqLevelText(this.crew, this.curUnit)
    if (crewLvlText.len() == 0) {
      let specDescriptionPart = isShowExpUpgrade ?
        loc("crew/qualification/specDescriptionPart", {
          expAmount = Cost().setRp(crewSpecType.getTotalExpByUnit(this.curUnit)).tostring()
        })
        : ""

      crewLvlText = loc("crew/qualification/specDescriptionMain",
        {
         specName = colorize("activeTextColor", nextSpecType.getName())
         descPart = specDescriptionPart
         trainCost = colorize("activeTextColor",
           crewSpecType.getUpgradeCostByCrewAndByUnit(this.crew, this.curUnit, nextSpecType.code).tostring())
        })
    }
    qualificationReqObj.setValue(crewLvlText)

    if (!isShowExpUpgrade)
      return

    //Exp ProgressBar
    let unitExpLeft = crewSpecType.getExpLeftByCrewAndUnit(this.crew, this.curUnit)
    let totalUnitExp = crewSpecType.getTotalExpByUnit(this.curUnit)

    let view = {
      markers = []
      progressBarValue = (1000 * unitExpLeft / totalUnitExp).tointeger()
    }

    //Exp ProgressBar discount markers.
    expTextObj.setValue(
      format( "%s: %s / %s",
        loc("crew/qualification/expUpgradeLabel"),
        Cost().setRp(unitExpLeft).toStringWithParams({ isRpAlwaysShown = true }),
        Cost().setRp(totalUnitExp).tostring()
      )
    )

    local expUpgradeText = ""
    let totalExp = crewSpecType.getTotalExpByUnit(this.curUnit)
    let discountData = crewSpecType.getExpUpgradeDiscountData()
    foreach (i, dataItem in discountData) {
      let romanNumeral = get_roman_numeral(i + 1)
      let markerView = {
        markerRatio = dataItem.percent.tofloat() / 100
        markerText = romanNumeral
      }
      view.markers.append(markerView)

      if (expUpgradeText.len() > 0)
        expUpgradeText = "".concat(expUpgradeText, "\n")
      let expAmount = (dataItem.percent * totalExp / 100).tointeger()
      let trainCost = crewSpecType.getUpgradeCostByUnitAndExp(this.curUnit, expAmount)
      let locParams = {
        romanNumeral = romanNumeral
        trainCost = trainCost.tostring()
        expAmount = Cost().setRp(expAmount).toStringWithParams({ isRpAlwaysShown = true })
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
      markerText = romanNumeral
    })

    view.hintText <- expUpgradeText
    let content = handyman.renderCached("%gui/crew/crewUnitExpBar.tpl", view)
    this.guiScene.replaceContentFromText(progressBarDiv, content, content.len(), this)
  }

  function onSpecIncreaseBtn() {
    let crewSpecType = getSpecTypeByCrewAndUnit(this.crew, this.curUnit)
    let nextSpecType = crewSpecType.getNextType()
    upgradeUnitSpec(this.crew, this.curUnit, this.curCrewUnitType, nextSpecType)
  }

  function onBuyAll() {
    buyAllCrewSkills(this.crew, this.curUnit, this.curCrewUnitType)
  }

  function getCornerImgId(page) {
    return $"{page.id}_available"
  }

  function updateAvailableSkillsIcons() {
    if (!this.pages)
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let pagesObj = this.scene.findObject("crew_pages_list")
    foreach (page in this.pages) {
      if (!this.isSkillsPage(page))
        continue
      let obj = pagesObj.findObject(this.getCornerImgId(page))
      if (!obj?.isValid())
        continue

      let statusType = g_skills_page_status.getPageStatus(
        this.crew, this.curUnit, page, this.curCrewUnitType, this.curPoints)
      obj["background-image"] = statusType.icon
      obj["background-color"] = this.guiScene.getConstantValue(statusType.color) || ""
      obj.wink = statusType.wink ? "yes" : "no"
      obj.show(statusType.show)
    }
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateDiscountInfo() {
    this.discountInfo = getCrewDiscountInfo(this.countryId, this.idInCountry)
    this.updateAirList()

    let obj = this.scene.findObject("buyPoints_discount")
    let buyPointsDiscount = this.discountInfo?.buyPoints ?? 0
    showCurBonus(obj, buyPointsDiscount, "buyPoints", true, true)
  }

  function updateAirList() {
    this.airList = []
    if (!("trainedSpec" in this.crew))
      return

    let sortData = [] // { unit, locname }
    foreach (unit in getAllUnits())
      if (unit.name in this.crew.trainedSpec && unit.getCrewUnitType() == this.curCrewUnitType) {
        let isCurrent = (this.crew?.aircraft ?? "") == unit.name
        if (isCurrent)
          this.airList.append(unit)
        else {
          sortData.append({
            unit = unit
            locname = utf8ToLower(getUnitName(unit))
          })
        }
      }

    sortData.sort(function(a, b) {
      return a.locname > b.locname ? 1 : (a.locname < b.locname ? -1 : 0)
    })

    foreach (data in sortData)
      this.airList.append(data.unit)
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
    else if (page.id == "trained") {
      if (this.skillsPageHandler != null)
        this.skillsPageHandler.setHandlerVisible(false)
      if (this.unitSpecHandler == null)
        this.unitSpecHandler = createCrewUnitSpecHandler(this.scene)
      if (this.unitSpecHandler != null) {
        this.unitSpecHandler.setHandlerVisible(true)
        this.unitSpecHandler.setHandlerData(this.crew, this.crewCurLevel, this.airList, this.curCrewUnitType)
      }
    }
    this.updatePointsAdvice()
    this.updateUnitTypeWarning(this.isSkillsPage(page))
    showObjById("upgrade_qualification_block", this.needShowUpgradeBlock(), this.scene)
  }

  function updateUnitTypeWarning(skillsVisible) {
    local show = false
    if (skillsVisible)
      show = this.curUnit != null && this.curUnit.getCrewUnitType() != this.curCrewUnitType
    this.scene.findObject("skills_unit_type_warning").show(show)
  }

  function onBuyPoints() {
    if (!this.scene?.isValid())
      return

    this.updateDiscountInfo()
    createCrewBuyPointsHandler(this.crew)
  }

  function goBack() {
    this.checkSkillPointsAndDo(base.goBack)
  }

  function onEventSetInQueue(_params) {
    base.goBack()
  }

  function onApply() {
    if (this.progressBox)
      return

    let blk = DataBlock()
    foreach (page in crewSkillPages)
      if (this.isSkillsPage(page)) {
        let typeBlk = DataBlock()
        foreach (_idx, item in page.items)
          if ("newValue" in item) {
            let value = getCrewSkillValue(this.crew.id, this.curUnit, page.id, item.name)
            if (value < item.newValue)
              typeBlk[item.name] = item.newValue - value
          }
        blk[page.id] = typeBlk
      }

    let curHandler = this //to prevent handler destroy even when invalid.
    let isTaskCreated = addTask(
      shop_upgrade_crew(this.crew.id, blk),
      { showProgressBox = true },
      function() {
        curHandler.isCrewUpgradeInProgress = false
        broadcastEvent("CrewSkillsChanged",
          { crew = curHandler.crew, unit = curHandler.curUnit })
        if (curHandler.isValid() && curHandler.afterApplyAction) {
          curHandler.afterApplyAction()
          curHandler.afterApplyAction = null
        }
        flushSlotbarUpdate()
      },
      function(_err) {
        curHandler.isCrewUpgradeInProgress = false
        flushSlotbarUpdate()
      }
    )

    if (isTaskCreated) {
      this.isCrewUpgradeInProgress = true
      suspendSlotbarUpdates()
    }
  }

  function onSelect() {
    this.onApply()
  }

  function checkSkillPointsAndDo(action, cancelAction = function() {}, updateAfterApply = true) {
    if (this.isCrewUpgradeInProgress)
      return

    let crewPoints = this.crew?.skillPoints ?? 0
    if (this.curPoints == crewPoints)
      return action()

    let msgOptions = [
      ["yes", function() {
        this.afterApplyAction = action
        this.updateAfterApplyAction = updateAfterApply
        this.onApply()
      }],
      ["no", action]
    ]

    this.msgBox("applySkills", loc("crew/applySkills"), msgOptions, "yes", {
      cancel_fn = cancelAction
      checkDuplicateId = true
    })
  }

  function baseGoForward(startFunc, needFade) {
    base.goForward(startFunc, needFade)
  }

  function goForward(startFunc, needFade = true) {
    this.checkSkillPointsAndDo(Callback(@() this.baseGoForward(startFunc, needFade), this))
  }

  function onSlotDblClick(_slotCrew) {
    if (this.curUnit != null)
      this.checkSkillPointsAndDo(@() ::open_weapons_for_unit(this.curUnit))
  }

  function beforeSlotbarChange(action, cancelAction) {
    this.checkSkillPointsAndDo(action, cancelAction)
  }

  function openSelectedCrew() {
    let newCrew = this.getCurCrew()
    if (!newCrew)
      return

    this.crew = newCrew
    this.countryId = this.crew.idCountry
    this.idInCountry = this.crew.idInCountry
    this.initMainParams(true, true)
  }

  function onUpgrCrewSkillsTutorial() {
    let steps = [
      {
        obj = ["crew_cur_points_block"]
        text = loc("tutorials/upg_crew/total_skill_points")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = [["crew_pages_list", "driver_available"]]
        text = loc("tutorials/upg_crew/skill_groups")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = [this.getObj("skill_row0").findObject("incCost"), "skill_row0"]
        text = loc("tutorials/upg_crew/take_skill_points")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      },
      {
        obj = [this.getObj("skill_row0").findObject("buttonInc"), "skill_row0"]
        text = loc("tutorials/upg_crew/inc_skills")
        actionType = tutorAction.FIRST_OBJ_CLICK
        nextActionShortcut = "help/OBJ_CLICK"
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(@() this.onButtonInc(this.getObj("skill_row0").findObject("buttonInc")), this)
      },
      {
        obj = [this.getObj("skill_row1").findObject("buttonInc"), "skill_row1"]
        text = loc("tutorials/upg_crew/inc_skills")
        actionType = tutorAction.FIRST_OBJ_CLICK
        nextActionShortcut = "help/OBJ_CLICK"
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(@() this.onButtonInc(this.getObj("skill_row1").findObject("buttonInc")), this)
      },
      {
        obj = ["btn_apply"]
        text = loc("tutorials/upg_crew/apply_upgr_skills")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(function() {
          this.afterApplyAction = this.canUpgradeCrewSpec(this.crew) ? this.onUpgrCrewSpec1Tutorial
            : this.onUpgrCrewTutorFinalStep
          this.onApply() }, this)
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function canUpgradeCrewSpec(upgCrew) {
    if (this.curUnit == null)
      return false

    let curSpecType = getSpecTypeByCrewAndUnit(upgCrew, this.curUnit)
    let wpSpecCost = curSpecType.getUpgradeCostByCrewAndByUnit(upgCrew, this.curUnit)
    let reqLevel = curSpecType.getUpgradeReqCrewLevel(this.curUnit)
    let crewLevel = getCrewLevel(upgCrew, this.curUnit, this.curUnit.getCrewUnitType())

    return get_cur_warpoints() >= wpSpecCost.wp &&
           curSpecType == crewSpecTypes.BASIC &&
           crewLevel >= reqLevel
  }

  function onUpgrCrewSpec1Tutorial() {
    let tblObj = this.scene.findObject("skills_table")
    if (!tblObj?.isValid())
      return

    local skillRowObj = null
    local btnSpecObj = null

    for (local i = 0; i < tblObj.childrenCount(); i++) {
      skillRowObj = tblObj.findObject($"skill_row{i}")
      if (!skillRowObj?.isValid())
        continue

      btnSpecObj = skillRowObj.findObject("btn_spec1")
      if (btnSpecObj?.isValid() && btnSpecObj.isVisible())
        break

      btnSpecObj = null
    }

    if (btnSpecObj == null)
      return

    let steps = [
      {
        obj = [btnSpecObj, skillRowObj]
        text = loc("tutorials/upg_crew/spec1")
        actionType = tutorAction.ANY_CLICK
        nextActionShortcut = "help/NEXT_ACTION"
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(this.onUpgrCrewSpec1ConfirmTutorial, this)
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onUpgrCrewSpec1ConfirmTutorial() {
    upgradeUnitSpec(this.crew, this.curUnit, null, crewSpecTypes.EXPERT)

    if (scene_msg_boxes_list.len() == 0) {
      let curSpec = getSpecTypeByCrewAndUnit(this.crew, this.curUnit)
      let message = format("Error: Empty MessageBox List for userId = %s\ncountry = %s" +
                               "\nidInCountry = %s\nunitname = %s\nspecCode = %s",
                               userIdStr.value,
                               this.crew.country,
                               this.crew.idInCountry.tostring(),
                               this.curUnit.name,
                               curSpec.code.tostring())
      script_net_assert_once("empty scene_msg_boxes_list", message)
      this.onUpgrCrewTutorFinalStep()
      return
    }

    let specMsgBox = scene_msg_boxes_list.top()
    let steps = [
      {
        obj = [[specMsgBox.findObject("buttons_holder"), specMsgBox.findObject("msgText")]]
        text = loc("tutorials/upg_crew/confirm_spec1")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }
    ]
    ::gui_modal_tutor(steps, this)
    saveLocalByAccount("upgradeCrewSpecTutorialPassed", true)
  }

  function onUpgrCrewTutorFinalStep() {
    let steps = [
      {
        text = loc("tutorials/upg_crew/final_massage")
        nextActionShortcut = "help/NEXT_ACTION"
        actionType = tutorAction.ANY_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onEventCrewSkillsChanged(params) {
    this.crew = this.getSlotCrew()
    this.initMainParams(!params?.isOnlyPointsChanged)
  }

  /** Triggered from CrewUnitSpecHandler. */
  function onEventQualificationIncreased(_params) {
    this.crew = this.getSlotCrew()
    this.initMainParams()
  }

  function onEventCrewTakeUnit(p) {
    if (!p?.unit)
      return

    if (!p?.prevUnit)
      this.openSelectedCrew()
    else {
      this.crew = this.getSlotCrew()
      this.initMainParams(false, true)
    }
    this.updatePage()
  }

  function onEventSlotbarPresetLoaded(_params) {
    this.openSelectedCrew()
    this.updatePage()
  }

  function onButtonInc(obj) {
    if (handlersManager.isHandlerValid(this.skillsPageHandler) && this.skillsPageHandler.isHandlerVisible)
      this.skillsPageHandler.onButtonInc(obj)
  }

  function onButtonIncRepeat(obj) {
    if (handlersManager.isHandlerValid(this.skillsPageHandler) && this.skillsPageHandler.isHandlerVisible)
      this.skillsPageHandler.onButtonIncRepeat(obj)
  }

  function onButtonDec(obj) {
    if (handlersManager.isHandlerValid(this.skillsPageHandler) && this.skillsPageHandler.isHandlerVisible)
      this.skillsPageHandler.onButtonDec(obj)
  }

  function onButtonDecRepeat(obj) {
    if (handlersManager.isHandlerValid(this.skillsPageHandler) && this.skillsPageHandler.isHandlerVisible)
      this.skillsPageHandler.onButtonDecRepeat(obj)
  }

  function getCurrentEdiff() {
    return this.curEdiff == -1 ? getCurrentGameModeEdiff() : this.curEdiff
  }

  function updateSkillsHandlerPoints() {
    if (this.skillsPageHandler != null)
      this.skillsPageHandler.setCurPoints(this.curPoints)
  }

  getCurCrewUnit = @(slotCrew) getCrewUnit(slotCrew)
  getSlotCrew = @() getCrew(this.countryId, this.idInCountry)
  onRecruitCrew = @() null

  function updateButtons() {
    this.scene.findObject("btn_apply").show(true)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/crew/crewPageModalHelp.blk"
      objContainer = this.scene.findObject("wnd_frame")
    }

    let links = [
      { obj = ["rb_unit_type"]
        msgId = "hint_select_venicle"
      }
      { obj = ["btn_apply"]
        msgId = "hint_btn_apply"
      }
      { obj = ["btn_buy"]
        msgId = "hint_btn_buy"
      }
      { obj = "crew_pages_list"
        msgId = "hint_crew_pages_list"
      }
      { obj = "trained"
        msgId = "hint_trained"
      }
      { obj = "crew_cur_points_block"
        msgId = "hint_crew_cur_points_block"
      }
    ]

    let page = this.pages[this.curPage]
    let isSkillPage = this.isSkillsPage(page)

    if (isSkillPage) {
      links.append({ obj = "table_row1", msgId = "hint_table_row1" })
      links.append({ obj = "table_row2", msgId = "hint_buttons_spec" })
      links.append({ obj = "table_row_progressbar", msgId = "hint_table_row_progressbar" })

      let minusButtons = []
      local idx = 0
      while (idx < page.items.len()) {
        minusButtons.append($"buttonDec_{idx}")
        idx++
      }
      links.append({ obj = minusButtons, msgId = "hint_btns_dec"})
    }

    let isMaxLevel = isCrewMaxLevel(this.crew, this.curUnit, this.getCurCountryName(), this.curCrewUnitType)
    if (!isMaxLevel && isSkillPage) {
      links.append({ obj = "table_row_inc_buttons", msgId = "hint_table_row_inc_buttons" })
      links.append({ obj = "table_row_price"
        msgId = "hint_table_row_price"
      })
    }
    res.links <- links
    return res
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function prepareHelpPage(handler) {
    let skillsTable = this.scene.findObject("skills_table")
    let skillsTablePos = skillsTable.getPos()
    let skillsTableSize = skillsTable.getSize()

    local hintsParams = [
      { hintName = "hint_crew_cur_points_block",
        objName = "crew_cur_points_block",
        shiftY = "- h - 1@bh - 2@helpInterval",
        posX = "sw/2 - w/2 - 1@bw"
      },
      { hintName = "hint_crew_cur_points_block",
        objName = "crew_cur_points_block",
        shiftY = "- h - 1@bh - 2@helpInterval",
        posX = "sw/2 - w/2 - 1@bw"
      },
      { hintName = "hint_btn_buy",
        objName = "btn_buy",
        shiftY = "+ 1@buttonHeight - 1@bh + 2@helpInterval",
        posX = "sw/2 + 0.7@sf - 1@bw - w"
      },
      { hintName = "hint_select_venicle",
        objName = "wnd_frame",
        shiftY = " + 2@helpInterval",
        posX = "sw/2 - 0.7@sf - 1@bw"
        sizeMults = [0, 1]
      }
    ]

    let page = this.pages[this.curPage]
    let isSkillPage = this.isSkillsPage(page)
    if (isSkillPage) {
      local skillsCount = 0
      foreach ( skill in page.items ) {
        if (skill.isVisible(this.curCrewUnitType)) {
          skillsCount++
        }
      }
      let lastRow = this.scene.findObject($"skill_row{skillsCount-1}")
      let tableHeight = lastRow.getPos()[1] + lastRow.getSize()[1] - skillsTablePos[1]

      let skills_help_table = this.scene.findObject("skills_help_table")
      skills_help_table.height = $"{tableHeight}"

      hintsParams.append(
        { hintName = "hint_table_row1", objName = "skills_table", shiftX = "- 1@shopWidthMax - 1@bw", shiftY = "- h - 1@helpInterval -1@bh"}
      )
      hintsParams.append({ hintName = "hint_table_row_inc_buttons",
        objName = "table_row_inc_buttons",
        shiftX = "- 1@bw",
        posY = $"{skillsTablePos[1] + skillsTableSize[1]} - 1@bh + 1@helpInterval"
        sizeMults = [0, 1]
      })
      hintsParams.append({ hintName = "hint_buttons_spec",
        objName = "table_row2",
        posX = "sw/2 - 0.7@sf - 1@bw + 2@shopWidthMax + 2@helpInterval",
        posY = "sh - h - 2@bh - 2@helpInterval"
      })
      hintsParams.append({hintName = "hint_table_row_progressbar",
        objName = "table_row_progressbar",
        shiftX = "-5@helpInterval - 1@bw",
        posY = $"sh - h - 2@bh - 2@helpInterval - 0.4@shopWidthMax"
      })
      hintsParams.append({hintName = "hint_table_row_price",
        objName = "table_row_price",
        shiftY = "-1@bh",
        shiftX = $"+ 2@helpInterval - 1@bw"
        sizeMults = [1, 0]
      })
      hintsParams.append({hintName = "hint_btns_dec",
        objName = "table_row2",
        shiftY = "-1@bh - h - 1@helpInterval",
        shiftX = $"-1@bw",
        sizeMults = [0, 0]
      })
    }

    foreach (param in hintsParams) {
      updateHintPosition(this.scene, handler.scene, param)
    }

    let hintBtnApply = handler.scene.findObject("hint_btn_apply")
    if (hintBtnApply?.isValid())
      hintBtnApply.pos = $"sw/2 + 0.7@sf - 1@bw - w, sh - h - 2@bh - 2@helpInterval"

    let hintQualification = handler.scene.findObject("hint_table_row2")
    if (hintQualification?.isValid())
      hintQualification.pos = $"sw/2 - 0.8@sf - 1@bw + 2@shopWidthMax + 2@helpInterval, sh - h - 2@bh - 2@helpInterval"

  }
}
