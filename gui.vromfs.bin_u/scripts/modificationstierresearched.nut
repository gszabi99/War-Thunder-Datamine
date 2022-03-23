let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")

::gui_start_mod_tier_researched <- function gui_start_mod_tier_researched(config)
{
  foreach(param, value in config)
  {
    if (::u.isArray(value) && value.len() == 1)
      config[param] = value[0]
  }

  let unit = ::getAircraftByName(::getTblValue("unit", config))
  if (!unit)
    return

  local wndParams = {
    unit = unit
    unitInResearch = config?.resUnit
    tier = config?.tier ?? []
    expReward = ::Cost().setRp(config?.expToInvUnit ?? 0)
  }
  ::gui_start_modal_wnd(::gui_handlers.ModificationsTierResearched, wndParams)
}

::gui_handlers.ModificationsTierResearched <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  unit = null
  tier = null
  expReward = null
  unitInResearch = null

  postConfig = null
  postCustomConfig = null

  function initScreen()
  {
    if (!expReward)
      expReward = ::Cost()

    if (::u.isArray(unitInResearch))  //fix crash, but need to fix combine function to correct show multiple researched units
      unitInResearch = unitInResearch[0] //but this is a really reare case, maybe no need to care about

    let isLastResearchedModule = ::shop_get_researchable_module_name(unit.name) == ""
    local locTextId = "modifications/full_tier_researched"
    if (isLastResearchedModule)
      locTextId = "modifications/full_unit_researched"

    let nameObj = scene.findObject("award_name")
    if (::checkObj(nameObj))
      nameObj.setValue(::loc(locTextId + "/header"))

    let imgObj = scene.findObject("award_image")
    if (::checkObj(imgObj))
    {
      local imageId = ::getUnitCountry(unit) + "_" + ::getUnitTypeTextByUnit(unit).tolower()
      if (isLastResearchedModule)
        imageId += "_unit"
      else
        imageId += "_modification"

      local imagePath = ::get_country_flag_img(imageId)
      if (imagePath == "")
        imagePath = "#ui/images/elite_" + (unit?.isTank()? "tank" : "vehicle") + "_revard.jpg?P1"

      imgObj["background-image"] = imagePath
    }

    local tierText = ""
    if (::u.isArray(tier))
    {
      if (tier.len() == 1)
        tierText = tier.top()
      else if (tier.len() == 2)
        tierText = ::get_roman_numeral(tier[0]) + ::loc("ui/comma") + ::get_roman_numeral(tier[1])
      else
      {
        local maxTier = 0
        local minTier = tier.len()
        foreach(t in tier)
        {
          maxTier = ::max(maxTier, t)
          minTier = ::min(minTier, t)
        }
        tierText = ::get_roman_numeral(minTier) + ::loc("ui/mdash") + ::get_roman_numeral(maxTier)
      }
    }
    else
      tierText = ::get_roman_numeral(tier)

    local msgText = ::loc(locTextId, { tier = tierText, unitName = ::getUnitName(unit) })
    if (!expReward.isZero())
    {
      msgText += "\n" + ::loc("reward") + ::loc("ui/colon") + ::loc("userlog/open_all_in_tier/resName",
                        { resUnitExpInvest = expReward.tostring(),
                          resUnitName = ::getUnitName(unitInResearch)
                        })
    }

    let descObj = scene.findObject("award_desc")
    if (::checkObj(descObj))
    {
      descObj["text-align"] = "center"
      descObj.setValue(msgText)
    }

    showSceneBtn("btn_upload_facebook_wallPost", ::has_feature("FacebookWallPost") && isLastResearchedModule)
    if (isLastResearchedModule)
    {
      postConfig = {
        locId = "researched_unit"
        subType = ps4_activity_feed.RESEARCHED_UNIT
        backgroundPost = true
      }

      postCustomConfig = {
        requireLocalization = ["unitName", "country"]
        unitName = unit.name + "_shop"
        rank = ::get_roman_numeral(unit?.rank ?? -1)
        country = ::getUnitCountry(unit)
        link = ::format(::loc("url/wiki_objects"), unit.name)
      }
    }
  }

  function onFacebookLoginAndPostMessage(obj)
  {
    activityFeedPostFunc(postConfig, postCustomConfig, bit_activity.FACEBOOK)
    obj.enable(false)
  }

  function onOk()
  {
    goBack()
  }

  function afterModalDestroy()
  {
    ::broadcastEvent("UpdateResearchingUnit", { unitName = unitInResearch })
    ::checkNonApprovedResearches(true)
    activityFeedPostFunc(postConfig, postCustomConfig, bit_activity.PS4_ACTIVITY_FEED)
  }

  function onUseDecorator() {}
  function onUnitActivate() {}
}
