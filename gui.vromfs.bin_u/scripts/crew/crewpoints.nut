::g_crew_points <- {}

g_crew_points.getSkillPointsPacks <- function getSkillPointsPacks(country)
{
  local res = []
  local blk = ::get_warpoints_blk()
  if (!blk?.crewSkillPointsCost)
    return res

  foreach(block in blk.crewSkillPointsCost)
  {
    local blkName = block.getBlockName()
    res.append({
      name = blkName
      cost = ::Cost(0, ::wp_get_skill_points_cost_gold(blkName, country))
      skills = block?.crewExp ?? 1
    })
  }

  return res
}

//pack can be a single pack or packs array
g_crew_points.buyPack <- function buyPack(crew, packsList, onSuccess = null)
{
  if (!::u.isArray(packsList))
    packsList = [packsList]
  local cost = ::Cost()
  local amount = 0
  foreach(pack in packsList)
  {
    amount += pack.skills
    cost += pack.cost
  }
  local locParams = {
    amount = ::getCrewSpText(amount)
    cost = cost.getTextAccordingToBalance()
  }

  local msgText = ::warningIfGold(::loc("shop/needMoneyQuestion_buySkillPoints", locParams), cost)
  ::scene_msg_box("purchase_ask", null, msgText,
    [["yes", ::Callback(function()
      {
        if (::check_balance_msgBox(cost))
          buyPackImpl(crew, packsList, onSuccess)
      }, this)
    ], ["no", function(){}]], "yes", { cancel_fn = function(){}})
}

g_crew_points.buyPackImpl <- function buyPackImpl(crew, packsList, onSuccess)
{
  local pack = packsList.remove(0)
  local taskId = shop_purchase_skillpoints(crew.id, pack.name)
  local cb = ::Callback(function()
  {
    ::broadcastEvent("CrewSkillsChanged", { crew = crew, isOnlyPointsChanged = true })
    if (packsList.len())
      buyPackImpl(crew, packsList, onSuccess)
    else if (onSuccess)
      onSuccess()
  }, this)
  ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
}

g_crew_points.getPacksToBuyAmount <- function getPacksToBuyAmount(country, skillPoints)
{
  local packs = getSkillPointsPacks(country)
  if (!packs.len())
    return []

  local bestPack = packs.top() //while it only for developers it enough
  return array(::ceil(skillPoints.tofloat() / bestPack.skills), bestPack)
}