require ecs
require app
require WTCamera
require DagorShaders
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common

[es(after=after_camera_sync, REQUIRE=watchedByPlr)]
def human_camera_shader_vars_update(info : UpdateStageInfoAct;
                                    var visual_hit__edgeColorVal : float&;
                                    visual_hit__edgeColorValDecrease : float;
                                    visual_hit__edgeColorValMax : float)
  let app = get_app()
  if app == null || app.flightControlMode == null
    return
  assume fcm = app.flightControlMode

  DagorShaders::set_color4(fcm.outEdgeColorVarId, 0.4f, 0.f, 0.f, visual_hit__edgeColorVal)
  DagorShaders::set_int(fcm.redOutBlackOutVarId, visual_hit__edgeColorVal > 0.f ? 1 : 0)
  DagorShaders::set_int(fcm.hasMobileBlackoutVarId, visual_hit__edgeColorVal > 0.f ? 1 : 0)
  visual_hit__edgeColorVal = clamp(visual_hit__edgeColorVal - visual_hit__edgeColorValDecrease * info.dt, 0., visual_hit__edgeColorValMax)

[es(tag=gameClient, REQUIRE=hero)]
def camara_visual_shader_punch_on_hit(evt : EventOnEntityHit;
                                      var visual_hit__edgeColorVal : float&;
                                      visual_hit__edgeColorValAddOnHit : float;
                                      visual_hit__edgeColorValMax : float;
                                      isAlive : bool)
  let acceptDamageType = (evt.damageType == int(DamageType.DM_MELEE) ||
                          evt.damageType == int(DamageType.DM_BACKSTAB) ||
                          evt.damageType == int(DamageType.DM_PROJECTILE) ||
                          evt.damageType == int(DamageType.DM_COLLISION))
  if has(evt.victim, "hero") && acceptDamageType && isAlive
    visual_hit__edgeColorVal = clamp(visual_hit__edgeColorVal + visual_hit__edgeColorValAddOnHit, 0., visual_hit__edgeColorValMax)

[es(tag=gameClient, on_disappear, REQUIRE=hero)]
def camara_visual_shader_punch_on_disappear(evt : Event;
                                            var visual_hit__edgeColorVal : float&)
  visual_hit__edgeColorVal = 0.