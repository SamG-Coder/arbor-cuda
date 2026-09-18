// CUDA WebShader 0.1.0. Generated from kernel tracePixels.
@group(0) @binding(0) var<storage, read> b_P: array<f32>;
@group(0) @binding(1) var<storage, read> b_Nodes: array<f32>;
@group(0) @binding(2) var<storage, read> b_Order: array<u32>;
@group(0) @binding(3) var<storage, read> b_C: array<f32>;
@group(0) @binding(4) var<storage, read_write> b_Hit: array<f32>;
struct CWParams {
  p_width: i32,
  p_height: i32,
  cw_pad_8: u32,
  cw_pad_12: u32,
}
@group(0) @binding(5) var<uniform> cw_params: CWParams;
const cw_block_size: vec3<u32> = vec3<u32>(8u, 8u, 1u);

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
fn f_leafWidth(cw_arg_u: f32, cw_arg_length: f32, cw_arg_halfWidth: f32, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_u: f32 = cw_arg_u;
  var v_length: f32 = cw_arg_length;
  var v_halfWidth: f32 = cw_arg_halfWidth;
  var v_footprint: f32 = cw_arg_footprint;
  var v_q: f32 = f_sat(cw_divide_f32(v_u, v_length), cw_thread, cw_block, cw_grid);
  var v_s: f32 = sin((3.14159265359f * v_q));
  var v_lobes: f32 = (0.77f + (0.23f * cos((((v_q * 3.14159265359f) * 10.0f) + 0.45f))));
  var v_fine: f32 = ((f_bandWeight(0.002f, v_footprint, cw_thread, cw_block, cw_grid) * 0.015f) * sin(((v_q * 3.14159265359f) * 160.0f)));
  return ((v_halfWidth * cw_pow_f32(max(0.0f, v_s), 0.72f)) * (v_lobes + v_fine));
}
fn f_leafHeight(cw_arg_u: f32, cw_arg_v: f32, cw_arg_len: f32, cw_arg_halfWidth: f32, cw_arg_curl: f32, cw_arg_twist: f32, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_u: f32 = cw_arg_u;
  var v_v: f32 = cw_arg_v;
  var v_len: f32 = cw_arg_len;
  var v_halfWidth: f32 = cw_arg_halfWidth;
  var v_curl: f32 = cw_arg_curl;
  var v_twist: f32 = cw_arg_twist;
  var v_footprint: f32 = cw_arg_footprint;
  var v_q: f32 = f_clampf(cw_divide_f32(v_u, v_len), (-0.2f), 1.2f, cw_thread, cw_block, cw_grid);
  var v_s: f32 = sin((3.14159265359f * v_q));
  var v_coarse: f32 = (((v_curl * v_s) + ((v_twist * (v_q - 0.4f)) * v_v)) + ((0.009f * cw_divide_f32((v_v * v_v), (v_halfWidth * v_halfWidth))) * v_s));
  var v_mid: f32 = (((0.0012f * exp(cw_divide_f32((-abs(v_v)), 0.005f))) * v_s) * f_bandWeight(0.007f, v_footprint, cw_thread, cw_block, cw_grid));
  return (v_coarse + v_mid);
}
fn f_sphereT(cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_p: vec3<f32>, cw_arg_radius: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_p: vec3<f32> = cw_arg_p;
  var v_radius: f32 = cw_arg_radius;
  var v_q: vec3<f32> = (v_ro - v_p);
  var v_b: f32 = f_dot3(v_q, v_rd, cw_thread, cw_block, cw_grid);
  var v_c: f32 = (f_dot3(v_q, v_q, cw_thread, cw_block, cw_grid) - (v_radius * v_radius));
  var v_d: f32 = ((v_b * v_b) - v_c);
  if ((v_d < 0.0f)) {
    return 100000.0f;
  }
  var v_t: f32 = ((-v_b) - sqrt(v_d));
  if ((v_t <= 0.0001f)) {
    v_t = ((-v_b) + sqrt(v_d));
  }
  var cw_tmp_3: f32;
  if ((v_t > 0.0001f)) {
    cw_tmp_3 = v_t;
  } else {
    cw_tmp_3 = 100000.0f;
  }
  return cw_tmp_3;
}
fn f_tubeT(cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_a: vec3<f32>, cw_arg_b: vec3<f32>, cw_arg_ra: f32, cw_arg_rb: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_a: vec3<f32> = cw_arg_a;
  var v_b: vec3<f32> = cw_arg_b;
  var v_ra: f32 = cw_arg_ra;
  var v_rb: f32 = cw_arg_rb;
  var v_axis: vec3<f32> = (v_b - v_a);
  var v_len: f32 = f_length3(v_axis, cw_thread, cw_block, cw_grid);
  v_axis = (v_axis / vec3<f32>(max(v_len, 0.000001f)));
  var v_q: vec3<f32> = (v_ro - v_a);
  var v_z: f32 = f_dot3(v_q, v_axis, cw_thread, cw_block, cw_grid);
  var v_dz: f32 = f_dot3(v_rd, v_axis, cw_thread, cw_block, cw_grid);
  var v_k: f32 = cw_divide_f32((v_rb - v_ra), max(0.000001f, v_len));
  var v_v: vec3<f32> = (v_q - (v_axis * vec3<f32>(v_z)));
  var v_d: vec3<f32> = (v_rd - (v_axis * vec3<f32>(v_dz)));
  var v_radius: f32 = (v_ra + (v_k * v_z));
  var v_aa: f32 = (f_dot3(v_d, v_d, cw_thread, cw_block, cw_grid) - (((v_k * v_k) * v_dz) * v_dz));
  var v_bb: f32 = (f_dot3(v_v, v_d, cw_thread, cw_block, cw_grid) - ((v_radius * v_k) * v_dz));
  var v_cc: f32 = (f_dot3(v_v, v_v, cw_thread, cw_block, cw_grid) - (v_radius * v_radius));
  var v_best: f32 = min(f_sphereT(v_ro, v_rd, v_a, v_ra, cw_thread, cw_block, cw_grid), f_sphereT(v_ro, v_rd, v_b, v_rb, cw_thread, cw_block, cw_grid));
  var v_disc: f32 = ((v_bb * v_bb) - (v_aa * v_cc));
  if (((v_disc >= 0.0f) && (abs(v_aa) > 1e-7f))) {
    {
      var v_j: i32 = 0i;
      loop {
        if (!(v_j < 2i)) { break; }
        var cw_tmp_4: f32;
        if ((v_j == 0i)) {
          cw_tmp_4 = (-1.0f);
        } else {
          cw_tmp_4 = 1.0f;
        }
        var v_t: f32 = cw_divide_f32(((-v_bb) + (cw_tmp_4 * sqrt(v_disc))), v_aa);
        var v_h: f32 = (v_z + (v_t * v_dz));
        if ((((v_t > 0.0001f) && (v_h >= 0.0f)) && (v_h <= v_len))) {
          v_best = min(v_best, v_t);
        }
        continuing {
          v_j += i32(1);
        }
      }
    }
  }
  return v_best;
}
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  return f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), 0i, cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_x: i32, cw_arg_y: i32, cw_arg_width: i32, cw_arg_height: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_x: i32 = cw_arg_x;
  var v_y: i32 = cw_arg_y;
  var v_width: i32 = cw_arg_width;
  var v_height: i32 = cw_arg_height;
  var v_sample: i32 = i32(b_C[(cw_buffer_offset_0 + 9i)]);
  var v_jx: f32 = (f_halton((v_sample + 1i), 2i, cw_thread, cw_block, cw_grid) - 0.5f);
  var v_jy: f32 = (f_halton((v_sample + 1i), 3i, cw_thread, cw_block, cw_grid) - 0.5f);
  var v_u: f32 = cw_divide_f32((((f32(v_x) + 0.5f) + v_jx) - (f32(v_width) * 0.5f)), f32(v_height));
  var v_v: f32 = cw_divide_f32(((((f32(v_height) * 0.5f) - f32(v_y)) - 0.5f) - v_jy), f32(v_height));
  var v_f: vec3<f32> = f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_r: vec3<f32> = f_cw_buffer_helper_5((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid);
  var v_up: vec3<f32> = f_cross3(v_r, v_f, cw_thread, cw_block, cw_grid);
  return f_norm3(((v_f + (v_r * vec3<f32>((v_u * b_C[(cw_buffer_offset_0 + 14i)])))) + (v_up * vec3<f32>((v_v * b_C[(cw_buffer_offset_0 + 14i)])))), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_2(cw_buffer_arg_0: i32, cw_buffer_arg_1: i32, cw_buffer_arg_2: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_cone: f32, cw_arg_time: f32, cw_arg_wind: f32, cw_arg_best: f32, cw_arg_worldSeed: i32, v_treeOut: ptr<function, i32>, cw_arg_shadows: bool, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var cw_buffer_offset_1: i32 = cw_buffer_arg_1;
  var cw_buffer_offset_2: i32 = cw_buffer_arg_2;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_cone: f32 = cw_arg_cone;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_best: f32 = cw_arg_best;
  var v_worldSeed: i32 = cw_arg_worldSeed;
  var v_shadows: bool = cw_arg_shadows;
  var v_foundTree: i32 = (-1i);
  var v_found: f32 = (-1.0f);
  var v_half: f32 = ((f32(18i) * 28.0f) * 0.5f);
  var v_worldSpan: vec2<f32> = f_boxSpan(v_ro, v_rd, vec3<f32>((-v_half), (-1.2f), (-v_half)), vec3<f32>(v_half, 13.5f, v_half), cw_thread, cw_block, cw_grid);
  var v_enter: f32 = max(0.0f, v_worldSpan.x);
  var v_exit: f32 = min(v_best, v_worldSpan.y);
  if ((v_exit < v_enter)) {
    (*v_treeOut) = (-1i);
    return vec2<f32>(v_best, (-1.0f));
  }
  var v_pos: vec3<f32> = (v_ro + (v_rd * vec3<f32>((v_enter + 0.0002f))));
  var v_ix: i32 = i32(floor(((cw_divide_f32(v_pos.x, 28.0f) + (f32(18i) * 0.5f)) + 0.5f)));
  var v_iz: i32 = i32(floor(((cw_divide_f32(v_pos.z, 28.0f) + (f32(18i) * 0.5f)) + 0.5f)));
  var cw_tmp_9: i32;
  if ((v_rd.x >= 0.0f)) {
    cw_tmp_9 = 1i;
  } else {
    cw_tmp_9 = (-1i);
  }
  var v_sx: i32 = cw_tmp_9;
  var cw_tmp_10: i32;
  if ((v_rd.z >= 0.0f)) {
    cw_tmp_10 = 1i;
  } else {
    cw_tmp_10 = (-1i);
  }
  var v_sz: i32 = cw_tmp_10;
  var v_invx: f32 = f_invSafe(v_rd.x, cw_thread, cw_block, cw_grid);
  var v_invz: f32 = f_invSafe(v_rd.z, cw_thread, cw_block, cw_grid);
  var cw_tmp_11: f32;
  if ((v_sx > 0i)) {
    cw_tmp_11 = 0.5f;
  } else {
    cw_tmp_11 = (-0.5f);
  }
  var v_bx: f32 = ((f32((v_ix - (18i / 2i))) + cw_tmp_11) * 28.0f);
  var cw_tmp_12: f32;
  if ((v_sz > 0i)) {
    cw_tmp_12 = 0.5f;
  } else {
    cw_tmp_12 = (-0.5f);
  }
  var v_bz: f32 = ((f32((v_iz - (18i / 2i))) + cw_tmp_12) * 28.0f);
  var v_tx: f32 = ((v_bx - v_ro.x) * v_invx);
  var v_tz: f32 = ((v_bz - v_ro.z) * v_invz);
  var v_dx: f32 = (28.0f * abs(v_invx));
  var v_dz: f32 = (28.0f * abs(v_invz));
  {
    var v_step: i32 = 0i;
    loop {
      if (!(v_step < 48i)) { break; }
      if (((((v_ix < 0i) || (v_iz < 0i)) || (v_ix >= 18i)) || (v_iz >= 18i))) {
        break;
      }
      var v_tree: i32 = ((v_iz * 18i) + v_ix);
      var v_sc: f32 = f_forestScale(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
      var v_centre: vec3<f32> = (f_forestPos(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid) + vec3<f32>(0.0f, (4.4f * v_sc), 0.0f));
      var v_radius: f32 = (6.6f * v_sc);
      var v_broad: f32 = f_sphereT(v_ro, v_rd, v_centre, v_radius, cw_thread, cw_block, cw_grid);
      if ((v_broad < v_best)) {
        var v_lr: vec3<f32> = f_forestToLocalPoint(v_ro, v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
        var v_ld: vec3<f32> = f_forestToLocalDir(v_rd, v_tree, v_worldSeed, cw_thread, cw_block, cw_grid);
        var v_phase: f32 = (f32((f_forestSeed(v_tree, v_worldSeed, cw_thread, cw_block, cw_grid) & 8191i)) * 0.0017f);
        var v_h: vec2<f32> = f_cw_buffer_helper_6((cw_buffer_offset_0 + 0i), (cw_buffer_offset_1 + 0i), (cw_buffer_offset_2 + 0i), v_lr, v_ld, cw_divide_f32(v_cone, v_sc), (v_time + v_phase), v_wind, cw_divide_f32(v_best, v_sc), (-1i), v_shadows, cw_thread, cw_block, cw_grid);
        if (((v_h.y >= 0.0f) && ((v_h.x * v_sc) < v_best))) {
          v_best = (v_h.x * v_sc);
          v_found = v_h.y;
          v_foundTree = v_tree;
        }
      }
      var cw_tmp_13: f32;
      if ((v_tx < v_tz)) {
        cw_tmp_13 = v_tx;
      } else {
        cw_tmp_13 = v_tz;
      }
      var v_next: f32 = cw_tmp_13;
      if (((v_next > v_exit) || (v_next > v_best))) {
        break;
      }
      if ((v_tx < v_tz)) {
        v_ix = (v_ix + v_sx);
        v_tx = (v_tx + v_dx);
      } else {
        v_iz = (v_iz + v_sz);
        v_tz = (v_tz + v_dz);
      }
      continuing {
        v_step += i32(1);
      }
    }
  }
  (*v_treeOut) = v_foundTree;
  return vec2<f32>(v_best, v_found);
}
fn f_cw_buffer_helper_3(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  let cw_argument_index_14 = (cw_buffer_offset_0 + v_i);
  let cw_argument_index_15 = (cw_buffer_offset_0 + (v_i + 1i));
  let cw_argument_index_16 = (cw_buffer_offset_0 + (v_i + 2i));
  return vec3<f32>(b_C[cw_argument_index_14], b_C[cw_argument_index_15], b_C[cw_argument_index_16]);
}
fn f_cw_buffer_helper_4(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  return f_norm3((f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), 4i, cw_thread, cw_block, cw_grid) - f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), 0i, cw_thread, cw_block, cw_grid)), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_5(cw_buffer_arg_0: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  return f_norm3(f_cross3(f_cw_buffer_helper_4((cw_buffer_offset_0 + 0i), cw_thread, cw_block, cw_grid), vec3<f32>(0.0f, 1.0f, 0.0f), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
}
fn f_cw_buffer_helper_6(cw_buffer_arg_0: i32, cw_buffer_arg_1: i32, cw_buffer_arg_2: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_cone: f32, cw_arg_time: f32, cw_arg_wind: f32, cw_arg_best: f32, cw_arg_ignore: i32, cw_arg_shadows: bool, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var cw_buffer_offset_1: i32 = cw_buffer_arg_1;
  var cw_buffer_offset_2: i32 = cw_buffer_arg_2;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_cone: f32 = cw_arg_cone;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_best: f32 = cw_arg_best;
  var v_ignore: i32 = cw_arg_ignore;
  var v_shadows: bool = cw_arg_shadows;
  var v_stack: array<i32, 32>;
  var v_top: i32 = 0i;
  var v_node: i32 = 1i;
  var v_found: i32 = (-1i);
  {
    var v_visit: i32 = 0i;
    loop {
      if (!(v_visit < 65536i)) { break; }
      if ((v_node <= 0i)) {
        break;
      }
      var v_b: i32 = (v_node * 8i);
      var v_span: vec2<f32> = f_boxSpan(v_ro, v_rd, f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), v_b, cw_thread, cw_block, cw_grid), f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
      var v_hit: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_b + 3i))] > 0.0f) && (v_span.y >= max(0.0001f, v_span.x))) && (v_span.x < v_best));
      if ((v_hit && (v_node < 32768i))) {
        var v_left: i32 = (v_node * 2i);
        var v_right: i32 = (v_left + 1i);
        var v_lb: i32 = (v_left * 8i);
        var v_rb: i32 = (v_right * 8i);
        var v_ls: vec2<f32> = f_boxSpan(v_ro, v_rd, f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), v_lb, cw_thread, cw_block, cw_grid), f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), (v_lb + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
        var v_rs: vec2<f32> = f_boxSpan(v_ro, v_rd, f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), v_rb, cw_thread, cw_block, cw_grid), f_cw_buffer_helper_7((cw_buffer_offset_1 + 0i), (v_rb + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
        var v_lh: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_lb + 3i))] > 0.0f) && (v_ls.y >= max(0.0001f, v_ls.x))) && (v_ls.x < v_best));
        var v_rh: bool = (((b_Nodes[(cw_buffer_offset_1 + (v_rb + 3i))] > 0.0f) && (v_rs.y >= max(0.0001f, v_rs.x))) && (v_rs.x < v_best));
        if ((v_lh && v_rh)) {
          var v_l: bool = (v_ls.x < v_rs.x);
          var cw_tmp_17: i32;
          if (v_l) {
            cw_tmp_17 = v_right;
          } else {
            cw_tmp_17 = v_left;
          }
          v_stack[v_top] = cw_tmp_17;
          v_top += i32(1);
          var cw_tmp_18: i32;
          if (v_l) {
            cw_tmp_18 = v_left;
          } else {
            cw_tmp_18 = v_right;
          }
          v_node = cw_tmp_18;
          continue;
        }
        if (v_lh) {
          v_node = v_left;
          continue;
        }
        if (v_rh) {
          v_node = v_right;
          continue;
        }
      } else {
        if (v_hit) {
          var v_id: i32 = i32(b_Order[(cw_buffer_offset_2 + (v_node - 32768i))]);
          if ((v_id != v_ignore)) {
            var v_footprint: f32 = max(0.000005f, (v_cone * max(0.05f, v_span.x)));
            var v_t: f32 = f_cw_buffer_helper_8((cw_buffer_offset_0 + 0i), v_id, v_ro, v_rd, v_footprint, v_time, v_wind, (!v_shadows), cw_thread, cw_block, cw_grid);
            if ((v_t < v_best)) {
              v_best = v_t;
              v_found = v_id;
            }
          }
        }
      }
      v_node = 0i;
      if ((v_top > 0i)) {
        v_top -= i32(1);
        v_node = v_stack[v_top];
      }
      continuing {
        v_visit += i32(1);
      }
    }
  }
  return vec2<f32>(v_best, f32(v_found));
}
fn f_cw_buffer_helper_7(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  let cw_argument_index_19 = (cw_buffer_offset_0 + v_i);
  let cw_argument_index_20 = (cw_buffer_offset_0 + (v_i + 1i));
  let cw_argument_index_21 = (cw_buffer_offset_0 + (v_i + 2i));
  return vec3<f32>(b_Nodes[cw_argument_index_19], b_Nodes[cw_argument_index_20], b_Nodes[cw_argument_index_21]);
}
fn f_cw_buffer_helper_8(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_footprint: f32, cw_arg_time: f32, cw_arg_wind: f32, cw_arg_refine: bool, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_footprint: f32 = cw_arg_footprint;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_refine: bool = cw_arg_refine;
  var v_b: i32 = (v_id * 24i);
  var v_type: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_type < 0i)) {
    return 100000.0f;
  }
  if ((v_type == 0i)) {
    return f_cw_buffer_helper_9((cw_buffer_offset_0 + 0i), v_id, v_ro, v_rd, v_footprint, v_refine, cw_thread, cw_block, cw_grid);
  }
  if ((v_type == 1i)) {
    return f_cw_buffer_helper_10((cw_buffer_offset_0 + 0i), v_id, v_ro, v_rd, v_footprint, v_time, v_wind, cw_thread, cw_block, cw_grid);
  }
  var v_h: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid);
  var v_q: vec3<f32> = (v_ro - f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid));
  var v_p: vec3<f32> = vec3<f32>(cw_divide_f32(v_q.x, v_h.x), cw_divide_f32(v_q.y, v_h.y), cw_divide_f32(v_q.z, v_h.z));
  var v_d: vec3<f32> = vec3<f32>(cw_divide_f32(v_rd.x, v_h.x), cw_divide_f32(v_rd.y, v_h.y), cw_divide_f32(v_rd.z, v_h.z));
  var v_aa: f32 = f_dot3(v_d, v_d, cw_thread, cw_block, cw_grid);
  var v_bb: f32 = f_dot3(v_p, v_d, cw_thread, cw_block, cw_grid);
  var v_cc: f32 = (f_dot3(v_p, v_p, cw_thread, cw_block, cw_grid) - 1.0f);
  var v_disc: f32 = ((v_bb * v_bb) - (v_aa * v_cc));
  if ((v_disc < 0.0f)) {
    return 100000.0f;
  }
  var v_t: f32 = cw_divide_f32(((-v_bb) - sqrt(v_disc)), v_aa);
  var cw_tmp_22: f32;
  if ((v_t > 0.0001f)) {
    cw_tmp_22 = v_t;
  } else {
    cw_tmp_22 = 100000.0f;
  }
  return cw_tmp_22;
}
fn f_cw_buffer_helper_9(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_footprint: f32, cw_arg_refine: bool, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_footprint: f32 = cw_arg_footprint;
  var v_refine: bool = cw_arg_refine;
  var v_b: i32 = (v_id * 24i);
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  var v_end: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid);
  if ((!v_refine)) {
    var v_ra: f32 = (b_P[(cw_buffer_offset_0 + (v_b + 7i))] - (min(0.021f, (b_P[(cw_buffer_offset_0 + (v_b + 7i))] * 0.055f)) * 0.32f));
    var v_rb: f32 = (b_P[(cw_buffer_offset_0 + (v_b + 11i))] - (min(0.021f, (b_P[(cw_buffer_offset_0 + (v_b + 11i))] * 0.055f)) * 0.32f));
    return f_tubeT(v_ro, v_rd, v_a, v_end, v_ra, v_rb, cw_thread, cw_block, cw_grid);
  }
  let cw_argument_index_23 = (cw_buffer_offset_0 + (v_b + 7i));
  let cw_argument_index_24 = (cw_buffer_offset_0 + (v_b + 11i));
  var v_t: f32 = f_tubeT(v_ro, v_rd, v_a, v_end, b_P[cw_argument_index_23], b_P[cw_argument_index_24], cw_thread, cw_block, cw_grid);
  if ((v_t >= 100000.0f)) {
    return 100000.0f;
  }
  var v_span: vec2<f32> = f_boxSpan(v_ro, v_rd, f_cw_buffer_helper_12((cw_buffer_offset_0 + 0i), v_id, cw_thread, cw_block, cw_grid), f_cw_buffer_helper_13((cw_buffer_offset_0 + 0i), v_id, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
  var v_eps: f32 = max(0.000025f, min(0.00025f, (v_footprint * 0.13f)));
  {
    var v_k: i32 = 0i;
    loop {
      if (!(v_k < 64i)) { break; }
      var v_f: f32 = f_cw_buffer_helper_14((cw_buffer_offset_0 + 0i), v_id, (v_ro + (v_rd * vec3<f32>(v_t))), v_footprint, cw_thread, cw_block, cw_grid);
      if ((v_f < v_eps)) {
        return v_t;
      }
      v_t = (v_t + max((v_eps * 0.35f), (v_f * 0.27f)));
      if ((v_t > v_span.y)) {
        return 100000.0f;
      }
      continuing {
        v_k += i32(1);
      }
    }
  }
  return 100000.0f;
}
fn f_cw_buffer_helper_10(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_ro: vec3<f32>, cw_arg_rd: vec3<f32>, cw_arg_footprint: f32, cw_arg_time: f32, cw_arg_wind: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_ro: vec3<f32> = cw_arg_ro;
  var v_rd: vec3<f32> = cw_arg_rd;
  var v_footprint: f32 = cw_arg_footprint;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_b: i32 = (v_id * 24i);
  var v_origin: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  var v_u: vec3<f32> = f_cw_buffer_helper_15((cw_buffer_offset_0 + 0i), v_id, v_time, v_wind, cw_thread, cw_block, cw_grid);
  var v_v: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 8i), cw_thread, cw_block, cw_grid);
  var v_n: vec3<f32> = f_cw_buffer_helper_16((cw_buffer_offset_0 + 0i), v_id, v_time, v_wind, cw_thread, cw_block, cw_grid);
  var v_stem: f32 = b_P[(cw_buffer_offset_0 + (v_b + 16i))];
  var v_len: f32 = b_P[(cw_buffer_offset_0 + (v_b + 7i))];
  var v_width: f32 = b_P[(cw_buffer_offset_0 + (v_b + 11i))];
  var v_q: vec3<f32> = (v_ro - v_origin);
  var v_x: f32 = (f_dot3(v_q, v_u, cw_thread, cw_block, cw_grid) - v_stem);
  var v_y: f32 = f_dot3(v_q, v_v, cw_thread, cw_block, cw_grid);
  var v_z: f32 = f_dot3(v_q, v_n, cw_thread, cw_block, cw_grid);
  var v_dx: f32 = f_dot3(v_rd, v_u, cw_thread, cw_block, cw_grid);
  var v_dy: f32 = f_dot3(v_rd, v_v, cw_thread, cw_block, cw_grid);
  var v_dz: f32 = f_dot3(v_rd, v_n, cw_thread, cw_block, cw_grid);
  var v_best: f32 = f_tubeT(v_ro, v_rd, v_origin, (v_origin + (v_u * vec3<f32>(v_stem))), 0.0011f, 0.00065f, cw_thread, cw_block, cw_grid);
  var v_span: vec2<f32> = f_boxSpan(vec3<f32>(v_x, v_y, v_z), vec3<f32>(v_dx, v_dy, v_dz), vec3<f32>((-0.001f), (-v_width), (-0.035f)), vec3<f32>((v_len + 0.001f), v_width, 0.065f), cw_thread, cw_block, cw_grid);
  if ((v_span.y < max(0.0001f, v_span.x))) {
    return v_best;
  }
  var cw_tmp_25: f32;
  if ((abs(v_dz) > 0.000001f)) {
    cw_tmp_25 = cw_divide_f32((-v_z), v_dz);
  } else {
    cw_tmp_25 = ((v_span.x + v_span.y) * 0.5f);
  }
  var v_t: f32 = cw_tmp_25;
  v_t = f_clampf(v_t, max(0.0001f, v_span.x), v_span.y, cw_thread, cw_block, cw_grid);
  {
    var v_k: i32 = 0i;
    loop {
      if (!(v_k < 7i)) { break; }
      var v_xx: f32 = (v_x + (v_dx * v_t));
      var v_yy: f32 = (v_y + (v_dy * v_t));
      let cw_argument_index_26 = (cw_buffer_offset_0 + (v_b + 17i));
      let cw_argument_index_27 = (cw_buffer_offset_0 + (v_b + 18i));
      var v_height: f32 = f_leafHeight(v_xx, v_yy, v_len, v_width, b_P[cw_argument_index_26], b_P[cw_argument_index_27], v_footprint, cw_thread, cw_block, cw_grid);
      var v_f: f32 = ((v_z + (v_dz * v_t)) - v_height);
      var v_e: f32 = 0.00015f;
      let cw_argument_index_28 = (cw_buffer_offset_0 + (v_b + 17i));
      let cw_argument_index_29 = (cw_buffer_offset_0 + (v_b + 18i));
      let cw_argument_index_30 = (cw_buffer_offset_0 + (v_b + 17i));
      let cw_argument_index_31 = (cw_buffer_offset_0 + (v_b + 18i));
      var v_hx: f32 = cw_divide_f32((f_leafHeight((v_xx + v_e), v_yy, v_len, v_width, b_P[cw_argument_index_28], b_P[cw_argument_index_29], v_footprint, cw_thread, cw_block, cw_grid) - f_leafHeight((v_xx - v_e), v_yy, v_len, v_width, b_P[cw_argument_index_30], b_P[cw_argument_index_31], v_footprint, cw_thread, cw_block, cw_grid)), (2.0f * v_e));
      let cw_argument_index_32 = (cw_buffer_offset_0 + (v_b + 17i));
      let cw_argument_index_33 = (cw_buffer_offset_0 + (v_b + 18i));
      let cw_argument_index_34 = (cw_buffer_offset_0 + (v_b + 17i));
      let cw_argument_index_35 = (cw_buffer_offset_0 + (v_b + 18i));
      var v_hy: f32 = cw_divide_f32((f_leafHeight(v_xx, (v_yy + v_e), v_len, v_width, b_P[cw_argument_index_32], b_P[cw_argument_index_33], v_footprint, cw_thread, cw_block, cw_grid) - f_leafHeight(v_xx, (v_yy - v_e), v_len, v_width, b_P[cw_argument_index_34], b_P[cw_argument_index_35], v_footprint, cw_thread, cw_block, cw_grid)), (2.0f * v_e));
      var v_deriv: f32 = ((v_dz - (v_hx * v_dx)) - (v_hy * v_dy));
      if ((abs(v_deriv) < 0.00001f)) {
        break;
      }
      v_t = (v_t - f_clampf(cw_divide_f32(v_f, v_deriv), (-0.13f), 0.13f, cw_thread, cw_block, cw_grid));
      v_t = f_clampf(v_t, v_span.x, v_span.y, cw_thread, cw_block, cw_grid);
      continuing {
        v_k += i32(1);
      }
    }
  }
  var v_xx: f32 = (v_x + (v_dx * v_t));
  var v_yy: f32 = (v_y + (v_dy * v_t));
  let cw_argument_index_36 = (cw_buffer_offset_0 + (v_b + 17i));
  let cw_argument_index_37 = (cw_buffer_offset_0 + (v_b + 18i));
  var v_err: f32 = abs(((v_z + (v_dz * v_t)) - f_leafHeight(v_xx, v_yy, v_len, v_width, b_P[cw_argument_index_36], b_P[cw_argument_index_37], v_footprint, cw_thread, cw_block, cw_grid)));
  if ((((((v_t > 0.0001f) && (v_xx > 0.0f)) && (v_xx < v_len)) && (abs(v_yy) < f_leafWidth(v_xx, v_len, v_width, v_footprint, cw_thread, cw_block, cw_grid))) && (v_err < 0.0003f))) {
    v_best = min(v_best, v_t);
  }
  return v_best;
}
fn f_cw_buffer_helper_11(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  let cw_argument_index_38 = (cw_buffer_offset_0 + v_i);
  let cw_argument_index_39 = (cw_buffer_offset_0 + (v_i + 1i));
  let cw_argument_index_40 = (cw_buffer_offset_0 + (v_i + 2i));
  return vec3<f32>(b_P[cw_argument_index_38], b_P[cw_argument_index_39], b_P[cw_argument_index_40]);
}
fn f_cw_buffer_helper_12(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_b: i32 = (v_id * 24i);
  var v_type: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_type < 0i)) {
    return vec3<f32>(100000.0f, 100000.0f, 100000.0f);
  }
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  if ((v_type == 0i)) {
    let cw_argument_index_41 = (cw_buffer_offset_0 + (v_b + 7i));
    let cw_argument_index_42 = (cw_buffer_offset_0 + (v_b + 11i));
    var v_r: f32 = (max(b_P[cw_argument_index_41], b_P[cw_argument_index_42]) + 0.002f);
    return (f_min3(v_a, f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid) - vec3<f32>(v_r, v_r, v_r));
  }
  if ((v_type == 2i)) {
    return (v_a - f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid));
  }
  var v_radius: f32 = ((b_P[(cw_buffer_offset_0 + (v_b + 7i))] + b_P[(cw_buffer_offset_0 + (v_b + 16i))]) + 0.025f);
  return (v_a - vec3<f32>(v_radius, v_radius, v_radius));
}
fn f_cw_buffer_helper_13(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_b: i32 = (v_id * 24i);
  var v_type: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_type < 0i)) {
    return vec3<f32>((-100000.0f), (-100000.0f), (-100000.0f));
  }
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  if ((v_type == 0i)) {
    let cw_argument_index_43 = (cw_buffer_offset_0 + (v_b + 7i));
    let cw_argument_index_44 = (cw_buffer_offset_0 + (v_b + 11i));
    var v_r: f32 = (max(b_P[cw_argument_index_43], b_P[cw_argument_index_44]) + 0.002f);
    return (f_max3(v_a, f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid) + vec3<f32>(v_r, v_r, v_r));
  }
  if ((v_type == 2i)) {
    return (v_a + f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid));
  }
  var v_radius: f32 = ((b_P[(cw_buffer_offset_0 + (v_b + 7i))] + b_P[(cw_buffer_offset_0 + (v_b + 16i))]) + 0.025f);
  return (v_a + vec3<f32>(v_radius, v_radius, v_radius));
}
fn f_cw_buffer_helper_14(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_p: vec3<f32>, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_p: vec3<f32> = cw_arg_p;
  var v_footprint: f32 = cw_arg_footprint;
  var v_b: i32 = (v_id * 24i);
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  var v_ab: vec3<f32> = (f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid) - v_a);
  var v_t: f32 = f_sat(cw_divide_f32(f_dot3((v_p - v_a), v_ab, cw_thread, cw_block, cw_grid), max(1e-7f, f_dot3(v_ab, v_ab, cw_thread, cw_block, cw_grid))), cw_thread, cw_block, cw_grid);
  let cw_argument_index_45 = (cw_buffer_offset_0 + (v_b + 7i));
  let cw_argument_index_46 = (cw_buffer_offset_0 + (v_b + 11i));
  var v_radius: f32 = f_lerp(b_P[cw_argument_index_45], b_P[cw_argument_index_46], v_t, cw_thread, cw_block, cw_grid);
  return ((f_length3(((v_p - v_a) - (v_ab * vec3<f32>(v_t))), cw_thread, cw_block, cw_grid) - v_radius) + f_cw_buffer_helper_17((cw_buffer_offset_0 + 0i), v_id, v_p, v_footprint, cw_thread, cw_block, cw_grid));
}
fn f_cw_buffer_helper_15(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_time: f32, cw_arg_wind: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_b: i32 = (v_id * 24i);
  var v_u: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid);
  var v_n: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 12i), cw_thread, cw_block, cw_grid);
  var v_phase: f32 = (f32((i32(b_P[(cw_buffer_offset_0 + (v_b + 15i))]) % 8192i)) * 0.618f);
  var v_a: f32 = (v_wind * ((0.11f * sin(((v_time * 2.1f) + v_phase))) + (0.045f * sin(((v_time * 5.8f) + (v_phase * 1.7f))))));
  return ((v_u * vec3<f32>(cos(v_a))) + (v_n * vec3<f32>(sin(v_a))));
}
fn f_cw_buffer_helper_16(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_time: f32, cw_arg_wind: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_time: f32 = cw_arg_time;
  var v_wind: f32 = cw_arg_wind;
  var v_b: i32 = (v_id * 24i);
  var v_u: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid);
  var v_n: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 12i), cw_thread, cw_block, cw_grid);
  var v_phase: f32 = (f32((i32(b_P[(cw_buffer_offset_0 + (v_b + 15i))]) % 8192i)) * 0.618f);
  var v_a: f32 = (v_wind * ((0.11f * sin(((v_time * 2.1f) + v_phase))) + (0.045f * sin(((v_time * 5.8f) + (v_phase * 1.7f))))));
  return ((v_n * vec3<f32>(cos(v_a))) - (v_u * vec3<f32>(sin(v_a))));
}
fn f_cw_buffer_helper_17(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_p: vec3<f32>, cw_arg_footprint: f32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> f32 {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_p: vec3<f32> = cw_arg_p;
  var v_footprint: f32 = cw_arg_footprint;
  var v_b: i32 = (v_id * 24i);
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  var v_d: vec3<f32> = (f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid) - v_a);
  var v_along: f32 = f_sat(cw_divide_f32(f_dot3((v_p - v_a), v_d, cw_thread, cw_block, cw_grid), max(0.000001f, f_dot3(v_d, v_d, cw_thread, cw_block, cw_grid))), cw_thread, cw_block, cw_grid);
  let cw_argument_index_47 = (cw_buffer_offset_0 + (v_b + 7i));
  let cw_argument_index_48 = (cw_buffer_offset_0 + (v_b + 11i));
  var v_radius: f32 = f_lerp(b_P[cw_argument_index_47], b_P[cw_argument_index_48], v_along, cw_thread, cw_block, cw_grid);
  var v_amp: f32 = min(0.021f, (v_radius * 0.055f));
  var v_columns: i32 = i32(max(7.0f, floor((cw_divide_f32(((b_P[(cw_buffer_offset_0 + (v_b + 18i))] * 2.0f) * 3.14159265359f), 0.065f) + 0.5f))));
  var v_period: f32 = cw_divide_f32(((v_radius * 2.0f) * 3.14159265359f), f32(v_columns));
  var v_coarse: f32 = f_bandWeight(v_period, v_footprint, cw_thread, cw_block, cw_grid);
  var v_fine: f32 = f_bandWeight(0.01f, v_footprint, cw_thread, cw_block, cw_grid);
  var v_grain: f32 = f_bandWeight(0.0025f, v_footprint, cw_thread, cw_block, cw_grid);
  if (((v_coarse < 0.000001f) && (v_fine < 0.000001f))) {
    return (v_amp * 0.32f);
  }
  var v_uv: vec2<f32> = f_cw_buffer_helper_18((cw_buffer_offset_0 + 0i), v_id, v_p, cw_thread, cw_block, cw_grid);
  var v_theta: f32 = v_uv.x;
  var v_arc: f32 = v_uv.y;
  var v_seed: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 15i))]);
  var v_x: f32 = ((((cw_divide_f32(v_theta, (2.0f * 3.14159265359f)) + 0.5f) * f32(v_columns)) + (0.32f * sin(((v_arc * 6.7f) + (cos(v_theta) * 3.0f))))) + (0.15f * sin(((v_arc * 19.0f) + (sin(v_theta) * 2.0f)))));
  var v_y: f32 = ((cw_divide_f32(v_arc, 0.19f) + (0.25f * sin((v_theta * 7.0f)))) + (0.1f * sin((v_theta * 19.0f))));
  var v_ix: i32 = i32(floor(v_x));
  var v_iy: i32 = i32(floor(v_y));
  var v_first: f32 = 100.0f;
  var v_second: f32 = 100.0f;
  {
    var v_j: i32 = (-1i);
    loop {
      if (!(v_j <= 1i)) { break; }
      {
        var v_k: i32 = (-1i);
        loop {
          if (!(v_k <= 1i)) { break; }
          var v_cell: i32 = (v_ix + v_k);
          var v_wrapped: i32 = (((v_cell % v_columns) + v_columns) % v_columns);
          var v_xx: f32 = (((f32(v_cell) + 0.18f) + (0.64f * f_hash2(v_wrapped, (v_iy + v_j), v_seed, cw_thread, cw_block, cw_grid))) - v_x);
          var v_yy: f32 = (((f32((v_iy + v_j)) + 0.18f) + (0.64f * f_hash2((v_wrapped + v_columns), (v_iy + v_j), (v_seed + 31i), cw_thread, cw_block, cw_grid))) - v_y);
          var v_dd: f32 = ((v_xx * v_xx) + (v_yy * v_yy));
          if ((v_dd < v_first)) {
            v_second = v_first;
            v_first = v_dd;
          } else {
            if ((v_dd < v_second)) {
              v_second = v_dd;
            }
          }
          continuing {
            v_k += i32(1);
          }
        }
      }
      continuing {
        v_j += i32(1);
      }
    }
  }
  var v_gap: f32 = (sqrt(v_second) - sqrt(v_first));
  var v_fissure: f32 = (1.0f - f_smooth(0.015f, 0.17f, v_gap, cw_thread, cw_block, cw_grid));
  var v_plates: f32 = (v_fissure * v_fissure);
  var v_coord: vec3<f32> = vec3<f32>((cos(v_theta) * 9.0f), (sin(v_theta) * 9.0f), (v_arc * 23.0f));
  var v_splinter: f32 = f_noise3(v_coord, v_seed, cw_thread, cw_block, cw_grid);
  var v_pores: f32 = f_noise3((v_coord * vec3<f32>(4.0f)), (v_seed + 731i), cw_thread, cw_block, cw_grid);
  return (v_amp * f_clampf((((0.32f + ((v_coarse * (v_plates - 0.37f)) * 0.69f)) + ((v_fine * (v_splinter - 0.5f)) * 0.24f)) + ((v_grain * (v_pores - 0.5f)) * 0.08f)), 0.005f, 1.0f, cw_thread, cw_block, cw_grid));
}
fn f_cw_buffer_helper_18(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_arg_p: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec2<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_p: vec3<f32> = cw_arg_p;
  var v_b: i32 = (v_id * 24i);
  var v_a: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  var v_d: vec3<f32> = f_norm3((f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid) - v_a), cw_thread, cw_block, cw_grid);
  var v_initial: vec3<f32> = f_cw_buffer_helper_11((cw_buffer_offset_0 + 0i), (v_b + 8i), cw_thread, cw_block, cw_grid);
  var v_u: vec3<f32> = f_norm3((v_initial - (v_d * vec3<f32>(f_dot3(v_initial, v_d, cw_thread, cw_block, cw_grid)))), cw_thread, cw_block, cw_grid);
  var v_v: vec3<f32> = f_cross3(v_d, v_u, cw_thread, cw_block, cw_grid);
  var v_q: vec3<f32> = (v_p - v_a);
  var v_z: f32 = f_dot3(v_q, v_d, cw_thread, cw_block, cw_grid);
  var v_theta: f32 = atan2(f_dot3(v_q, v_v, cw_thread, cw_block, cw_grid), f_dot3(v_q, v_u, cw_thread, cw_block, cw_grid));
  return vec2<f32>(v_theta, (b_P[(cw_buffer_offset_0 + (v_b + 16i))] + v_z));
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

@compute @workgroup_size(8, 8, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_x: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  var v_y: i32 = i32(((cw_block.y * cw_block_size.y) + cw_thread.y));
  if (((v_x >= cw_params.p_width) || (v_y >= cw_params.p_height))) {
    return;
  }
  var v_b: i32 = (((v_y * cw_params.p_width) + v_x) * 4i);
  var v_ro: vec3<f32> = f_cw_buffer_helper_0(0i, cw_thread, cw_block, cw_grid);
  var v_rd: vec3<f32> = f_cw_buffer_helper_1(0i, v_x, v_y, cw_params.p_width, cw_params.p_height, cw_thread, cw_block, cw_grid);
  var cw_tmp_5: f32;
  if ((v_rd.y < (-0.00001f))) {
    cw_tmp_5 = cw_divide_f32((-v_ro.y), v_rd.y);
  } else {
    cw_tmp_5 = 100000.0f;
  }
  var v_ground: f32 = cw_tmp_5;
  var v_tree: i32 = (-1i);
  let cw_argument_index_6 = 8i;
  let cw_argument_index_7 = 11i;
  var cw_tmp_8: f32;
  if ((v_ground > 0.0f)) {
    cw_tmp_8 = v_ground;
  } else {
    cw_tmp_8 = 100000.0f;
  }
  var v_h: vec2<f32> = f_cw_buffer_helper_2(0i, 0i, 0i, v_ro, v_rd, cw_divide_f32(b_C[14i], f32(cw_params.p_height)), b_C[cw_argument_index_6], b_C[cw_argument_index_7], cw_tmp_8, i32(b_C[31i]), &v_tree, false, cw_thread, cw_block, cw_grid);
  b_Hit[v_b] = v_h.x;
  b_Hit[(v_b + 1i)] = v_h.y;
  b_Hit[(v_b + 2i)] = f32(v_tree);
  b_Hit[(v_b + 3i)] = cw_divide_f32((b_C[14i] * v_h.x), f32(cw_params.p_height));
}
