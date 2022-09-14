let { format } = require("string")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { DECORATION, UNLOCK, REWARD_TOOLTIP, UNLOCK_SHORT
} = require("%scripts/utils/genericTooltipTypes.nut")
let { getUnlockLocName, getSubUnlockLocName,
  getUnlockDesc, getUnlockConditionsText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { hasActiveUnlock, getUnitListByUnlockId } = require("%scripts/unlocks/unlockMarkers.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let MAX_STAGES_NUM = 10 // limited by images gui/hud/gui_skin/unlock_icons/stage_(un)locked_N.png

::g_unlock_view <- {
  function getUnlockTitle(unlockConfig) {
    local name = unlockConfig.useSubUnlockName ? getSubUnlockLocName(unlockConfig)
      : unlockConfig.locId != "" ? getUnlockLocName(unlockConfig)
      : ::get_unlock_name_text(unlockConfig.unlockType, unlockConfig.id)
    if (name == "")
      name = ::get_unlock_type_text(unlockConfig.unlockType, unlockConfig.id)
    let stage = (unlockConfig.needToAddCurStageToName && unlockConfig.curStage >= 0)
      ? unlockConfig.curStage + (::is_unlocked_scripted(-1, unlockConfig.id) ? 0 : 1)
      : 0
    return $"{name} {::roman_numerals[stage]}"
  }

  function getChapterAndGroupText(unlockBlk) {
    let chapterAndGroupText = []
    if ("chapter" in unlockBlk)
      chapterAndGroupText.append(::loc($"unlocks/chapter/{unlockBlk.chapter}"))
    if ((unlockBlk?.group ?? "") != "") {
      local locId = $"unlocks/group/{unlockBlk.group}"
      let parentUnlock = ::g_unlocks.getUnlockById(unlockBlk.group)
      if (parentUnlock?.chapter == unlockBlk?.chapter)
        locId = $"{parentUnlock.id}/name"
      chapterAndGroupText.append(::loc(locId))
    }
    return chapterAndGroupText.len() > 0
      ? $"({", ".join(chapterAndGroupText, true)})"
      : ""
  }

  function getSubunlocksView(cfg) {
    let isBitMode = ::UnlockConditions.isBitModeType(cfg.type)
    let titles = ::UnlockConditions.getLocForBitValues(cfg.type, cfg.names, cfg.hasCustomUnlockableList)

    let subunlocks = []
    foreach (idx, title in titles) {
      let unlockId = cfg.names[idx]
      let unlockBlk = ::g_unlocks.getUnlockById(unlockId)
      if(!::is_unlock_visible(unlockBlk) && !(unlockBlk?.showInDesc ?? false))
        continue

      let isUnlocked = isBitMode ? is_bit_set(cfg.curVal, idx) : ::is_unlocked_scripted(-1, unlockId)
      subunlocks.append({ title, isUnlocked })
    }

    return (subunlocks.len() > 0) ? { subunlocks } : null
  }

  function fillSimplifiedUnlockInfo(unlockBlk, unlockObj, context) {
    let isShowUnlock = unlockBlk != null && ::is_unlock_visible(unlockBlk)
    unlockObj.show(isShowUnlock)
    if(!isShowUnlock)
      return

    let unlockConfig = ::build_conditions_config(unlockBlk)
    ::build_unlock_desc(unlockConfig)

    fillUnlockTitle(unlockConfig, unlockObj)
    fillUnlockImage(unlockConfig, unlockObj)
    fillUnlockProgressBar(unlockConfig, unlockObj)
    fillReward(unlockConfig, unlockObj)
    fillUnlockConditions(unlockConfig, unlockObj, context)
    updateLockStatus(unlockConfig, unlockObj)

    let closeBtn = unlockObj.findObject("removeFromFavoritesBtn")
    if(::check_obj(closeBtn))
      closeBtn.unlockId = unlockBlk.id

    let tooltipObj = unlockObj.findObject("unlock_tooltip")
    tooltipObj.tooltipId = UNLOCK_SHORT.getTooltipId(unlockConfig.id, {
      showChapter = true
    })
  }

  function getUnlockImageConfig(unlockConfig)
  {
    let unlockType = getUnlockType(unlockConfig)
    let isUnlocked = ::is_unlocked_scripted(unlockType, unlockConfig.id)
    local iconStyle = unlockConfig?.iconStyle ?? ""
    let image = unlockConfig?.image ?? ""

    if (iconStyle=="" && image=="")
      iconStyle = (isUnlocked? "default_unlocked" : "default_locked") +
          ((isUnlocked || unlockConfig.curStage < 1)? "" : "_stage_" + unlockConfig.curStage)

    let effect = isUnlocked || needShowLockIcon(unlockConfig) ? ""
      : unlockConfig.lockStyle != "" ? unlockConfig.lockStyle
      : unlockType == ::UNLOCKABLE_MEDAL ? "darkened"
      : "desaturated"

    return {
      style = iconStyle
      image = unlockType == ::UNLOCKABLE_PILOT ? (unlockConfig?.descrImage ?? image) : image
      ratio = unlockConfig?.imgRatio ?? 1.0
      params = unlockConfig?.iconParams
      effect
    }
  }

  function fillUnlockImage(unlockConfig, unlockObj)
  {
    let iconObj = unlockObj.findObject("achivment_ico")
    let imgConfig = getUnlockImageConfig(unlockConfig)
    iconObj.effectType = imgConfig.effect

    if (unlockConfig?.iconData) {
      ::LayersIcon.replaceIconByIconData(iconObj, unlockConfig.iconData)
      return
    }

    ::LayersIcon.replaceIcon(
      iconObj,
      imgConfig.style,
      imgConfig.image,
      imgConfig.ratio,
      null/*defStyle*/,
      imgConfig.params
    )
  }

  function updateLockStatus(cfg, obj) {
    let needLockIcon = needShowLockIcon(cfg)
    let lockObj = obj.findObject("lock_icon")
    lockObj.show(needLockIcon)
  }

  function needShowLockIcon(cfg) {
    if (cfg?.isTrophyLocked)
      return true

    let unlockType = getUnlockType(cfg)
    let isUnlocked = ::is_unlocked_scripted(unlockType, cfg.id)
    if (isUnlocked)
      return false

    return cfg.lockStyle == "lock"
      || unlockType == ::UNLOCKABLE_DECAL
      || unlockType == ::UNLOCKABLE_PILOT
  }

  function getUnitActionButtonsView(unit) {
    if ((unit.isInShop ?? false) == false)
      return []

    let gcb = globalCallbacks.UNIT_PREVIEW
    return [{
      image = "#ui/gameuiskin#btn_preview.svg"
      tooltip = "#mainmenu/btnPreview"
      funcName = gcb.cbName
      actionParamsMarkup = gcb.getParamsMarkup({ unitId = unit.name })
    }]
  }

  function getUnitViewDataItem(unlockConfig, params = {}) {
    let unit = ::getAircraftByName(unlockConfig.id)
    if (!unit)
      return null

    let ignoreAvailability = params?.ignoreAvailability
    let isBought = ignoreAvailability ? false : unit.isBought()
    let buttons = getUnitActionButtonsView(unit)
    let receiveOnce = "mainmenu/receiveOnlyOnce"

    let unitPlate = ::build_aircraft_item(unit.name, unit, {
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

    let gcb = globalCallbacks.DECORATOR_PREVIEW
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
    let unlockType = getUnlockType(unlockConfig)
    let decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
    let decorator = ::g_decorator.getDecorator(unlockConfig.id, decoratorType)
    if (!decorator)
      return {}

    let nameColor = decorator ? decorator.getRarityColor() : "activeTextColor"
    let isHave = params?.ignoreAvailability ? false : decoratorType.isPlayerHaveDecorator(unlockConfig.id)
    let buttons = getDecoratorActionButtonsView(decorator, decoratorType)
    let locName = decoratorType.getLocName(unlockConfig.id, true)

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
    let unlockType = getUnlockType(unlockConfig)
    if (unlockType == ::UNLOCKABLE_AIRCRAFT)
      return getUnitViewDataItem(unlockConfig, params)

    if (unlockType == ::UNLOCKABLE_DECAL
      || unlockType == ::UNLOCKABLE_SKIN
      || unlockType == ::UNLOCKABLE_ATTACHABLE)
      return getDecoratorViewDataItem(unlockConfig, params)

    if (unlockType == ::UNLOCKABLE_PILOT)
      return getPilotViewDataItem(unlockConfig)

    local icon = "#ui/gameuiskin#item_type_placeholder.svg"
    local title = unlockConfig.name

    if (unlockType == ::UNLOCKABLE_TITLE)
    {
      icon = "#ui/gameuiskin#item_type_unlock.svg"
      title = format(::loc("reward/title"), title)
    }

    return {
      icon = icon
      title = title
    }
  }

  function getViewItem(unlockConfig, params = {}) {
    let view = params
    view.list <- [getViewDataItem(unlockConfig, params)]
    return ::handyman.renderCached("%gui/items/trophyDesc", view)
  }
}

//  g_unlock_view functions 'unlockConfig' param is unlocks data table, created through
//  build_conditions_config(unlockBlk)
//  ::build_unlock_desc(unlockConfig)

g_unlock_view.fillUnlockConditions <- function fillUnlockConditions(unlockConfig, unlockObj, context)
{
  if( ! ::checkObj(unlockObj))
    return

  let hiddenObj = unlockObj.findObject("hidden_block")
  if (!::check_obj(hiddenObj))
    return

  let guiScene = unlockObj.getScene()
  local hiddenContent = ""
  let expandImgObj = unlockObj.findObject("expandImg")

  let isBitMode = ::UnlockConditions.isBitModeType(unlockConfig.type)
  let names = ::UnlockConditions.getLocForBitValues(unlockConfig.type, unlockConfig.names, unlockConfig.hasCustomUnlockableList)

  guiScene.replaceContentFromText(hiddenObj, "", 0, context)
  for(local i = 0; i < names.len(); i++)
  {
    let unlockId = unlockConfig.names[i]
    let unlock = ::g_unlocks.getUnlockById(unlockId)
    if(unlock && !::is_unlock_visible(unlock) && !(unlock?.showInDesc ?? false))
      continue

    let isUnlocked = isBitMode? is_bit_set(unlockConfig.curVal, i) : ::is_unlocked_scripted(-1, unlockId)
    hiddenContent += "unlockCondition {"
    hiddenContent += format("textarea {text:t='%s' } \n %s \n",
                              ::g_string.stripTags(names[i]),
                              ("image" in unlockConfig && unlockConfig.image != "" ? "" : "unlockImg{}"))
    hiddenContent += format("unlocked:t='%s'; ", (isUnlocked ? "yes" : "no"))
    if(unlockConfig.type == "char_resources")
    {
      let decorator = ::g_decorator.getDecoratorById(unlockConfig.names[i])
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
  let obj = unlockObj.findObject("progress_bar")
  let data = unlockConfig.getProgressBarData()
  obj.show(data.show)
  if (data.show)
    obj.setValue(data.value)
}

g_unlock_view.fillUnlockDescription <- function fillUnlockDescription(unlockConfig, unlockObj)
{
  unlockObj.findObject("description").setValue(getUnlockDesc(unlockConfig))

  let curVal = ::g_unlocks.isUnlockComplete(unlockConfig) ? null : unlockConfig.curVal
  let mainCondText = ::UnlockConditions.getMainConditionText(unlockConfig.conditions, curVal, unlockConfig.maxVal)
  unlockObj.findObject("main_cond").setValue(mainCondText)

  let mainCond = ::UnlockConditions.getMainProgressCondition(unlockConfig.conditions)
  let mulText = ::UnlockConditions.getMultipliersText(mainCond ?? {})
  unlockObj.findObject("mult_desc").setValue(mulText)

  unlockObj.findObject("conditions").setValue(getUnlockConditionsText(unlockConfig, {
    withMainCondition = false
    showMult = false
  }))

  let showUnitsBtnObj = unlockObj.findObject("show_units_btn")
  showUnitsBtnObj.show(hasActiveUnlock(unlockConfig.id, getShopDiffCode())
    && getUnitListByUnlockId(unlockConfig.id).len() > 0)
  showUnitsBtnObj.unlockId = unlockConfig.id

  let showPrizesBtnObj = unlockObj.findObject("show_prizes_btn")
  showPrizesBtnObj.show(unlockConfig?.trophyId != null)
  showPrizesBtnObj.trophyId = unlockConfig?.trophyId
}

g_unlock_view.fillReward <- function fillReward(unlockConfig, unlockObj)
{
  let id = unlockConfig.id
  let rewardObj = unlockObj.findObject("reward")
  if( ! ::checkObj(rewardObj))
    return
  local rewardText = ""
  local tooltipId = REWARD_TOOLTIP.getTooltipId(id)
  let unlockType = unlockConfig.unlockType
  if(::isInArray(unlockType, [::UNLOCKABLE_DECAL, ::UNLOCKABLE_MEDAL, ::UNLOCKABLE_SKIN]))
  {
    rewardText = ::get_unlock_name_text(unlockType, id)
  }
  else if (unlockType == ::UNLOCKABLE_TITLE)
    rewardText = format(::loc("reward/title"), ::get_unlock_name_text(unlockType, id))
  else if (unlockType == ::UNLOCKABLE_TROPHY)
  {
    let item = ::ItemsManager.findItemById(id, itemType.TROPHY)
    if (item)
    {
      rewardText = item.getName() //colored
      tooltipId = ::g_tooltip.getIdItem(id)
    }
  }

  if (rewardText != "")
    rewardText = ::loc("challenge/reward") + " " + ::colorize("activeTextColor", rewardText)

  let tooltipObj = rewardObj.findObject("tooltip")
  if(::checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  let showStages = ("stages" in unlockConfig) && (unlockConfig.stages.len() > 1)
  if ((showStages && unlockConfig.curStage >= 0) || ("reward" in unlockConfig))
    rewardText = getRewardText(unlockConfig, unlockConfig.curStage)

  rewardObj.show(rewardText != "")
  rewardObj.setValue(rewardText)
}

g_unlock_view.fillStages <- function fillStages(unlockConfig, unlockObj, context)
{
  if (!unlockObj?.isValid())
    return
  let stagesObj = unlockObj.findObject("stages")
  if (!stagesObj?.isValid())
    return

  local currentStage = 0
  local textStages = ""
  let needToFillStages = unlockConfig.needToFillStages && unlockConfig.stages.len() <= MAX_STAGES_NUM
  for (local i = 0; i < unlockConfig.stages.len(); i++) {
    let stage = unlockConfig.stages[i]
    let curValStage = (unlockConfig.curVal > stage.val)? stage.val : unlockConfig.curVal
    let isUnlockedStage = curValStage >= stage.val
    currentStage = isUnlockedStage ? i + 1 : currentStage
    if (needToFillStages) {
      textStages += "unlocked { {parity} substrateImg {} img { background-image:t='{image}' } {tooltip} }"
        .subst({
          image = isUnlockedStage ? $"#ui/gameuiskin#stage_unlocked_{i+1}.png" : $"#ui/gameuiskin#stage_locked_{i+1}.png"
          parity = i % 2 == 0 ? "class:t='even';" : "class:t='odd';"
          tooltip = UNLOCK_SHORT.getMarkup(unlockConfig.id, {stage=i})
        })
    }
  }
  unlockObj.getScene().replaceContentFromText(stagesObj, textStages, textStages.len(), context)
  if (currentStage != 0)
    unlockConfig.curStage = currentStage
}

g_unlock_view.fillUnlockTitle <- function fillUnlockTitle(unlockConfig, unlockObj)
{
  let title = getUnlockTitle(unlockConfig)
  unlockObj.findObject("achivment_title").setValue(title)
}

g_unlock_view.getRewardText <- function getRewardText(unlockConfig, stageNum)
{
  if (("stages" in unlockConfig) && (stageNum in unlockConfig.stages))
    unlockConfig = unlockConfig.stages[stageNum]

  let reward = ::getTblValue("reward", unlockConfig, null)
  let text = reward? reward.tostring() : ""
  if (text != "")
    return ::loc("challenge/reward") + " " + "<color=@activeTextColor>" + text + "</color>"
  return ""
}

g_unlock_view.fillUnlockFav <- function fillUnlockFav(unlockId, unlockObj)
{
  let checkboxFavorites = unlockObj.findObject("checkbox_favorites")
  if( ! ::checkObj(checkboxFavorites))
    return
  checkboxFavorites.unlockId = unlockId
  ::g_unlock_view.fillUnlockFavCheckbox(checkboxFavorites)
}

g_unlock_view.fillUnlockFavCheckbox <- function fillUnlockFavCheckbox(obj)
{
  let isUnlockInFavorites = obj.unlockId in ::g_unlocks.getFavoriteUnlocks()
  obj.setValue(isUnlockInFavorites)
  obj.tooltip = ::loc( isUnlockInFavorites ?
    "mainmenu/UnlockAchievementsRemoveFromFavorite/hint" :
    "mainmenu/UnlockAchievementsToFavorite/hint")
}

g_unlock_view.fillUnlockPurchaseButton <- function fillUnlockPurchaseButton(unlockData, unlockObj)
{
  let purchButtonObj = unlockObj.findObject("purchase_button")
  if (!::check_obj(purchButtonObj))
    return

  let unlockId = unlockData.id
  purchButtonObj.unlockId = unlockId
  let isUnlocked = ::is_unlocked_scripted(-1, unlockId)
  let haveStages = ::getTblValue("stages", unlockData, []).len() > 1
  let cost = ::get_unlock_cost(unlockId)
  let canSpendGold = cost.gold == 0 || ::has_feature("SpendGold")
  let isPurchaseTime = ::g_unlocks.isVisibleByTime(unlockId, false)

  let show = isPurchaseTime && canSpendGold && !haveStages && !isUnlocked && !cost.isZero()
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
    ::dagor.debug(msg)
  }
}
