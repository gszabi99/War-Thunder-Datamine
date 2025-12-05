module narrator_common shared
require ecs
require ecs.safe
require app 
require soundEvent
require soundSystem


def private get_narrator_preset()
  var name : string
  query() <| $ [es] (narrator__banksPreset : string)
    name = narrator__banksPreset
  return name


def is_narrator_loaded()
  return sound_banks_is_master_preset_loaded() && sound_banks_is_preset_loaded(get_narrator_preset())


def private need_cooldown(cooldown : float; phrase : string; is_ally, has_path : bool; narrator__history : Object)
  if cooldown > 0.
    let key = is_ally || !has_path ? phrase : "{phrase}_enemy"
    let lastTime = get_float(narrator__history[key]) ?? -1.
    return lastTime >= 0. && get_sync_time() < lastTime + cooldown
  return false


def private add_to_history(phrase : string; is_ally, has_path : bool; var narrator__history : Object&)
  let key = is_ally || !has_path ? phrase : "{phrase}_enemy"
  narrator__history |> set(key, get_sync_time())


def start_narrator_impl(phrase : string;
                        is_ally : bool;
                        team__narrator : Object;
                        var narrator__history : Object&;
                        var narrator__event : SoundEvent&)
  let obj = team__narrator[phrase] ?as Object
  if obj != null && is_narrator_loaded()
    let hasPath = has(*obj, "path")
    let path = hasPath ? (*obj).path ?? "" : get_string(*obj, is_ally ? "ally" : "enemy", "")
    if !empty(path)
      add_to_history(phrase, is_ally, hasPath, narrator__history)
      release(narrator__event)
      let delay = (*obj).delay ?? 0.
      narrator__event |> delayed_play(path, get_listener_pos(), delay)


def start_narrator(phrase : string;
                   is_ally : bool;
                   replace : bool;
                   team_id : int;
                   var narrator__event : SoundEvent&;
                   var narrator__queue : Array&;
                   var narrator__history : Object&)

  find_query() <| $ [es] (team__id : int; team__narrator : Object)
    if team__id != team_id
      return false
    let obj = team__narrator[phrase] ?as Object
    if obj == null
      return true
    if need_cooldown((*obj).cooldown ?? 0., phrase, is_ally, has(*obj, "path"), narrator__history)
      return true

    if replace
      release(narrator__event)
      narrator__queue |> clear()

    if length(narrator__queue) == 0 && !is_valid_handle_value(narrator__event)
      start_narrator_impl(phrase, is_ally, team__narrator, narrator__history, narrator__event)
    else
      using() <| $(var item : Object)
        item |> set("phrase", phrase)
        item |> set("isAlly", is_ally)
        item |> set("teamId", team_id)
        narrator__queue |> push(item)

    return true
