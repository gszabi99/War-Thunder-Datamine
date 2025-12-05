require ecs

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common

require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require pathfinder

[es(tag=server)]
def on_personal_squadmate_positional_order(evt : RequestPersonalSquadMateOrder;
                                           eid : EntityId;
                                           squad_member__squad : EntityId;
                                           
                                           var squad_member__orderType : int&;
                                           var squad_member__orderPosition : float3&;
                                           var squad_member__orderByDirection : float3&;
                                           var squad_member__orderToPosition : float3&;
                                           var squad_member__orderToDirection : float3&;
                                           var squad_member__orderUseEntity : EntityId&;
                                           var squad_member__isPersonalOrder : bool&;
                                           var squad_member__forceReposition : bool&)
  if is_squad_mate_order_positional(evt.orderType)
    query(squad_member__squad) <| $ [es, unused_argument(squad__leader)] (squad__leader : EntityId)
      reset_squad_mate_beh_tree(eid)

      squad_member__orderType = evt.orderType
      squad_member__orderPosition = evt.orderPosition
      squad_member__orderByDirection = evt.orderByDirection
      squad_member__orderToPosition = evt.orderToPosition
      squad_member__orderToDirection = evt.orderToDirection
      squad_member__orderUseEntity = evt.orderUseEntity
      squad_member__isPersonalOrder = true

      let projExtents = float3(0.5, 1.0, 0.5)
      var projectedPos = squad_member__orderPosition + float3(0.0, -0.1, 0.0)
      if project_to_nearest_navmesh_point_avoid_obstacles(projectedPos, projExtents)
        if projectedPos.y - squad_member__orderPosition.y < 1.0
          squad_member__orderPosition = projectedPos

      if is_squad_mate_order_peekout(squad_member__orderType)
        projectedPos = squad_member__orderToPosition + float3(0.0, -0.1, 0.0)
        if project_to_nearest_navmesh_point_avoid_obstacles(projectedPos, projExtents)
          if projectedPos.y - squad_member__orderToPosition.y < 1.0
            squad_member__orderToPosition = projectedPos

      squad_member__forceReposition = true
      reset_next_squad_mate_order(eid)

      request_squad_member_response_fast(eid)
      
