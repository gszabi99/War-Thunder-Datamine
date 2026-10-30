options gen2

module x64_avx shared public


















def dot4(acc : int4; w : int8 const?; x : int8 const?) : int4 {
    var s0 = 0
    var s1 = 0
    var s2 = 0
    var s3 = 0
    unsafe {
        for (e in range(4)) {
            s0 += int(w[e]) * int(x[e])
            s1 += int(w[4 + e]) * int(x[4 + e])
            s2 += int(w[8 + e]) * int(x[8 + e])
            s3 += int(w[12 + e]) * int(x[12 + e])
        }
    }
    return acc + int4(s0, s1, s2, s3)
}




def dot32(acc : int4; w : int8 const?; x : int8 const?) : int4 {
    var s0 = 0
    var s1 = 0
    var s2 = 0
    var s3 = 0
    unsafe {
        for (e in range(4)) {
            s0 += int(w[e]) * int(x[e]) + int(w[16 + e]) * int(x[16 + e])
            s1 += int(w[4 + e]) * int(x[4 + e]) + int(w[20 + e]) * int(x[20 + e])
            s2 += int(w[8 + e]) * int(x[8 + e]) + int(w[24 + e]) * int(x[24 + e])
            s3 += int(w[12 + e]) * int(x[12 + e]) + int(w[28 + e]) * int(x[28 + e])
        }
    }
    return acc + int4(s0, s1, s2, s3)
}




def dot32_ps(acc : float4; w : int8 const?; x : int8 const?; s : float) : float4 {
    let d = dot32(int4(0, 0, 0, 0), w, x)
    return acc + float4(d) * float4(s, s, s, s)
}




def dot32_acc8(var acc : float?; w : int8 const?; x : int8 const?; s : float) {
    unsafe {
        for (j in range(8)) {
            var q = 0
            for (e in range(4)) {
                q += int(w[j * 4 + e]) * int(x[j * 4 + e])
            }
            acc[j] += float(q) * s
        }
    }
}




def dot32_mx4(acc : int4; lut : int8 const?; wn : uint8 const?; x : int8 const?) : int4 {
    var s0 = 0
    var s1 = 0
    var s2 = 0
    var s3 = 0
    unsafe {
        for (e in range(4)) {
            s0 += int(lut[int(wn[e]) & 15]) * int(x[e]) + int(lut[int(wn[e]) >> 4]) * int(x[16 + e])
            s1 += int(lut[int(wn[4 + e]) & 15]) * int(x[4 + e]) + int(lut[int(wn[4 + e]) >> 4]) * int(x[20 + e])
            s2 += int(lut[int(wn[8 + e]) & 15]) * int(x[8 + e]) + int(lut[int(wn[8 + e]) >> 4]) * int(x[24 + e])
            s3 += int(lut[int(wn[12 + e]) & 15]) * int(x[12 + e]) + int(lut[int(wn[12 + e]) >> 4]) * int(x[28 + e])
        }
    }
    return acc + int4(s0, s1, s2, s3)
}




def mx4_dequant32(lut : int8 const?; wn : uint8 const?; var dst : int8?) {
    unsafe {
        for (j in range(16)) {
            let b = int(wn[j])
            dst[j] = lut[b & 15]
            dst[16 + j] = lut[b >> 4]
        }
    }
}




def dot32_vnni(acc : int4; w : int8 const?; x : int8 const?) : int4 {
    return dot32(acc, w, x)
}




def dot32_acc8_vnni(var acc : float?; w : int8 const?; x : int8 const?; s : float) {
    dot32_acc8(acc, w, x, s)
}




def dot32_mx4_vnni(acc : int4; lut : int8 const?; wn : uint8 const?; x : int8 const?) : int4 {
    return dot32_mx4(acc, lut, wn, x)
}




def dot64_acc16(var acc : float?; w : int8 const?; x : int8 const?; s0, s1 : float) {
    unsafe {
        dot32_acc8(acc, w, x, s0)
        dot32_acc8(acc + 8, w + 32, x + 32, s1)
    }
}




def dot64_acc16_vnni(var acc : float?; w : int8 const?; x : int8 const?; s0, s1 : float) {
    dot64_acc16(acc, w, x, s0, s1)
}




def mx4_dequant64(lut : int8 const?; wn : uint8 const?; var dst : int8?) {
    unsafe {
        mx4_dequant32(lut, wn, dst)
        mx4_dequant32(lut, wn + 16, dst + 32)
    }
}
