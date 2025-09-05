require ecs
require app
require %game.events


[es(tag=gameClient, REQUIRE=hero)]
def disable_shooting_while_aiming_artillery_es(evt : EventToggleArtilleryView;
                                               var human_input__canShoot : bool&)
  human_input__canShoot = !evt.enable
