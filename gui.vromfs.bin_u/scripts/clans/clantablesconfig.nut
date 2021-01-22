local clanInfoView = require("scripts/clans/clanInfoView.nut")

local function isFitsRequirements(clanData) {
  local requirements = clanData?.membership_req
  if (requirements == null ||
    (requirements.blockCount() == 0 && requirements.paramCount() == 0))
    return true

  local resultBlk = ::DataBlock()
  clan_evaluate_membership_requirements(requirements, resultBlk)
  return resultBlk?.result
}

local clanTableFieldsByPage = {
  clans_search = [
    { id = "fits_requirements", icon = "#ui/gameuiskin#lb_fits_requirements.svg",
      type = ::g_lb_data_type.TEXT, sort = false, byDifficulty = false
      getCellImage = @(clanData) isFitsRequirements(clanData) ? "#ui/gameuiskin#favorite"
        : "#ui/gameuiskin#icon_primary_fail.svg"
      getCellTooltipText = function(clanData) {
        local reqText = clanInfoView.getClanRequirementsText(clanData?.membership_req)
        return reqText != "" ? reqText : ::loc("clan/no_requirements")
      }
    }
    { id = "activity", field = @() ::has_feature("ClanVehicles") ? "clan_activity_by_periods" : "activity",
      showByFeature = "ClanActivity", byDifficulty = false }
    { id = "members_cnt", sort = false, byDifficulty = false }
    { id = ::ranked_column_prefix + "_arc", icon = "#ui/gameuiskin#lb_elo_rating_arcade.svg",
      tooltip = "#clan/dr_era/desc", byDifficulty = false, diffCode = ::DIFFICULTY_ARCADE }
    { id = ::ranked_column_prefix + "_hist", icon = "#ui/gameuiskin#lb_elo_rating.svg",
      tooltip = "#clan/dr_era/desc", byDifficulty = false, diffCode = ::DIFFICULTY_REALISTIC }
    { id = "slogan", icon = "", tooltip = "", text = "#clan/clan_slogan", byDifficulty = false, sort = false,
      type = ::g_lb_data_type.TEXT, width = "0.4@sf", autoScrollText = "hoverOrSelect" }
  ]
  clans_leaderboards = [
    { id = ::ranked_column_prefix, tooltip = "#clan/dr_era/desc"
      getIcon = @(diffCode) ::g_difficulty.getDifficultyByDiffCode(diffCode).clanRatingImage }
    { id = "members_cnt", sort = false, byDifficulty = false }
    { id = "air_kills", field = "akills", sort = false }
    { id = "ground_kills", field = "gkills", sort = false }
    { id = "deaths", sort = false }
    { id = "time_pvp_played", type = ::g_lb_data_type.TIME_MIN, field = "ftime", sort = false }
  ]
}

foreach (page in clanTableFieldsByPage)
  foreach (category in page) {
    if (!("type" in category))
      category.type <- ::g_lb_data_type.NUM
    if (!("sort" in category))
      category.sort <- true
    if (!("byDifficulty" in category))
      category.byDifficulty <- true
    if (!("field" in category))
      category.field <- category.id
    if (!("icon" in category))
      category.icon <- $"#ui/gameuiskin#lb_{category.id}.svg"
    if (!("tooltip" in category))
      category.tooltip <- $"#clan/{category.id}/desc"
    if (!("getIcon" in category))
      category.getIcon <- @(diffCode) icon
  }

local helpLinksByPage = {
  clans_search = [
    { obj = "img_fits_requirements"
      msgId = "hint_fits_requirements" }
    { obj = "img_activity"
      msgId = "hint_activity" }
    { obj = "img_members_cnt"
      msgId = "hint_members_cnt_search" }
    { obj = ["txt_" + ::ranked_column_prefix + "_arc"]
      msgId = "hint_dr_era_column_header_arc" }
    { obj = ["txt_" + ::ranked_column_prefix + "_hist"]
      msgId = "hint_dr_era_column_header_hist" }
  ]
  clans_leaderboards = [
    { obj = ["img_" + ::ranked_column_prefix]
      msgId = "hint_dr_era_column_header" }
    { obj = "img_members_cnt"
      msgId = "hint_members_cnt" }
    { obj = "img_air_kills"
      msgId = "hint_air_kills" }
    { obj = "img_ground_kills"
      msgId = "hint_ground_kills" }
    { obj = "img_deaths"
      msgId = "hint_deaths" }
    { obj = "img_time_pvp_played"
      msgId = "hint_time_pvp_played" }
  ]
}

local function getClanTableSortFields() {
  return {
    clans_leaderboards = clanTableFieldsByPage.clans_leaderboards.findvalue(@(f) f.id == ::ranked_column_prefix)
    clans_search = clanTableFieldsByPage.clans_search.findvalue(@(f) f.id == "activity")
  }
}

local function getClanTableFieldsByPage(page) {
  return clanTableFieldsByPage[page].filter(@(f) ("diffCode" not in f)
    || ::get_show_in_squadron_statistics(::g_difficulty.getDifficultyByDiffCode(f.diffCode)))
}

local function getClanTableHelpLinksByPage(page) {
  return helpLinksByPage[page]
}

return {
  getClanTableSortFields
  getClanTableFieldsByPage
  getClanTableHelpLinksByPage
}