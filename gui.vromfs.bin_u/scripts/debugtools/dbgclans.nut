::debug_show_all_clan_awards <- function debug_show_all_clan_awards()
{
  if (!::is_dev_version)
    return
  let clanData = ::get_clan_info_table(::debug_get_clan_blk())
  let placeAwardsList = ::g_clans.getClanPlaceRewardLogData(clanData)
  ::showUnlocksGroupWnd([
    {
      unlocksList = placeAwardsList,
      titleText = "debug_show_all_clan_awards"
    }
  ])
}

::debug_get_clan_blk <- function debug_get_clan_blk()
{
  let blk = ::DataBlock()
  blk.load("../prog/scripts/debugData/debugClan.blk")
  return blk
}
