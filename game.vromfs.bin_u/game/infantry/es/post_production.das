require app
require ecs
require ecs.common
require ecs.soa_template

require %appGame.wt_events
require %appGame.infantry.es.post_production_common
require math.base
require DagorDataBlock
require DagorSystem
require DagorConsole
require strings


[es(tag=playingReplay, REQUIRE=postProductionEntity, REQUIRE_NOT=daeditor__previewEntity, on_event=EventEntityCreated)]
def schedule_entity_for_saving(evt : Event;
                               eid : EntityId;
                               post_production_entity__savingTemplate : string;
                               transform : float3x4)
  let postProdEntityTemplate = "+post_production_entity"
  var templName = getEntityTemplateName(eid)
  templName = replace(templName, postProdEntityTemplate, "")
  createEntity(post_production_entity__savingTemplate) <| $(var init : ComponentsInitializer)
    set(init, "saving_entity__template", templName)
    set(init, "saving_entity__creationTime", get_sync_time())
    set(init, "transform", transform)
    set(init, "saving_entity__isAutoDestroy", has(eid, "autodeleteEffectEntity"))

[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction, before=post_production_save_entities_into_file)]
def save_entity_for_post_prod_es(evt : ReplayPostProdSaveFile;
                                 var postProductionEntities : PostProductionEntity_SOA&)
  query() <| $ [es(REQUIRE=postProductionEntityToSave)] (eid : EntityId;
                                                         transform : float3x4;
                                                         saving_entity__creationTime : float;
                                                         saving_entity__template : string;
                                                         saving_entity__isAutoDestroy : bool)
    push(postProductionEntities, PostProductionEntity(
      replay_post_production__creationTime = saving_entity__creationTime,
      replay_post_production__template = saving_entity__template,
      replay_post_production__transform = transform,
      replay_post_production__isAutoDestroy = saving_entity__isAutoDestroy))
    destroyEntity(eid)

[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction)]
def post_production_save_entities_into_file(evt : ReplayPostProdSaveFile;
                                            postProductionEntities : PostProductionEntity_SOA)
  using() <| $(var blk : DataBlock)
    for entity in postProductionEntities
      blk |> datablock_add_new_block("post_production_entity") <| $(postProdEntBlk)
        postProdEntBlk |> add("time", entity.replay_post_production__creationTime)
        postProdEntBlk |> add("tmpl", string(entity.replay_post_production__template))
        postProdEntBlk |> add("tm", entity.replay_post_production__transform)
        postProdEntBlk |> add("autoDestroy", entity.replay_post_production__isAutoDestroy)
    datablock_save_to_text_file(blk, "PostProduction.blk")

def private verify_postprod_blk_params(blk : DataBlock?)
  if blk != null
    if datablock_param_exists(*blk, "time", -1)
      if datablock_param_exists(*blk, "tmpl", -1)
        if datablock_param_exists(*blk, "tm", -1)
          if datablock_param_exists(*blk, "autoDestroy", -1)
            return true
  return false

[soa_es, es(tag=playingReplay, before=post_production_creation_es, REQUIRE=replayPostProduction)]
def post_production_load_entities_from_file(evt : ReplayPostProdLoadFile;
                                            var postProductionEntities : PostProductionEntity_SOA&)
  var loaded = false
  using() <| $(var blk : DataBlock)
    if !datablock_load(blk, "PostProduction.blk", DataBlockReadFlag.ROBUST)
      logerr("Error on reading PostProduction.blk, check whether file exists")
      return
    postProductionEntities |> resize(int(blk.blockCount))
    for i, entity in 0u..blk.blockCount, postProductionEntities
      let keyFrameBlk = blk |> datablock_get_block(i)
      if verify_postprod_blk_params(keyFrameBlk)
        entity.replay_post_production__creationTime = datablock_getReal(keyFrameBlk, "time", 0.0)
        entity.replay_post_production__template := datablock_getStr(*keyFrameBlk, "tmpl", "")
        entity.replay_post_production__transform = datablock_getTm(*keyFrameBlk, "tm", IDENT_TM)
        entity.replay_post_production__isAutoDestroy = datablock_getBool(*keyFrameBlk, "autoDestroy", false)
      else
        logerr("Unsuppoted format of PostProduction.blk")
        postProductionEntities |> clear()
        loaded = false
        break
      loaded = true
  if loaded
    console_print("Post production entities loaded")

[soa_es, es(tag=playingReplay, REQUIRE=replayPostProduction)]
def post_production_creation_es(evt : ReplayPostProdLoadFile;
                                replay_post_production__creatingTemplate : string;
                                postProductionEntities : PostProductionEntity_SOA)
  let curTime = get_sync_time()
  for entity in postProductionEntities
    if entity.replay_post_production__isAutoDestroy && curTime > entity.replay_post_production__creationTime
      continue
    createEntity(replay_post_production__creatingTemplate) <| $(var init : ComponentsInitializer)
      set(init, "creating_entity__creationTime", entity.replay_post_production__creationTime)
      set(init, "creating_entity__template", entity.replay_post_production__template)
      set(init, "creating_entity__transform", entity.replay_post_production__transform)

[es(tag=playingReplay, no_order)]
def post_production_creating_entity_es(info : UpdateStageInfoAct;
                                       eid : EntityId;
                                       creating_entity__creationTime : float;
                                       creating_entity__template : string;
                                       creating_entity__transform : float3x4)
  if info.curTime > creating_entity__creationTime
    createEntity(creating_entity__template) <| $(var init : ComponentsInitializer)
      set(init, "transform", creating_entity__transform)
    destroyEntity(eid)