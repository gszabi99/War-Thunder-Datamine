local { getTextWithCrossplayIcon, needShowCrossPlayInfo } = require("scripts/social/crossplay.nut")
local { getSuitableUncompletedTutorialData } = require("scripts/tutorials/tutorialsData.nut")

local function getEventsButtonText()
{
  local activeEventsNum = ::events.getEventsVisibleInEventsWindowCount()
  return activeEventsNum <= 0
    ? ::loc("mainmenu/events/eventlist_btn_no_active_events")
    : ::loc("mainmenu/btnTournamentsAndEvents")
}

local function getWorldWarButtonText(isWwEnabled = null)
{
  local text = ::loc("mainmenu/btnWorldwar")
  if ((isWwEnabled ?? ::g_world_war.canJoinWorldwarBattle()))
  {
    local operationText = ::g_world_war.getPlayedOperationText(false)
    if (operationText !=null)
      text = operationText
  }

  text = getTextWithCrossplayIcon(needShowCrossPlayInfo(), text)
  return "{0} {1}".subst(::loc("icon/worldWar"), text)
}

local function getTutorialData()
{
  local curUnit = ::get_show_aircraft()
  local {
    mission = null,
    id = ""
  } = getSuitableUncompletedTutorialData(curUnit, 0)

  return {
    tutorialMission = mission
    tutorialId = id
  }
}

local function getTutorialButtonText(tutorialMission = null)
{
  tutorialMission = tutorialMission ?? getTutorialData()?.tutorialMission
  return tutorialMission
    ? ::loc("missions/" + (tutorialMission?.name ?? "") + "/short", "")
    : ::loc("mainmenu/btnTutorial")
}

local promoTextFunctions = {
  events_mainmenu_button = getEventsButtonText
  world_war_button = getWorldWarButtonText
  tutorial_mainmenu_button = getTutorialButtonText
}

return {
  getTutorialData    = getTutorialData
  promoTextFunctions = promoTextFunctions
}