options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module interfaces shared private




















require daslib/ast_boost
require daslib/templates_boost
require daslib/defer
require daslib/generic_return
require strings
require ast

[structure_macro(name="interface")]
class InterfaceMacro : AstStructureAnnotation {
    
    
    def override finish(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        for (fld in st.fields) {
            if (fld.name == "__rtti") {
                continue
            }
            if (!fld._type.isFunction) {
                errors := "interface can only define functions. {fld.name} is not a function\n{errors}"
                return false
            }
        }
        return true
    }
}

[structure_macro(name="implements")]
class ImplementsMacro : AstStructureAnnotation {
    
    
    
    
    
    
    
    
    
    
    
    def override apply(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        if (length(args) != 1) {
            errors := "implements macro takes exactly one argument"
            return false
        }
        var iface_name : string
        if (args[0].basicType == Type.tBool) {
            iface_name = string(args[0].name)
        } elif (args[0].basicType == Type.tString && args[0].name == "name") {
            iface_name = string(args[0].sValue)
        } else {
            errors := "expecting [implements(InteraceName)] or [implements(name=InteraceName)]"
            return false
        }
        
        var parent <- compiling_program() |> find_unique_structure(iface_name)
        if (parent == null) {
            errors := "{iface_name} not found"
            return false
        }
        
        let iface_var_name = "_interface_{iface_name}"
        let iface_class_name = "_implementation_{st.name}_{iface_name}"
        let iface_get_name = "get`{iface_name}"
        let iface_get_name_func = "{st.name}`{iface_get_name}"
        
        var inscope cls <- make_class(iface_class_name, parent, st._module)
        cls.flags |= StructureFlags.privateStructure
        var iface_index = -1
        for (ann, ii in cls.annotations, count()) {
            if (ann.annotation.name == "interface") {
                iface_index = ii
                break
            }
        }
        if (iface_index == -1) {
            errors := "can only implement interfaces, {iface_name} is not an [interface]"
            return false
        }
        cls.annotations |> erase(iface_index)
        
        var inscope iface_ptr <- qmacro_type(type<$t(parent)?>)
        st |> add_structure_field(iface_var_name, clone_type(iface_ptr), default<ExpressionPtr>)
        
        var inscope fn_get_i <- qmacro_method(iface_get_name_func, st) $(var self : $t(st)) : $t(iface_ptr) {
            if (self.$f(iface_var_name) == null) {
                self.$f(iface_var_name) = new <$t(cls)>(unsafe(addr(self)))
            }
            return self.$f(iface_var_name)
        }
        add_function(st._module, fn_get_i)
        
        var inscope st_ptr <- qmacro_type(type<$t(st)?>)
        let fi = cls |> add_structure_field("_self", clone_type(st_ptr), default<ExpressionPtr>)
        cls.fields[fi].annotation |> add_annotation_argument("do_not_delete", true)
        cls.fields[fi].flags |= FieldDeclarationFlags.doNotDelete | FieldDeclarationFlags.privateField
        
        var inscope ctor <- qmacro_function("{iface_class_name}`{iface_class_name}") $(s : $t(st_ptr)) {
            _self = s
        }
        var inscope ctor_fun <- make_class_constructor(cls, ctor)
        modify_to_class_member(cls, ctor, false, false)
        add_function(st._module, ctor)
        add_function(st._module, ctor_fun)
        
        st |> add_structure_field(
            iface_get_name,
            qmacro_type(type<function<(var self : $t(st)) : $t(iface_ptr)>>),
            qmacro(@@$i(iface_get_name_func))
        )
        
        
        
        
        
        
        var cur_ancestor = parent.parent
        while (cur_ancestor != null) {
            if (is_interface_struct(cur_ancestor)) {
                let anc_name = string(cur_ancestor.name)
                let anc_get_name = "get`{anc_name}"
                
                
                var already_exists = false
                for (efld in st.fields) {
                    if (string(efld.name) == anc_get_name) {
                        already_exists = true
                        break
                    }
                }
                if (!already_exists) {
                    
                    
                    var anc_struct <- compiling_program() |> find_unique_structure(anc_name)
                    if (anc_struct != null) {
                        let anc_get_func = "{st.name}`{anc_get_name}"
                        var inscope anc_ptr <- qmacro_type(type<$t(anc_struct)?>)
                        
                        
                        var inscope fn_anc <- qmacro_method(anc_get_func, st) $(var self : $t(st)) : $t(anc_ptr) {
                            return $c(iface_get_name_func)(self)
                        }
                        add_function(st._module, fn_anc)
                        st |> add_structure_field(
                            anc_get_name,
                            qmacro_type(type<function<(var self : $t(st)) : $t(anc_ptr)>>),
                            qmacro(@@$i(anc_get_func))
                        )
                    }
                }
            }
            cur_ancestor = cur_ancestor.parent
        }
        
        let skipl = length(iface_name) + 1
        for (fld in st.fields) {
            if (string(fld.name) |> starts_with("{iface_name}`")) {
                let method_name = string(fld.name) |> slice(skipl)
                var found = false
                for (cm in cls.fields) {
                    if (cm.name == method_name) {
                        found = true
                        let fmethod_name = "{iface_class_name}`{method_name}"
                        var inscope fmethod_args : array<VariablePtr>
                        var inscope fcall_args : array<ExpressionPtr>
                        var inscope ret_type : TypeDeclPtr
                        if (cm._type.isFunction) {
                            
                            cm.init |> move_new <| qmacro(cast<$t(cm._type)>(@@$i(fmethod_name)))
                            for (n, t in cm._type.argNames, cm._type.argTypes) {
                                if (n != "self") {
                                    fcall_args |> emplace_new <| qmacro($i(n))
                                    fmethod_args |> emplace_new <| new Variable(name := n, _type <- clone_type(t))
                                }
                            }
                            ret_type |> move_new <| clone_type(cm._type.firstType)
                        } else {
                            
                            
                            
                            let iface_func_name = "{iface_name}`{method_name}"
                            var inscope ifn <- find_unique_function(parent._module, iface_func_name, true)
                            if (ifn == null) {
                                errors := "cannot find default method function {iface_func_name}"
                                return false
                            }
                            cm.init |> move_new <| qmacro(@@$i(fmethod_name))
                            for (arg in ifn.arguments) {
                                let arg_name = string(arg.name)
                                if (arg_name != "self") {
                                    fcall_args |> emplace_new <| qmacro($i(arg.name))
                                    fmethod_args |> emplace_new <| new Variable(name := arg_name, _type <- clone_type(arg._type))
                                }
                            }
                            ret_type |> move_new <| clone_type(ifn.result)
                        }
                        var inscope fmethod <- qmacro_method(fmethod_name, cls) $(var self : $t(cls); $a(fmethod_args)) : $t(ret_type) {
                            generic_return(invoke(self._self.$f(fld.name), *self._self, $a(fcall_args)))
                        }
                        add_function(st._module, fmethod)
                        break
                    }
                }
                if (!found) {
                    errors := "unknown interface method {method_name} in {iface_class_name}"
                    return false
                }
            }
        }
        add_structure(st._module, cls)
        return true
    }

    
    
    
    
    
    def override finish(var st : StructurePtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        
        var iface_name : string
        if (args[0].basicType == Type.tBool) {
            iface_name = string(args[0].name)
        } elif (args[0].basicType == Type.tString && args[0].name == "name") {
            iface_name = string(args[0].sValue)
        } else {
            return true  
        }
        var iface <- compiling_program() |> find_unique_structure(iface_name)
        if (iface == null) {
            return true  
        }
        
        var missing : string
        for (ifld in iface.fields) {
            let ifld_name = string(ifld.name)
            
            if (ifld_name == "__rtti" || ifld_name == "__finalize") {
                continue
            }
            if (!ifld._type.isFunction) {
                continue
            }
            
            if (ifld.init != null) {
                continue
            }
            
            let expected = "{iface_name}`{ifld_name}"
            var found = false
            for (sfld in st.fields) {
                if (string(sfld.name) == expected) {
                    found = true
                    break
                }
            }
            if (!found) {
                missing = "{missing}{st.name} does not implement {iface_name}.{ifld_name}\n"
            }
        }
        if (length(missing) > 0) {
            errors := missing
            return false
        }
        return true
    }
}




def private is_interface_struct(st : Structure?) : bool {
    
    if (st == null) {
        return false
    }
    for (ann in st.annotations) {
        if (ann.annotation.name == "interface") {
            return true
        }
    }
    return false
}


























[variant_macro(name="InterfaceAsIs")]
class InterfaceAsIs : AstVariantMacro {
    
    
    
    
    
    

    
    
    
    
    
    
    
    def override visitExprIsVariant(prog : ProgramPtr; mod : Module?; expr : smart_ptr<ExprIsVariant>) : ExpressionPtr {
        
        
        
        
        assume vtype = expr.value._type
        if (!(vtype.isPointer && vtype.firstType != null && vtype.firstType.isStructure)) {
            return <- default<ExpressionPtr>
        }
        
        
        
        
        let iname = string(expr.name)
        var tgt = prog |> find_unique_structure(iname)
        if (tgt == null || !is_interface_struct(tgt)) {
            return <- default<ExpressionPtr>
        }
        
        
        
        
        let getter_field = "get`{iname}"
        var st = vtype.firstType.structType
        for (fld in st.fields) {
            if (string(fld.name) == getter_field) {
                
                
                return <- quote(true)
            }
        }
        
        return <- quote(false)
    }

    
    
    
    
    
    
    
    
    
    def override visitExprAsVariant(prog : ProgramPtr; mod : Module?; expr : smart_ptr<ExprAsVariant>) : ExpressionPtr {
        
        assume vtype = expr.value._type
        if (!(vtype.isPointer && vtype.firstType != null && vtype.firstType.isStructure)) {
            return <- default<ExpressionPtr>
        }
        let iname = string(expr.name)
        var tgt = prog |> find_unique_structure(iname)
        if (tgt == null || !is_interface_struct(tgt)) {
            return <- default<ExpressionPtr>
        }
        
        let getter_field = "get`{iname}"
        var st = vtype.firstType.structType
        for (fld in st.fields) {
            if (string(fld.name) == getter_field) {
                
                
                let func_name = "{st.name}`get`{iname}"
                
                
                
                return <- qmacro($c(func_name)(*$e(expr.value)))
            }
        }
        
        
        return <- default<ExpressionPtr>
    }

    
    
    
    
    
    
    
    
    
    def override visitExprSafeAsVariant(prog : ProgramPtr; mod : Module?; expr : smart_ptr<ExprSafeAsVariant>) : ExpressionPtr {
        
        assume vtype = expr.value._type
        if (!(vtype.isPointer && vtype.firstType != null && vtype.firstType.isStructure)) {
            return <- default<ExpressionPtr>
        }
        let iname = string(expr.name)
        var tgt = prog |> find_unique_structure(iname)
        if (tgt == null || !is_interface_struct(tgt)) {
            return <- default<ExpressionPtr>
        }
        
        let getter_field = "get`{iname}"
        var st = vtype.firstType.structType
        for (fld in st.fields) {
            if (string(fld.name) == getter_field) {
                
                let func_name = "{st.name}`get`{iname}"
                
                
                
                
                var inscope val <- clone_expression(expr.value)
                
                return <- qmacro($e(val) != null ? $c(func_name)(*$e(expr.value)) : null)
            }
        }
        return <- default<ExpressionPtr>
    }
}

