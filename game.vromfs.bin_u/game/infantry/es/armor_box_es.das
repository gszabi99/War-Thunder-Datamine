require ecs
require net

require %appGame.wt_events
require %appGame.infantry.es.armor_common


[es(tag=server, before=useful_box_use_finish_es, REQUIRE=armorBox)]
def armor_box_resupply_armor_es(evt : CmdUseUsefulBox;
                                var useful_box__requiredUseCount : int&;
                                var useful_box__successUse : bool&)
  useful_box__successUse ||= resupply_armor_for_soldier(evt.requesterEid)
  if !useful_box__successUse
    send_net_event(evt.requesterEid, CmdHeroLogEvent(event = "ammo_full", text = "resupply/ammo_full"))
  useful_box__requiredUseCount = 1
