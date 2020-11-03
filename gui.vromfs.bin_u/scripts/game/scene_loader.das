require ecs
require DagorRandom
require Level

[es (on_event=EventEntityCreated)]
def scene_loader_es(evt : Event;
                    level_dot_bin : string;
                    level_dot_environment : string;
                    level_dot_weather : string;
                var level_dot_loaded : bool&)
  load_scene(grnd(), level_dot_bin, level_dot_environment, level_dot_weather)
  level_dot_loaded = true