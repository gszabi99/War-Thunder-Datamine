require ecs
require Unit
require soundEvent
require soundSystem
require DagorSystem
require app
require DagorConsole
require Sound


[es(tag=sound, no_order)]
def rain_sound_update_es(act : UpdateStageInfoAct;
                         var rain_sound__event : SoundEvent&;
                         rain_sound__eventPath : string;
                         rain_sound__eventPathInf : string;
                         var rain_sound__isCockpit : bool&;
                         rain_sound__eventNameCockpit : string;
                         rain_sound__eventName : string;
                         var rain_sound__isForInfantry : bool&;
                         rain_sound__unitTypeToSoundType : FloatList)
  let isPlaying = is_playing(rain_sound__event)
  if get_rain_amount() > 0.1
    ecs::query() <| $ [es(REQUIRE=controlledHero)] (unitType : int; unit__ref : UnitRef; human_steps_sound__smid : int = 0)
      let unit = unit__ref.unit
      let isInfantry = unitType == int(UnitType.UT_Human)
      if !isPlaying || rain_sound__isCockpit != unit.isCameraInCockpit || isInfantry != rain_sound__isForInfantry
        abandon(rain_sound__event)
        let name = (unit.isCameraInCockpit && rain_sound__eventNameCockpit != "") ? rain_sound__eventNameCockpit : rain_sound__eventName
        let path = isInfantry ? rain_sound__eventPathInf : rain_sound__eventPath
        rain_sound__event |> play(path + "/" + name)
        rain_sound__isCockpit = unit.isCameraInCockpit
        rain_sound__isForInfantry = isInfantry

      rain_sound__event |> set_var_optional("model_type", rain_sound__unitTypeToSoundType[unitType])
      rain_sound__event |> set_var_optional("mat", float(human_steps_sound__smid))
  elif isPlaying
    abandon(rain_sound__event)

