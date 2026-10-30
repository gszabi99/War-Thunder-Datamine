require ecs
require ecs.common

[es(tag=render, on_appear)]
def random_face(evt : Event; eid : EntityId; random_face__names : StringList)
  let rand = int(eid_frnd(eid) * float(length(random_face__names)))
  addSubTemplate(eid, string(random_face__names[rand]))
