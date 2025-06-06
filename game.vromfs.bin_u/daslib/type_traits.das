options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers

module type_traits shared private

require daslib/ast_boost
require daslib/macro_boost

[typeinfo_macro(name="fields_count")]
class TypeInfoGetFieldsNum : AstTypeInfoMacro {
    
    def override getAstChange(expr : smart_ptr<ExprTypeInfo>; var errors : das_string) : ExpressionPtr {
        if (expr.typeexpr != null) {
            if (!expr.typeexpr.isStructure) {
                errors := "expecting structure"
                return <- default<ExpressionPtr>
            }
            let fieldsNum = length(expr.typeexpr.structType.fields)
            return <- new ExprConstInt(at = expr.at, value = fieldsNum)
        }
        errors := "type is missing or not inferred"
        return <- default<ExpressionPtr>
    }
}


[typeinfo_macro(name="safe_has_property")]
class TypeInfoHasProperty : AstTypeInfoMacro {
    
    def override getAstChange(expr : smart_ptr<ExprTypeInfo>; var errors : das_string) : ExpressionPtr {
        if (expr.typeexpr != null) {
            if (!expr.typeexpr.isHandle && !expr.typeexpr.isStructure) {
                errors := "expecting handle type or structure. typeinfo(safe_has_property<propName> v)"
                return <- default<ExpressionPtr>
            }
            if (empty(expr.subtrait)) {
                errors := "expecting trait string. typeinfo(safe_has_property<propName> v)"
                return <- default<ExpressionPtr>
            }

            let propName = ".`{expr.subtrait}"
            var res = false
            get_ptr(compiling_program()) |> for_each_module() <| $(mod) {
                if (res) {
                    return
                }
                mod |> for_each_function(propName) <| $(fn) {
                    if (fn.moreFlags.propertyFunction && expr.typeexpr |> is_same_type(fn.arguments[0]._type, RefMatters.yes, ConstMatters.no, TemporaryMatters.no)) {
                        res = true
                    }
                }
            }

            return <- new ExprConstBool(at = expr.at, value = res)
        }
        errors := "type is missing or not inferred"
        return <- default<ExpressionPtr>
    }
}

[call_macro(name="is_subclass_of")]
class IsSubclassOf : AstCallMacro {
    
    def override visit(prog : ProgramPtr; mod : Module?; var call : smart_ptr<ExprCallMacro>) : ExpressionPtr {
        macro_verify(call.arguments |> length == 2, prog, call.at, "expecting is_subclass_of(classptr,typeexpr)")
        macro_verify(call.arguments[0]._type != null, prog, call.at, "expecting is_subclass_of(classptr,typeexpr), classptr type is missing")
        macro_verify(call.arguments[1]._type != null, prog, call.at, "expecting is_subclass_of(classptr,typeexpr), typeexpr type is missing")
        assume classType = call.arguments[0]._type
        if (!(classType.isStructure && classType.structType.flags.isClass)) {
            macro_error(prog, call.at, "expecting is_subclass_of(class,...)")
            return <- default<ExpressionPtr>
        }
        assume typeExpr = call.arguments[1]._type
        if (!(typeExpr.isStructure && typeExpr.structType.flags.isClass)) {
            macro_error(prog, call.at, "expecting is_subclass_of(...,type<class_typeexpr>)")
            return <- default<ExpressionPtr>
        }
        var cptr = classType.structType
        while (cptr != null) {
            if (cptr == typeExpr.structType) {
                return <- quote(true)
            }
            cptr = cptr.parent
        }
        return <- quote(false)
    }
}
