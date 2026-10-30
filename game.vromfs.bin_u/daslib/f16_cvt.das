options gen2

module f16_cvt shared public














def f16_to_f32(h : uint) : float {
    let exp = (h >> 10u) & 0x1Fu
    let mant = h & 0x3FFu
    let neg = (h & 0x8000u) != 0u
    if (exp == 0u) {  
        let v = float(mant) * 5.9604644775390625e-8
        return neg ? -v : v
    }
    let sign = (h & 0x8000u) << 16u
    var bits : uint
    if (exp == 0x1Fu) {
        bits = sign | 0x7F800000u | (mant << 13u)
    } else {  
        bits = sign | ((exp + 112u) << 23u) | (mant << 13u)
    }
    return unsafe(reinterpret<float>(bits))
}



def f32_to_f16(f : float) : uint {
    let bits = unsafe(reinterpret<uint>(f))
    let sign = (bits >> 16u) & 0x8000u
    let absb = bits & 0x7FFFFFFFu
    if (absb > 0x7F800000u) {
        return sign | 0x7E00u
    }
    if (absb >= 0x47800000u) {         
        return sign | 0x7C00u
    }
    if (absb >= 0x38800000u) {         
        let v = absb - 0x38000000u     
        return sign | ((v + 0xFFFu + ((v >> 13u) & 1u)) >> 13u)  
    }
    let e = absb >> 23u                
    let m = (absb & 0x7FFFFFu) | 0x800000u
    if (e < 102u || (e == 102u && m == 0x800000u)) {  
        return sign
    }
    let sh = 126u - e                  
    let base = m >> sh
    let rem = m & ((1u << sh) - 1u)
    let half = 1u << (sh - 1u)
    let up = rem > half || (rem == half && (base & 1u) == 1u)
    return sign | (up ? base + 1u : base)  
}
