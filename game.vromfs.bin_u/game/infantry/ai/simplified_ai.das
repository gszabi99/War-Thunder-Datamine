require ecs


[es(tag=server, on_appear, track=simplified_ai__limitedMode)]
def simplified_ai_on_change(evt : Event;
                            simplified_ai__limitedMode : int)
  query() <| $ [es] (var beh_tree__limitedMode : int&)
    beh_tree__limitedMode = simplified_ai__limitedMode

[es(tag=server, on_appear)]
def simplified_ai_agent_dangers_on_appear(evt : Event;
                                          var beh_tree__limitedMode : int&)
  query() <| $ [es] (simplified_ai__limitedMode : int)
    beh_tree__limitedMode = simplified_ai__limitedMode
