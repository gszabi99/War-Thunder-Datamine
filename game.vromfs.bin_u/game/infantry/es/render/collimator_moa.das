require ecs
require %gameLibs.render.collimatorMoaCore.render.collimator_moa_public




[es(tag=render, before=collimator_moa_update_lens_eids_es,
    REQUIRE=cockpitEntity, REQUIRE=watchedByPlr)]
def collimator_moa_update_gunmod_infantry(info : UpdateStageInfoAct;
                                          human_weap__currentGunModEids : EidList)
  var collimatorEid = INVALID_ENTITY_ID
  for gunModEid in human_weap__currentGunModEids
    if collimator_moa_is_moa_scope(gunModEid)
      collimatorEid = gunModEid
      break
  collimator_moa_set_gun_mod_eid(collimatorEid)
