require app
require ecs
require %appGame.infantry.es.throwable_common













def replace_throwable_item_local(throwable_item_local : EntityId;
                                 throwable_item_common : EntityId)
  destroyEntity(throwable_item_local)
  query(throwable_item_common) <| $ [es] (var animchar_render__enabled : bool&)
    animchar_render__enabled = true
















































[es(tag=gameClient, REQUIRE=throwable_item, on_appear, track=throwable_item__throwed)]
def throwable_item_switch_render_on_throw(evt : Event;
                                          throwable_item__throwed : bool;
                                          var animchar_render__enabled : bool&)
  animchar_render__enabled = throwable_item__throwed

[es(tag=gameClient, REQUIRE=throwable_item, REQUIRE_NOT=clientSide, on_appear, track=throwable_item__throwed, after=throwable_item_switch_render_on_throw)]
def throwable_item_local_replace_on_common_throwed(evt : Event;
                                                   eid : EntityId;
                                                   throwable_item__launcher : EntityId;
                                                   throwable_item__throwed : bool;
                                                   var animchar_render__enabled : bool&)
  if !throwable_item__throwed
    return

  query(throwable_item__launcher) <| $ [es] (throwable_launcher_throw__localItemReplaceMode : int;
                                             throwable_launcher_lerp__lerpingTime : float;
                                             var throwable_launcher_throw__localItem : EntityId&;
                                             var throwable_launcher_throw__localItemThrowed : bool&)
    let localItem = throwable_launcher_throw__localItem
    let localItemThrowed = throwable_launcher_throw__localItemThrowed
    throwable_launcher_throw__localItem = INVALID_ENTITY_ID
    throwable_launcher_throw__localItemThrowed = true

    if localItem == INVALID_ENTITY_ID
      return
    if !localItemThrowed
      destroyEntity(localItem)
      return

    if throwable_launcher_throw__localItemReplaceMode == int(ThrowableLauncherLocalItemReplaceMode.TLLIRM_INSTANT)
      destroyEntity(localItem)
    elif throwable_launcher_throw__localItemReplaceMode == int(ThrowableLauncherLocalItemReplaceMode.TLLIRM_LERP)
      animchar_render__enabled = false
      addSubTemplate(localItem, "throwable_item_local_lerp") <| $(var init)
        set(init, "throwable_item_lerp__common", eid)
        set(init, "throwable_item_lerp__commonAppearAtTime", get_sync_time())
        set(init, "throwable_item_lerp__lerpingTime", throwable_launcher_lerp__lerpingTime)












