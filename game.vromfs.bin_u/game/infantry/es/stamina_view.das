require ecs
require %game.events
require HumanPhys
require DngHuman
require DagorMath

[es(tag=(gameClient), REQUIRE=watchedByPlr, REQUIRE_NOT=aircraftCrew, after=after_net_phys_sync)]
def hero_stamina_es(info : ParallelUpdateFrameDelayed;
                    human_net_phys : HumanActor;
                    human__totalMaxStamina : float;
                    var view_lowStamina : bool&;
                    var view_stamina : int&)
  let canStartSprint = human_net_phys.phys.canStartSprint
  view_lowStamina = !canStartSprint

  view_stamina = int(human_net_phys.phys.currentState.stamina * safeinv(human__totalMaxStamina * 0.01) + 1.0)

[es(tag=(gameClient), REQUIRE=(watchedByPlr, aircraftCrew))]
def aircraft_crew_stamina_view(info : ParallelUpdateFrameDelayed;
                               aircraft_crew__stamina : float;
                               entity_mods__aircraftCrewMaxStaminaMult : float = 1.0;
                               var view_stamina : int&)
  view_stamina = int(100.0 * aircraft_crew__stamina * safeinv(entity_mods__aircraftCrewMaxStaminaMult) + 1.0)
