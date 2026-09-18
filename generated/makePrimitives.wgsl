// CUDA WebShader 0.1.0. Generated from kernel makePrimitives.
@group(0) @binding(0) var<storage, read> b_B: array<f32>;
@group(0) @binding(1) var<storage, read_write> b_P: array<f32>;
struct CWParams {
  p_seed: i32,
  cw_pad_4: u32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(2) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(64u, 1u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }

alias cw_f64 = vec2<u32>;
fn cw_d_shl(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(0u, a.x << (n - 32u)); }
  return vec2<u32>(a.x << n, (a.y << n) | (a.x >> (32u - n)));
}
fn cw_d_shr(a: vec2<u32>, n: u32) -> vec2<u32> {
  if(n == 0u) { return a; }
  if(n >= 64u) { return vec2<u32>(0u); }
  if(n >= 32u) { return vec2<u32>(a.y >> (n - 32u), 0u); }
  return vec2<u32>((a.x >> n) | (a.y << (32u - n)), a.y >> n);
}
fn cw_d_jam(a: vec2<u32>, n: u32) -> vec2<u32> {
  let shifted = cw_d_shr(a, n);
  return shifted | vec2<u32>(select(0u, 1u, any(cw_d_shl(shifted, n) != a)), 0u);
}
fn cw_d_uadd(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  let low = a.x + b.x;
  return vec2<u32>(low, a.y + b.y + select(0u, 1u, low < a.x));
}
fn cw_d_usub(a: vec2<u32>, b: vec2<u32>) -> vec2<u32> {
  return vec2<u32>(a.x - b.x, a.y - b.y - select(0u, 1u, a.x < b.x));
}
fn cw_d_uless(a: vec2<u32>, b: vec2<u32>) -> bool {
  return a.y < b.y || (a.y == b.y && a.x < b.x);
}
fn cw_d_nan(a: cw_f64) -> bool { return (a.y & 2147483647u) > 2146435072u || ((a.y & 2147483647u) == 2146435072u && a.x != 0u); }
fn cw_d_inf(a: cw_f64) -> bool { return (a.y & 2147483647u) == 2146435072u && a.x == 0u; }
fn cw_d_zero(a: cw_f64) -> bool { return (a.y & 2147483647u) == 0u && a.x == 0u; }
fn cw_d_neg(a: cw_f64) -> cw_f64 { return a ^ vec2<u32>(0u, 2147483648u); }
struct CWDoubleParts { significand: vec2<u32>, exponent: i32, }
fn cw_d_parts(a: cw_f64) -> CWDoubleParts {
  let raw = (a.y >> 20u) & 2047u;
  var s = vec2<u32>(a.x, a.y & 1048575u);
  var e = i32(raw) - 1023i;
  if(raw != 0u) { s.y |= 1048576u; }
  else {
    e = -1022i;
    if(any(s != vec2<u32>(0u))) {
      loop { if((s.y & 1048576u) != 0u) { break; } s = cw_d_shl(s, 1u); e--; }
    }
  }
  return CWDoubleParts(s,e);
}
// Input has its leading bit at bit 55 and three guard/round/sticky bits.
fn cw_d_pack(sign: u32, exponent: i32, value: vec2<u32>) -> cw_f64 {
  var e = exponent; var v = value;
  if(e < -1022i) { v = cw_d_jam(v, u32(-1022i-e)); e = -1022i; }
  let tail = v.x & 7u;
  var s = cw_d_shr(v, 3u);
  if(tail > 4u || (tail == 4u && (s.x & 1u) != 0u)) { s = cw_d_uadd(s,vec2<u32>(1u,0u)); }
  if((s.y & 2097152u) != 0u) { s = cw_d_shr(s,1u); e++; }
  if(e > 1023i) { return vec2<u32>(0u,sign | 2146435072u); }
  let field = select(0u, u32(e+1023i), (s.y & 1048576u) != 0u);
  return vec2<u32>(s.x, sign | (field << 20u) | (s.y & 1048575u));
}
fn cw_d_from_f32(a: f32) -> cw_f64 {
  let bits = bitcast<u32>(a); let sign = bits & 2147483648u;
  let field = (bits >> 23u) & 255u; var mantissa = bits & 8388607u;
  if(field == 255u) { return vec2<u32>(0u,sign | 2146435072u | select(0u,524288u,mantissa != 0u)); }
  if(field == 0u && mantissa == 0u) { return vec2<u32>(0u,sign); }
  var e = i32(field)-127i;
  if(field == 0u) { e = -126i; loop { if((mantissa & 8388608u) != 0u) { break; } mantissa <<= 1u; e--; } }
  let s = cw_d_shl(vec2<u32>(mantissa & 8388607u,0u),29u);
  return vec2<u32>(s.x,sign | (u32(e+1023i) << 20u) | s.y);
}
fn cw_d_from_u32(a: u32) -> cw_f64 {
  if(a == 0u) { return vec2<u32>(0u); }
  let e = 31u-countLeadingZeros(a); let s = cw_d_shl(vec2<u32>(a,0u),52u-e);
  return vec2<u32>(s.x,((e+1023u) << 20u) | (s.y & 1048575u));
}
fn cw_d_from_i32(a: i32) -> cw_f64 {
  if(a < 0i) { return cw_d_neg(cw_d_from_u32(0u-u32(a))); }
  return cw_d_from_u32(u32(a));
}
fn cw_d_to_f32(a: cw_f64) -> f32 {
  let sign = a.y & 2147483648u;
  if(cw_d_nan(a)) { return bitcast<f32>(sign | 2143289344u); }
  if(cw_d_inf(a)) { return bitcast<f32>(sign | 2139095040u); }
  if(cw_d_zero(a)) { return bitcast<f32>(sign); }
  let p = cw_d_parts(a); var e = p.exponent;
  let shift = 29u + u32(max(-126i-e,0i));
  // Keep three rounding bits while reducing the 53-bit significand to 24 bits.
  let v = cw_d_jam(p.significand,shift-3u); let tail = v.x & 7u;
  var s = cw_d_shr(v,3u).x;
  if(tail > 4u || (tail == 4u && (s & 1u) != 0u)) { s++; }
  e = max(e,-126i);
  if(s >= 16777216u) { s >>= 1u; e++; }
  if(e > 127i) { return bitcast<f32>(sign | 2139095040u); }
  let field = select(0u,u32(e+127i),s >= 8388608u);
  return bitcast<f32>(sign | (field << 23u) | (s & 8388607u));
}
fn cw_d_u64_to_f32(a: vec2<u32>) -> f32 {
  if(all(a == vec2<u32>(0u))) { return 0.0f; }
  var e = select(31u-countLeadingZeros(a.x),63u-countLeadingZeros(a.y),a.y != 0u);
  var v: vec2<u32>;
  if(e > 26u) { v = cw_d_jam(a,e-26u); } else { v = cw_d_shl(a,26u-e); }
  let tail = v.x & 7u; var s = v.x >> 3u;
  if(tail > 4u || (tail == 4u && (s & 1u) != 0u)) { s++; }
  if(s >= 16777216u) { s >>= 1u; e++; }
  return bitcast<f32>(((e+127u) << 23u) | (s & 8388607u));
}
fn cw_d_eq(a: cw_f64,b: cw_f64) -> bool { return !cw_d_nan(a) && !cw_d_nan(b) && (all(a == b) || (cw_d_zero(a) && cw_d_zero(b))); }
fn cw_d_lt(a: cw_f64,b: cw_f64) -> bool {
  if(cw_d_nan(a) || cw_d_nan(b) || cw_d_eq(a,b)) { return false; }
  let sa = a.y >> 31u; let sb = b.y >> 31u;
  if(sa != sb) { return sa != 0u; }
  return select(cw_d_uless(a,b),cw_d_uless(b,a),sa != 0u);
}
fn cw_d_le(a: cw_f64,b: cw_f64) -> bool { return cw_d_lt(a,b) || cw_d_eq(a,b); }
fn cw_d_add(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_inf(b) && ((a.y ^ b.y) >> 31u) != 0u)) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a)) { return a; } if(cw_d_inf(b)) { return b; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y & b.y) & 2147483648u); }
  if(cw_d_zero(a)) { return b; } if(cw_d_zero(b)) { return a; }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b);
  var x = cw_d_shl(pa.significand,3u); var y = cw_d_shl(pb.significand,3u);
  var e = max(pa.exponent,pb.exponent); var sign = a.y & 2147483648u;
  x = cw_d_jam(x,u32(e-pa.exponent)); y = cw_d_jam(y,u32(e-pb.exponent));
  var sum: vec2<u32>;
  if(((a.y ^ b.y) >> 31u) == 0u) {
    sum = cw_d_uadd(x,y);
    if((sum.y & 16777216u) != 0u) { sum = cw_d_jam(sum,1u); e++; }
  } else {
    if(cw_d_uless(x,y)) { sum = cw_d_usub(y,x); sign = b.y & 2147483648u; }
    else { sum = cw_d_usub(x,y); }
    if(all(sum == vec2<u32>(0u))) { return vec2<u32>(0u); }
    loop { if((sum.y & 8388608u) != 0u) { break; } sum = cw_d_shl(sum,1u); e--; }
  }
  return cw_d_pack(sign,e,sum);
}
fn cw_d_sub(a: cw_f64,b: cw_f64) -> cw_f64 { return cw_d_add(a,cw_d_neg(b)); }
fn cw_d_mul(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_zero(b)) || (cw_d_inf(b) && cw_d_zero(a))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b);
  if(all(pa.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pb.significand,3u)); }
  if(all(pb.significand == vec2<u32>(0u,1048576u))) { return cw_d_pack(sign,pa.exponent+pb.exponent,cw_d_shl(pa.significand,3u)); }
  var product = vec4<u32>(0u); var term = vec4<u32>(pa.significand,0u,0u); var multiplier = pb.significand;
  for(var i = 0u; i < 53u; i++) {
    if((multiplier.x & 1u) != 0u) {
      var carry = 0u;
      for(var j = 0u; j < 4u; j++) {
        let p = product[j]; let s = p + term[j]; let t = s + carry;
        carry = select(0u,1u,s < p || t < s); product[j] = t;
      }
    }
    term = vec4<u32>(term.x << 1u,(term.y << 1u) | (term.x >> 31u),(term.z << 1u) | (term.y >> 31u),(term.w << 1u) | (term.z >> 31u));
    multiplier = cw_d_shr(multiplier,1u);
  }
  let extra = select(0u,1u,(product.w & 512u) != 0u);
  for(var i = 0u; i < 49u+extra; i++) {
    product = vec4<u32>((product.x >> 1u) | (product.y << 31u) | (product.x & 1u),(product.y >> 1u) | (product.z << 31u),(product.z >> 1u) | (product.w << 31u),product.w >> 1u);
  }
  return cw_d_pack(sign,pa.exponent+pb.exponent+i32(extra),product.xy);
}
fn cw_d_div(a: cw_f64,b: cw_f64) -> cw_f64 {
  let sign = (a.y ^ b.y) & 2147483648u;
  if(cw_d_nan(a) || cw_d_nan(b) || (cw_d_inf(a) && cw_d_inf(b)) || (cw_d_zero(a) && cw_d_zero(b))) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a) || cw_d_zero(b)) { return vec2<u32>(0u,sign | 2146435072u); }
  if(cw_d_zero(a) || cw_d_inf(b)) { return vec2<u32>(0u,sign); }
  let pa = cw_d_parts(a); let pb = cw_d_parts(b); var e = pa.exponent-pb.exponent;
  var remainder = pa.significand; var q = vec2<u32>(0u);
  if(cw_d_uless(remainder,pb.significand)) { remainder = cw_d_shl(remainder,1u); e--; }
  for(var i = 0u; i < 56u; i++) {
    q = cw_d_shl(q,1u);
    if(!cw_d_uless(remainder,pb.significand)) { remainder = cw_d_usub(remainder,pb.significand); q.x |= 1u; }
    if(i < 55u) { remainder = cw_d_shl(remainder,1u); }
  }
  if(any(remainder != vec2<u32>(0u))) { q.x |= 1u; }
  return cw_d_pack(sign,e,q);
}

// Restoring square root: 56 root bits include guard/round/sticky for binary64.
fn cw_d_sqrt(a: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_zero(a)) { return a; }
  if((a.y & 2147483648u) != 0u) { return vec2<u32>(0u,2146959360u); }
  if(cw_d_inf(a)) { return a; }
  let p = cw_d_parts(a);
  let odd = p.exponent & 1i;
  let shift = 58i + odd;
  var root = vec2<u32>(0u);
  var remainder = vec2<u32>(0u);
  for(var i=55i; i>=0i; i--) {
    var pair=0u;
    for(var j=0i; j<2i; j++) {
      let bit=2i*i+j-shift;
      if(bit>=0i && bit<53i) { pair |= ((p.significand[u32(bit)/32u] >> (u32(bit)%32u)) & 1u) << u32(j); }
    }
    remainder=cw_d_shl(remainder,2u); remainder.x |= pair;
    var trial=cw_d_shl(root,2u); trial.x |= 1u;
    root=cw_d_shl(root,1u);
    if(!cw_d_uless(remainder,trial)) { remainder=cw_d_usub(remainder,trial); root.x |= 1u; }
  }
  if(any(remainder!=vec2<u32>(0u))) { root.x |= 1u; }
  return cw_d_pack(0u,(p.exponent-odd)/2i,root);
}
fn cw_d_fmin(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return b; } if(cw_d_nan(b)) { return a; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y | b.y) & 2147483648u); }
  return select(b,a,cw_d_lt(a,b));
}
fn cw_d_fmax(a: cw_f64,b: cw_f64) -> cw_f64 {
  if(cw_d_nan(a)) { return b; } if(cw_d_nan(b)) { return a; }
  if(cw_d_zero(a) && cw_d_zero(b)) { return vec2<u32>(0u,(a.y & b.y) & 2147483648u); }
  return select(a,b,cw_d_lt(a,b));
}

fn f_clampf(cw_arg_x: f32, cw_arg_a: f32, cw_arg_b: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  return min(v_b, max(v_a, v_x));
}
fn f_sat(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  return f_clampf(v_x, 0.0f, 1.0f, cw_thread, cw_block, cw_grid);
}
fn f_lerp(cw_arg_a: f32, cw_arg_b: f32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  var v_t: f32 = cw_arg_t;
  return (v_a + ((v_b - v_a) * v_t));
}
fn f_frac(cw_arg_a: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  return (v_a - floor(v_a));
}
fn f_smooth(cw_arg_a: f32, cw_arg_b: f32, cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: f32 = cw_arg_a;
  var v_b: f32 = cw_arg_b;
  var v_x: f32 = cw_arg_x;
  var v_t: f32 = f_sat(cw_divide_f32((v_x - v_a), (v_b - v_a)), cw_thread, cw_block, cw_grid);
  return ((v_t * v_t) * (3.0f - (2.0f * v_t)));
}
fn f_dot3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return (((v_a.x * v_b.x) + (v_a.y * v_b.y)) + (v_a.z * v_b.z));
}
fn f_cross3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(((v_a.y * v_b.z) - (v_a.z * v_b.y)), ((v_a.z * v_b.x) - (v_a.x * v_b.z)), ((v_a.x * v_b.y) - (v_a.y * v_b.x)));
}
fn f_length3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_a: vec3<f32> = cw_arg_a;
  return sqrt(f_dot3(v_a, v_a, cw_thread, cw_block, cw_grid));
}
fn f_norm3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  return (v_a / vec3<f32>(max(1e-7f, f_length3(v_a, cw_thread, cw_block, cw_grid))));
}
fn f_min3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(min(v_a.x, v_b.x), min(v_a.y, v_b.y), min(v_a.z, v_b.z));
}
fn f_max3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  return vec3<f32>(max(v_a.x, v_b.x), max(v_a.y, v_b.y), max(v_a.z, v_b.z));
}
fn f_abs3(cw_arg_a: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  return vec3<f32>(abs(v_a.x), abs(v_a.y), abs(v_a.z));
}
fn f_mix3(cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  var v_t: f32 = cw_arg_t;
  return (v_a + ((v_b - v_a) * vec3<f32>(v_t)));
}
fn f_hashU(cw_arg_x: u32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_x: u32 = cw_arg_x;
  v_x = (v_x ^ (v_x >> u32(16i)));
  v_x = (v_x * 2146121005u);
  v_x = (v_x ^ (v_x >> u32(15i)));
  v_x = (v_x * 2221713035u);
  v_x = (v_x ^ (v_x >> u32(16i)));
  return v_x;
}
fn f_rnd(cw_arg_n: i32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_n: i32 = cw_arg_n;
  var v_seed: i32 = cw_arg_seed;
  return cw_divide_f32(f32((f_hashU((u32(v_n) ^ f_hashU(u32(v_seed), cw_thread, cw_block, cw_grid)), cw_thread, cw_block, cw_grid) & 16777215u)), 16777216.0f);
}
fn f_hash2(cw_arg_x: i32, cw_arg_y: i32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_seed: i32 = cw_arg_seed;
  return f_rnd(((v_x * 1973i) + (v_y * 9277i)), v_seed, cw_thread, cw_block, cw_grid);
}
fn f_noise(cw_arg_x: f32, cw_arg_y: f32, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var v_y: f32 = cw_arg_y;
  var v_seed: i32 = cw_arg_seed;
  var v_ix: i32 = i32(floor(v_x));
  var v_iy: i32 = i32(floor(v_y));
  var v_fx: f32 = f_frac(v_x, cw_thread, cw_block, cw_grid);
  var v_fy: f32 = f_frac(v_y, cw_thread, cw_block, cw_grid);
  v_fx = ((v_fx * v_fx) * (3.0f - (2.0f * v_fx)));
  v_fy = ((v_fy * v_fy) * (3.0f - (2.0f * v_fy)));
  return f_lerp(f_lerp(f_hash2(v_ix, v_iy, v_seed, cw_thread, cw_block, cw_grid), f_hash2((v_ix + 1i), v_iy, v_seed, cw_thread, cw_block, cw_grid), v_fx, cw_thread, cw_block, cw_grid), f_lerp(f_hash2(v_ix, (v_iy + 1i), v_seed, cw_thread, cw_block, cw_grid), f_hash2((v_ix + 1i), (v_iy + 1i), v_seed, cw_thread, cw_block, cw_grid), v_fx, cw_thread, cw_block, cw_grid), v_fy, cw_thread, cw_block, cw_grid);
}
fn f_noise3(cw_arg_p: vec3<f32>, cw_arg_seed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_p: vec3<f32> = cw_arg_p;
  var v_seed: i32 = cw_arg_seed;
  var v_iz: i32 = i32(floor(v_p.z));
  var v_f: f32 = f_frac(v_p.z, cw_thread, cw_block, cw_grid);
  v_f = ((v_f * v_f) * (3.0f - (2.0f * v_f)));
  return f_lerp(f_noise(v_p.x, v_p.y, (v_seed + (v_iz * 131i)), cw_thread, cw_block, cw_grid), f_noise(v_p.x, v_p.y, (v_seed + ((v_iz + 1i) * 131i)), cw_thread, cw_block, cw_grid), v_f, cw_thread, cw_block, cw_grid);
}
fn f_invSafe(cw_arg_x: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_x: f32 = cw_arg_x;
  var cw_tmp_1: f32;
  if ((abs(v_x) < 1e-8f)) {
    var cw_tmp_0: f32;
    if ((v_x < 0.0f)) {
      cw_tmp_0 = (-100000000.0f);
    } else {
      cw_tmp_0 = 100000000.0f;
    }
    cw_tmp_1 = cw_tmp_0;
  } else {
    cw_tmp_1 = cw_divide_f32(1.0f, v_x);
  }
  return cw_tmp_1;
}
fn f_boxSpan(cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_lo: vec3<f32>, cw_arg_hi: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_lo: vec3<f32> = cw_arg_lo;
  var v_hi: vec3<f32> = cw_arg_hi;
  var v_a: vec3<f32> = ((v_lo - v_ro) * vec3<f32>(f_invSafe(v_rd.x, cw_thread, cw_block, cw_grid), f_invSafe(v_rd.y, cw_thread, cw_block, cw_grid), f_invSafe(v_rd.z, cw_thread, cw_block, cw_grid)));
  var v_b: vec3<f32> = ((v_hi - v_ro) * vec3<f32>(f_invSafe(v_rd.x, cw_thread, cw_block, cw_grid), f_invSafe(v_rd.y, cw_thread, cw_block, cw_grid), f_invSafe(v_rd.z, cw_thread, cw_block, cw_grid)));
  var v_mn: vec3<f32> = f_min3(v_a, v_b, cw_thread, cw_block, cw_grid);
  var v_mx: vec3<f32> = f_max3(v_a, v_b, cw_thread, cw_block, cw_grid);
  return vec2<f32>(max(v_mn.x, max(v_mn.y, v_mn.z)), min(v_mx.x, min(v_mx.y, v_mx.z)));
}
fn f_basisU(cw_arg_n: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_n: vec3<f32> = cw_arg_n;
  var cw_tmp_2: vec3<f32>;
  if ((abs(v_n.y) < 0.91f)) {
    cw_tmp_2 = vec3<f32>(0.0f, 1.0f, 0.0f);
  } else {
    cw_tmp_2 = vec3<f32>(0.0f, 0.0f, 1.0f);
  }
  return f_norm3(f_cross3(cw_tmp_2, v_n, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
}
fn f_bandWeight(cw_arg_period: f32, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_period: f32 = cw_arg_period;
  var v_footprint: f32 = cw_arg_footprint;
  return (1.0f - f_smooth((v_period * 0.12f), (v_period * 0.65f), v_footprint, cw_thread, cw_block, cw_grid));
}
fn f_packRGB(cw_arg_c: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_c: vec3<f32> = cw_arg_c;
  var v_r: u32 = u32(((f_sat(v_c.x, cw_thread, cw_block, cw_grid) * 255.0f) + 0.5f));
  var v_g: u32 = u32(((f_sat(v_c.y, cw_thread, cw_block, cw_grid) * 255.0f) + 0.5f));
  var v_b: u32 = u32(((f_sat(v_c.z, cw_thread, cw_block, cw_grid) * 255.0f) + 0.5f));
  return (((v_r | (v_g << u32(8i))) | (v_b << u32(16i))) | 4278190080u);
}
fn f_halton(cw_arg_n: i32, cw_arg_base: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_n: i32 = cw_arg_n;
  var v_base: i32 = cw_arg_base;
  var v_f: f32 = 1.0f;
  var v_r: f32 = 0.0f;
  {
    var v_j: i32 = 0i;
    loop {
      if (!(v_j < 12i)) { break; }
      if ((v_n <= 0i)) {
        break;
      }
      v_f = cw_divide_f32(v_f, f32(v_base));
      v_r = (v_r + (v_f * f32((v_n % v_base))));
      v_n = (v_n / v_base);
      continuing {
        v_j += i32(1);
      }
    }
  }
  return v_r;
}
fn f_forestSeed(cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> i32 {
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  return i32((f_hashU(u32((((v_tree * 92821i) + (v_worldSeed * 68917i)) + 17i)), cw_thread, cw_block, cw_grid) & 1048575u));
}
fn f_forestPos(cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_x: i32 = ((v_tree % 18i) - (18i / 2i));
  var v_z: i32 = ((v_tree / 18i) - (18i / 2i));
  var v_s: i32 = f_forestSeed(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
  var v_jx: f32 = ((f_rnd(1i, v_s, cw_thread, cw_block, cw_grid) - 0.5f) * 10.0f);
  var v_jz: f32 = ((f_rnd(2i, v_s, cw_thread, cw_block, cw_grid) - 0.5f) * 10.0f);
  var v_warpX: f32 = ((f_noise((f32(v_x) * 0.19f), (f32(v_z) * 0.19f), (v_worldSeed + 311i), cw_thread, cw_block, cw_grid) - 0.5f) * 3.0f);
  var v_warpZ: f32 = ((f_noise(((f32(v_x) * 0.19f) + 17.0f), ((f32(v_z) * 0.19f) - 9.0f), (v_worldSeed + 733i), cw_thread, cw_block, cw_grid) - 0.5f) * 3.0f);
  return vec3<f32>((((f32(v_x) * 28.0f) + v_jx) + v_warpX), 0.0f, (((f32(v_z) * 28.0f) + v_jz) + v_warpZ));
}
fn f_forestScale(cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_s: i32 = f_forestSeed(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
  return (0.72f + (f_rnd(3i, v_s, cw_thread, cw_block, cw_grid) * 0.62f));
}
fn f_forestYaw(cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  return ((f_rnd(4i, f_forestSeed(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid) * 3.14159265359f) * 2.0f);
}
fn f_forestToLocalPoint(cw_arg_p: vec3<f32>, cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_p: vec3<f32> = cw_arg_p;
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_q: vec3<f32> = (v_p - f_forestPos(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid));
  var v_a: f32 = (-f_forestYaw(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid));
  var v_c: f32 = cos(v_a);
  var v_s: f32 = sin(v_a);
  var v_sc: f32 = f_forestScale(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
  return (vec3<f32>(((v_q.x * v_c) - (v_q.z * v_s)), v_q.y, ((v_q.x * v_s) + (v_q.z * v_c))) / vec3<f32>(v_sc));
}
fn f_forestToLocalDir(cw_arg_d: vec3<f32>, cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_d: vec3<f32> = cw_arg_d;
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_a: f32 = (-f_forestYaw(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid));
  var v_c: f32 = cos(v_a);
  var v_s: f32 = sin(v_a);
  return f_norm3(vec3<f32>(((v_d.x * v_c) - (v_d.z * v_s)), v_d.y, ((v_d.x * v_s) + (v_d.z * v_c))), cw_thread, cw_block, cw_grid);
}
fn f_forestToWorldNormal(cw_arg_n: vec3<f32>, cw_arg_tree: i32, cw_arg_worldSeed: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var v_n: vec3<f32> = cw_arg_n;
  var v_tree: i32 = cw_arg_tree;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_a: f32 = f_forestYaw(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
  var v_c: f32 = cos(v_a);
  var v_s: f32 = sin(v_a);
  return f_norm3(vec3<f32>(((v_n.x * v_c) - (v_n.z * v_s)), v_n.y, ((v_n.x * v_s) + (v_n.z * v_c))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_t: f32 = cw_arg_t;
  var v_b: i32 = (v_id * 20i);
  var v_q: f32 = (1.0f - v_t);
  return ((((f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid) * vec3<f32>(((v_q * v_q) * v_q))) + (f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 3i), cw_thread, cw_block, cw_grid) * vec3<f32>((((3.0f * v_q) * v_q) * v_t)))) + (f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 6i), cw_thread, cw_block, cw_grid) * vec3<f32>((((3.0f * v_q) * v_t) * v_t)))) + (f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 9i), cw_thread, cw_block, cw_grid) * vec3<f32>(((v_t * v_t) * v_t))));
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_arg_v: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  var v_v: vec3<f32> = cw_arg_v;
  b_P[(cw_buffer_offset_0 + v_i)] = v_v.x;
  b_P[(cw_buffer_offset_0 + (v_i + 1i))] = v_v.y;
  b_P[(cw_buffer_offset_0 + (v_i + 2i))] = v_v.z;
}
fn f_cw_buffer_helper_2(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_t: f32 = cw_arg_t;
  let cw_argument_index_3 = (cw_buffer_offset_0 + ((v_id * 20i) + 12i));
  let cw_argument_index_4 = (cw_buffer_offset_0 + ((v_id * 20i) + 13i));
  return f_lerp(b_B[cw_argument_index_3], b_B[cw_argument_index_4], v_t, cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_3(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_t: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_t: f32 = cw_arg_t;
  var v_b: i32 = (v_id * 20i);
  var v_q: f32 = (1.0f - v_t);
  return f_norm3(((((f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 3i), cw_thread, cw_block, cw_grid) - f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid)) * vec3<f32>((v_q * v_q))) + ((f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 6i), cw_thread, cw_block, cw_grid) - f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 3i), cw_thread, cw_block, cw_grid)) * vec3<f32>(((2.0f * v_q) * v_t)))) + ((f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 9i), cw_thread, cw_block, cw_grid) - f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), (v_b + 6i), cw_thread, cw_block, cw_grid)) * vec3<f32>((v_t * v_t)))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_4(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  let cw_argument_index_5 = (cw_buffer_offset_0 + v_i);
  let cw_argument_index_6 = (cw_buffer_offset_0 + (v_i + 1i));
  let cw_argument_index_7 = (cw_buffer_offset_0 + (v_i + 2i));
  return vec3<f32>(b_B[cw_argument_index_5], b_B[cw_argument_index_6], b_B[cw_argument_index_7]);
}

fn cw_pow_f32(base: f32, exponent: f32) -> f32 {
  if(exponent >= -64.0f && exponent <= 64.0f && exponent == trunc(exponent)) {
    var count=u32(abs(exponent));
    var value=cw_d_from_f32(base);var product=cw_d_from_u32(1u);
    loop {
      if(count == 0u) { break; }
      if((count & 1u) != 0u) { product=cw_d_mul(product,value); }
      count >>= 1u;
      if(count != 0u) { value=cw_d_mul(value,value); }
    }
    if(exponent < 0.0f) { product=cw_d_div(cw_d_from_u32(1u),product); }
    return cw_d_to_f32(product);
  }
  return pow(base,exponent);
}

@compute @workgroup_size(64, 1, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_i: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  if ((v_i >= 32768i)) {
    return;
  }
  var v_b: i32 = (v_i * 24i);
  {
    var v_j: i32 = 0i;
    loop {
      if (!(v_j < 24i)) { break; }
      b_P[(v_b + v_j)] = 0.0f;
      continuing {
        v_j += i32(1);
      }
    }
  }
  b_P[(v_b + 3i)] = (-1.0f);
  if ((v_i >= 29412i)) {
    return;
  }
  if ((v_i < 5124i)) {
    var v_c: i32 = 0i;
    var v_segment: i32 = 0i;
    var v_segments: i32 = 12i;
    if ((v_i < 12i)) {
      v_c = 0i;
      v_segment = v_i;
      v_segments = 12i;
    } else {
      if ((v_i < 60i)) {
        v_c = (1i + ((v_i - 12i) / 6i));
        v_segment = ((v_i - 12i) % 6i);
        v_segments = 6i;
      } else {
        if ((v_i < 156i)) {
          v_c = (9i + ((v_i - 60i) / 8i));
          v_segment = ((v_i - 60i) % 8i);
          v_segments = 8i;
        } else {
          if ((v_i < 516i)) {
            v_c = (21i + ((v_i - 156i) / 5i));
            v_segment = ((v_i - 156i) % 5i);
            v_segments = 5i;
          } else {
            if ((v_i < 1668i)) {
              v_c = (93i + ((v_i - 516i) / 4i));
              v_segment = ((v_i - 516i) % 4i);
              v_segments = 4i;
            } else {
              v_c = (381i + ((v_i - 1668i) / 2i));
              v_segment = ((v_i - 1668i) % 2i);
              v_segments = 2i;
            }
          }
        }
      }
    }
    var v_t0: f32 = cw_divide_f32(f32(v_segment), f32(v_segments));
    var v_t1: f32 = cw_divide_f32(f32((v_segment + 1i)), f32(v_segments));
    f_cw_buffer_helper_1(0i, v_b, f_cw_buffer_helper_0(0i, v_c, v_t0, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    b_P[(v_b + 3i)] = 0.0f;
    f_cw_buffer_helper_1(0i, (v_b + 4i), f_cw_buffer_helper_0(0i, v_c, v_t1, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    b_P[(v_b + 7i)] = f_cw_buffer_helper_2(0i, v_c, v_t0, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 11i)] = f_cw_buffer_helper_2(0i, v_c, v_t1, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 15i)] = b_B[((v_c * 20i) + 15i)];
    var v_arclength: f32 = b_B[((v_c * 20i) + 14i)];
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 12i)) { break; }
        if ((v_j < v_segment)) {
          v_arclength = (v_arclength + f_length3((f_cw_buffer_helper_0(0i, v_c, cw_divide_f32(f32((v_j + 1i)), f32(v_segments)), cw_thread, cw_block, cw_grid) - f_cw_buffer_helper_0(0i, v_c, cw_divide_f32(f32(v_j), f32(v_segments)), cw_thread, cw_block, cw_grid)), cw_thread, cw_block, cw_grid));
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
    b_P[(v_b + 16i)] = v_arclength;
    b_P[(v_b + 17i)] = f32(v_c);
    b_P[(v_b + 18i)] = b_B[((v_c * 20i) + 12i)];
    f_cw_buffer_helper_1(0i, (v_b + 8i), f_basisU(f_cw_buffer_helper_3(0i, v_c, 0.0f, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    return;
  }
  if ((v_i < (5124i + 24192i))) {
    var v_leaf: i32 = (v_i - 5124i);
    var v_twig: i32 = (v_leaf / 14i);
    var v_k: i32 = (v_leaf % 14i);
    var v_c: i32 = (381i + v_twig);
    var v_h: f32 = f_rnd((v_leaf + 13i), cw_params.p_seed, cw_thread, cw_block, cw_grid);
    var v_t: f32 = (0.16f + cw_divide_f32((0.81f * (f32(v_k) + 0.4f)), 14.0f));
    var v_anchor: vec3<f32> = f_cw_buffer_helper_0(0i, v_c, v_t, cw_thread, cw_block, cw_grid);
    var v_axis: vec3<f32> = f_cw_buffer_helper_3(0i, v_c, v_t, cw_thread, cw_block, cw_grid);
    var v_bu: vec3<f32> = f_basisU(v_axis, cw_thread, cw_block, cw_grid);
    var v_bv: vec3<f32> = f_cross3(v_axis, v_bu, cw_thread, cw_block, cw_grid);
    var v_angle: f32 = ((f32(v_k) * 2.399963f) + (f_rnd(v_twig, cw_params.p_seed, cw_thread, cw_block, cw_grid) * 6.28f));
    var v_out: vec3<f32> = f_norm3(((v_bu * vec3<f32>(cos(v_angle))) + (v_bv * vec3<f32>(sin(v_angle)))), cw_thread, cw_block, cw_grid);
    var v_u: vec3<f32> = f_norm3((((v_out * vec3<f32>(0.82f)) + (v_axis * vec3<f32>(0.35f))) + vec3<f32>(0.0f, 0.2f, 0.0f)), cw_thread, cw_block, cw_grid);
    var v_normal: vec3<f32> = f_norm3((vec3<f32>(0.0f, 1.0f, 0.0f) + (v_out * vec3<f32>((0.2f + (v_h * 0.38f))))), cw_thread, cw_block, cw_grid);
    var v_v: vec3<f32> = f_norm3(f_cross3(v_normal, v_u, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    v_normal = f_norm3(f_cross3(v_u, v_v, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
    f_cw_buffer_helper_1(0i, v_b, v_anchor, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 3i)] = 1.0f;
    f_cw_buffer_helper_1(0i, (v_b + 4i), v_u, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 7i)] = (0.145f + (0.075f * v_h));
    f_cw_buffer_helper_1(0i, (v_b + 8i), v_v, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 11i)] = (b_P[(v_b + 7i)] * (0.34f + (0.07f * f_rnd((v_leaf + 37i), cw_params.p_seed, cw_thread, cw_block, cw_grid))));
    f_cw_buffer_helper_1(0i, (v_b + 12i), v_normal, cw_thread, cw_block, cw_grid);
    b_P[(v_b + 15i)] = f32((v_leaf + (cw_params.p_seed * 11i)));
    b_P[(v_b + 16i)] = (0.023f + (0.024f * f_rnd((v_leaf + 149i), cw_params.p_seed, cw_thread, cw_block, cw_grid)));
    b_P[(v_b + 17i)] = (0.013f + (0.016f * v_h));
    b_P[(v_b + 18i)] = ((f_rnd((v_leaf + 777i), cw_params.p_seed, cw_thread, cw_block, cw_grid) - 0.5f) * 0.1f);
    b_P[(v_b + 19i)] = f32(v_twig);
    return;
  }
  var v_rock: i32 = ((v_i - 5124i) - 24192i);
  var v_a: f32 = (f_rnd(((v_rock * 3i) + 1i), cw_params.p_seed, cw_thread, cw_block, cw_grid) * 6.2831853f);
  var v_r: f32 = (0.8f + (4.5f * sqrt(f_rnd(((v_rock * 3i) + 2i), cw_params.p_seed, cw_thread, cw_block, cw_grid))));
  var v_size: f32 = (0.045f + (0.19f * cw_pow_f32(f_rnd((v_rock + 371i), cw_params.p_seed, cw_thread, cw_block, cw_grid), 3.0f)));
  f_cw_buffer_helper_1(0i, v_b, vec3<f32>((cos(v_a) * v_r), ((v_size * 0.3f) - 0.015f), (sin(v_a) * v_r)), cw_thread, cw_block, cw_grid);
  b_P[(v_b + 3i)] = 2.0f;
  f_cw_buffer_helper_1(0i, (v_b + 4i), vec3<f32>(v_size, (v_size * 0.55f), (v_size * (0.7f + (f_rnd((v_rock + 16i), cw_params.p_seed, cw_thread, cw_block, cw_grid) * 0.5f)))), cw_thread, cw_block, cw_grid);
  b_P[(v_b + 15i)] = f32((v_rock + cw_params.p_seed));
}
