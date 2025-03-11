options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers

module archive shared private

require daslib/contracts
require daslib/apply
require daslib/templates
require math
require strings
require rtti

class public Serializer {
    
    def abstract write(bytes : void? implicit; size : int) : bool   
    def abstract read(bytes : void? implicit; size : int) : bool    
    def abstract error(code : string) : void                        
    def abstract OK : bool                                          
}

class public MemSerializer : Serializer {
    
    def MemSerializer {
        
        pass    
    }
    def MemSerializer(from : array<uint8>) {
        data := from
    }
    def extractData : array<uint8> {
        
        return <- data
    }
    def getCopyOfData : array<uint8> {
        
        var cdata := data
        return <- cdata
    }
    def getLastError {
        
        return lastError
    }
    def override OK {
        
        return lastError == ""
    }
    def override write(bytes : void? implicit; size : int) : bool {
        
        let pos = length(data)
        data |> resize_no_init(pos + size)
        unsafe {
            memcpy(addr(data[pos]), bytes, size)
        }
        return true
    }
    def override read(bytes : void? implicit; size : int) : bool {
        
        let newOffset = readOffset + size
        let maxOffset = length(data)
        if (newOffset > maxOffset) {
            error("reading past the end of stream")
            readOffset = maxOffset
            return false
        }
        unsafe {
            memcpy(bytes, addr(data[readOffset]), size)
        }
        readOffset = newOffset
        return true
    }
    def override error(code : string) : void {
        
        lastError = code
    }
    private data : array<uint8>
    private readOffset : int
    private lastError : string
}

struct public Archive {
    
    version : uint
    reading : bool
    stream  : Serializer?
}

def public serialize_raw(var arch : Archive; var value : auto(TT)&) {
    
    if (arch.reading) {
        arch.stream->read(unsafe(addr(value)), typeinfo sizeof(value))
    } else {
        arch.stream->write(unsafe(addr(value)), typeinfo sizeof(value))
    }
}

def public read_raw(var arch : Archive; var value : auto(TT)&) {
    
    assert(arch.reading)
    arch.stream->read(unsafe(addr(value)), typeinfo sizeof(value))
}

def public write_raw(var arch : Archive; var value : auto(TT)&) {
    
    assert(!arch.reading)
    arch.stream->write(unsafe(addr(value)), typeinfo sizeof(value))
}

[expect_any_enum(value) || expect_any_workhorse_raw(value) || expect_value_handle(value)]
def public serialize(var arch : Archive; var value : auto(TT)&) {
    
    arch |> serialize_raw(value)
}

[expect_any_function(value)]
def public serialize(var arch : Archive; var value : auto(TT)&) {
    if (arch.reading) {
        var mnh : uint64
        arch |> read_raw(mnh)
        if (mnh != 0ul) {
            unsafe {
                value = reinterpret<TT -#>(get_function_by_mangled_name_hash(mnh))
            }
        }
    } else {
        var mnh = get_function_mangled_name_hash(value)
        arch |> write_raw(mnh)
    }
}

def public serialize(var arch : Archive; var value : float3x3) {
    arch |> serialize_raw(value)
}

def public serialize(var arch : Archive; var value : float3x4) {
    arch |> serialize_raw(value)
}

def public serialize(var arch : Archive; var value : float4x4) {
    arch |> serialize_raw(value)
}

[expect_any_struct(value)]
def public serialize(var arch : Archive; var value : auto(TT)&) {
    if (arch.reading) {
        delete value
    }
    apply(value) <| $ [unused_argument(name)] (name : string; field) {
        arch |> _::serialize(field)
    }
}

[expect_any_tuple(value)]
def public serialize(var arch : Archive; var value : auto(TT)&) {
    if (arch.reading) {
        delete value
    }
    apply(value) <| $ [unused_argument(name)] (name : string; field) {
        arch |> _::serialize(field)
    }
}

[expect_any_variant(value)]
def public serialize(var arch : Archive; var value : auto(TT)&) {
    if (arch.reading) {
        delete value
        var index : int
        arch |> read_raw(index)
        unsafe {
            value |> set_variant_index(index)
        }
    } else {
        var index = variant_index(value)
        arch |> write_raw(index)
    }
    apply(value) <| $ [unused_argument(name)] (name : string; field) {
        arch |> _::serialize(field)
    }
}

def public serialize(var arch : Archive; var value : auto(TT)[]) {
    for (element in value) {
        arch |> _::serialize(element)
    }
}

def public serialize(var arch : Archive; var value : array<auto(TT)>) {
    if (arch.reading) {
        var len : int
        unsafe {
            delete value
        }
        arch |> read_raw(len)
        value |> resize(len)
        for (element in value) {
            arch |> _::serialize(element)
        }
    } else {
        var len = length(value)
        arch |> write_raw(len)
        for (element in value) {
            arch |> _::serialize(element)
        }
    }
}

def public serialize(var arch : Archive; var value : table<auto(KT); auto(VT)>) {
    if (arch.reading) {
        var len : int
        arch |> read_raw(len)
        delete value
        for (_ in range(len)) {
            var k : KT -const -& -#
            arch |> _::serialize(k)
            arch |> _::serialize(unsafe(value[k]))
        }
    } else {
        var len = length(value)
        arch |> write_raw(len)
        for (k, v in keys(value), values(value)) {
            var K = k
            arch |> _::serialize(K)
            arch |> _::serialize(v)
        }
    }
}

def public serialize(var arch : Archive; var value : string&) {
    unsafe {
        if (arch.reading) {
            var len : int
            arch |> read_raw(len)
            if (len > 0) {
                var tbuf : array<uint8>
                tbuf |> resize_no_init(len + 1)                         
                arch.stream->read(addr(tbuf[0]), len)
                tbuf[len] = 0u8
                value = clone_string(reinterpret<string#> addr(tbuf[0]))
                delete tbuf
            } else {
                value = ""
            }
        } else {
            var len = length(value)
            arch |> write_raw(len)
            if (len > 0) {
                arch.stream->write(reinterpret<void?> value, len)
            }
        }
    }
}

def public serialize(var arch : Archive; var value : auto(TT)?) {
    if (arch.reading) {
        value = null
    }
}

def public mem_archive_save(var t : auto&) {
    
    var mems = new MemSerializer()
    var sarch = Archive(reading = false, stream = mems)
    sarch |> serialize(t)
    return <- mems->extractData()
}

def public mem_archive_load(var data : array<uint8>; var t : auto&; canfail : bool = false) : bool {
    
    var memr = new MemSerializer(data)
    var rarch = Archive(reading = true, stream = memr)
    rarch |> serialize(t)
    if (!memr->OK()) {
        if (!canfail) {
            panic(memr->getLastError())
        }
        return false
    }
    return true
}
