let psn = require("sonyLib/webApi.nut")
let statsd = require("statsd")
let { GUI } = require("scripts/utils/configs.nut")

let requestsTable = {
  player = "$USER_NAME_OR_ID",
  count = "$STORY_COUNT",
  onlineUserId = "$ONLINE_ID",
  productName = "$PRODUCT_NAME",
  titleName = "$TITLE_NAME",
  fiveStarValue = "$FIVE_STAR_VALUE",
  sourceCount = "$SOURCE_COUNT"
}

// specialization getters below expect valid data, validated by the caller
let function getActivityFeedImageByParam(feed, imagesConfig)
{
  let config = imagesConfig.other?[feed.blkParamName]

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

let function getActivityFeedImageByCountry(feed, imagesConfig) {
  let aircraft = ::getAircraftByName(feed.unitNameId)
  let esUnitType = ::get_es_unit_type(aircraft)
  let unit = ::getUnitTypeText(esUnitType)
  let country = feed.country

  let variants = imagesConfig?[country]?[unit]
  if (u.isDataBlock(variants))
    return imagesConfig.mainPart + variants.getParamValue(::math.rnd() % variants.paramCount())

  ::dagor.debug("getActivityFeedImagesByCountry: no config for '"+country+"/"+unit+" ("+feed.unitNameId+")")
  debugTableData(imagesConfig)
  return ""
}

let function getActivityFeedImages(feed) {
  let guiBlk = GUI.get()
  let imagesConfig = guiBlk?.activity_feed_image_url
  if (u.isEmpty(imagesConfig))
  {
    ::dagor.debug("getActivityFeedImages: empty or missing activity_feed_image_url block in gui.blk")
    return null
  }

  let feedUrl = imagesConfig?.mainPart
  let imgExt = imagesConfig?.fileExtension
  if (!feedUrl || !imgExt)
  {
    ::dagor.debug("getActivityFeedImages: invalid feed config, url base '"+feedUrl+"', image extension '"+imgExt)
    debugTableData(imagesConfig)
    return null
  }

  let logo = imagesConfig?.logoEnd || ""
  let big = imagesConfig?.bigLogoEnd || ""
  let ext = imagesConfig.fileExtension
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
  let sendStat = function(tags) {
    let qualifiedNameParts = split(::getEnumValName("ps4_activity_feed", config.subType, true), ".")
    tags["type"] <- qualifiedNameParts[1]
    statsd.send_counter("sq.activityfeed", 1, tags)
  }

  let locId = ::getTblValue("locId", config, "")
  if (locId == "" && u.isEmpty(customFeedParams?.captions))
  {
    sendStat({action = "abort", reason = "no_loc_id"})
    ::dagor.debug("ps4PostActivityFeed, Not found locId in config")
    ::debugTableData(config)
    return
  }

  let localizedKeyWords = {}
  if ("requireLocalization" in customFeedParams)
    foreach(name in customFeedParams.requireLocalization)
      localizedKeyWords[name] <- ::g_localization.getLocalizedTextWithAbbreviation(customFeedParams[name])

  let activityFeed_config = customFeedParams.__merge(requestsTable)

  let getFilledFeedTextByLang = function(key) {
    let captions = {}
    let localizedTable = ::g_localization.getLocalizedTextWithAbbreviation(key)

    foreach(lang, string in localizedTable)
    {
      let localizationTable = {}
      foreach(name, value in activityFeed_config)
        localizationTable[name] <- localizedKeyWords?[name][lang] ?? value

      captions[lang] <- string.subst(localizationTable)
    }

    return captions
  }

  let images = getActivityFeedImages(customFeedParams)
  let largeImage = customFeedParams?.images?.large || images?.large
  let smallImage = customFeedParams?.images?.small || images?.small

  let body = {
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
      let tags = { action = "post", result = err ? "fail" : "success" }
      if (err != null)
        tags["reason"] <- err.code.tostring()
      sendStat(tags)
  })
}