let function getPrizeChanceConfig(prize) {
  let res = {
    chanceIcon = null
    chanceTooltip = ""
  }

  let weight = prize?.weight
  if (weight == null)
    return res

  res.chanceIcon = ::get_game_settings_blk()?.visualizationTrophyWeights[weight].icon
  let chanceName = ::loc($"item/chance/{weight}")
  res.chanceTooltip = $"{::loc("item/chance")}{::loc("ui/colon")}{chanceName}"
  return res
}

let function getPrizeChanceLegendMarkup() {
  let chancesBlk = ::get_game_settings_blk()?.visualizationTrophyWeights
  if (chancesBlk == null)
    return ""

  let chances = []
  for(local i = 0; i < chancesBlk.blockCount(); i++) {
    let chanceBlk = chancesBlk.getBlock(i)
    chances.append({
      chanceName = ::loc($"item/chance/{chanceBlk.getBlockName()}")
      chanceIcon = chanceBlk?.icon
    })
  }
  if (chances.len() == 0)
    return ""

  return ::handyman.renderCached("%gui/items/prizeChanceLegend", { chances = chances })
}


return {
  getPrizeChanceConfig = getPrizeChanceConfig
  getPrizeChanceLegendMarkup = getPrizeChanceLegendMarkup
}