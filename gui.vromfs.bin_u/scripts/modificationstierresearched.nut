from "%scripts/dagui_natives.nut" import shop_get_researchable_module_name
from "%scripts/dagui_library.nut" import *
from "%scripts/social/psConsts.nut" import bit_activity, ps4_activity_feed

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnitTypeTextByUnit, getUnitName, getUnitCountry } = require("%scripts/unit/unitInfo.nut")

let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { checkNonApprovedResearches } = require("%scripts/researches/researchActions.nut")

function guiStartModTierResearched(config) {
  foreach (param, value in config) {
    if (u.isArray(value) && value.len() == 1)
      config[param] = value[0]
  }

  let unit = getAircraftByName(getTblValue("unit", config))
  if (!unit)
    return

  local wndParams = {
    unit = unit
    unitInResearch = config?.resUnit
    tier = config?.tier ?? []
    expReward = Cost().setRp(config?.expToInvUnit ?? 0)
  }
  loadHandler(gui_handlers.ModificationsTierResearched, wndParams)
}

gui_handlers.ModificationsTierResearched <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"

  unit = null
  tier = null
  expReward = null
  unitInResearch = null

  postConfig = null
  postCustomConfig = null

  function initScreen() {
    if (!this.expReward)
      this.expReward = Cost()

    if (u.isArray(this.unitInResearch))  
      this.unitInResearch = this.unitInResearch[0] 

    let isLastResearchedModule = shop_get_researchable_module_name(this.unit.name) == ""
    local locTextId = "modifications/full_tier_researched"
    if (isLastResearchedModule)
      locTextId = "modifications/full_unit_researched"

    let nameObj = this.scene.findObject("award_name")
    if (checkObj(nameObj))
      nameObj.setValue(loc($"{locTextId}/header"))

    let imgObj = this.scene.findObject("award_image")
    if (checkObj(imgObj)) {
      local imageId = "_".concat(getUnitCountry(this.unit), getUnitTypeTextByUnit(this.unit).tolower())
      if (isLastResearchedModule)
        imageId = $"{imageId}_unit"
      else
        imageId = $"{imageId}_modification"

      local imagePath = getCountryFlagImg(imageId)
      if (imagePath == "")
        imagePath = "".concat(
          "#ui/images/elite_",
          this.unit?.isTank() ? "tank" : "vehicle",
          "_revard?P1"
        )

      imgObj["background-image"] = imagePath
    }

    local tierText = ""
    if (u.isArray(this.tier)) {
      if (this.tier.len() == 1)
        tierText = this.tier.top()
      else if (this.tier.len() == 2)
        tierText = loc("ui/comma").concat(get_roman_numeral(this.tier[0]), get_roman_numeral(this.tier[1]))
      else {
        local maxTier = 0
        local minTier = this.tier.len()
        foreach (t in this.tier) {
          maxTier = max(maxTier, t)
          minTier = min(minTier, t)
        }
        tierText = loc("ui/mdash").concat(get_roman_numeral(minTier), get_roman_numeral(maxTier))
      }
    }
    else
      tierText = get_roman_numeral(this.tier)

    local msgText = loc(locTextId, { tier = tierText, unitName = getUnitName(this.unit) })
    if (!this.expReward.isZero()) {
      msgText = "".concat(
        msgText, "\n", loc("reward"), loc("ui/colon"),
        loc("userlog/open_all_in_tier/resName",
          { resUnitExpInvest = this.expReward.tostring(),
            resUnitName = getUnitName(this.unitInResearch)
          })
      )
    }

    let descObj = this.scene.findObject("award_desc")
    if (checkObj(descObj)) {
      descObj["text-align"] = "center"
      descObj.setValue(msgText)
    }

    if (isLastResearchedModule) {
      this.postConfig = {
        locId = "researched_unit"
        subType = ps4_activity_feed.RESEARCHED_UNIT
        backgroundPost = true
      }

      this.postCustomConfig = {
        requireLocalization = ["unitName", "country"]
        unitName =$"{this.unit.name}_shop"
        rank = get_roman_numeral(this.unit?.rank ?? -1)
        country = getUnitCountry(this.unit)
        link = format(getCurCircuitOverride("wikiObjectsURL", loc("url/wiki_objects")), this.unit.name)
      }
    }
  }

  function onOk() {
    this.goBack()
  }

  function afterModalDestroy() {
    broadcastEvent("UpdateResearchingUnit", { unitName = this.unitInResearch })
    checkNonApprovedResearches(true)
    activityFeedPostFunc(this.postConfig, this.postCustomConfig, bit_activity.PS4_ACTIVITY_FEED)
  }

  function onUseDecorator() {}
  function onUnitActivate() {}
}

return {
  guiStartModTierResearched
}
