options gen2

module aarch64_neon shared public


















def sdot4(acc : int4; w : int8 const?; x : int8 const?) : int4 {
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




def sdot4_w(acc : int4; w : int4; x : int8 const?) : int4 {
    var s0 = 0
    var s1 = 0
    var s2 = 0
    var s3 = 0
    unsafe {
        for (e in range(4)) {
            s0 += sign_extend_byte(w.x, e) * int(x[e])
            s1 += sign_extend_byte(w.y, e) * int(x[4 + e])
            s2 += sign_extend_byte(w.z, e) * int(x[8 + e])
            s3 += sign_extend_byte(w.w, e) * int(x[12 + e])
        }
    }
    return acc + int4(s0, s1, s2, s3)
}

def private sign_extend_byte(lane : int; e : int) : int => (((lane >> (e * 8)) & 0xff) ^ 0x80) - 0x80




def tbl16_lo(lut : int8 const?; nib : uint8 const?) : int4 {
    var l0 = 0
    var l1 = 0
    var l2 = 0
    var l3 = 0
    unsafe {
        for (e in range(4)) {
            l0 |= (int(lut[int(nib[e]) & 0x0f]) & 0xff) << (e * 8)
            l1 |= (int(lut[int(nib[4 + e]) & 0x0f]) & 0xff) << (e * 8)
            l2 |= (int(lut[int(nib[8 + e]) & 0x0f]) & 0xff) << (e * 8)
            l3 |= (int(lut[int(nib[12 + e]) & 0x0f]) & 0xff) << (e * 8)
        }
    }
    return int4(l0, l1, l2, l3)
}




def tbl16_hi(lut : int8 const?; nib : uint8 const?) : int4 {
    var l0 = 0
    var l1 = 0
    var l2 = 0
    var l3 = 0
    unsafe {
        for (e in range(4)) {
            l0 |= (int(lut[int(nib[e]) >> 4]) & 0xff) << (e * 8)
            l1 |= (int(lut[int(nib[4 + e]) >> 4]) & 0xff) << (e * 8)
            l2 |= (int(lut[int(nib[8 + e]) >> 4]) & 0xff) << (e * 8)
            l3 |= (int(lut[int(nib[12 + e]) >> 4]) & 0xff) << (e * 8)
        }
    }
    return int4(l0, l1, l2, l3)
}




def sdot4_laneq(acc : int4; w : int8 const?; x : int8 const?; lane : int) : int4 {
    let b = lane * 4
    var r = acc
    unsafe {
        let x0 = int(x[b])
        let x1 = int(x[b + 1])
        let x2 = int(x[b + 2])
        let x3 = int(x[b + 3])
        r.x += int(w[0]) * x0 + int(w[1]) * x1 + int(w[2]) * x2 + int(w[3]) * x3
        r.y += int(w[4]) * x0 + int(w[5]) * x1 + int(w[6]) * x2 + int(w[7]) * x3
        r.z += int(w[8]) * x0 + int(w[9]) * x1 + int(w[10]) * x2 + int(w[11]) * x3
        r.w += int(w[12]) * x0 + int(w[13]) * x1 + int(w[14]) * x2 + int(w[15]) * x3
    }
    return r
}




def sdot4_laneq_w(acc : int4; w : int4; x : int8 const?; lane : int) : int4 {
    let b = lane * 4
    var r = acc
    unsafe {
        let x0 = int(x[b])
        let x1 = int(x[b + 1])
        let x2 = int(x[b + 2])
        let x3 = int(x[b + 3])
        r.x += sign_extend_byte(w.x, 0) * x0 + sign_extend_byte(w.x, 1) * x1 + sign_extend_byte(w.x, 2) * x2 + sign_extend_byte(w.x, 3) * x3
        r.y += sign_extend_byte(w.y, 0) * x0 + sign_extend_byte(w.y, 1) * x1 + sign_extend_byte(w.y, 2) * x2 + sign_extend_byte(w.y, 3) * x3
        r.z += sign_extend_byte(w.z, 0) * x0 + sign_extend_byte(w.z, 1) * x1 + sign_extend_byte(w.z, 2) * x2 + sign_extend_byte(w.z, 3) * x3
        r.w += sign_extend_byte(w.w, 0) * x0 + sign_extend_byte(w.w, 1) * x1 + sign_extend_byte(w.w, 2) * x2 + sign_extend_byte(w.w, 3) * x3
    }
    return r
}




def smmla(acc : int4; a : int8 const?; b : int8 const?) : int4 {
    var d00 = 0
    var d01 = 0
    var d10 = 0
    var d11 = 0
    unsafe {
        for (k in range(8)) {
            let a0 = int(a[k])
            let a1 = int(a[8 + k])
            let b0 = int(b[k])
            let b1 = int(b[8 + k])
            d00 += a0 * b0
            d01 += a0 * b1
            d10 += a1 * b0
            d11 += a1 * b1
        }
    }
    return acc + int4(d00, d01, d10, d11)
}
