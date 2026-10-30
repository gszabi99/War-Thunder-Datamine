options gen2
module runtime_memory shared public

struct ContextMemory {
    
    heap_used : uint64 
    heap_reserved : uint64 
    strings_used : uint64 
    strings_reserved : uint64 
    stack : uint64 
    globals : uint64 
    native_stack : uint64 
}
def context_memory() : ContextMemory {
    
    let overhead = context_memory_sizes()
    return ContextMemory(heap_used = heap_bytes_allocated(), heap_reserved = heap_total_allocated(),
        strings_used = string_heap_bytes_allocated(), strings_reserved = string_heap_total_allocated(),
        stack = overhead.x, globals = overhead.y, native_stack = native_thread_stack_size())
}

struct IdleForkMemory {
    
    count : uint64 
    memory : ContextMemory 
}
[arch(at="ARCHITECTURE_MEMORY.md#runtime-memory-snapshots")]
def context_idle_forks() : IdleForkMemory {
    
    
    let heap = context_idle_fork_memory(0); let strings = context_idle_fork_memory(1)
    let overhead = context_idle_fork_memory(2); let count = context_idle_fork_memory(3)
    return IdleForkMemory(count = count.x, memory = ContextMemory(heap_used = heap.x, heap_reserved = heap.y,
        strings_used = strings.x, strings_reserved = strings.y, stack = overhead.x, globals = overhead.y))
}
