from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let daguiFonts = require("%scripts/viewUtils/daguiFonts.nut")
let stdMath = require("%sqstd/math.nut")
let crewSkillsPageHandler = require("%scripts/crew/crewSkillsPageHandler.nut")
let { getSkillValue } = require("%scripts/crew/crewSkills.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isCountryHaveUnitType } = require("%scripts/shop/shopUnitsInfo.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")

::gui_modal_crew <- function gui_modal_crew(params = {}) {
  if (hasFeature("CrewSkills"))
    ::gui_start_modal_wnd(::gui_handlers.CrewModalHandler, params)
  else
    ::showInfoMsgBox(loc("msgbox/notAvailbleYet"))
}

::gui_handlers.CrewModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/crew/crew.blk"

  slotbarActions = ["aircraft","sec_weapons", "weapons", "showroom", "repair" ]

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

  needHideSlotbar = false
  curUnit = null

  function initScreen()
  {
    if (!this.scene)
      return goBack()
    crew = getSlotCrew()
    if (!crew)
      return goBack()

    let country = ::g_crews_list.get()?[countryId].country
    if (country)
      switchProfileCountry(country)

    initMainParams(true, true)
    if (!needHideSlotbar)
      this.createSlotbar({
        emptyText="#shop/aircraftNotSelected",
        beforeSlotbarSelect = @(onOk, onCancel, _slotData) checkSkillPointsAndDo(onOk, onCancel)
        afterSlotbarSelect = openSelectedCrew
        onSlotDblClick = onSlotDblClick
      }.__update(getSlotbarParams()))

    if (showTutorial)
      onUpgrCrewSkillsTutorial()
    else if (!::loadLocalByAccount("upgradeCrewSpecTutorialPassed", false)
          && !::g_crew.isAllCrewsMinLevel()
          && ::g_crew.isAllCrewsHasBasicSpec()
          && canUpgradeCrewSpec(crew))
      onUpgrCrewSpec1Tutorial()
  }

  getSlotbarParams = @() {
    crewId = crew.id
    showNewSlot=false
  }

  function updateCrewInfo()
  {
    local text = ""
    if (curUnit != null && curUnit.getCrewUnitType() == curCrewUnitType)
    {
      text = ::g_string.implode([
        loc("crew/currentAircraft") + loc("ui/colon")
          + colorize("activeTextColor", ::getUnitName(curUnit))
        loc("crew/totalCrew") + loc("ui/colon")
          + colorize("activeTextColor", curUnit.getCrewTotalCount())
      ], loc("ui/comma"))
      if (curUnit.unitType.hasAiGunners && (curUnit?.gunnersCount ?? 0) > 0)
        text += "\n" + loc("crew/numDefensiveArmamentTurrets") + loc("ui/colon")
          + colorize("activeTextColor", curUnit.gunnersCount)
    }
    this.scene.findObject("crew-info-text").setValue(text)
  }

  function initMainParams(reloadSkills=true, reinitUnitType = false)
  {
    if (!checkObj(this.scene))
      return

    curUnit = getCrewUnit(crew)
    curCrewUnitType = reinitUnitType ? (curUnit?.getCrewUnitType?() ?? curCrewUnitType) : curCrewUnitType

    ::update_gamercards()
    if (reloadSkills)
      ::load_crew_skills()

    this.scene.findObject("crew_name").setValue(::g_crew.getCrewName(crew))

    updateUnitTypeRadioButtons()
    updateButtons()
  }

  function countSkills()
  {
    curPoints = ("skillPoints" in crew)? crew.skillPoints : 0
    crewCurLevel = ::g_crew.getCrewLevel(crew, curUnit, curCrewUnitType)
    crewLevelInc = ::g_crew.getCrewLevel(crew, curUnit, curCrewUnitType, true) - crewCurLevel
    foreach(page in ::crew_skills)
      foreach(item in page.items)
      {
        let value = getSkillValue(crew.id, curUnit, page.id, item.name)
        let newValue = getTblValue("newValue", item, value)
        if (newValue > value)
          curPoints -= ::g_crew.getSkillCost(item, newValue, value)
      }
    updateSkillsHandlerPoints()
    this.scene.findObject("crew_cur_skills").setValue(stdMath.round_by_value(crewCurLevel, 0.01).tostring())
    updatePointsText()
    updateBuyAllButton()
    updateAvailableSkillsIcons()
  }

  function onSkillRowChange(item, newValue)
  {
    let wasValue = ::g_crew.getSkillNewValue(item, crew, curUnit)
    let changeCost = ::g_crew.getSkillCost(item, newValue, wasValue)
    let crewLevelChange = ::g_crew.getSkillCrewLevel(item, newValue, wasValue)
    item.newValue <- newValue //!!FIX ME: this code must be in g_crew too
    curPoints -= changeCost
    updateSkillsHandlerPoints()
    crewLevelInc += crewLevelChange

    updatePointsText()
    updateBuyAllButton()
    updatePointsAdvice()
    updateAvailableSkillsIcons()
    ::broadcastEvent("CrewNewSkillsChanged", { crew = crew })
  }

  function getCurCountryName()
  {
    return ::g_crews_list.get()[countryId].country
  }

  function updateUnitTypeRadioButtons()
  {
    let rbObj = this.scene.findObject("rb_unit_type")
    if (!checkObj(rbObj))
      return

    local data = ""
    let crewUnitTypes = []
    local isVisibleCurCrewTypeButton =false
    foreach(unitType in unitTypes.types)
    {
      if (!unitType.isVisibleInShop())
        continue

      let crewUnitType = unitType.crewUnitType
      if (isInArray(crewUnitType,crewUnitTypes))
        continue

      if (!isCountryHaveUnitType(getCurCountryName(), unitType.esUnitType))
        continue

      crewUnitTypes.append(crewUnitType)
      let isCurrent = curCrewUnitType == crewUnitType
      isVisibleCurCrewTypeButton = isVisibleCurCrewTypeButton || isCurrent
      data += format("RadioButton { id:t='%s'; text:t='%s'; %s RadioButtonImg{} }",
                     "unit_type_" + crewUnitType,
                     unitType.getCrewArmyLocName(),
                     isCurrent ? "selected:t='yes';" : "")
    }
    this.guiScene.replaceContentFromText(rbObj, data, data.len(), this)
    if (!isVisibleCurCrewTypeButton) //need switch unit type if cur type not visible
      rbObj.setValue(0)
    updateUnitType()
  }

  function updateUnitType()
  {
    countSkills()
    updateCrewInfo()
    initPages()
  }

  function initPages()
  {
    updateDiscountInfo()

    pages = []
    foreach(page in ::crew_skills)
      if (page.isVisible(curCrewUnitType))
        pages.append(page)
    pages.append({ id = "trained" })

    let maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo, false)
    let discountText = maxDiscount > 0? ("-" + maxDiscount + "%") : ""
    let discountTooltip = ::g_crew.getDiscountsTooltipByInfo(discountInfo, false)

    curPage = 0


    let view = {
      tabs = []
    }
    foreach(index, page in pages)
    {
      if (page.id == curPageId)
        curPage = index

      let tabData = {
        id = page.id
        tabName = loc("crew/"+ page.id)
        navImagesText = ::get_navigation_images_text(index, pages.len())
      }

      if (isSkillsPage(page))
        tabData.cornerImg <- {
          cornerImg = ""
          cornerImgId = getCornerImgId(page)
        }
      else if (page.id == "trained")
        tabData.discount <- {
          text = discountText
          tooltip = discountTooltip
        }

      view.tabs.append(tabData)
    }
    let pagesObj = this.scene.findObject("crew_pages_list")
    pagesObj.smallFont = needSmallerHeaderFont(pagesObj.getSize(), view.tabs) ? "yes" : "no"
    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    this.guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    pagesObj.setValue(curPage)
    updateAvailableSkillsIcons()
  }

  function needSmallerHeaderFont(targetSize, viewTabs)
  {
    local width = 0
    foreach(tab in viewTabs)
      width += daguiFonts.getStringWidthPx(tab.tabName, "fontNormal", this.guiScene)

    width += viewTabs.len() * to_pixels("2@listboxHPadding + 1@listboxItemsInterval")
    if (::show_console_buttons)
      width += 2*targetSize[1] //gamepad navigation icons width = ph

    return width > targetSize[0]
  }

  function onChangeUnitType(obj)
  {
    curCrewUnitType = obj.getValue()
    updateUnitType()
  }

  function onCrewPage(obj)
  {
    if (!obj)
      return
    let value = obj.getValue()
    if (value in pages)
    {
      curPage = value
      curPageId = obj.getChild(value).id
      fillPage()
    }
  }

  function getCrewSkillTooltipLocId(skillName, pageName)
  {
    return "crew/" + pageName + "/" + skillName + "/tooltip"
  }

  function isSkillsPage(page)
  {
    return "items" in page
  }

  function fillPage()
  {
    updatePage()
  }

  function updatePointsText()
  {
    let isMaxLevel = ::g_crew.isCrewMaxLevel(crew, curUnit, getCurCountryName(), curCrewUnitType)
    let curPointsText = ::get_crew_sp_text(curPoints)
    this.scene.findObject("crew_cur_points").setValue(isMaxLevel ? "" : curPointsText)

    local levelIncText = ""
    local levelIncTooltip = loc("crew/usedSkills/tooltip")
    if (isMaxLevel)
    {
      levelIncText = loc("ui/parentheses/space", { text = loc("options/quality_max") })
      levelIncTooltip += "\n" + loc("crew/availablePoints") + curPointsText
    }
    else if (crewLevelInc > 0.005)
      levelIncText = "+" + stdMath.round_by_value(crewLevelInc, 0.01)

    this.scene.findObject("crew_new_skills").setValue(levelIncText)
    this.scene.findObject("crew_level_block").tooltip = levelIncTooltip
    this.scene.findObject("btn_apply").enable(crewLevelInc > 0)
    this.showSceneBtn("crew_cur_points_block", !isMaxLevel)
    this.showSceneBtn("btn_buy", hasFeature("SpendGold") && !isMaxLevel && crew.id != -1)
  }

  function updatePointsAdvice()
  {
    let page = pages[curPage]
    let isSkills = isSkillsPage(page)
    this.scene.findObject("crew_points_advice_block").show(isSkills)
    if (!isSkills)
      return
    let statusType = ::g_skills_page_status.getPageStatus(crew, curUnit, page, curCrewUnitType, curPoints)
    this.scene.findObject("crew_points_advice").show(statusType.show)
    this.scene.findObject("crew_points_advice_text")["crewStatus"] = statusType.style
  }

  function updateBuyAllButton()
  {
    if (!hasFeature("CrewBuyAllSkills"))
      return

    let totalPointsToMax = ::g_crew.getSkillPointsToMaxAllSkills(crew, curUnit, curCrewUnitType)
    this.showSceneBtn("btn_buy_all", totalPointsToMax > 0 && crew.id != -1)
    let text = loc("mainmenu/btnBuyAll") + loc("ui/parentheses/space", { text = ::get_crew_sp_text(totalPointsToMax) })
    setColoredDoubleTextToButton(this.scene, "btn_buy_all", text)
  }

  function onBuyAll()
  {
    ::g_crew.buyAllSkills(crew, curUnit, curCrewUnitType)
  }

  function getCornerImgId(page)
  {
    return page.id + "_available"
  }

  function updateAvailableSkillsIcons()
  {
    if (!pages)
      return

    this.guiScene.setUpdatesEnabled(false, false)
    let pagesObj = this.scene.findObject("crew_pages_list")
    foreach(page in pages)
    {
      if (!isSkillsPage(page))
        continue
      let obj = pagesObj.findObject(getCornerImgId(page))
      if (!checkObj(obj))
        continue

      let statusType = ::g_skills_page_status.getPageStatus(
        crew, curUnit, page, curCrewUnitType, curPoints)
      obj["background-image"] = statusType.icon
      obj["background-color"] = this.guiScene.getConstantValue(statusType.color) || ""
      obj.wink = statusType.wink ? "yes" : "no"
      obj.show(statusType.show)
    }
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateDiscountInfo()
  {
    discountInfo = ::g_crew.getDiscountInfo(countryId, idInCountry)
    updateAirList()

    let obj = this.scene.findObject("buyPoints_discount")
    let buyPointsDiscount = getTblValue("buyPoints", discountInfo, 0)
    ::showCurBonus(obj, buyPointsDiscount, "buyPoints", true, true)
  }

  function updateAirList()
  {
    airList = []
    if (!("trainedSpec" in crew))
      return

    let sortData = [] // { unit, locname }
    foreach(unit in ::all_units)
      if (unit.name in crew.trainedSpec && unit.getCrewUnitType() == curCrewUnitType)
      {
        let isCurrent = getTblValue("aircraft", crew, "") == unit.name
        if (isCurrent)
          airList.append(unit)
        else
        {
          sortData.append({
            unit = unit
            locname = ::g_string.utf8ToLower(::getUnitName(unit))
          })
        }
      }

    sortData.sort(function(a,b)
    {
      return a.locname > b.locname ? 1 : (a.locname < b.locname ? -1 : 0)
    })

    foreach(data in sortData)
      airList.append(data.unit)
  }

  function updatePage()
  {
    let page = pages[curPage]
    if (isSkillsPage(page))
    {
      let skillsHandlerParams = {
        scene = this.scene.findObject("skills_table")
        curPage = page
        crew = crew
        curCrewUnitType = curCrewUnitType
        curPoints = curPoints
        onSkillRowChangeCb = Callback(onSkillRowChange, this)
        unit = curUnit
      }
      if (unitSpecHandler != null)
        unitSpecHandler.setHandlerVisible(false)
      if (skillsPageHandler == null)
        skillsPageHandler = crewSkillsPageHandler(skillsHandlerParams)
      else
        skillsPageHandler.updateHandlerData(skillsHandlerParams)
      if (skillsPageHandler != null)
        skillsPageHandler.setHandlerVisible(true)
    }
    else if (page.id=="trained")
    {
      if (skillsPageHandler != null)
        skillsPageHandler.setHandlerVisible(false)
      if (unitSpecHandler == null)
        unitSpecHandler = ::g_crew.createCrewUnitSpecHandler(this.scene)
      if (unitSpecHandler != null)
      {
        unitSpecHandler.setHandlerVisible(true)
        unitSpecHandler.setHandlerData(crew, crewCurLevel, airList, curCrewUnitType)
      }
    }
    updatePointsAdvice()
    updateUnitTypeWarning(isSkillsPage(page))
  }

  function updateUnitTypeWarning(skillsVisible)
  {
    local show = false
    if (skillsVisible)
      show = curUnit != null && curUnit.getCrewUnitType() != curCrewUnitType
    this.scene.findObject("skills_unit_type_warning").show(show)
  }

  function onBuyPoints()
  {
    if (!checkObj(this.scene))
      return

    updateDiscountInfo()
    ::g_crew.createCrewBuyPointsHandler(crew)
  }

  function goBack()
  {
    checkSkillPointsAndDo(base.goBack)
  }

  function onEventSetInQueue(_params)
  {
    base.goBack()
  }

  function onApply()
  {
    if (this.progressBox)
      return

    let blk = ::DataBlock()
    foreach(page in ::crew_skills)
      if (isSkillsPage(page))
      {
        let typeBlk = ::DataBlock()
        foreach(_idx, item in page.items)
          if ("newValue" in item)
          {
            let value = getSkillValue(crew.id, curUnit, page.id, item.name)
            if (value<item.newValue)
              typeBlk[item.name] = item.newValue-value
          }
        blk[page.id] = typeBlk
      }

    let curHandler = this //to prevent handler destroy even when invalid.
    let isTaskCreated = ::g_tasker.addTask(
      ::shop_upgrade_crew(crew.id, blk),
      { showProgressBox = true },
      function()
      {
        ::broadcastEvent("CrewSkillsChanged",
          { crew = curHandler.crew, unit = curHandler.curUnit })
        if (curHandler.isValid() && curHandler.afterApplyAction)
        {
          curHandler.afterApplyAction()
          curHandler.afterApplyAction = null
        }
        ::g_crews_list.flushSlotbarUpdate()
      },
      @(_err) ::g_crews_list.flushSlotbarUpdate()
    )

    if (isTaskCreated)
      ::g_crews_list.suspendSlotbarUpdates()
  }

  function onSelect()
  {
    onApply()
  }

  function checkSkillPointsAndDo(action, cancelAction = function() {}, updateAfterApply = true)
  {
    let crewPoints = getTblValue("skillPoints", crew, 0)
    if (curPoints == crewPoints)
      return action()

    let msgOptions = [
      ["yes", function() {
        afterApplyAction = action
        updateAfterApplyAction = updateAfterApply
        onApply()
      }],
      ["no", action]
    ]

    this.msgBox("applySkills", loc("crew/applySkills"), msgOptions, "yes", {
      cancel_fn = cancelAction
      checkDuplicateId = true
    })
  }

  function baseGoForward(startFunc, needFade)
  {
    base.goForward(startFunc, needFade)
  }

  function goForward(startFunc, needFade=true)
  {
    checkSkillPointsAndDo(Callback(@() baseGoForward(startFunc, needFade), this))
  }

  function onSlotDblClick(_slotCrew)
  {
    if (curUnit != null)
      checkSkillPointsAndDo(@() ::open_weapons_for_unit(curUnit))
  }

  function beforeSlotbarChange(action, cancelAction)
  {
    checkSkillPointsAndDo(action, cancelAction)
  }

  function openSelectedCrew()
  {
    let newCrew = this.getCurCrew()
    if (!newCrew)
      return

    crew = newCrew
    countryId = crew.idCountry
    idInCountry = crew.idInCountry
    initMainParams(true, true)
  }

  function onUpgrCrewSkillsTutorial()
  {
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
        cb = Callback(@() onButtonInc(this.getObj("skill_row0").findObject("buttonInc")), this)
      },
      {
        obj = [this.getObj("skill_row1").findObject("buttonInc"), "skill_row1"]
        text = loc("tutorials/upg_crew/inc_skills")
        actionType = tutorAction.FIRST_OBJ_CLICK
        nextActionShortcut = "help/OBJ_CLICK"
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(@() onButtonInc(this.getObj("skill_row1").findObject("buttonInc")), this)
      },
      {
        obj = ["btn_apply"]
        text = loc("tutorials/upg_crew/apply_upgr_skills")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::GAMEPAD_ENTER_SHORTCUT
        cb = Callback(function() {
          afterApplyAction = canUpgradeCrewSpec(crew) ? onUpgrCrewSpec1Tutorial
            : onUpgrCrewTutorFinalStep
          onApply() }, this)
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function canUpgradeCrewSpec(upgCrew)
  {
    if (curUnit == null)
      return false

    let curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(upgCrew, curUnit)
    let wpSpecCost = curSpecType.getUpgradeCostByCrewAndByUnit(upgCrew, curUnit)
    let reqLevel = curSpecType.getUpgradeReqCrewLevel(curUnit)
    let crewLevel = ::g_crew.getCrewLevel(upgCrew, curUnit, curUnit.getCrewUnitType())

    return ::get_cur_warpoints() >= wpSpecCost.wp &&
           curSpecType == ::g_crew_spec_type.BASIC &&
           crewLevel >= reqLevel
  }

  function onUpgrCrewSpec1Tutorial()
  {
    let tblObj = this.scene.findObject("skills_table")
    if (!checkObj(tblObj))
      return

    local skillRowObj = null
    local btnSpecObj = null

    for(local i = 0; i < tblObj.childrenCount(); i++)
    {
      skillRowObj = tblObj.findObject("skill_row" + i)
      if (!checkObj(skillRowObj))
        continue

      btnSpecObj = skillRowObj.findObject("btn_spec1")
      if (checkObj(btnSpecObj) && btnSpecObj.isVisible())
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
        cb = Callback(onUpgrCrewSpec1ConfirmTutorial, this)
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onUpgrCrewSpec1ConfirmTutorial()
  {
    ::g_crew.upgradeUnitSpec(crew, curUnit, null, ::g_crew_spec_type.EXPERT)

    if (::scene_msg_boxes_list.len() == 0)
    {
      let curSpec = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, curUnit)
      let message = format("Error: Empty MessageBox List for userId = %s\ncountry = %s" +
                               "\nidInCountry = %s\nunitname = %s\nspecCode = %s",
                               ::my_user_id_str,
                               crew.country,
                               crew.idInCountry.tostring(),
                               curUnit.name,
                               curSpec.code.tostring())
      ::script_net_assert_once("empty scene_msg_boxes_list", message)
      onUpgrCrewTutorFinalStep()
      return
    }

    let specMsgBox = ::scene_msg_boxes_list.top()
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
    ::saveLocalByAccount("upgradeCrewSpecTutorialPassed", true)
  }

  function onUpgrCrewTutorFinalStep()
  {
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

  function onEventCrewSkillsChanged(params)
  {
    crew = getSlotCrew()
    initMainParams(!getTblValue("isOnlyPointsChanged", params, false))
  }

  /** Triggered from CrewUnitSpecHandler. */
  function onEventQualificationIncreased(_params)
  {
    crew = getSlotCrew()
    initMainParams()
  }

  function onEventCrewTakeUnit(p)
  {
    if (!p?.unit)
      return

    if (!p?.prevUnit)
      openSelectedCrew()
    else
    {
      crew = getSlotCrew()
      initMainParams(false, true)
    }
    updatePage()
  }

  function onEventSlotbarPresetLoaded(_params)
  {
    openSelectedCrew()
    updatePage()
  }

  function onButtonInc(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonInc(obj)
  }

  function onButtonIncRepeat(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonIncRepeat(obj)
  }

  function onButtonDec(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonDec(obj)
  }

  function onButtonDecRepeat(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonDecRepeat(obj)
  }

  function getCrewLevel()
  {
    return crewCurLevel
  }

  function getCurrentEdiff()
  {
    return curEdiff == -1 ? ::get_current_ediff() : curEdiff
  }

  function updateSkillsHandlerPoints()
  {
    if (skillsPageHandler != null)
      skillsPageHandler.setCurPoints(curPoints)
  }

  getCrewUnit = @(slotCrew) ::g_crew.getCrewUnit(slotCrew)
  getSlotCrew = @() getCrew(countryId, idInCountry)
  onRecruitCrew = @() null

  function updateButtons()
  {
    this.scene.findObject("btn_apply").show(true)
  }
}

