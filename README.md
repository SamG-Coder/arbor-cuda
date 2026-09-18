# ARBOR FOREST
## A seeded continuous-detail forest in CUDA → WebGPU

**[Walk the forest](https://samg-coder.github.io/arbor-cuda/)** · [GPU checks](https://samg-coder.github.io/arbor-cuda/tests/browser.html)

ARBOR FOREST expands the original single-tree renderer into a 324-tree grove while keeping the same continuous-detail surface system. The browser loads no tree meshes, leaf cards or texture maps.

Each forest cell derives its own deterministic seed from the master seed. That per-tree seed controls position jitter, rotation, scale, material variation and wind phase. The expensive branch/leaf structural dataset is resident once and reused, so forest size does not multiply the source-tree geometry allocation by 324. This build deliberately keeps the same underlying branch topology resident; the per-tree seed morphs the instance rather than storing 324 independent branch BVHs.

## Why the far view stays cheap

The renderer now has two visibility levels, but not conventional whole-tree visual LODs. Primary rays first traverse the forest grid with a 2D DDA. Only a tree cell crossed by the ray gets a cheap bounding-sphere test, and only a surviving tree enters the detailed branch/leaf BVH. Far-away views therefore do not loop through every tree's 29,412 objects.

Once a tree is entered, the same persistent woody segments and curved leaves are intersected. Bark plates, fissures, grain, leaf serrations, veins and relief continue to use projected-footprint filtering, so high-frequency detail resolves smoothly instead of swapping the tree model. There are no billboard canopies or whole-tree alpha fades.

## Forest

- 18 × 18 = **324 trees**
- one deterministic seed per tree
- **5,124 woody segments** and **24,192 curved leaves** in the resident source structure
- seeded per-tree scale, yaw, colour/material response and wind phase
- forest-grid DDA → per-tree bound → detailed BVH
- continuous bark/leaf surface refinement
- CUDA-authored generation, intersections, surfaces, lighting and final pixels

## Run

Double-click `START.bat` on Windows, or run:

```sh
node server.mjs
```

Open `http://localhost:8091`. Requires Node.js 20+ and a WebGPU-capable browser. Do not open `index.html` with `file://`; WebGPU needs localhost or HTTPS.

The forest master seed can be changed in Field Notes. Every tree then receives a different deterministic derived seed.

## Rebuild and Pages

```sh
npm run build
npm test
npm run pages
```

`build` translates all 12 CUDA entry points. `pages` writes a static `dist/` folder for HTTPS hosting. GitHub Actions on `main` runs `npm test`, packages that folder, and deploys [GitHub Pages](https://samg-coder.github.io/arbor-cuda/).

## Validation

`npm test` checks generated shader consistency, host ABI and runtime contracts. The native CPU harness still validates the resident tree BVH, continuous footprint filtering and stable leaf intersections. The forest preview is produced by that same authored CUDA path through the CPU harness; it is not a browser-GPU benchmark.

Hardware WebGPU performance should be measured with `tests/browser.html` on the target device, or on the deployed [GPU checks](https://samg-coder.github.io/arbor-cuda/tests/browser.html) page.


## FPS forest update

- Click the view to capture the mouse. **WASD** walks, **Shift** runs, **Esc** releases pointer lock.
- The camera is a proper first-person walk camera at 1.72 m eye height, not an orbit camera.
- Tree placement uses deterministic per-seed jitter plus a low-frequency warp so the forest no longer reads as a grid.
- Bark and foliage have stronger deterministic per-tree colour variation.
- Full traced tree-to-tree sun visibility is **off by default** because it was the dominant lighting cost. Press **J** to enable it.
