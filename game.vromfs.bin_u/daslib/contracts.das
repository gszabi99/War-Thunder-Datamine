options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module contracts shared private

require ast
require daslib/ast_boost

def public isYetAnotherVectorTemplate(td : TypeDeclPtr) {
    
    return td.isHandle && td.annotation != null && td.annotation.is_any_vector
}

class IsAnyType : AstFunctionAnnotation {
    def override appendToMangledName(func : FunctionPtr; decl : AnnotationDeclaration; var mangledName : das_string) : void {
        mangledName := "{class_info(self).name}:{describe(decl)}"
    }
    def override apply(var func : FunctionPtr; var group : ModuleGroup; args : AnnotationArgumentList; var errors : das_string) : bool {
        if (args |> length != 1) {
            errors := "expecting at least one argument"
            return false
        }
        for (argv in args) {
            let val = get_annotation_argument_value(argv)
            if (!(val is tBool)) {
                errors := "invalid argument type {argv.name}"
                return false
            }
            var found = false
            for (fna in func.arguments) {
                if (fna.name == argv.name) {
                    found = true
                    break
                }
            }
            if (!found) {
                errors := "function {func.name} does not have argument {argv.name}"
                return false
            }
        }
        return true
    }
    def override isSpecialized : bool {
        return true
    }
}

[contract(name="expect_any_array")]
class IsAnyArrayMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (!(typ.baseType == Type.tArray || length(typ.dim) != 0 || isYetAnotherVectorTemplate(typ))) {
                        errors := "argument {argv.name} is not a vector, array, or [], it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_enum")]
class IsAnyEnumMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (length(typ.dim) != 0 || (typ.baseType != Type.tEnumeration && typ.baseType != Type.tEnumeration8 && typ.baseType != Type.tEnumeration16 && typ.baseType != Type.tEnumeration64)) {
                        errors := "argument {argv.name} is not an enumeration"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_bitfield")]
class IsAnyBitfieldMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (length(typ.dim) != 0 || typ.baseType != Type.tBitfield) {
                        errors := "argument {argv.name} is not a bitfield"
                        return false
                    }
                }
            }
        }
        return true
    }
}


[contract(name="expect_any_vector_type")]
class IsAnyVectorType : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (length(typ.dim) != 0 || !isVectorType(typ.baseType)) {
                        errors := "argument {argv.name} is not a vector type (int2, float3, range, etc)"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_struct")]
class IsAnyStructMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tStructure || typ.structType == null || typ.structType.flags.isClass) {
                        errors := "argument {argv.name} is not a structure, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_numeric")]
class IsAnyNumericMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (!typ.isNumeric) {
                        errors := "argument {argv.name} is not a numeric, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_workhorse")]
class IsAnyWorkhorse : IsAnyType {
    
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (!typ.isWorkhorseType) {
                        errors := "argument {argv.name} is not a workhorse type, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_workhorse_raw")]
class IsAnyWorkhorseNonPtrMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (!typ.isCtorType && typ.baseType != Type.tBool) {
                        errors := "argument {argv.name} is not a workhorse raw type, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_tuple")]
class IsAnyTupleNonPtrMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tTuple) {
                        errors := "argument {argv.name} is not a tuple, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_variant")]
class IsAnyVariantNonPtrMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tVariant) {
                        errors := "argument {argv.name} is not a variant, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_function")]
class IsAnyFunctionNonPtrMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tFunction) {
                        errors := "argument {argv.name} is not a function, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_any_lambda")]
class IsAnyLambdaMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tLambda) {
                        errors := "argument {argv.name} is not a lambda, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_ref")]
class IsRefMacro : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (!typ.isRef) {
                        errors := "argument {argv.name} is not a reference, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_pointer")]
class IsPointer : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tPointer) {
                        errors := "argument {argv.name} is not a pointer, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_class")]
class IsClass : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tPointer || typ.firstType.baseType != Type.tStructure || !typ.firstType.structType.flags.isClass) {
                        errors := "argument {argv.name} is not a class pointer, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}

[contract(name="expect_value_handle")]
class IsValueHandle : IsAnyType {
    
    def override isCompatible(var func : FunctionPtr; var types : VectorTypeDeclPtr; decl : AnnotationDeclaration; var errors : das_string) : bool {
        for (fna, typ in func.arguments, types) {
            for (argv in decl.arguments) {
                if (fna.name == argv.name) {
                    if (typ.baseType != Type.tHandle || typ.isRefType) {
                        errors := "argument {argv.name} is not a value handle, it is {describe(typ)}"
                        return false
                    }
                }
            }
        }
        return true
    }
}