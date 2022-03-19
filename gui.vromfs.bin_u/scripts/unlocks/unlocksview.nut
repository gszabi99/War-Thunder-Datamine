local globalCallbacks = require("sqDagui/globalCallbacks/globalCallbacks.nut")
local { getUnitRole } = require("scripts/unit/unitInfoTexts.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { is_bit_set } = require("std/math.nut")
local { DECORATION, UNLOCK, REWARD_TOOLTIP, UNLOCK_SHORT
} = require("scripts/utils/genericTooltipTypes.nut")
local { getUnlockLocName, getSubUnlockLocName } = require("scripts/unlocks/unlocksViewModule.nut")
local { hasActiveUnlock, getUnitListByUnlockId } = require("scripts/unlocks/unlockMarkers.nut")
local { getShopDiffCode } = require("scripts/shop/shopDifficulty.nut")

::g_unlock_view <- {
  function getUnlockTitle(unlockConfig) {
    local name = unlockConfig.useSubUnlockName ? getSubUnlockLocName(unlockConfig)
      : unlockConfig.locId != "" ? getUnlockLocName(unlockConfig)
      : ::get_unlock_name_text(unlockConfig.unlockType, unlockConfig.id)
    local stage = unlockConfig.curStage >= 0
      ? unlockConfig.curStage + (::is_unlocked_scripted(-1, unlockConfig.id) ? 0 : 1)
      : 0
    return $"{name} {::roman_numerals[stage]}"
  }

  function fillSimplifiedUnlockInfo(unlockBlk, unlockObj, context) {
    local isShowUnlock = unlockBlk != null && ::is_unlock_visible(unlockBlk)
    unlockObj.show(isShowUnlock)
    if(!isShowUnlock)
      return

    local unlockConfig = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(unlockConfig)

    local title = fillUnlockTitle(unlockConfig, unlockObj)
    fillUnlockImage(unlockConfig, unlockObj)
    fillUnlockProgressBar(unlockConfig, unlockObj)
    fillReward(unlockConfig, unlockObj)
    fillUnlockConditions(unlockConfig, unlockObj, context)

    local closeBtn = unlockObj.findObject("removeFromFavoritesBtn")
    if(::check_obj(closeBtn))
      closeBtn.unlockId = unlockBlk.id

    local chapterAndGroupText = []
    if ("chapter" in unlockBlk)
      chapterAndGroupText.append(::loc($"unlocks/chapter/{unlockBlk.chapter}"))
    if ((unlockBlk?.group ?? "") != "") {
      local locId = $"unlocks/group/{unlockBlk.group}"
      local parentUnlock = ::g_unlocks.getUnlockById(unlockBlk.group)
      if (parentUnlock?.chapter == unlockBlk?.chapter)
        locId = $"{parentUnlock.id}/name"
      chapterAndGroupText.append(::loc(locId))
    }

    unlockObj.tooltip = "\n".join([::colorize("unlockHeaderColor", title),
      chapterAndGroupText.len() > 0 ? $"({", ".join(chapterAndGroupText, true)})" : "",
      unlockConfig?.stagesText ?? "",
      ::UnlockConditions.getConditionsText(
        unlockConfig.conditions,
        unlockConfig.showProgress ? unlockConfig.curVal : null,
        unlockConfig.maxVal,
        { isExpired = unlockConfig.isExpired })
    ], true)
  }

  function getUnlockImageConfig(unlockConfig)
  {
    local unlockType = getUnlockType(unlockConfig)
    local isUnlocked = ::is_unlocked_scripted(unlockType, unlockConfig.id)
    local iconStyle = unlockConfig?.iconStyle ?? ""
    local image = unlockConfig?.image ?? ""

    if (iconStyle=="" && image=="")
      iconStyle = (isUnlocked? "default_unlocked" : "default_locked") +
          ((isUnlocked || unlockConfig.curStage < 1)? "" : "_stage_" + unlockConfig.curStage)

    return {
      style = iconStyle
      image = unlockType == ::UNLOCKABLE_PILOT? unlockConfig.descrImage : image
      ratio = unlockConfig?.imgRatio ?? 1.0
      params = unlockConfig?.iconParams
      isDecalLocked = (!isUnlocked && (unlockType == ::UNLOCKABLE_DECAL
        || unlockType == ::UNLOCKABLE_MEDAL) )
      isAchievementLocked = (!isUnlocked && unlockConfig.curStage <= 0
        && unlockType != ::UNLOCKABLE_MEDAL && unlockType != ::UNLOCKABLE_DECAL)
    }
  }

  function fillUnlockImage(unlockConfig, unlockObj)
  {
    local imgConfig = getUnlockImageConfig(unlockConfig)
    local iconObj = unlockObj.findObject("achivment_ico")
    iconObj.decal_locked = imgConfig.isDecalLocked ? "yes" : "no"
    iconObj.achievement_locked = imgConfig.isAchievementLocked ? "yes" : "no"

    ::LayersIcon.replaceIcon(
      iconObj,
      imgConfig.style,
      imgConfig.image,
      imgConfig.ratio,
      null/*defStyle*/,
      imgConfig.params
    )
  }

  function getUnitActionButtonsView(unit) {
    if ((unit.isInShop ?? false) == false)
      return []

    local gcb = globalCallbacks.UNIT_PREVIEW
    return [{
      image = "#ui/gameuiskin#btn_preview.svg"
      tooltip = "#mainmenu/btnPreview"
      funcName = gcb.cbName
      actionParamsMarkup = gcb.getParamsMarkup({ unitId = unit.name })
    }]
  }

  function getUnitViewDataItem(unlockConfig, params = {}) {
    local unit = ::getAircraftByName(unlockConfig.id)
    if (!unit)
      return null

    local ignoreAvailability = params?.ignoreAvailability
    local isBought = ignoreAvailability ? false : unit.isBought()
    local buttons = getUnitActionButtonsView(unit)
    local receiveOnce = "mainmenu/receiveOnlyOnce"

    local unitPlate = ::build_aircraft_item(unit.name, unit, {
      hasActions = true,
      status = ignoreAvailability ? "owned" : isBought ? "locked" : "canBuy",
      isLocalState = !ignoreAvailability
      showAsTrophyContent = true
      tooltipParams = {
        showLocalState = true
      }
    })

    return {
      shopItemType = getUnitRole(unit)
      unitPlate = unitPlate
      classIco = ::getUnitClassIco(unit)
      commentText = isBought? ::colorize("badTextColor", ::loc(receiveOnce)) : null
      buttons = buttons
      buttonsCount = buttons.len()
    }
  }

  function getUnlockType(unlockConfig) {
    return unlockConfig?.unlockType ?? unlockConfig?.type ?? -1
  }

  function getDecoratorActionButtonsView(decorator, decoratorType) {
    if (!decorator.canPreview())
      return []

    local gcb = globalCallbacks.DECORATOR_PREVIEW
    return [{
      image = "#ui/gameuiskin#btn_preview.svg"
      tooltip = "#mainmenu/btnPreview"
      funcName = gcb.cbName
      actionParamsMarkup = gcb.getParamsMarkup({
        resource = decorator.id,
        resourceType = decoratorType.resourceType
      })
    }]
  }

  function getDecoratorViewDataItem(unlockConfig, params = {}) {
    local unlockType = getUnlockType(unlockConfig)
    local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
    local decorator = ::g_decorator.getDecorator(unlockConfig.id, decoratorType)
    if (!decorator)
      return {}

    local nameColor = decorator ? decorator.getRarityColor() : "activeTextColor"
    local isHave = params?.ignoreAvailability ? false : decoratorType.isPlayerHaveDecorator(unlockConfig.id)
    local buttons = getDecoratorActionButtonsView(decorator, decoratorType)
    local locName = decoratorType.getLocName(unlockConfig.id, true)

    return {
      icon = decoratorType.prizeTypeIcon
      title = ::colorize(nameColor, locName)
      tooltipId = ::g_tooltip.getIdDecorator(decorator.id, decoratorType.unlockedItemType)
      commentText = isHave ? ::colorize("badTextColor", ::loc("mainmenu/receiveOnlyOnce")) : null
      buttons = buttons
    }
  }

  function getPilotViewDataItem(unlockConfig) {
    return {
      title = ::loc("trophy/unlockables_names/gamerpic")
      previewImage = "cardAvatar { value:t='" + unlockConfig.id +"'}"
    }
  }

  function getViewDataItem(unlockConfig, params = {}) {
    local unlockType = getUnlockType(unlockConfig)
    if (unlockType == ::UNLOCKABLE_AIRCRAFT)
      return getUnitViewDataItem(unlockConfig, params)

    if (unlockType == ::UNLOCKABLE_DECAL
      || unlockType == ::UNLOCKABLE_SKIN
      || unlockType == ::UNLOCKABLE_ATTACHABLE)
      return getDecoratorViewDataItem(unlockConfig, params)

    if (unlockType == ::UNLOCKABLE_PILOT)
      return getPilotViewDataItem(unlockConfig)

    local icon = "#ui/gameuiskin#item_type_placeholder"
    local title = unlockConfig.name

    if (unlockType == ::UNLOCKABLE_TITLE)
    {
      icon = "#ui/gameuiskin#item_type_unlock"
      title = ::format(::loc("reward/title"), title)
    }

    return {
      icon = icon
      title = title
    }
  }

  function getViewItem(unlockConfig, params = {}) {
    local view = params
    view.list <- [getViewDataItem(unlockConfig, params)]
    return ::handyman.renderCached("gui/items/trophyDesc", view)
  }
}

//  g_unlock_view functions 'unlockConfig' param is unlocks data table, created through
//  build_conditions_config(unlockBlk)
//  ::build_unlock_desc(unlockConfig)

g_unlock_view.fillUnlockConditions <- function fillUnlockConditions(unlockConfig, unlockObj, context)
{
  if( ! ::checkObj(unlockObj))
    return

  local hiddenObj = unlockObj.findObject("hidden_block")
  if (!::check_obj(hiddenObj))
    return

  local guiScene = unlockObj.getScene()
  local hiddenContent = ""
  local expandImgObj = unlockObj.findObject("expandImg")

  local isBitMode = ::UnlockConditions.isBitModeType(unlockConfig.type)
  local names = ::UnlockConditions.getLocForBitValues(unlockConfig.type, unlockConfig.names, unlockConfig.hasCustomUnlockableList)

  guiScene.replaceContentFromText(hiddenObj, "", 0, context)
  for(local i = 0; i < names.len(); i++)
  {
    local unlockId = unlockConfig.names[i]
    local unlock = ::g_unlocks.getUnlockById(unlockId)
    if(unlock && !::is_unlock_visible(unlock) && !(unlock?.showInDesc ?? false))
      continue

    local isUnlocked = isBitMode? is_bit_set(unlockConfig.curVal, i) : ::is_unlocked_scripted(-1, unlockId)
    hiddenContent += "unlockCondition {"
    hiddenContent += ::format("textarea {text:t='%s' } \n %s \n",
                              ::g_string.stripTags(names[i]),
                              ("image" in unlockConfig && unlockConfig.image != "" ? "" : "unlockImg{}"))
    hiddenContent += format("unlocked:t='%s'; ", (isUnlocked ? "yes" : "no"))
    if(unlockConfig.type == "char_resources")
    {
      local decorator = ::g_decorator.getDecoratorById(unlockConfig.names[i])
      if (decorator)
        hiddenContent += DECORATION.getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
    }
    else if(unlock)
      hiddenContent += UNLOCK.getMarkup(unlock.id, {showProgress=true})

    hiddenContent += "}"
  }
  if(hiddenContent != "")
  {
    expandImgObj.show(true)
    guiScene.appendWithBlk(hiddenObj, hiddenContent, context)
  }
  else
    expandImgObj.show(false)
}

g_unlock_view.fillUnlockProgressBar <- function fillUnlockProgressBar(unlockConfig, unlockObj)
{
  local obj = unlockObj.findObject("progress_bar")
  local data = unlockConfig.getProgressBarData()
  obj.show(data.show)
  if (data.show)
    obj.setValue(data.value)
}

g_unlock_view.fillUnlockDescription <- function fillUnlockDescription(unlockConfig, unlockObj)
{
  unlockObj.findObject("description")
    .setValue(::getUnlockDescription(unlockConfig, { showMult = false }))

  local showUnitsBtnObj = unlockObj.findObject("show_units_btn")
  showUnitsBtnObj.show(hasActiveUnlock(unlockConfig.id, getShopDiffCode())
    && getUnitListByUnlockId(unlockConfig.id).len() > 0)
  showUnitsBtnObj.unlockId = unlockConfig.id

  local mainCond = ::UnlockConditions.getMainProgressCondition(unlockConfig.conditions)
  local mulText = ::UnlockConditions.getMultipliersText(mainCond ?? {})
  unlockObj.findObject("mult_desc").setValue(mulText)
}

g_unlock_view.fillReward <- function fillReward(unlockConfig, unlockObj)
{
  local id = unlockConfig.id
  local rewardObj = unlockObj.findObject("reward")
  if( ! ::checkObj(rewardObj))
    return
  local rewardText = ""
  local tooltipId = REWARD_TOOLTIP.getTooltipId(id)
  local unlockType = unlockConfig.unlockType
  if(::isInArray(unlockType, [::UNLOCKABLE_DECAL, ::UNLOCKABLE_MEDAL, ::UNLOCKABLE_SKIN]))
  {
    rewardText = ::get_unlock_name_text(unlockType, id)
  }
  else if (unlockType == ::UNLOCKABLE_TITLE)
    rewardText = ::format(::loc("reward/title"), ::get_unlock_name_text(unlockType, id))
  else if (unlockType == ::UNLOCKABLE_TROPHY)
  {
    local item = ::ItemsManager.findItemById(id, itemType.TROPHY)
    if (item)
    {
      rewardText = item.getName() //colored
      tooltipId = ::g_tooltip.getIdItem(id)
    }
  }

  if (rewardText != "")
    rewardText = ::loc("challenge/reward") + " " + ::colorize("activeTextColor", rewardText)

  local tooltipObj = rewardObj.findObject("tooltip")
  if(::checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  local showStages = ("stages" in unlockConfig) && (unlockConfig.stages.len() > 1)
  if ((showStages && unlockConfig.curStage >= 0) || ("reward" in unlockConfig))
    rewardText = getRewardText(unlockConfig, unlockConfig.curStage)

  rewardObj.show(rewardText != "")
  rewardObj.setValue(rewardText)
}

g_unlock_view.fillStages <- function fillStages(unlockConfig, unlockObj, context)
{
  if (!unlockObj?.isValid())
    return
  local stagesObj = unlockObj.findObject("stages")
  if (!stagesObj?.isValid())
    return

  local currentStage = 0
  local textStages = ""
  for(local i = 0; i < unlockConfig.stages.len(); i++)
  {
    local stage = unlockConfig.stages[i]
    local curValStage = (unlockConfig.curVal > stage.val)? stage.val : unlockConfig.curVal
    local isUnlockedStage = curValStage >= stage.val
    currentStage = isUnlockedStage ? i + 1 : currentStage
    textStages += "unlocked { {parity} substrateImg {} img { background-image:t='{image}' } {tooltip} }"
      .subst({
        image = isUnlockedStage ? $"#ui/gameuiskin#stage_unlocked_{i+1}" : $"#ui/gameuiskin#stage_locked_{i+1}"
        parity = i % 2 == 0 ? "class:t='even';" : "class:t='odd';"
        tooltip = UNLOCK_SHORT.getMarkup(unlockConfig.id, {stage=i})
      })
  }
  unlockObj.getScene().replaceContentFromText(stagesObj, textStages, textStages.len(), context)
  if (currentStage != 0)
    unlockConfig.curStage = currentStage
}

g_unlock_view.fillUnlockTitle <- function fillUnlockTitle(unlockConfig, unlockObj)
{
  local title = getUnlockTitle(unlockConfig)
  unlockObj.findObject("achivment_title").setValue(title)
  return title
}

g_unlock_view.getRewardText <- function getRewardText(unlockConfig, stageNum)
{
  if (("stages" in unlockConfig) && (stageNum in unlockConfig.stages))
    unlockConfig = unlockConfig.stages[stageNum]

  local reward = ::getTblValue("reward", unlockConfig, null)
  local text = reward? reward.tostring() : ""
  if (text != "")
    return ::loc("challenge/reward") + " " + "<color=@activeTextColor>" + text + "</color>"
  return ""
}

g_unlock_view.fillUnlockFav <- function fillUnlockFav(unlockId, unlockObj)
{
  local checkboxFavorites = unlockObj.findObject("checkbox_favorites")
  if( ! ::checkObj(checkboxFavorites))
    return
  checkboxFavorites.unlockId = unlockId
  ::g_unlock_view.fillUnlockFavCheckbox(checkboxFavorites)
}

g_unlock_view.fillUnlockFavCheckbox <- function fillUnlockFavCheckbox(obj)
{
  local isUnlockInFavorites = obj.unlockId in ::g_unlocks.getFavoriteUnlocks()
  obj.setValue(isUnlockInFavorites)
  obj.tooltip = ::loc( isUnlockInFavorites ?
    "mainmenu/UnlockAchievementsRemoveFromFavorite/hint" :
    "mainmenu/UnlockAchievementsToFavorite/hint")
}

g_unlock_view.fillUnlockPurchaseButton <- function fillUnlockPurchaseButton(unlockData, unlockObj)
{
  local purchButtonObj = unlockObj.findObject("purchase_button")
  if (!::check_obj(purchButtonObj))
    return

  local unlockId = unlockData.id
  purchButtonObj.unlockId = unlockId
  local isUnlocked = ::is_unlocked_scripted(-1, unlockId)
  local haveStages = ::getTblValue("stages", unlockData, []).len() > 1
  local cost = ::get_unlock_cost(unlockId)
  local canSpendGold = cost.gold == 0 || ::has_feature("SpendGold")
  local isPurchaseTime = ::g_unlocks.isVisibleByTime(unlockId, false)

  local show = isPurchaseTime && canSpendGold && !haveStages && !isUnlocked && !cost.isZero()
  purchButtonObj.show(show)
  if (show)
    placePriceTextToButton(unlockObj, "purchase_button", ::loc("mainmenu/btnBuy"), cost)

  if (!show && !cost.isZero())
  {
    local msg = "UnlocksPurchase: can't purchase " + unlockId + ": "
    if (!canSpendGold)
      msg += "can't spend gold"
    else if (haveStages)
      msg += "has stages = " + unlockData.stages.len()
    else if (isUnlocked)
      msg += "already unlocked"
    else if (!isPurchaseTime)
    {
      msg += "not purchase time. see time before."
      ::g_unlocks.debugLogVisibleByTimeInfo(unlockId)
    }
    dagor.debug(msg)
  }
}
