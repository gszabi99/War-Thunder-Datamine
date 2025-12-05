options no_aot = true
options rtti
module game_effect_macro shared private

require ecs
require ecs.macro_common
require daslib/ast_boost
require daslib/templates_boost


require %appGame.wt_events public

def get_game_effect_block(invert : bool; field_name : string)
  if !invert
    return <- qmacro_block() <|
      query(evt.attachedTo) <| $ [es] (var $i(field_name) : bool&)
        let excludeEid = eid
        $i(field_name) = evt.activated || find_query() <| $ [marker(tag)] (eid, game_effect__attachedTo : EntityId)
          return eid != excludeEid && game_effect__attachedTo == evt.attachedTo

  return <- qmacro_block() <|
    query(evt.attachedTo) <| $ [es] (var $i(field_name) : bool&)
      let excludeEid = eid
      $i(field_name) = evt.activated || find_query() <| $ [marker(tag)] (eid, game_effect__attachedTo : EntityId)
        return eid != excludeEid && game_effect__attachedTo == evt.attachedTo
      $i(field_name) = !$i(field_name)

[function_macro(name="es_game_effect")]
class GameEffectAnnotation : AstFunctionAnnotation
  [unused_argument(group)] def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool

    if length(func.arguments) > 0
      errors := "es_game_effect function should be without arguments"
      return false

    let fieldArg = find_arg(args, "bool_flag")
    if !validate_string_argument(fieldArg, "bool_flag", errors)
      return false
    let fieldName = "{fieldArg}"

    let tagArg = find_arg(args, "tag")
    if !validate_string_argument(tagArg, "tag", errors)
      return false
    let tagName = "{tagArg}"

    let invertArg = find_arg(args, "invert")
    if !(invertArg is nothing) && !(invertArg is tBool)
      errors := "invert arg should be bool value"
      return false
    let invert = (invertArg is nothing) ? false  : (invertArg as tBool)

    let esAnn = find_annotation("ecs", "es")
    assert(esAnn != null)

    var inscope blk <- get_game_effect_block(invert, fieldName)
    blk |> force_at(func.body.at)
    blk |> force_generated(true)

    apply_template(func.at, blk) <| $(rules)
      rules |> replaceAnnotationArgument("marker") <| @(var ann)
        ann.annotation := unsafe(reinterpret<smart_ptr<Annotation>> esAnn)
        ann.arguments |> clear()
        ann.arguments |> add_annotation_argument("REQUIRE", tagName)

    func.body |> move() <| blk

    func.arguments |> emplace_new <| new Variable(name := "evt", at = func.at, flags = VariableFlags.generated,
      _type <- typeinfo ast_typedecl(type<GameEffectStateChanged const>)
    )
    func.arguments |> emplace_new <| new Variable(name := "eid", at = func.at, flags = VariableFlags.generated,
      _type <- typeinfo ast_typedecl(type<EntityId const>)
    )

    let require_val =  ("REQUIRE", RttiValue(tString = tagName))
    func |> append_annotation("ecs", "es", [ require_val ])

    return true
