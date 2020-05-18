::g_unlock_view <- {
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
    if ((unlockBlk?.group ?? "") != "")
      chapterAndGroupText.append(::loc($"unlocks/group/{unlockBlk.group}"))

    unlockObj.tooltip = "\n".join([::colorize("unlockHeaderColor", title),
      chapterAndGroupText.len() > 0 ? $"({", ".join(chapterAndGroupText, true)})" : "",
      unlockConfig?.stagesText ?? "",
      ::UnlockConditions.getConditionsText(unlockConfig.conditions,
        unlockConfig.showProgress ? unlockConfig.curVal : null, unlockConfig.maxVal)
    ], true)
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
  local names = ::UnlockConditions.getLocForBitValues(unlockConfig.type, unlockConfig.names)
  guiScene.replaceContentFromText(hiddenObj, "", 0, context)
  for(local i = 0; i < names.len(); i++)
  {
    local isUnlocked = unlockConfig.curVal & (1 << i)
    hiddenContent += "unlockCondition {"
    hiddenContent += ::format("textarea {text:t='%s' } \n %s \n",
                              ::g_string.stripTags(names[i]),
                              ("image" in unlockConfig && unlockConfig.image != "" ? "" : "unlockImg{}"))
    hiddenContent += format("unlocked:t='%s'; ", (isUnlocked ? "yes" : "no"))
    if(unlockConfig.type == "char_resources")
    {
      local decorator = ::g_decorator.getDecoratorById(unlockConfig.names[i])
      if (decorator)
        hiddenContent += ::g_tooltip_type.DECORATION.getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
    }
    else
    {
      local unlock = ::g_unlocks.getUnlockById(unlockConfig.names[i])
      if(unlock)
        hiddenContent += ::g_tooltip_type.UNLOCK.getMarkup(unlock.id, {showProgress=true})
    }

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
  unlockObj.findObject("description").setValue(getUnlockDescription(unlockConfig))
}

g_unlock_view.fillUnlockImage <- function fillUnlockImage(unlockConfig, unlockObj)
{
  local unlockType = unlockConfig.unlockType
  local isUnlocked = ::is_unlocked_scripted(-1, unlockConfig.id)
  local iconObj = unlockObj.findObject("achivment_ico")
  iconObj.decal_locked = (!isUnlocked && (unlockType == ::UNLOCKABLE_DECAL || unlockType == ::UNLOCKABLE_MEDAL) ) ? "yes" : "no"
  iconObj.achievement_locked = (!isUnlocked && unlockConfig.curStage <= 0 &&
      unlockType != ::UNLOCKABLE_MEDAL && unlockType != ::UNLOCKABLE_DECAL) ? "yes" : "no"

  local iconStyle = unlockConfig.iconStyle
  local image = unlockConfig.image

  if (iconStyle=="" && image=="")
  {
    iconStyle = (isUnlocked? "default_unlocked" : "default_locked") +
        ((isUnlocked || unlockConfig.curStage < 1)? "" : "_stage_" + unlockConfig.curStage)
  }

  ::LayersIcon.replaceIcon(
    iconObj,
    iconStyle,
    image,
    unlockConfig.imgRatio,
    null/*defStyle*/,
    unlockConfig.iconParams
  )
}

g_unlock_view.fillReward <- function fillReward(unlockConfig, unlockObj)
{
  local id = unlockConfig.id
  local rewardObj = unlockObj.findObject("reward")
  if( ! ::checkObj(rewardObj))
    return
  local rewardText = ""
  local tooltipId = ::g_tooltip_type.REWARD_TOOLTIP.getTooltipId(id)
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
  if( ! ::checkObj(unlockObj))
    return
  local guiScene = unlockObj.getScene()
  local currentStage = 0
  local stageLokedIcon = "#ui/gameuiskin#stage_locked_"
  local stageUnlokedIcon = "#ui/gameuiskin#stage_unlocked_"
  local unlocedStageText = "unlocked { substrateImg {} img { background-image:t='" + stageUnlokedIcon
  local locedStageText = "unlocked { substrateImg {} img { background-image:t='" + stageLokedIcon
  local textStages = ""
  local stagesObj = unlockObj.findObject("stages")
  if( ! ::checkObj(stagesObj))
    return
  guiScene.replaceContentFromText(stagesObj, "", 0, context)
  for(local i = 0; i < unlockConfig.stages.len(); i++)
  {
    local stage = unlockConfig.stages[i]
    local curValStage = (unlockConfig.curVal > stage.val)? stage.val : unlockConfig.curVal
    local isUnlockedStage = curValStage >= stage.val
    local stageClass = i % 2 == 0 ? "class:t='even';" : "class:t='odd';"
    currentStage = isUnlockedStage ? i + 1 : currentStage
    textStages += (isUnlockedStage ? unlocedStageText  : locedStageText ) + (i + 1) + "';}" +
                   stageClass +
                   ::g_tooltip_type.UNLOCK_SHORT.getMarkup(unlockConfig.id, {stage=i}) +"}"
  }
  if(textStages != "")
    guiScene.appendWithBlk(stagesObj, textStages, context)
  if (currentStage != 0)
    unlockConfig.curStage = currentStage
}

g_unlock_view.fillUnlockTitle <- function fillUnlockTitle(unlockConfig, unlockObj)
{
  local name = ""
  local isUnlocked = ::is_unlocked_scripted(-1, unlockConfig.id)
  name = unlockConfig.locId != "" ? ::get_locId_name(unlockConfig) : ::get_unlock_name_text(unlockConfig.unlockType, unlockConfig.id)
  local title = name + " " + ::roman_numerals[(unlockConfig.curStage >= 0 ? unlockConfig.curStage + (isUnlocked ? 0 : 1) : 0)]
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
  local checkboxFavorites = unlockObj.findObject("checkbox-favorites")
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
    ::placePriceTextToButton(unlockObj, "purchase_button", ::loc("mainmenu/btnBuy"), cost)

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