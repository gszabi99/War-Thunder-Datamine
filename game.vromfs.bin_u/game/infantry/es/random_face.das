require ecs

[es(tag=render, on_appear)]
def random_face(evt : Event; eid : EntityId; random_face__names : StringList)
  let rand = uint(eid) % uint(length(random_face__names))
  addSubTemplate(eid, string(random_face__names[rand]))
