require ecs
require soundEvent


[es(tag=sound, on_appear, REQUIRE_NOT=clientSide)]
def shell_launch_sound(evt : Event;
                       shell_launch_sound__name : string;
                       shell__owner : EntityId;
                       transform : float3x4)
  query(shell__owner) <| $ [es] (is_watched_sound : bool)
    oneshot(is_watched_sound ? "infantry/player/{shell_launch_sound__name}" : "infantry/enemy/{shell_launch_sound__name}", transform[3])
