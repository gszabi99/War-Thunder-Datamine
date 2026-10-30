require ecs

enum PlantSiteAnim
  PLANT = 0
  DEFUSE = 1

[es(tag=server, on_appear, track=(bomb_site__operator, bomb_site__isDefusing, bomb_site__isPlantingOrReseting))]
def plant_site_operator_animation(evt : Event;
                                  bomb_site__operator : EntityId;
                                  bomb_site__isDefusing : bool;
                                  bomb_site__isPlantingOrReseting : bool;
                                  bomb_site__plantAnimationTemplate : string;
                                  bomb_site__defuseAnimationTemplate : string;
                                  var bomb_site__animationAction : int&;
                                  var bomb_site__animationOperator : EntityId&;
                                  var bomb_site__animationEntity : EntityId&)
  if !bomb_site__operator || (!bomb_site__isDefusing && !bomb_site__isPlantingOrReseting)
    destroyEntity(bomb_site__animationEntity)
    bomb_site__animationEntity = INVALID_ENTITY_ID
    return

  let currentAction = bomb_site__isDefusing ? PlantSiteAnim.DEFUSE : PlantSiteAnim.PLANT
  if !!bomb_site__animationEntity && int(currentAction) == bomb_site__animationAction && bomb_site__animationOperator == bomb_site__operator
    return

  let animationTemplate = currentAction == PlantSiteAnim.DEFUSE ? bomb_site__defuseAnimationTemplate : bomb_site__plantAnimationTemplate

  destroyEntity(bomb_site__animationEntity)
  bomb_site__animationAction = int(currentAction)
  bomb_site__animationOperator = bomb_site__operator
  bomb_site__animationEntity = INVALID_ENTITY_ID
  if !empty(animationTemplate)
    bomb_site__animationEntity = createEntity(animationTemplate) <| $(var init : ComponentsInitializer)
      set(init, "game_effect__attachedTo", bomb_site__operator)

[es(tag=server, on_disappear)]
def plant_site_stop_operator_animation_on_destroy(evt : Event;
                                                  var bomb_site__animationEntity : EntityId&)
  destroyEntity(bomb_site__animationEntity)
  bomb_site__animationEntity = INVALID_ENTITY_ID
