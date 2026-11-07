# Keeping up with upstream

Touqi's `oot-5070` branch is Lichii `build-88` + selected Lichii PRs + Touqi changes.

```
git remote add lichii https://github.com/zortos293/Lichii.git
git fetch lichii --tags
git fetch lichii "refs/pull/<n>/head:refs/remotes/lichii/pr-<n>"
```

To move to a newer Lichii build:

1. Create a test branch from the new tag and merge `oot-5070` into it. Internal names were left
   as upstream's to keep this clean.
2. Build with `tools/oot-bench/build-lichii.cmd`, package with `Package-LocalBuild.ps1`.
3. Run `make bench` 3 times each on the new official build, the merged build and the current
   `oot-5070`. Keep the merge only if P95/P99 do not get worse and the image is correct.

Contributing back: changes useful upstream (for example `EDEN_NX2_FRAME_LOG`) go to Lichii as a
small PR from a branch based on Lichii's `nx2`, written and submitted by the owner, with AI
assistance disclosed. Measurements on other hardware are also useful as comments on open PRs.

## The main branch (`nx2`)

The fork's `nx2` holds exactly the tested `oot-5070` code: it was joined with a merge commit
whose tree is `oot-5070`'s, so both histories are kept. These Eglantine `nx2` commits are in its
history but **not in its code** (they conflict with Lichii's versions of the same files and
were not built or tested here):

| Commit | Change |
| --- | --- |
| `df92fc6c95` | keep other threads out of the Vulkan scheduler while the split's back submits |
| `8820bb79aa` | buffer cache: size native storage buffers from the mapping (DLSS) |
| `8ef3563080` | release the guest RAM when a Switch 2 game stops |
| `6dd4781249`, `c7b1ab446a`, `320f081816` | rename the `eden` data folder to `eglantine` + migration prompt (Lichii keeps `eden` on purpose) |
| `0ca2032bff`, `cb60749eb9`, `6051d36e80` | translations, Discord link, PR retargeting |

Port any of them as a separate, built and benchmarked change.
