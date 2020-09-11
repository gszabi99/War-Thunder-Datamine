local function getPrizeChanceConfig(prize) {
  local res = {
    chanceIcon = null
    chanceTooltip = ""
  }

  local weight = prize?.weight
  if (weight == null)
    return res

  res.chanceIcon = ::get_game_settings_blk()?.visualizationTrophyWeights[weight].icon
  local chanceName = ::loc($"item/chance/{weight}")
  res.chanceTooltip = $"{::loc("item/chance")}{::loc("ui/colon")}{chanceName}"
  return res
}

local function getPrizeChanceLegendMarkup() {
  local chancesBlk = ::get_game_settings_blk()?.visualizationTrophyWeights
  if (chancesBlk == null)
    return ""

  local chances = []
  for(local i = 0; i < chancesBlk.blockCount(); i++) {
    local chanceBlk = chancesBlk.getBlock(i)
    chances.append({
      chanceName = ::loc($"item/chance/{chanceBlk.getBlockName()}")
      chanceIcon = chanceBlk?.icon
    })
  }
  if (chances.len() == 0)
    return ""

  return ::handyman.renderCached("gui/items/prizeChanceLegend", { chances = chances })
}


return {
  getPrizeChanceConfig = getPrizeChanceConfig
  getPrizeChanceLegendMarkup = getPrizeChanceLegendMarkup
}