//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { floor } = require("math")
let { addTypes } = require("%sqStdLibs/helpers/enums.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { getSkillCategoryByName } = require("%scripts/crew/crewSkills.nut")
let { getSkillCategoryTooltipContent } = require("%scripts/crew/crewSkillsView.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { updateDecoratorDescription } = require("%scripts/customization/decoratorDescription.nut")
let { getChallengeView } = require("%scripts/battlePass/challenges.nut")
let { fillItemDescr, fillDescTextAboutDiv,
  fillItemDescUnderTable } = require("%scripts/items/itemVisual.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getCrew } = require("%scripts/crew/crew.nut")
let { getUnlockDesc, getUnlockCondsDescByCfg, getUnlockMultDescByCfg, getUnlockChapterAndGroupText,
  getUnlockMainCondDescByCfg, getUnlockTitle } = require("%scripts/unlocks/unlocksViewModule.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getSubunlockCfg } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getDecorator, getPlaneBySkinId } = require("%scripts/customization/decorCache.nut")

let tooltipTypes = {
  types = []
}

tooltipTypes.template <- {
  typeName = "" //added automatically by type name

  _buildId = function(id, params = null) {
    let t = params ? clone params : {}
    t.ttype <- this.typeName
    t.id    <- id
    return ::save_to_json(t)
  }
  //full params list depend on specific type
  getTooltipId = function(id, params = null, _p2 = null, _p3 = null) {
    return this._buildId(id, params)
  }
  getMarkup = @(id, params = null, p2 = null, p3 = null)
    format(@"title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='%s'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }",
      this.getTooltipId(id, params, p2, p3))

  getTooltipContent = function(_id, _params) { return "" }
  isCustomTooltipFill = false //if true, need to use fillTooltip instead of getTooltipContent
  fillTooltip = function(_obj, _handler, _id, _params) { //return isSucceed
    return false
  }
  onClose = @(_obj) null
}

let function addTooltipTypes(tTypes) {
  addTypes(tooltipTypes, tTypes, null, "typeName")
  return tTypes.map(@(_, id) tooltipTypes[id])
}

let exportTypes = addTooltipTypes({
  EMPTY = {
  }

  UNLOCK = { //tooltip by unlock name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params) {
      if (!checkObj(obj))
        return false

      let config = ::build_log_unlock_data(params.__merge({ id = unlockId }))

      if (config.type == -1)
        return false

      ::build_unlock_tooltip_by_config(obj, config, handler)
      return true
    }
  }

  UNLOCK_SHORT = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unlockId, params) {
      if (!checkObj(obj))
        return false

      let unlock = getUnlockById(unlockId)
      if (unlock == null)
        return false

      let stage = params?.stage.tointeger() ?? -1
      let config = ::build_conditions_config(unlock, stage)
      let subunlockCfg = getSubunlockCfg(config.conditions)

      obj.getScene().replaceContent(obj, "%gui/unlocks/shortTooltip.blk", handler)

      let header = getUnlockTitle(config)
      obj.findObject("header").setValue(header)

      if (params?.showChapter ?? false)
        obj.findObject("chapter").setValue(getUnlockChapterAndGroupText(unlock))

      let mainCond = getUnlockMainCondDescByCfg(subunlockCfg ?? config)
      let conds = getUnlockCondsDescByCfg(subunlockCfg ?? config)
      obj.findObject("desc_text").setValue(getUnlockDesc(subunlockCfg ?? config))
      obj.findObject("mainCond").setValue(mainCond)
      obj.findObject("multDesc").setValue(getUnlockMultDescByCfg(subunlockCfg ?? config))
      obj.findObject("conds").setValue(conds)

      let hasMainCond = mainCond != ""
      let hasAnyCond = hasMainCond || conds != ""
      if (hasMainCond && !::is_unlocked_scripted(-1, unlockId)) {
        let pObj = obj.findObject("progress")
        let progressData = subunlockCfg?.getProgressBarData() ?? config.getProgressBarData()
        pObj.setValue(progressData.value)
        pObj.show(progressData.show)
      }
      else if (hasAnyCond)
        obj.findObject("challenge_complete").show(true)

      let reward = ::g_unlock_view.getRewardText(config, stage)
      obj.findObject("reward").setValue(reward)

      let view = ::g_unlock_view.getSubunlocksView(subunlockCfg ?? config)
      if (view) {
        let markup = ::handyman.renderCached("%gui/unlocks/subunlocks.tpl", view)
        let nestObj = obj.findObject("subunlocks")
        nestObj.show(true)
        obj.getScene().replaceContentFromText(nestObj, markup, markup.len(), this)
      }

      return true
    }
  }

  DECORATION = { //tooltip by decoration id and decoration type
                 //@decorType = UNLOCKABLE_DECAL or UNLOCKABLE_SKIN
                 //can be without exist unlock
                 //for skins decorId is like skin unlock id   -  <unitName>"/"<skinName>
    getTooltipId = function(decorId, decorType, params = null, _p3 = null) {
      let p = params || {}
      p.decorType <- decorType
      return this._buildId(decorId, p)
    }

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params) {
      let unlockType = getTblValue("decorType", params, -1)
      let decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
      if (decoratorType == ::g_decorator_type.UNKNOWN)
        return false

      let decorator = getDecorator(id, decoratorType)
      if (!decorator)
        return false

      obj.getScene().replaceContent(obj, "%gui/customization/decalTooltip.blk", handler)

      updateDecoratorDescription(obj, handler, decoratorType, decorator, params)
      return true
    }
  }

  ITEM = { //by item name
    item = null
    tooltipObj = null
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, params = null) {
      if (!checkObj(obj))
        return false

      this.item = ::ItemsManager.findItemById(itemName)
      if (!this.item)
        return false

      this.tooltipObj = obj

      if (params?.isDisguised || workshop.shouldDisguiseItem(this.item)) {
        this.item = this.item.makeEmptyInventoryItem()
        this.item.setDisguise(true)
      }

      local preferMarkup = this.item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      fillItemDescr(this.item, obj, handler, false, preferMarkup,
        params.__merge({ showOnlyCategoriesOfPrizes = true, showTooltip = false }))

      if (this.item?.hasLifetimeTimer())
        obj?.findObject("update_timer").setUserData(this)

      return true
    }
    onEventItemsShopUpdate = function(_eventParams, obj, handler, id, params) {
      this.fillTooltip(obj, handler, id, params)
    }
    onTimer = function (_obj, _dt) {
      if (this.item && this.tooltipObj?.isValid())
        fillItemDescUnderTable(this.item, this.tooltipObj)
    }
  }

  INVENTORY = { //by inventory item uid
    isCustomTooltipFill = true
    item = null
    tooltipObj = null
    fillTooltip = function(obj, handler, itemUid, ...) {
      if (!checkObj(obj))
        return false

      this.tooltipObj = obj
      this.item = ::ItemsManager.findItemByUid(itemUid)
      if (!this.item)
        return false

      let preferMarkup = this.item.isPreferMarkupDescInTooltip
      obj.getScene().replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      fillItemDescr(this.item, obj, handler, false, preferMarkup,
        { showOnlyCategoriesOfPrizes = true })

      if (this.item.hasTimer())
        obj?.findObject("update_timer").setUserData(this)

      return true
    }
    onEventItemsShopUpdate = function(_eventParams, obj, handler, id, params) {
      this.fillTooltip(obj, handler, id, params)
    }
    onTimer = function (_obj, _dt) {
      if (!this.item || !this.tooltipObj?.isValid())
        return

      fillDescTextAboutDiv(this.item, this.tooltipObj)
    }
  }

  SUBTROPHY = { //by item Name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, itemName, ...) {
      if (!checkObj(obj))
        return false

      let item = ::ItemsManager.findItemById(itemName)
      if (!item)
        return false
      let data = item.getLongDescriptionMarkup()
      if (data == "")
        return false

      // Showing only trophy content, without title and icon.
      obj.width = "@itemInfoWidth"
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  UNIT = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params) {
      if (!checkObj(obj))
        return false
      let unit = ::getAircraftByName(id)
      if (!unit)
        return false
      let guiScene = obj.getScene()
      guiScene.setUpdatesEnabled(false, false)
      guiScene.replaceContent(obj, "%gui/airTooltip.blk", handler)
      let contentObj = obj.findObject("air_info_tooltip")
      ::showAirInfo(unit, true, contentObj, handler, params)
      guiScene.setUpdatesEnabled(true, true)

      if (obj.getSize()[1] < ::g_dagui_utils.toPixels(obj.getScene(), "1@rh"))
        return true

      contentObj.height = "1@rh - 2@framePadding"
      let unitImgObj = contentObj.findObject("aircraft-image")
      if (unitImgObj?.isValid())
        unitImgObj.height = "fh"
      return true
    }
    onEventUnitModsRecount = function(eventParams, obj, handler, id, params) {
      if (id == getTblValue("name", getTblValue("unit", eventParams)))
        this.fillTooltip(obj, handler, id, params)
    }
    onEventSecondWeaponModsUpdated = function(eventParams, obj, handler, id, params) {
      if (id == getTblValue("name", getTblValue("unit", eventParams)))
        this.fillTooltip(obj, handler, id, params)
    }
  }

  UNIT_GROUP = {
    isCustomTooltipFill = true
    getTooltipId = function(group, params = null) {
      return this._buildId({ units = group?.units.keys(), name = group?.name }, params)
    }
    fillTooltip = function(obj, handler, group, _params) {
      if (!checkObj(obj))
        return false

      let name = loc("ui/quotes", { text = loc(group.name) })
      let list = []
      foreach (str in group.units) {
        let unit = ::getAircraftByName(str)
        if (!unit)
          continue

        list.append({
          unitName = ::getUnitName(str)
          icon = ::getUnitClassIco(str)
          shopItemType = getUnitRole(unit)
        })
      }

      let columns = []
      let unitsInArmyRowsMax = max(floor(list.len() / 2).tointeger(), 3)
      let hasMultipleColumns = list.len() > unitsInArmyRowsMax
      if (!hasMultipleColumns)
        columns.append({ groupList = list })
      else {
        columns.append({ groupList = list.slice(0, unitsInArmyRowsMax), isFirst = true })
        columns.append({ groupList = list.slice(unitsInArmyRowsMax) })
      }

      let data = ::handyman.renderCached("%gui/tooltips/unitGroupTooltip.tpl", {
        title = $"{loc("unitsGroup/groupContains", { name = name})}{loc("ui/colon")}",
        hasMultipleColumns = hasMultipleColumns,
        columns = columns
      })
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  RANDOM_UNIT = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, _id, params) {
      if (!checkObj(obj))
        return false
      let groupName = params?.groupName
      let missionRules = ::g_mis_custom_state.getCurMissionRules()
      if (!groupName || !missionRules)
        return false

      let unitsList = missionRules.getRandomUnitsList(groupName)
      let unitsView = []
      local unit
      foreach (unitName in unitsList) {
        unit = ::getAircraftByName(unitName)
        if (!unit)
          unitsView.append({ name = unitName })
        else
          unitsView.append({
            name = ::getUnitName(unit)
            unitClassIcon = ::getUnitClassIco(unit.name)
            shopItemType = getUnitRole(unit)
            tooltipId = ::g_tooltip.getIdUnit(unit.name, { needShopInfo = true })
          })
      }

      let tooltipParams = {
        groupName = loc("respawn/randomUnitsGroup/description",
          { groupName = colorize("activeTextColor", missionRules.getRandomUnitsGroupLocName(groupName)) })
        rankGroup = loc("shop/age") + loc("ui/colon") +
          colorize("activeTextColor", missionRules.getRandomUnitsGroupLocRank(groupName))
        battleRatingGroup = loc("shop/battle_rating") + loc("ui/colon") +
          colorize("activeTextColor", missionRules.getRandomUnitsGroupLocBattleRating(groupName))
        units = unitsView
      }
      let data = ::handyman.renderCached("%gui/tooltips/randomUnitTooltip.tpl", tooltipParams)

      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  SKILL_CATEGORY = { //by categoryName, unitTypeName
    getTooltipId = function(categoryName, unitName = "", _p2 = null, _p3 = null) {
      return this._buildId(categoryName, { unitName = unitName })
    }
    getTooltipContent = function(categoryName, params) {
      let unit = ::getAircraftByName(params?.unitName ?? "")
      let crewUnitType = (unit?.unitType ?? unitTypes.INVALID).crewUnitType
      let skillCategory = getSkillCategoryByName(categoryName)
      let crewCountryId = ::find_in_array(shopCountriesList, profileCountrySq.value, -1)
      let crewIdInCountry = getTblValue(crewCountryId, ::selected_crews, -1)
      let crewData = getCrew(crewCountryId, crewIdInCountry)
      if (skillCategory != null && crewUnitType != CUT_INVALID && crewData != null)
        return getSkillCategoryTooltipContent(skillCategory, crewUnitType, crewData, unit)
      return ""
    }
  }

  CREW_SPECIALIZATION = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, _p3 = null) {
      return this._buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params) {
      let crew = ::get_crew_by_id(::to_integer_safe(crewIdStr, -1))
      let unit = ::getAircraftByName(getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = ::g_crew_spec_type.getTypeByCode(getTblValue("specTypeCode", params, -1))
      if (specType == ::g_crew_spec_type.UNKNOWN)
        specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
      if (specType == ::g_crew_spec_type.UNKNOWN)
        return ""

      return specType.getTooltipContent(crew, unit)
    }
  }

  BUY_CREW_SPEC = { //by crewId, unitName, specTypeCode
    getTooltipId = function(crewId, unitName = "", specTypeCode = -1, _p3 = null) {
      return this._buildId(crewId, { unitName = unitName, specTypeCode = specTypeCode })
    }
    getTooltipContent = function(crewIdStr, params) {
      let crew = ::get_crew_by_id(::to_integer_safe(crewIdStr, -1))
      let unit = ::getAircraftByName(getTblValue("unitName", params, ""))
      if (!unit)
        return ""

      local specType = ::g_crew_spec_type.getTypeByCode(getTblValue("specTypeCode", params, -1))
      if (specType == ::g_crew_spec_type.UNKNOWN)
        specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit).getNextType()
      if (specType == ::g_crew_spec_type.UNKNOWN)
        return ""

      return specType.getBtnBuyTooltipContent(crew, unit)
    }
  }

  SPECIAL_TASK = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params) {
      if (!checkObj(obj))
        return false

      let warbond = ::g_warbonds.findWarbond(
        getTblValue("wbId", params),
        getTblValue("wbListId", params)
      )
      let award = warbond ? warbond.getAwardById(id) : null
      if (!award)
        return false

      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      if (award.fillItemDesc(obj, handler))
        return true

      obj.findObject("item_name").setValue(award.getNameText())
      obj.findObject("item_desc").setValue(award.getDescText())

      let imageData = award.getDescriptionImage()
      guiScene.replaceContentFromText(obj.findObject("item_icon"), imageData, imageData.len(), handler)
      return true
    }
  }

  BATTLE_TASK = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!checkObj(obj))
        return false

      let battleTask = ::g_battle_tasks.getTaskById(id)
      if (!battleTask)
        return false

      let config = ::g_battle_tasks.generateUnlockConfigByTask(battleTask)
      let view = ::g_battle_tasks.generateItemView(config, { isOnlyInfo = true })
      let data = ::handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", { items = [view], isSmallText = true })

      let guiScene = obj.getScene()
      obj.width = "1@unlockBlockWidth"
      guiScene.replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  BATTLE_PASS_CHALLENGE = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!checkObj(obj))
        return false

      let unlockBlk = id && id != "" && getUnlockById(id)
      let data = ::handyman.renderCached("%gui/unlocks/battleTasksItem.tpl",
        { items = [getChallengeView(unlockBlk, { isOnlyInfo = true })], isSmallText = true })

      let guiScene = obj.getScene()
      obj.width = "1@unlockBlockWidth"
      guiScene.replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  REWARD_TOOLTIP = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, _handler, unlockId, _params) {
      if (!checkObj(obj))
        return false

      let unlockBlk = unlockId && unlockId != "" && getUnlockById(unlockId)
      if (!unlockBlk)
        return false

      let config = ::build_conditions_config(unlockBlk)
      let name = config.id
      let unlockType = config.unlockType
      let decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
      let guiScene = obj.getScene()
      if (decoratorType == ::g_decorator_type.DECALS
          || decoratorType == ::g_decorator_type.ATTACHABLES
          || unlockType == UNLOCKABLE_MEDAL) {
        let bgImage = format("background-image:t='%s';", config.image)
        let size = format("size:t='128, 128/%f';", config.imgRatio)
        let svgSize = format("background-svg-size:t='128, 128/%f';", config.imgRatio)

        guiScene.appendWithBlk(obj, " ".concat("img{", bgImage, size, svgSize, "}"), this)
      }
      else if (decoratorType == ::g_decorator_type.SKINS) {
        let unit = ::getAircraftByName(getPlaneBySkinId(name))
        local text = []
        if (unit)
          text.append(loc("reward/skin_for") + " " + ::getUnitName(unit))
        text.append(decoratorType.getLocDesc(name))

        text = ::locOrStrip(::g_string.implode(text, "\n"))
        let textBlock = "textareaNoTab {smallFont:t='yes'; max-width:t='0.5@sf'; text:t='%s';}"
        guiScene.appendWithBlk(obj, format(textBlock, text), this)
      }
      else
        return false

      return true
    }
  }
})

let function getTooltipType(typeName) {
  let res = tooltipTypes?[typeName]
  return type(res) == "table" ? res : this.EMPTY
}

return exportTypes.__update({
  addTooltipTypes
  getTooltipType
})