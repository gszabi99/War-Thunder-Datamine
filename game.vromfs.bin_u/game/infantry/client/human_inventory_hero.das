require ecs
require DngHuman
require HumanPhys
require DagorMath
require math.base
require %game.events
require %appGame.infantry.es.inventory_common


[es(tag=gameClient, after=before_human_inventory_use_update, REQUIRE=hero, REQUIRE_NOT=deadEntity)]
def human_inventory_hero_es(info : ParallelUpdateFrameDelayed;
                            eid : EntityId;
                            bindedCamera : EntityId;
                            itemsAround : EidList;
                            human__aimTm : float3x4;
                            human_inventory__selectConvex : Point4List;
                            human_inventory__selectTpsConvex : Point4List;
                            human_inventory__pickupDistance : float = 2.5;
                            human_weap__gunEids : EidList;
                            human_inventory__pickupItemMinBox : float3 = float3(0.1f, 0.1f, 0.1f);
                            human__canPickupItems : bool = true;
                            human_net_phys : HumanActor;
                            isTpsView : bool = false;
                            var human_inventory__selectedItem : EntityId&)
  if !human__canPickupItems
    return

  let slot = HUWeaponSlots.EWS_PRIMARY
  let weaponEid = length(human_weap__gunEids) > 0 ? human_weap__gunEids[int(slot)] : INVALID_ENTITY_ID
  var result = false
  query(weaponEid) <| $ [es] (gun__maxAmmo : int;
                              gun__totalAmmo : int;
                              gun__numReserveAmmo  : int)
    if gun__totalAmmo >= (gun__numReserveAmmo - 1) * gun__maxAmmo
      human_inventory__selectedItem = INVALID_ENTITY_ID
      result = true
  if result
    return


  var bestScore = FLT_MIN
  var bestEntity = INVALID_ENTITY_ID
  var isBestUseful = false

  let camTmComp = get_TMatrix(bindedCamera, "transform") ?? IDENT_TM
  if camTmComp == IDENT_TM
    return
  var camTm := camTmComp
  camTm[0] = camTm[2]
  camTm |> orthonormalize()

  let tps = isTpsView && human_net_phys.phys.currentState.zoomPosition == 0.0
  let viewTm & = camTm
  let viewItm = inverse(viewTm)

  let projToChar = dot(human__aimTm[3] - viewTm[3], viewTm[0])
  let pickupDistance = human_inventory__pickupDistance
  let aimDir = viewTm[0]
  let aimFrom = viewTm[3] + projToChar * aimDir
  let aimTo = aimFrom + aimDir * pickupDistance

  for itemEid in itemsAround
    if itemEid == eid
      continue

    var isInteractionBlockedByLastOwner = false
    var pickupScore = ItemPickupScore(score = -1.0, useful = false)
    query(itemEid) <| $ [es] (item__lastOwner : EntityId = INVALID_ENTITY_ID;
                              item__overridePickupScore = -1.;
                              canItemPickedUpOnlyByLastOwner : Tag const?)
      isInteractionBlockedByLastOwner = canItemPickedUpOnlyByLastOwner != null && item__lastOwner != eid
      pickupScore.score = item__overridePickupScore
    if isInteractionBlockedByLastOwner
      continue


    if pickupScore.score < 0.
      pickupScore = get_item_pickup_score(eid, itemEid, weaponEid, tps ? human_inventory__selectTpsConvex : human_inventory__selectConvex,
                                          viewItm, aimDir, aimFrom, aimTo, human_inventory__pickupItemMinBox, human_inventory__selectedItem == itemEid)
    if pickupScore.score > bestScore
      isBestUseful = pickupScore.useful
      bestScore = pickupScore.score
      bestEntity = itemEid

  human_inventory__selectedItem = bestEntity
