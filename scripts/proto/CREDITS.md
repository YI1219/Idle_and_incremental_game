# Island prototype credits

New code in `scripts/proto/` and `shaders/proto/`. No third-party source files are copied.

## Algorithms (reimplemented, not vendored)

| Idea | Source | License |
| --- | --- | --- |
| Terraced marching-squares cells, with mask-0 cells treated as empty so one pass cuts the coast and hole rims | [Yūgen's Terrain Authoring Toolkit](https://github.com/ToumaKamijou/Yugens-Terrain-Authoring-Toolkit) by ToumaKamijou | MIT |
| Underside as an inverted, stretched, tapered reading of the top height | [Flylands](https://github.com/sugarshock/flylands) by sugarshock | MIT |

MIT notice: these works are used as references only. Their copyright stays with the authors. This folder does not include their source.

## Rock meshes

The prototype instances the meshes already stored under `assets/rockkit/`. It does not add a second copy.

| Pack | Pieces | License |
| --- | --- | --- |
| KayKit Forest Nature Pack 1.0 FREE, Kay Lousberg | `Rock_2_H`, `Rock_2_E`, `Rock_3_Q`, `Rock_3_O`, `Rock_3_K`, `Rock_3_G`, `Rock_1_K`, `Rock_1_O` | CC0 1.0 (`assets/rockkit/kaykit/License.txt`). Credit appreciated: Kay Lousberg, https://www.kaylousberg.com |
| Quaternius Stylized Nature MegaKit Standard | `Rock_Medium_1`, `Rock_Medium_3` | CC0 1.0 (`assets/rockkit/quaternius/License_Standard.txt`). Models by Quaternius |

Kenney Nature Kit was not fetched for this pass. The two packs above are the ones already in the repo and the ones used by the earlier Blender rock study.
