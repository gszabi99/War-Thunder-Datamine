options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module ast_used shared private

require daslib/ast_boost

struct public OnlyUsedTypes {
    
    st : table<Structure?>   
    en : table<Enumeration?>   
}

class TypeVisitor : AstVisitor {
    usedTypes : OnlyUsedTypes 
    def TypeVisitor {
        pass
    }
    def collect(typ : TypeDeclPtr) {
        if (typ.baseType == Type.tStructure) {
            if (usedTypes.st |> key_exists(typ.structType)) {
                return
            }
        }
        if (typ.structType != null) {
            insert(usedTypes.st, typ.structType)
            for (fld in typ.structType.fields) {
                collect(fld._type)
            }
        }
        if (typ.enumType != null) {
            insert(usedTypes.en, typ.enumType)
        }
        if (typ.firstType != null) {
            collect(typ.firstType)
        }
        if (typ.secondType != null) {
            collect(typ.secondType)
        }
        for (arg in typ.argTypes) {
            collect(arg)
        }
    }
    def override preVisitTypeDecl(typ : TypeDeclPtr) : void {
        collect(typ)
    }
}

def public collect_used_types(vfun : array<Function?>; vvar : array<Variable?>; blk : block<(usedTypes : OnlyUsedTypes) : void>) {
    
    
    var astVisitor = new TypeVisitor()
    var inscope astVisitorAdapter <- make_visitor(*astVisitor)
    for (f in vfun) {
        unsafe {
            visit(reinterpret<FunctionPtr> f, astVisitorAdapter)
        }
    }
    for (v in vvar) {
        astVisitor->collect(v._type)
    }
    invoke(blk, astVisitor.usedTypes)
    unsafe {
        delete astVisitor
    }
}
