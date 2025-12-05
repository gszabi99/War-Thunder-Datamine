options no_aot
module net_console_macro shared

require daslib/ast_boost
require daslib/templates_boost
require rtti
require ecs.macro_common

require ecs public
require net public
require app public
require DagorConsole public
require %appGame.infantry.es.hero_common public
require %appGame.infantry.es.server_debug_common public

def get_controlled_hero_eid(possible_eid : uint)
  return possible_eid != 0u ? EntityId(possible_eid) : get_controlled_hero_eid()

def get_controlled_player_eid(possible_eid : uint)
  return possible_eid != 0u ? EntityId(possible_eid) : get_local_player_eid()

[function_macro(name="net_console_cmd")]
class NetConsoleCommandAnnotation : AstFunctionAnnotation
  [unused_argument(group, progArgs)] def override patch(var func : FunctionPtr; var group : ModuleGroup; args, progArgs : AnnotationArgumentList; var errors : das_string; var astChanged : bool &) : bool
    if (func.flags & FunctionFlags.exports) == FunctionFlags.exports
      return true

    let nameArg = find_arg(args, "name")
    if !validate_string_argument(nameArg, "name", errors)
      return false

    func.flags |= FunctionFlags.exports

    var inscope serverCmdArguments <- new ExprStringBuilder(uninitialized)
    serverCmdArguments.elements |> emplace_new(new ExprConstString(value := "{nameArg}"))

    var netHeroArgIdx = -1
    var netPlayerArgIdx = -1
    for arg, i in func.arguments, iter_range(func.arguments)
      serverCmdArguments.elements |> emplace_new(new ExprConstString(value := " "))
      serverCmdArguments.elements |> emplace_new(new ExprVar(name := arg.name))

      
      let isHero = find_arg(arg.annotation, "net_hero")
      if !(isHero is nothing)
        netHeroArgIdx = i
      
      let isPlayer = find_arg(arg.annotation, "net_player")
      if !(isPlayer is nothing)
        netPlayerArgIdx = i

    var inscope blk <- qmacro_block() <|
      if !is_server()
        exec_server_cmd($e(serverCmdArguments))
        return

    blk |> force_at(func.at)
    blk |> force_generated(true)
    var funcBlk = unsafe(reinterpret<ExprBlock?> func.body)
    funcBlk.list |> emplace(blk, 0)
    astChanged = true

    delete serverCmdArguments

    
    if netHeroArgIdx >= 0
      assume heroEidArg = func.arguments[netHeroArgIdx]

      
      var inscope ec <- new ExprCall(at = func.at, name := "get_controlled_hero_eid")
      ec.arguments |> emplace_new(new ExprVar(name := "_{heroEidArg.name}_"))

      var inscope el <- new ExprLet(at = func.at, atInit = func.at)
      el.variables |> emplace_new() <| new Variable(at = func.at,
        name := heroEidArg.name,
        _type <- new TypeDecl(baseType = Type.autoinfer, flags = TypeDeclFlags.constant, at = func.at),
        init <- ec
      )

      el |> force_generated(true)
      funcBlk.list |> emplace(el, 0)
      heroEidArg.name := "_{heroEidArg.name}_"
      heroEidArg._type := null
      heroEidArg._type |> move_new() <| new TypeDecl(baseType = Type.tUInt, at = func.at)
      heroEidArg.init := null
      heroEidArg.init |> move_new() <| new ExprConstUInt(at = func.at, value = 0u)

    
    if netPlayerArgIdx >= 0
      assume playerEidArg = func.arguments[netPlayerArgIdx]

      var inscope ec <- new ExprCall(at = func.at, name := "get_controlled_player_eid")
      ec.arguments |> emplace_new(new ExprVar(name := "_{playerEidArg.name}_"))

      var inscope el <- new ExprLet(at = func.at, atInit = func.at)
      el.variables |> emplace_new() <| new Variable(at = func.at,
        name := playerEidArg.name,
        _type <- new TypeDecl(baseType = Type.autoinfer, flags = TypeDeclFlags.constant, at = func.at),
        init <- ec
      )

      el |> force_generated(true)
      funcBlk.list |> emplace(el, 0)
      playerEidArg.name := "_{playerEidArg.name}_"
      playerEidArg._type := null
      playerEidArg._type |> move_new() <| new TypeDecl(baseType = Type.tUInt, at = func.at)
      playerEidArg.init := null
      playerEidArg.init |> move_new() <| new ExprConstUInt(at = func.at, value = 0u)

    let hint = find_arg(args, "hint")
    let name_val =  ("name", RttiValue(tString = "{nameArg}"))
    let hint_val =  ("hint", RttiValue(tString = hint is nothing ? "" : "{hint}"))
    func |> append_annotation("DagorConsole", "console_cmd", [ name_val, hint_val])

    return true
