require ecs
require math
require math.base
require %game.dm.dm_events

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.team_common
require AnimV20
require CollRes
require DagorSystem


enum AnimDir : int
  FRONT
  BACK
  LEFT
  RIGHT

let ANIM_DIR_KEYS = fixed_array<string>(
  "front",
  "back",
  "left",
  "right")

let REPEAT_ANIM_KEYS = fixed_array(
  "repeat1",
  "repeat2")

[es(on_appear)]
def hit_reaction_init(evt : Event;
                      eid : EntityId;
                      var animchar : AnimcharBaseComponent;
                      collres : CollisionResource;
                      hit_reaction__anims : Object;
                      hit_reaction__animNodeDefault : string = "default";
                      hit_reaction__fifoNode : string = "fifo3_hit";
                      var hit_reaction__fifoNodeIdx : int&;
                      var hit_reaction__animNodeIdxs : IntList&;
                      var hit_reaction__repeatNodeIdxs : int2&)
  assume animGraph = animchar.animGraph
  if animGraph != null
    let fifoNodeIdx = *animGraph |> anim_graph_getBlendNodeId(hit_reaction__fifoNode)
    assume fifoNode = *animGraph |> anim_graph_getBlendNodePtr(fifoNodeIdx)
    if fifoNode != null && *fifoNode |> anim_blend_node_isSubOf(AnimBlendCtrl_Fifo3CID)
      hit_reaction__fifoNodeIdx = fifoNodeIdx
    else
      let templateName = getEntityTemplateName(eid)
      logerr("Can't find fifo hit node {hit_reaction__fifoNode} in {templateName}")

    let animDirsCount = length(ANIM_DIR_KEYS)
    let nodesCount = collres |> collres_get_nodesCount()
    let animNodesCount = nodesCount * animDirsCount
    hit_reaction__animNodeIdxs |> resize(animNodesCount)

    var defaultAnimBlendNodeIdx = -1
    let defaultAnimName = hit_reaction__anims |> get_string(hit_reaction__animNodeDefault, "")
    if defaultAnimName != ""
      defaultAnimBlendNodeIdx = *animGraph |> anim_graph_getBlendNodeId(defaultAnimName)

    for i in range(0, length(REPEAT_ANIM_KEYS))
      let repeatAnimKey = REPEAT_ANIM_KEYS[i]
      let repeatAnimName = hit_reaction__anims |> get_string(repeatAnimKey, "")
      if repeatAnimName != ""
        hit_reaction__repeatNodeIdxs[i] = *animGraph |> anim_graph_getBlendNodeId(repeatAnimName)
      else
        hit_reaction__repeatNodeIdxs[i] = -1

    for i in range(0, nodesCount)
      let collNode = collres |> collres_get_node(i)
      let collNodeName = collNode |> collnode_get_name()
      let animGroup = hit_reaction__anims |> get_ecs_object(collNodeName)
      if animGroup != null
        for dir in range(0, animDirsCount)
          let animIdx = i * animDirsCount + dir
          let dirKey = ANIM_DIR_KEYS[dir]
          let animName = animGroup |> get_string(dirKey, "")
          if animName == "-"
            hit_reaction__animNodeIdxs[animIdx] = -1
          elif animName != ""
            hit_reaction__animNodeIdxs[animIdx] = *animGraph |> anim_graph_getBlendNodeId(animName)
          else
            hit_reaction__animNodeIdxs[animIdx] = defaultAnimBlendNodeIdx
      else
        for dir in range(0, animDirsCount)
          let animIdx = i * animDirsCount + dir
          hit_reaction__animNodeIdxs[animIdx] = -1


def hit_reaction_impl(eid : EntityId;
                      var animchar : AnimcharBaseComponent;
                      human_net_phys__isCrawl : bool;
                      hit_reaction__fifoNodeIdx : int;
                      hit_reaction__animNodeIdxs : IntList&;
                      hit_reaction__repeatNodeIdxs : int2;
                      transform : float3x4&;
                      damageType : int;
                      hit_dir : float3;
                      collNodeId : int)
  assume animGraph = animchar.animGraph
  if animGraph != null
    let animNodesCount = length(hit_reaction__animNodeIdxs)
    let animDirsCount = length(ANIM_DIR_KEYS)

    let isDamageTypeValid = (damageType == int(DamageType.DM_PROJECTILE) || damageType == int(DamageType.DM_MELEE) || damageType == int(DamageType.DM_BACKSTAB))
    let isCollNodeValid = (collNodeId >= 0 && collNodeId * animDirsCount + (animDirsCount - 1) < animNodesCount)
    let isEidValid = (!has(eid, "hero"))

    if isDamageTypeValid && isCollNodeValid && isEidValid
      let transformInv = inverse(transform)
      let hitDirLocal = rotate(transformInv, hit_dir)
      let isStand = !human_net_phys__isCrawl

      
      var ang = 0.0

      let HIT_DIRECTION_RATIO = 0.8

      if (isStand)
        if abs(hitDirLocal.y) < HIT_DIRECTION_RATIO 
          ang = rad_to_deg(atan2(hitDirLocal.z, -hitDirLocal.x))
      else
        if abs(hitDirLocal.x) < HIT_DIRECTION_RATIO 
          ang = rad_to_deg(atan2(hitDirLocal.z, hitDirLocal.y))

      var dirIdx = AnimDir.FRONT
      if abs(ang) > 45.0
        if ang >= 45.0 && ang <= 135.0
          dirIdx = AnimDir.RIGHT
        elif ang >= -135.0 && ang <= -45.0
          dirIdx = AnimDir.LEFT
        else
          dirIdx = AnimDir.BACK

      let nodeIdx = hit_reaction__animNodeIdxs[collNodeId * animDirsCount + int(dirIdx)]
      if nodeIdx != -1
        var animState = animchar.animState

        var node = *animGraph |> anim_graph_getBlendNodePtr(nodeIdx)

        var fifoNode = *animGraph |> anim_graph_getFifo3NodePtr(hit_reaction__fifoNodeIdx)
        if *fifoNode |> anim_blend_ctrl_fifo3_isEnqueued(*animState, node)
          for i in range(0, length(REPEAT_ANIM_KEYS))
            let repeatAnimNodeIdx = hit_reaction__repeatNodeIdxs[i]
            if repeatAnimNodeIdx != -1
              var repeatAnimNode = *animGraph |> anim_graph_getBlendNodePtr(repeatAnimNodeIdx)
              if !(*fifoNode |> anim_blend_ctrl_fifo3_isEnqueued(*animState, repeatAnimNode))
                node = repeatAnimNode
                break

        if !(*fifoNode |> anim_blend_ctrl_fifo3_isEnqueued(*animState, node))
          *node |> anim_blend_node_resume(*animState, true)
        *fifoNode |> anim_blend_ctrl_fifo3_enqueueState(
          *animState, node, 0.05, 0.0)


[es(tag=gameClient, REQUIRE_NOT=hero)]
def human_hit_hero_client_es(evt : EventOnHitEntity; eid : EntityId; team = TEAM_UNASSIGNED)
  let offenderTeam = get_int(evt.offender, "team") ?? TEAM_UNASSIGNED
  if evt.offender == get_controlled_hero_eid() && offenderTeam != team
    sendEvent(eid, CmdOnHeroHit(damageType = int(DamageType.DM_PROJECTILE), hitDir = evt.dir, collNodeId = evt.collNodeId))


[es(tag=gameClient, REQUIRE_NOT=hero)]
def human_melee_hit_hero_client_es(evt : EventMeleeHitEntity; eid : EntityId; team = TEAM_UNASSIGNED)
  let offenderTeam = get_int(evt.offender, "team") ?? TEAM_UNASSIGNED
  if evt.offender == get_controlled_hero_eid() && offenderTeam != team
    sendEvent(eid, CmdOnHeroHit(damageType = int(DamageType.DM_MELEE), hitDir = evt.dir, collNodeId = evt.collNodeId))


[es(tag=gameClient)]
def human_hit_reaction_client_es(evt : CmdOnHeroHit;
                                 eid : EntityId;
                                 var animchar : AnimcharBaseComponent;
                                 human_net_phys__isCrawl : bool = false;
                                 hit_reaction__fifoNodeIdx : int;
                                 hit_reaction__animNodeIdxs : IntList&;
                                 hit_reaction__repeatNodeIdxs : int2;
                                 transform : float3x4;
                                 human_hit_reaction__use : bool)
  if human_hit_reaction__use
    hit_reaction_impl(
      eid, animchar, human_net_phys__isCrawl, hit_reaction__fifoNodeIdx,
      hit_reaction__animNodeIdxs, hit_reaction__repeatNodeIdxs,
      transform, evt.damageType, evt.hitDir, evt.collNodeId)


[es(tag=render, tag=server)]
def human_hit_reaction_local_es(evt : EventOnEntityHit;
                                eid : EntityId;
                                var animchar : AnimcharBaseComponent;
                                human_net_phys__isCrawl : bool = false;
                                hit_reaction__fifoNodeIdx : int;
                                hit_reaction__animNodeIdxs : IntList&;
                                hit_reaction__repeatNodeIdxs : int2;
                                transform : float3x4;
                                human_hit_reaction__use : bool)
  if human_hit_reaction__use
    let victim = evt.victim
    if eid == victim
      hit_reaction_impl(
        eid, animchar, human_net_phys__isCrawl, hit_reaction__fifoNodeIdx,
        hit_reaction__animNodeIdxs, hit_reaction__repeatNodeIdxs,
        transform, evt.damageType, evt.hitDir, evt.collNodeId)

[es(tag=server, REQUIRE=human)]
def human_set_show_hp_ui_on_hit(evt : EventOnEntityHit;
                                eid : EntityId;
                                var human__showHpUi : bool&)
  if eid == evt.victim
    human__showHpUi = true
