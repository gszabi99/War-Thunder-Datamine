require ecs
require Unit
require DngHuman

[es(on_event=(CmdUnitUpdateTransformComponent, CmdUnitUpdateTransformComponentHero), REQUIRE_NOT=(unit_tag__fortification, human_net_phys))]
def unit_update_tm_component_es(evt : Event;
                                active : bool;
                                unit__ref : UnitRef;
                                var transform : float3x4)
  if active
    transform = unit__ref.unit.unitTm

[es(on_event=(CmdUnitUpdateTransformComponent, CmdUnitUpdateTransformComponentHero))]
def human_save_tm(evt : Event;
                  human_net_phys : HumanActor;
                  human_net_phys__locationOffset : float3 const?;
                  var transform : float3x4)
  location_toTM(human_net_phys.phys.visualLocation, transform)
  if human_net_phys__locationOffset != null
    transform[3] += *human_net_phys__locationOffset

[es(tag=server, on_appear, REQUIRE=whitelistedDetector)]
def whilelisted_detector_init(evt : Event;
                              var unit__ref : UnitRef&)
  unit__ref.unit.isWhitelistedDetector = true