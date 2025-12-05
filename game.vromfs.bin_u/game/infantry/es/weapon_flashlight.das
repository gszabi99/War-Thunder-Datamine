require ecs
require ecs.common

require %appGame.wt_events


[es(tag=server, on_appear)]
def weapon_flashlight_prepare(evt : Event;
                              var gun_flashlight__isOn : bool&;
                              var light__brightness : float&)
  gun_flashlight__isOn = false
  light__brightness = 0.0


[es(tag=server)]
def use_weapon_flashlight_server(evt : CmdTacticalDeviceMode;
                                 human_weap__currentGunEid : EntityId)
  query(human_weap__currentGunEid) <| $ [es] (var gun_flashlight__isOn : bool&)
    gun_flashlight__isOn = !gun_flashlight__isOn


[es(tag=gameClient, track=gun_flashlight__isOn)]
def use_weapon_flashlight_client(evt : Event;
                                 gun_flashlight__isOn : bool;
                                 gun_flashlight__normalBrightness : float;
                                 var light__brightness : float&)
  light__brightness = gun_flashlight__isOn ? gun_flashlight__normalBrightness : 0.0
