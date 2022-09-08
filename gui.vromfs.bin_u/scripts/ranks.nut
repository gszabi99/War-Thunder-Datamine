let { format } = require("string")
::g_script_reloader.loadOnce("%scripts/ranks_common_shared.nut")

let avatars = require("%scripts/user/avatars.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")

::max_player_rank <- 100
::max_country_rank <- 7

::discounts <- { //count from const in warpointsBlk by (name + "Mul")
}
::event_muls <- {
  xpFirstWinInDayMul = 1.0
  wpFirstWinInDayMul = 1.0
}

let current_user_profile = {
  name = ""
  icon = "cardicon_default"
  pilotId = 0
  country = "country_ussr"
  balance = 0
  rank = 0
  prestige = 0
  rankProgress = 0 //0..100
  medals = 0
  aircrafts = 0
  gold = 0

  exp = -1
  exp_by_country = {}
  ranks = {}
}

::exp_per_rank <- []
::prestige_by_rank <-[]

::g_script_reloader.registerPersistentData("RanksGlobals", ::getroottable(),
  [
    "discounts", "event_muls",
    "exp_per_rank", "max_player_rank", "prestige_by_rank"
  ])

::load_player_exp_table <- function load_player_exp_table()
{
  let ranks_blk = ::get_ranks_blk()
  let efr = ranks_blk?.exp_for_playerRank

  ::exp_per_rank = []

  if (efr)
    for (local i = 0; i < efr.paramCount(); i++)
      ::exp_per_rank.append(efr.getParamValue(i))

  ::max_player_rank = ::exp_per_rank.len()
}

::init_prestige_by_rank <- function init_prestige_by_rank()
{
  let blk = ::get_ranks_blk()
  let prestigeByRank = blk?.prestige_by_rank

  ::prestige_by_rank = []
  if (!prestigeByRank)
    return

  for (local i = 0; i < prestigeByRank.paramCount(); i++)
    ::prestige_by_rank.append(prestigeByRank.getParamValue(i))
}

::get_cur_exp_table <- function get_cur_exp_table(country = "", profileData = null, rank = null, exp = null)
{
  local res = null //{ exp, rankExp }
  if (rank == null)
    rank = ::get_player_rank_by_country(country, profileData)
  let maxRank = (country == "") ? ::max_player_rank : ::max_country_rank

  if (rank < maxRank)
  {
    let expTbl = ::exp_per_rank
    if (rank >= expTbl.len())
      return res

    let prev = (rank > 0) ? expTbl[rank - 1] : 0
    let next = expTbl[rank]
    local cur = (exp == null)
                ? ::get_player_exp_by_country(country, profileData)
                : exp
    res = {
      rank    = rank
      exp     = cur - prev
      rankExp = next - prev
    }
  }
  return res
}

::get_player_rank_by_country <- function get_player_rank_by_country(c = null, profileData=null)
{
  if (!profileData)
    profileData = current_user_profile
  if (c == null || c == "")
    return profileData.rank
  if (c in profileData.ranks)
    return profileData.ranks[c]
  return 0
}

::get_player_exp_by_country <- function get_player_exp_by_country(c = null, profileData=null)
{
  if (!profileData)
    profileData = current_user_profile
  if (c == null || c == "")
    return profileData.exp
  if (c in profileData.exp_by_country)
    return profileData.exp_by_country[c]
  return 0
}

::get_rank_by_exp <- function get_rank_by_exp(exp)
{
  local rank = 0
  let rankTbl = ::exp_per_rank
  for (local i = 0; i < rankTbl.len(); i++)
    if (exp >= rankTbl[i])
      rank++

  return rank
}

::calc_rank_progress <- function calc_rank_progress(profileData = null)
{
  let rankTbl = ::get_cur_exp_table("", profileData)
  if (rankTbl)
    return (1000.0 * rankTbl.exp.tofloat() / rankTbl.rankExp.tofloat()).tointeger()
  return -1
}

::get_prestige_by_rank <- function get_prestige_by_rank(rank)
{
  for (local i = ::prestige_by_rank.len() - 1; i >= 0; i--)
    if (rank >= ::prestige_by_rank[i])
      return i
  return 0
}

let function get_cur_session_country()
{
  if (::is_multiplayer())
  {
    let sessionInfo = ::get_mp_session_info()
    let team = ::get_mp_local_team()
    if (team==1)
      return sessionInfo.alliesCountry
    if (team==2)
      return sessionInfo.axisCountry
  }
  return null
}

::get_profile_info <- function get_profile_info()
{
  let info = ::get_cur_rank_info()

  current_user_profile.name = info.name //::is_online_available() ? info.name : "" ;
  if (::my_user_name!=info.name && info.name!="")
    ::my_user_name = info.name

  current_user_profile.balance = info.wp
  current_user_profile.country = info.country || "country_0"
  current_user_profile.aircrafts = info.aircrafts
  current_user_profile.gold = info.gold
  current_user_profile.pilotId = info.pilotId
  current_user_profile.icon = avatars.getIconById(info.pilotId)
  current_user_profile.medals = ::get_num_unlocked(::UNLOCKABLE_MEDAL, true)
  //dagor.debug("unlocked medals: "+current_user_profile.medals)

  //Show the current country in the game when you select an outcast.
  if (current_user_profile.country=="country_0")
  {
    let country = get_cur_session_country()
    if (country && country!="")
      current_user_profile.country = "country_" + country
  }
  if (current_user_profile.country!="country_0")
    current_user_profile.countryRank <- ::get_player_rank_by_country(current_user_profile.country)

  let isInClan = ::clan_get_my_clan_id() != "-1"
  current_user_profile.clanTag <- isInClan ? ::clan_get_my_clan_tag() : ""
  current_user_profile.clanName <- isInClan  ? ::clan_get_my_clan_name() : ""
  current_user_profile.clanType <- isInClan  ? ::clan_get_my_clan_type() : ""
  ::clanUserTable[::my_user_name] <- current_user_profile.clanTag

  current_user_profile.exp <- info.exp
  current_user_profile.free_exp <- ::shop_get_free_exp()
  current_user_profile.rank <- ::get_rank_by_exp(current_user_profile.exp)
  current_user_profile.prestige <- ::get_prestige_by_rank(current_user_profile.rank)
  current_user_profile.rankProgress <- ::calc_rank_progress(current_user_profile)

  return current_user_profile
}

::get_balance <- function get_balance()
{
  let info = ::get_cur_rank_info()
  return { wp = info.wp, gold = info.gold }
}

::get_gui_balance <- function get_gui_balance()
{
  let info = ::get_cur_rank_info()
  return ::Balance(info.wp, info.gold, ::shop_get_free_exp())
}

::on_mission_started_mp <- function on_mission_started_mp()
{
  ::dagor.debug("on_mission_started_mp - CLIENT")
  ::g_streaks.clear()
  ::before_first_flight_in_session = true;
  ::clear_spawn_score();
  ::cur_mission_mode <- -1
  ::broadcastEvent("MissionStarted")
}

let airTypes = [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER]
::get_weapon_image <- function get_weapon_image(unitType, weaponBlk, costBlk)
{
  if (unitType == ::ES_UNIT_TYPE_TANK)
  {
    return costBlk?.image_tank
           ?? weaponBlk?.image_tank
           ?? costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
  else if (airTypes.contains(unitType))
  {
    return costBlk?.image_aircraft
           ?? weaponBlk?.image_aircraft
           ?? costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
  else // unitType == ::ES_UNIT_TYPE_INVALID
  {
    return costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
}

let function get_aircraft_rank(curAir)
{
  return ::get_wpcost_blk()?[curAir]?.rank ?? 0
}

let minValuesToShowRewardPremium = persist("minValuesToShowRewardPremium", @() ::Watched({ wp = 0, exp = 0 }))

let function haveCountryRankAir(country, rank)
{
  let crews = ::g_crews_list.get()
  foreach (c in crews)
    if (c.country == country)
      foreach(crew in c.crews)
        if (("aircraft" in crew) && get_aircraft_rank(crew.aircraft)>=rank)
          return true
  return false
}

//!!FIX ME: should to remove from this function all what not about unit.
::update_aircraft_warpoints <- function update_aircraft_warpoints(maxCallTimeMsec = 0)
{
  let startTime = ::dagor.getCurTime()
  let errorsTextArray = []
  foreach (unit in ::all_units)
  {
    if (unit.isInited)
      continue

    let errors = unit.initOnce()
    if (errors)
      errorsTextArray.extend(errors)

    if (maxCallTimeMsec && ::dagor.getCurTime() - startTime >= maxCallTimeMsec)
    {
      ::dagor.assertf(errorsTextArray.len() == 0, ::g_string.implode(errorsTextArray, "\n"))
      return PT_STEP_STATUS.SUSPEND
    }
  }

  //update discounts info
  let ws = ::get_warpoints_blk()
  foreach(name, value in ::discounts)
    if (ws?[name+"DiscountMul"] != null)
      ::discounts[name] = (100.0*(1.0 - ws[name+"DiscountMul"])+0.5).tointeger()

  //update bonuses info
  foreach(name, value in ::event_muls)
    if (ws?[name] != null)
      ::event_muls[name] = ws[name]

  minValuesToShowRewardPremium({
    wp  = ws?.wp_to_show_premium_reward ?? 0
    exp = ws?.exp_to_show_premium_reward ?? 0
  })

  ::dagor.assertf(errorsTextArray.len() == 0, ::g_string.implode(errorsTextArray, "\n"))
  return PT_STEP_STATUS.NEXT_STEP
}

::checkAllowed <- function checkAllowed(tbl)
{
  if (::disable_network())
    return true

  let silent = tbl?.silent ?? false

  if ("silentFeature" in tbl)
    if (!::has_feature(tbl.silentFeature))
    {
      if (!silent)
        ::showInfoMsgBox(::loc("msgbox/notAvailbleInDemo"), "in_demo_only_feature")
      return false
    }

  if ("minLevel" in tbl)
    if (::get_profile_info().rank < tbl.minLevel)
    {
      if (!silent)
        ::showInfoMsgBox(format(::loc("charServer/needRankFmt"), tbl.minLevel), "in_demo_only_minlevel")
      return false
    }

  if (("minRank" in tbl) && ("rankCountry" in tbl))
  {
    let country = $"country_{tbl.rankCountry}"
    if (!haveCountryRankAir(country, tbl.minRank))
    {
      if (!silent)
      {
        ::showInfoMsgBox(
          ::loc("charServer/needAirRankFmt", {
              tier = tbl.minRank,
              country = ::loc(country)
          }),
          "in_demo_only_minrank")
      }
      return false
    }
  }

  if ("unlock" in tbl)
    if (!::is_unlocked_scripted(::UNLOCKABLE_SINGLEMISSION, tbl.unlock) && !::is_debug_mode_enabled)
    {
      if (!silent)
      {
        let msg = ::loc("charServer/needUnlock") + "\n\n" + ::get_unlock_description(tbl.unlock, 1)
        ::showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }

  //check entitlement - this is always last
  if ("entitlement" in tbl)
  {
    if (::has_entitlement(tbl.entitlement))
      return true
    else if (!silent && (tbl.entitlement == ::shop_get_premium_account_ent_name()))
    {
      let guiScene = ::get_gui_scene()
      local handler = this
      if (!handler || handler == getroottable())
        handler = ::get_cur_base_gui_handler()
      let askFunc = (@(guiScene, handler) function(locText, entitlement) {
        if (::has_feature("EnablePremiumPurchase"))
        {
          let text = ::loc("charServer/noEntitlement/"+locText)
          handler.msgBox("no_entitlement", text,
          [
            ["yes", (@(guiScene, handler, entitlement) function() { guiScene.performDelayed(handler, (@(entitlement) function() {
                this.onOnlineShopPremium();
              })(entitlement)) })(guiScene, handler, entitlement) ],
            ["no", function() {} ]
          ], "yes")
        }
        else
          ::scene_msg_box("premium_not_available", null, ::loc("charServer/notAvailableYet"),
            [["cancel"]], "cancel")
      })(guiScene, handler)

      askFunc("loc" in tbl ? tbl.loc : tbl.entitlement, tbl.entitlement);
    }
    return false;
  }
  return true;
}


let playerRankByCountries = {}
let function updatePlayerRankByCountries() {
  foreach(c in shopCountriesList)
    playerRankByCountries[c] <- ::get_player_rank_by_country(c)
}

let function updatePlayerRankByCountry(country, rank) {
  playerRankByCountries[country] <- rank
}

return {
  minValuesToShowRewardPremium
  updatePlayerRankByCountries
  updatePlayerRankByCountry
  playerRankByCountries
}
