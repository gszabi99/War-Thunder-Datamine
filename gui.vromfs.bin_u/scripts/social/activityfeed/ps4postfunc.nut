local psn = require("sonyLib/webApi.nut")
local statsd = require("statsd")

local requestsTable = {
  player = "$USER_NAME_OR_ID",
  count = "$STORY_COUNT",
  onlineUserId = "$ONLINE_ID",
  productName = "$PRODUCT_NAME",
  titleName = "$TITLE_NAME",
  fiveStarValue = "$FIVE_STAR_VALUE",
  sourceCount = "$SOURCE_COUNT"
}

// specialization getters below expect valid data, validated by the caller
local function getActivityFeedImageByParam(feed, imagesConfig)
{
  local config = imagesConfig.other?[feed.blkParamName]

  if (u.isString(config))
    return imagesConfig.mainPart + config

  if (u.isDataBlock(config) && config?.name)
  {
    local url = imagesConfig.mainPart + config.name + feed.imgSuffix
    if (config?.variations)
      url += ::format("_%.2d", ::math.rnd() % config.variations + 1)
    return url
  }

  ::dagor.debug("getActivityFeedImagesByParam: no image name in '"+feed.blkParamName)
  debugTableData(config)
  return ""
}

local function getActivityFeedImageByCountry(feed, imagesConfig) {
  local aircraft = ::getAircraftByName(feed.unitNameId)
  local esUnitType = ::get_es_unit_type(aircraft)
  local unit = ::getUnitTypeText(esUnitType)
  local country = feed.country

  local variants = imagesConfig?[country]?[unit]
  if (u.isDataBlock(variants))
    return imagesConfig.mainPart + variants.getParamValue(::math.rnd() % variants.paramCount())

  ::dagor.debug("getActivityFeedImagesByCountry: no config for '"+country+"/"+unit+" ("+feed.unitNameId+")")
  debugTableData(imagesConfig)
  return ""
}

local function getActivityFeedImages(feed) {
  local guiBlk = ::configs.GUI.get()
  local imagesConfig = guiBlk?.activity_feed_image_url
  if (u.isEmpty(imagesConfig))
  {
    ::dagor.debug("getActivityFeedImages: empty or missing activity_feed_image_url block in gui.blk")
    return null
  }

  local feedUrl = imagesConfig?.mainPart
  local imgExt = imagesConfig?.fileExtension
  if (!feedUrl || !imgExt)
  {
    ::dagor.debug("getActivityFeedImages: invalid feed config, url base '"+feedUrl+"', image extension '"+imgExt)
    debugTableData(imagesConfig)
    return null
  }

  local logo = imagesConfig?.logoEnd || ""
  local big = imagesConfig?.bigLogoEnd || ""
  local ext = imagesConfig.fileExtension
  local url = ""
  if (!u.isEmpty(feed?.blkParamName) && !u.isEmpty(imagesConfig?.other))
    url = getActivityFeedImageByParam(feed, imagesConfig)
  else if (!u.isEmpty(feed?.country) && !u.isEmpty(feed?.unitNameId))
    url = getActivityFeedImageByCountry(feed, imagesConfig)

  if (!u.isEmpty(url))
    return {
      small = url + (feed?.shouldForceLogo ? logo : "") + ext
      large = url + big + ext
    }

  ::dagor.debug("getActivityFeedImages: could not select method to build image URLs from gui.blk and feed config")
  debugTableData(feed)
  return null
}

return function(config, customFeedParams) {
  local sendStat = function(tags) {
    local qualifiedNameParts = split(::getEnumValName("ps4_activity_feed", config.subType, true), ".")
    tags["type"] <- qualifiedNameParts[1]
    statsd.send_counter("sq.activityfeed", 1, tags)
  }

  local locId = ::getTblValue("locId", config, "")
  if (locId == "" && u.isEmpty(customFeedParams?.captions))
  {
    sendStat({action = "abort", reason = "no_loc_id"})
    ::dagor.debug("ps4PostActivityFeed, Not found locId in config")
    ::debugTableData(config)
    return
  }

  local localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- ::g_localization.getLocalizedTextWithAbbreviation(customFeedParams[name])

  local activityFeed_config = customFeedParams.__merge(requestsTable)

  local getFilledFeedTextByLang = function(key) {
    local captions = {}
    local localizedTable = ::g_localization.getLocalizedTextWithAbbreviation(key)

    foreach(lang, string in localizedTable)
    {
      local localizationTable = {}
      foreach(name, value in activityFeed_config)
        localizationTable[name] <- localizedKeyWords?[name][lang] ?? value

      captions[lang] <- string.subst(localizationTable)
    }

    return captions
  }

  local images = getActivityFeedImages(customFeedParams)
  local largeImage = customFeedParams?.images?.large || images?.large
  local smallImage = customFeedParams?.images?.small || images?.small

  local body = {
    captions = customFeedParams?.captions || getFilledFeedTextByLang("activityFeed/" + locId)
    condensedCaptions = customFeedParams?.condensedCaptions || getFilledFeedTextByLang("activityFeed/" + locId + "/condensed")
    storyType = "IN_GAME_POST"
    subType = config?.subType || 0
    targets = [{accountId=::ps4_get_account_id(), type="ONLINE_ID"}]
  }
  if (largeImage)
    body.targets.append({meta=largeImage, type="LARGE_IMAGE_URL"})
  if (smallImage)
    body.targets.append({meta=smallImage, type="SMALL_IMAGE_URL", aspectRatio="2.08:1"})

  psn.send(psn.feed.post(body), function(_, err) {
      local tags = { action = "post", result = err ? "fail" : "success" }
      if (err != null)
        tags["reason"] <- err.code.tostring()
      sendStat(tags)
  })
}