require ecs
require AnimV20


[es(on_appear)]
def heal_anim_init_es(evt : Event;
                      item__healAnimEnumName : string;
                      var item__healAnimEnumValue : int&)
  item__healAnimEnumValue = animV20_add_enum_value(item__healAnimEnumName)


[es(on_appear)]
def heal_target_anim_init_es(evt : Event;
                             item__healTargetAnimEnumName : string;
                             var item__healTargetAnimEnumValue : int&)
  item__healTargetAnimEnumValue = animV20_add_enum_value(item__healTargetAnimEnumName)
