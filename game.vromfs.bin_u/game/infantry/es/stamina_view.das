require ecs
require %game.events
require HumanPhys
require DngHuman
require DagorMath

[es(tag=(gameClient), REQUIRE=watchedByPlr, REQUIRE_NOT=aircraftCrew, after=after_net_phys_sync)]
def hero_stamina_es(info : ParallelUpdateFrameDelayed;
                    human_net_phys : HumanActor;
                    human__totalMaxStamina : float;
                    var view__lowStamina : bool&;
                    var view__staminaPercentage : int&)
  let canStartSprint = human_net_phys.phys.canStartSprint
  view__lowStamina = !canStartSprint

  view__staminaPercentage = int(cvt(human_net_phys.phys.currentState.stamina, 0., human__totalMaxStamina, 1., 100.))

[es(tag=(gameClient), REQUIRE=(watchedByPlr, aircraftCrew))]
def aircraft_crew_stamina_view(info : ParallelUpdateFrameDelayed;
                               aircraft_crew__stamina : float;
                               entity_mods__aircraftCrewMaxStaminaMult : float = 1.0;
                               var view__staminaPercentage : int&)
  view__staminaPercentage = int(100.0 * aircraft_crew__stamina * safeinv(entity_mods__aircraftCrewMaxStaminaMult) + 1.0)
