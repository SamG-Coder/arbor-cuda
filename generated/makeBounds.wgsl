// CUDA WebShader 0.1.0. Generated from kernel makeBounds.
@group(0) @binding(0) var<storage, read> b_P: array<f32>;
@group(0) @binding(1) var<storage, read> b_Order: array<u32>;
@group(0) @binding(2) var<storage, read_write> b_Nodes: array<f32>;
const cw_block_size: vec3<u32> = vec3<u32>(128u, 1u, 1u);

fn cw_divide_f32(a: f32, b: f32) -> f32 { let q = a / b; if ((bitcast<u32>(q) & 0x7f800000u) == 0x7f800000u || (bitcast<u32>(q) & 0x7fffffffu) == 0u || (bitcast<u32>(b) & 0x7f800000u) == 0x7f800000u) { return q; } let residual = fma(-q, b, a); return q + residual / b; }
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
fn f_spread(cw_arg_x: u32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> u32 {
  var v_x: u32 = cw_arg_x;
  v_x = (v_x & 1023u);
  v_x = ((v_x | (v_x << u32(16i))) & 50331903u);
  v_x = ((v_x | (v_x << u32(8i))) & 50393103u);
  v_x = ((v_x | (v_x << u32(4i))) & 51130563u);
  v_x = ((v_x | (v_x << u32(2i))) & 153391689u);
  return v_x;
}
fn f_cw_buffer_helper_0(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_b: i32 = (v_id * 24i);
  var v_type: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_type < 0i)) {
    return vec3<f32>(100000.0f, 100000.0f, 100000.0f);
  }
  var v_a: vec3<f32> = f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  if ((v_type == 0i)) {
    let cw_argument_index_4 = (cw_buffer_offset_0 + (v_b + 7i));
    let cw_argument_index_5 = (cw_buffer_offset_0 + (v_b + 11i));
    var v_r: f32 = (max(b_P[cw_argument_index_4], b_P[cw_argument_index_5]) + 0.002f);
    return (f_min3(v_a, f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid) - vec3<f32>(v_r, v_r, v_r));
  }
  if ((v_type == 2i)) {
    return (v_a - f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid));
  }
  var v_radius: f32 = ((b_P[(cw_buffer_offset_0 + (v_b + 7i))] + b_P[(cw_buffer_offset_0 + (v_b + 16i))]) + 0.025f);
  return (v_a - vec3<f32>(v_radius, v_radius, v_radius));
}
fn f_cw_buffer_helper_1(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_arg_v: vec3<f32>, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  var v_v: vec3<f32> = cw_arg_v;
  b_Nodes[(cw_buffer_offset_0 + v_i)] = v_v.x;
  b_Nodes[(cw_buffer_offset_0 + (v_i + 1i))] = v_v.y;
  b_Nodes[(cw_buffer_offset_0 + (v_i + 2i))] = v_v.z;
}
fn f_cw_buffer_helper_2(cw_buffer_arg_0: i32, cw_arg_id: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_id: i32 = cw_arg_id;
  var v_b: i32 = (v_id * 24i);
  var v_type: i32 = i32(b_P[(cw_buffer_offset_0 + (v_b + 3i))]);
  if ((v_type < 0i)) {
    return vec3<f32>((-100000.0f), (-100000.0f), (-100000.0f));
  }
  var v_a: vec3<f32> = f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), v_b, cw_thread, cw_block, cw_grid);
  if ((v_type == 0i)) {
    let cw_argument_index_6 = (cw_buffer_offset_0 + (v_b + 7i));
    let cw_argument_index_7 = (cw_buffer_offset_0 + (v_b + 11i));
    var v_r: f32 = (max(b_P[cw_argument_index_6], b_P[cw_argument_index_7]) + 0.002f);
    return (f_max3(v_a, f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid) + vec3<f32>(v_r, v_r, v_r));
  }
  if ((v_type == 2i)) {
    return (v_a + f_cw_buffer_helper_3((cw_buffer_offset_0 + 0i), (v_b + 4i), cw_thread, cw_block, cw_grid));
  }
  var v_radius: f32 = ((b_P[(cw_buffer_offset_0 + (v_b + 7i))] + b_P[(cw_buffer_offset_0 + (v_b + 16i))]) + 0.025f);
  return (v_a + vec3<f32>(v_radius, v_radius, v_radius));
}
fn f_cw_buffer_helper_3(cw_buffer_arg_0: i32, cw_arg_i: i32, cw_thread: vec3<u32>, cw_block: vec3<u32>, cw_grid: vec3<u32>) -> vec3<f32> {
  var cw_buffer_offset_0: i32 = cw_buffer_arg_0;
  var v_i: i32 = cw_arg_i;
  let cw_argument_index_8 = (cw_buffer_offset_0 + v_i);
  let cw_argument_index_9 = (cw_buffer_offset_0 + (v_i + 1i));
  let cw_argument_index_10 = (cw_buffer_offset_0 + (v_i + 2i));
  return vec3<f32>(b_P[cw_argument_index_8], b_P[cw_argument_index_9], b_P[cw_argument_index_10]);
}

@compute @workgroup_size(128, 1, 1)
fn main(
  @builtin(local_invocation_id) cw_thread: vec3<u32>,
  @builtin(workgroup_id) cw_block: vec3<u32>,
  @builtin(num_workgroups) cw_grid: vec3<u32>
) {
  var v_i: i32 = i32(((cw_block.x * cw_block_size.x) + cw_thread.x));
  if ((v_i >= 32768i)) {
    return;
  }
  var v_id: i32 = i32(b_Order[v_i]);
  var v_b: i32 = ((32768i + v_i) * 8i);
  f_cw_buffer_helper_1(0i, v_b, f_cw_buffer_helper_0(0i, v_id, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
  f_cw_buffer_helper_1(0i, (v_b + 4i), f_cw_buffer_helper_2(0i, v_id, cw_thread, cw_block, cw_grid), cw_thread, cw_block, cw_grid);
  var cw_tmp_3: f32;
  if ((b_P[((v_id * 24i) + 3i)] >= 0.0f)) {
    cw_tmp_3 = 1.0f;
  } else {
    cw_tmp_3 = 0.0f;
  }
  b_Nodes[(v_b + 3i)] = cw_tmp_3;
  b_Nodes[(v_b + 7i)] = f32(v_id);
}
