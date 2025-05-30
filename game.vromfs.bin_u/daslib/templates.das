options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers

module templates shared private

require ast
require rtti
require daslib/ast_boost

[call_macro(name="decltype")]
class DecltypeMacro : AstCallMacro {
    
    
    
    
    
    remove_ref = false
    def override visit(prog : ProgramPtr; mod : Module?; var expr : smart_ptr<ExprCallMacro>) : ExpressionPtr {
        if (expr.arguments |> length != 1) {
            macro_error(prog, expr.at, "decltype expecting 1 argument")
            return <- default<ExpressionPtr>
        }
        if (expr.arguments[0]._type == null || expr.arguments[0]._type.isAutoOrAlias) {
            macro_error(prog, expr.at, "decltype requires fully inferred type")
            return <- default<ExpressionPtr>
        }
        var inscope tt <- clone_type(expr.arguments[0]._type)
        if (remove_ref) {
            tt.flags &= ~TypeDeclFlags.ref
        }
        var inscope mkt <- new ExprTypeDecl(at = expr.at,
            typeexpr <- tt
        )
        return <- mkt
    }
}

[call_macro(name="decltype_noref")]
class DecltypeNoRefMacro : DecltypeMacro {
    
    override remove_ref = true
}

[function_macro(name="template")]
class TemplateMacro : AstFunctionAnnotation {
    
    
    
    
    
    
    
    
    
    
    
    def override transform(var expr : smart_ptr<ExprCallFunc>; var errors : das_string) : ExpressionPtr {
        if (expr.func == null) {
            compiling_program() |> macro_error(expr.at, "expecting inferred function")
            return <- expr
        }
        let taidx = find_index_if(each(expr.func.annotations)) <| $(ann) {
            return ann.annotation.name == "template"
        }
        if (taidx == -1) {
            return <- expr
        }
        var inscope ffunc := unsafe(reinterpret<FunctionPtr> expr.func)
        
        var inscope newcall <- unsafe(reinterpret<smart_ptr<ExprCallFunc>> clone_expression(expr))
        
        var inscope fclone <- clone_function(ffunc)
        fclone.fromGeneric |> move <| ffunc
        fclone.flags |= FunctionFlags.privateFunction
        newcall.func = null
        var extra = ""
        for (t in fclone.annotations[taidx].arguments) {
            let argidx = find_index_if(each(fclone.arguments)) <| $(farg) {
                return farg.name == t.name
            }
            if (argidx == -1) {
                errors := "can't find template argument {t.name} (or duplicate)"
                return <- default<ExpressionPtr>
            }
            if (true) {
                var inscope argExpr := newcall.arguments[argidx]
                if (argExpr is ExprRef2Value) {
                    let r2v = newcall.arguments[argidx] as ExprRef2Value
                    argExpr := r2v.subexpr
                }
                let canStrip = t.basicType == Type.tBool ? t.bValue : true
                if (canStrip && !(argExpr is ExprTypeDecl)) {
                    errors := "template argument must be type<...> and not {describe(newcall.arguments[argidx])}. {newcall.arguments[argidx].__rtti}"
                    return <- default<ExpressionPtr>
                }
                let tname = describe_typedecl(argExpr._type, true, true, true)
                extra += "`{hash(tname)}"
            }
            fclone.arguments |> erase(argidx)
            newcall.arguments |> erase(argidx)
        }
        fclone.annotations |> erase(taidx)
        
        fclone.name := "`template{extra}`{fclone.name}"
        newcall.name := "_::{fclone.name}"
        
        compiling_module() |> add_function(fclone)
        return <- newcall
    }
}
