# Poly Haven existing geometry sources

Powered by Poly Haven. Offline source evaluation only; none is a production dependency or accepted cliff replacement.

- [Namaqualand Boulder02](https://polyhaven.com/a/namaqualand_boulder_02): Greg Zaal photography, Rico Cilliers modeling.
- [Rock Face02](https://polyhaven.com/a/rock_face_02): Dario Barresi photography, Rico Cilliers modeling.
- [Boulder01](https://polyhaven.com/a/boulder_01): Rico Cilliers.

Official assets are [CC0](https://polyhaven.com/license), allowing modification and redistribution, including commercial use. The website's example renders and text are separate from those assets; none was copied into the project. Only official1k glTF JSON and referenced geometry buffers were downloaded. No bitmap preview, albedo, normal or roughness texture was downloaded. The resolution label is the official package label; actual triangle counts are recorded in Blender reports rather than inferred from website figures.

The official `https://api.polyhaven.com/files/<slug>` metadata responses are preserved in `*_files.json`. [Download manifest](download_manifest.json) records the exact download URLs, byte sizes, official MD5 and locally calculated SHA256. Original glTF/buffer files remain in their per-source directories. Separate work copies remove image/material/texture/sampler references only; geometry buffer bytes and scene transforms remain original. Blender refinements, GLBs and originals stay local under the art binary policy; reports preserve their identity. Re-downloading uses already saved official metadata and an identifying `YunluArtStudy/1.0` User-Agent. There is no runtime API request or purchase.

The [official API terms](https://raw.githubusercontent.com/Poly-Haven/Public-API/master/ToS.md) were inspected and retained in `api_terms.txt`. Attribution here and in the review identifies the provider. This provenance is not a claim that the sources match the game's stylized art. Source qualification, failed repairs and native in-engine placement results are separated in the [bedrock review](../../../../review/terrain_fidelity/2026-10-17/bedrock_local/README.md).

## Subsequent existing cliff-group sources

`cliff_group_manifest.json` separately preserves geometry-only downloads of [Mountainside](https://polyhaven.com/a/mountainside) and [Namaqualand Cliff02](https://polyhaven.com/a/namaqualand_cliff_02), both official CC0 assets, with their original glTF/buffer bytes and exact URL/size/MD5/SHA. The earlier three-source manifest is unchanged. Separate Blender reductions and closed-copy refinements remain unaccepted research. No preview/material raster downloads, purchases or runtime installation. [Current native review](../../../../review/terrain_fidelity/2026-10-17/cliff_group_sources/README.md).
