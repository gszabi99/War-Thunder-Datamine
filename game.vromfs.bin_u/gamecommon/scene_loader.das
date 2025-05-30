require ecs
require DagorRandom
require level

[es(on_event=EventEntityCreated)]
def scene_loader_es(evt : Event;
                    level__bin : string;
                    level__environment : string;
                    level__weather : string;
                    var level__loaded : bool&)
  load_scene(grnd(), level__bin, level__environment, level__weather)
  level__loaded = true