# 素材登记

本文件逐包记录选用资源的作者、来源与具体许可。原始压缩包和完整下载不进入仓库；上游文件名与SHA256保留在 `asset_manifest_20261024.json` 供核对。

许可按具体素材包及对应版本分别判断。Downtown City MegaKit免费Standard的随包 `assets/city/License_Standard.txt` 明确标注CC0 1.0；不将其他通用网页条款或付费Source的功能归为本包内容。原有素材来源登记如下。

| 仓库内文件 | 来源文件 | 素材包 | 页面 | 许可证 | 下载日期 | SHA-256（前 16 位） |
| --- | --- | --- | --- | --- | --- | --- |
| `assets/models/weapons/ak.gltf` | `Guns/glTF/AK.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `7320d771b829e2dc` |
| `assets/models/characters/enemy.gltf` | `Characters/glTF/Character_Enemy.gltf` | Quaternius — Toon Shooter Game Kit | https://quaternius.com/packs/toonshootergamekit.html | CC0（页面标注） | 2026-10-23 | `60c77a900ddd7608` |
| `assets/audio/hit_body.ogg` | `Audio/impactPunch_medium_001.ogg` | Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | 2026-10-23 | `e71d23abcc3f10d9` |
| `assets/audio/hit_head.ogg` | `Audio/impactPlate_light_002.ogg` | Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | 2026-10-23 | `8ac5869ea434cf0d` |
| `assets/vfx/muzzle.png` | `PNG (Transparent)/muzzle_02.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `96164063353cc038` |
| `assets/vfx/spark.png` | `PNG (Transparent)/spark_05.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `9624ea2017b8b276` |
| `assets/vfx/puff.png` | `PNG (Transparent)/smoke_04.png` | Kenney — Particle Pack | https://kenney.nl/assets/particle-pack | CC0 | 2026-10-23 | `2db2f69874cdb1e5` |

## 代码生成的素材

| 内容 | 位置 | 许可证 |
| --- | --- | --- |
| 枪声、换弹声、空仓声 | `weapons/procedural_audio.gd`，运行时生成 | MIT，移植自 Ironline 1944 |
| 准星 | `ui/crosshair.gd`，运行时绘制 | 本项目 |

## 2026-10-24 新增六项素材

本次六项均从原作者免费入口取得，原始下载不随仓库分发，没有从旧origin工程拷素材。Quaternius仅免费Standard，未取得付费Source扩展；免费包实测153种独立模型，工程只取需要的部分。Rubble采用1K颜色/GL法线/粗糙度，2K备选只在素材库。

| 文件范围 | 作者与来源 | 许可 | 用途与限制 |
| --- | --- | --- | --- |
| `assets/city/` | [Quaternius Downtown Standard](https://quaternius.itch.io/downtown-city-megakit) | CC0 | 真实街道、建筑与道具；关闭顶点遮罩乘底色，未附付费Source着色器 |
| `assets/ruins/` | [Majadroid](https://majadroid.itch.io/3d-apocalyptic-building-city-cc0) | CC0 | 外围四种废墟塔楼 |
| `assets/rubble/` | [Poly Haven Rubble](https://polyhaven.com/a/rubble) | CC0-1.0 | 地面材质；不是飞散的实体碎块 |
| `assets/weapons/` | [Stein Games](https://stein-indie.itch.io/classic-weapons-pack) | CC0 | AK47近景16,578三角、2K贴图；无新增手臂/动画/LOD |
| 可选，不随仓库分发：`addons/pyrolux_fx/` | [gennai PYROLUX Lite](https://gennai.itch.io/pyrolux-lite) | 作者自定义 | 允许游戏集成/导出；禁止素材本身或其部分单独、作为素材包/模板/工具再分发；Git忽略，队友自行从作者取得。原包无音效 |
| `addons/destruction/` | [Jummit v7.2](https://github.com/Jummit/godot-destruction-plugin/releases/tag/v7.2) | MIT | 保留许可证，Godot4.7兼容修复见插件LOCAL_CHANGES.md |

本仓库实际第三方文件的相对路径、字节数、SHA256和来源见`asset_manifest_20261024.json`；另保留可公开资源的上游下载哈希。PYROLUX仅列可选来源与许可，不列其本机原始文件。新箱墙与补给几何由项目代码生成；手雷爆炸音由代码合成。
