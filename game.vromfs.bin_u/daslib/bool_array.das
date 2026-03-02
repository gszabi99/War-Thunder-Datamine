options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options strict_smart_pointers = true

module bool_array shared public







require strings

struct BoolArray {
    
    private bits : array<uint>
    private real_size : uint
    [hint(unsafe_range_check, noalias=self)]
    def finalize {
        
        delete bits
    }
    def const operator [] (index : int) : bool {
        
        let uindex = uint(index)
        if (uindex >= real_size) panic("index out of range, {index}")
        let offs = uindex >> 5u
        let mask = (1u << (uindex & 31u))
        return (bits[offs] & mask) != 0u
    }
    [hint(unsafe_range_check, noalias=self)]
    def operator [] =(index : int, value : bool) {
        
        let uindex = uint(index)
        if (uindex >= real_size) panic("index out of range, {index}")
        let offs = uindex >> 5u
        let mask = (1u << (uindex & 31u))
        if (value) {
            bits[offs] |= mask
        } else {
            bits[offs] &= ~mask
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def operator [] ^^=(index : int, value : bool) {
        
        if (value) {
            let uindex = uint(index)
            if (uindex >= real_size) panic("index out of range, {index}")
            let offs = uindex >> 5u
            let mask = (1u << (uindex & 31u))
            bits[offs] ^= mask
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def operator [] &&=(index : int, value : bool) {
        
        if (!value) {
            let uindex = uint(index)
            if (uindex >= real_size) panic("index out of range, {index}")
            let offs = uindex >> 5u
            let mask = (1u << (uindex & 31u))
            bits[offs] &= ~mask
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def operator [] ||=(index : int, value : bool) {
        
        if (value) {
            let uindex = uint(index)
            if (uindex >= real_size) panic("index out of range, {index}")
            let offs = uindex >> 5u
            let mask = (1u << (uindex & 31u))
            bits[offs] |= mask
        }
    }
    def static clear(var self : BoolArray) {
        
        with (self) {
            real_size = 0u
            bits.clear()
        }
    }
    def static reserve(var self : BoolArray, capacity : int) {
        
        with (self) {
            assert(capacity >= 0)
            let needed_uints = (uint(capacity) + 31u) >> 5u
            bits.reserve(int(needed_uints))
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def static resize(var self : BoolArray, newSize : int) {
        
        with (self) {
            assert(newSize >= 0)
            let new_real_size = uint(newSize)
            if (new_real_size > real_size && (real_size & 31u) != 0u) {
                
                let offs = real_size >> 5u
                let tail_mask = (1u << (real_size & 31u)) - 1u
                bits[offs] &= tail_mask
            }
            real_size = new_real_size
            let newBitsCount = (real_size + 31u) >> 5u
            bits.resize(int(newBitsCount))
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def static push(var self : BoolArray, value : bool) {
        
        with (self) {
            if ((real_size & 31u) == 0u) {
                
                bits.push(0u)
            }
            let offs = real_size >> 5u
            let mask = (1u << (real_size & 31u))
            if (value) {
                bits[offs] |= mask
            } else {
                bits[offs] &= ~mask
            }
            real_size += 1u
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def static push(var self : BoolArray, value : bool, at : int) {
        
        if (at != int(self.real_size)) {
            self.insert(at, value)
        } else {
            self.push(value)
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def static pop(var self : BoolArray) : bool {
        
        with (self) {
            if (real_size == 0u) panic("pop from empty BoolArray")
            let old_size = real_size
            let value = self[ int(old_size - 1u) ]
            resize(self, int(real_size - 1u))
            return value
        }
    }
    def static length(self : BoolArray) : int {
        
        return int(self.real_size)
    }
    [hint(noalias=self)]
    def static erase(var self : BoolArray, index : int) {
        
        with (self) {
            let uindex = uint(index)
            if (uindex >= real_size) panic("index out of range, {index}")
            
            let start_offs = uindex >> 5u
            let start_bit = uindex & 31u
            let w = bits[start_offs]
            let low_bits = w & ((1u << start_bit) - 1u)
            let upper_bits = start_bit < 31u ? (w >> (start_bit + 1u)) : 0u
            var new_w = low_bits | (upper_bits << start_bit)
            
            let total_uints = (real_size + 31u) >> 5u
            for (offs in (start_offs + 1u) .. total_uints) {
                let next_w = bits[offs]
                let next_low_bit = next_w & 1u
                new_w |= (next_low_bit << 31u)
                bits[offs - 1u] = new_w
                new_w = next_w >> 1u
            }
            bits[total_uints - 1u] = new_w
            
            resize(self, int(real_size - 1u))
        }
    }
    [hint(unsafe_range_check, noalias=self)]
    def static insert(var self : BoolArray, index : int, value : bool) {
        
        with (self) {
            let uindex = uint(index)
            if (uindex > real_size) panic("index out of range, {index}")
            if (uindex == real_size) {
                push(self, value)
                return
            }
            resize(self, int(real_size + 1u))
            
            let start_offs = uindex >> 5u
            var start_bit = uindex & 31u
            var w = bits[start_offs]
            var carry_bit = w >> 31u
            var lower_bits = w & ((1u << start_bit) - 1u)
            var upper_bits = w & ~((1u << start_bit) - 1u)
            upper_bits <<= 1u
            let set_bit = value ? (1u << start_bit) : 0u
            w = lower_bits | set_bit | upper_bits
            bits[start_offs] = w
            
            let total_uints = (real_size + 31u) >> 5u
            for (offs in (start_offs + 1u) .. total_uints) {
                let next_w = bits[offs]
                let next_carry_bit = next_w >> 31u
                let next_lower_bits = next_w & ((1u << 31u) - 1u)
                let new_w = (next_lower_bits << 1u) | carry_bit
                bits[offs] = new_w
                carry_bit = next_carry_bit
            }
            bits[total_uints - 1u] |= carry_bit
        }
    }
    def static to_string(self : BoolArray) {
        
        return build_string() $(wr) {
            wr.write("[")
            for (bit in 0 .. int(self.real_size)) {
                if (bit != 0) wr.write(", ")
                wr.write(self[bit] ? "true" : "false")
            }
            wr.write("]")
        }
    }
    [unsafe_operation]
    def static data_pointer(var self : BoolArray) : uint ? {
        
        return unsafe(addr(self.bits[0]))
    }

    [unsafe_operation]
    def static data_pointer(self : BoolArray) : uint const ? {
        
        return unsafe(addr(self.bits[0]))
    }
}

[unsafe_outside_of_for, unsafe_deref]
def each(self : BoolArray) : iterator<bool> {
    
    let pself = unsafe(addr(self))
    return <- generator<bool>() <| $ {
        let len = (*pself).length()
        return false if (len == 0)
        let full_uints = uint(len) >> 5u
        let remaining_bits = uint(len) & 31u
        let data_ptr = unsafe((*pself).data_pointer())
        for (i in 0u .. full_uints) {
            var bits_value = unsafe(data_ptr[i])
            for (b in 0u .. 32u) {
                yield (bits_value & 1u) != 0u
                bits_value >>= 1u
            }
        }
        var tail = unsafe(data_ptr[full_uints])
        for (b in 0u .. remaining_bits) {
            yield (tail & 1u) != 0u
            tail >>= 1u
        }
        return false
    }
}
