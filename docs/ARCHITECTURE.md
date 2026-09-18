# ARBOR / implementation notes

## The intentional scope change

STRATUM selected whole-lot detail tiers and committed replacement cache pages. ARBOR instead keeps one tree's complete structural representation resident. A camera move never invokes the growth, primitive-generation, sort or BVH-build entry points. This is the appropriate bounded implementation for one specimen; it does not claim a solution to forest-scale geometry paging.

## Numeric record layout

All arrays are flat f32/u32 buffers so CUDA/WebGPU do not disagree about float3 struct padding.

`B`: 2,109 curve descriptors × 20 floats. Four Bezier control points, start/end radius, parent arc offset, stable seed and chord length.

`P`: 32,768 records × 24 floats. `P[3]` is -1 for unused, 0 for wood, 1 for leaf, 2 for stone. Wood stores endpoints and radii, transported reference axis, cumulative longitudinal coordinate and original curve radius. Leaves store anchor, axis, lateral basis, normal, length, half-width, seed, petiole length, camber, twist and twig ID.

`Nodes`: 65,536 records × 8 floats. Heap-indexed binary tree, root at 1, leaf level starting at 32,768. Each record stores minimum xyz, active descendant count, maximum xyz and leaf ID/unused. `Order` maps Morton-sorted leaf slots back to original stable primitive IDs.

## Ordering and races

Each growth generation is a distinct ordered dispatch. Children read only a completed parent generation. Every leaf/wood primitive has one writer. Each bitonic stage is a separate dispatch; only the invocation with `i < (i xor distance)` writes that pair, so two invocations cannot write the same pair. Each BVH level is a separate dispatch. The queue orders each producer before its consumers.

Rendering reads the immutable tree. Ray hits, linear radiance, albedo guides, filtered radiance and the progressive history have distinct buffers. The filter never reads and writes the same radiance allocation. Each output pixel has one writer.

## Continuity, not transparency

There is no screen-distance `lod` switch. Bark components are blended toward a constant mean with continuously varying footprint weights. Curved leaves retain their actual positions and silhouettes; only fine serrations and midrib-scale displacement lose unresolved frequencies. The ray opacity of a leaf is always opaque. Thin-sheet light transmission is kept separate from visibility.

The simple band filter is not a guarantee of zero aliasing. Stable IDs prevent whole-object popping; filtered signals avoid deliberate frequency steps. Finite pixel sampling, grazing-angle numerical solvers and history resets are separate limitations and should not be advertised as solved.

## Inspection modes

The band visualization shows representative physical periods of 65 mm, 5 mm and 1 mm as RGB. It is a diagnostic of the filter, not a fabricated triangle count. Field-note footprint is evaluated at the target plane; visible surface footprints vary with ray distance. Geometry counts and bytes come from the fixed ABI and actual buffer allocations. GPU timings are left unavailable when timestamp queries are not exposed.

## Optional versus absent systems

Optional: sun/ambient-occlusion tracing, breeze, progressive accumulation during still views, diagnostic views and high resolution.

Absent: neural networks, adaptive online training, streaming pages, game simulation, enemy AI, external mesh or texture loading, full path tracing, motion-vector reprojection, a growing triangle hierarchy and a complete mobile flight interface.
