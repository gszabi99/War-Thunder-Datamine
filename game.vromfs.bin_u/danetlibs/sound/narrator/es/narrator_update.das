require ecs
require ecs.safe
require soundEvent
require narrator.modules.narrator_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=sound_begin_update_es, before=sound_end_update_es)]
def narrator_update(evt : Event;
                    var narrator__event : SoundEvent&;
                    var narrator__queue : Array&;
                    var narrator__history : Object&)

  if is_valid_handle_value(narrator__event) && !is_playing(narrator__event)
    release(narrator__event)

    if length(narrator__queue) > 0
      let obj = narrator__queue[0] as Object
      if obj != null
        let phrase = (*obj).phrase ?? ""
        let teamId = (*obj).teamId ?? -1
        let isAlly = (*obj).isAlly ?? false
        find_query() <| $ [es] (team__id : int; team__narrator : Object)
          if teamId == team__id
            start_narrator_impl(phrase, isAlly, team__narrator, narrator__history, narrator__event)
            return true
          return false
      erase(narrator__queue, 0)
