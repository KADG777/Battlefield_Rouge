# 架构与依赖规则

引擎：Godot 4.7.2，Forward+，Jolt 物理。所有人必须用同一个版本。

## 目录

| 目录 | 放什么 |
| --- | --- |
| `autoload/` | 全局单例：`Events`（信号总线）、`RunState`（本局状态）、`InputMapSetup`（按键） |
| `components/` | 可复用的小部件：生命值、受击判定、数值（Stats） |
| `weapons/` | 武器数据（`.tres`）和开火逻辑 |
| `actors/` | 玩家、敌人 |
| `zone/` | 战区控制（zone director）、据点 |
| `buffs/` | 增益，每个增益一个 `.tres` |
| `ui/` | HUD、三选一增益界面、结算界面 |
| `maps/` | 战区场景，由 `tools/gen_zones.py` 生成 |
| `tools/` | 编辑器外的辅助脚本 |
| `docs/adr/` | 架构决策记录 |

## 依赖规则

1. `components/`、`weapons/`、`actors/` 只向 `Events` 发信号，不读写 `RunState`，也不通过路径或分组去找别的系统。
2. 只有 `RunState` 和 `zone/` 下的战区控制可以改本局状态。
3. 增益只修改 `Stats`，不直接改玩家或武器脚本。新增增益只需要加一个 `.tres`。
4. 依赖方向只能是 `ui → zone → actors → components`，反过来要用信号。
5. 从 `../origin/sheji` 迁移代码时，先删掉对 `GameState`、`VoiceManager`、突破模式、载具、商店的引用，再放进来。

## 一个战区的流程

由 `zone/zone_director.gd` 执行，场景里的节点顺序是：几何 → 掩体点 → 据点 → 玩家 → 敌人 → `ZoneDirector` → `HUD`。HUD 放在最后，保证它 `_ready` 时战区控制已经准备好。

1. 烘焙导航网格，把 `RunState.buffs` 应用到玩家的 `Stats`，把玩家和掩体点交给每个敌人。
2. 敌人全部死亡 → `Events.zone_cleared`，据点开放。
3. 据点占满 → `Events.point_captured`。不是最后一个战区就暂停并弹出三选一；选完发 `Events.buff_chosen`（`RunState` 记下增益），`RunState.advance_zone()`，切到下一个战区场景。最后一个战区则发 `Events.run_won` 并显示胜利界面。
4. 玩家死亡 → `Events.player_died`，`RunState` 清空本局，显示阵亡界面。重新开始回到第 1 个战区。

新增战区：在 `tools/gen_zones.py` 里加一个布局，生成后把场景路径加到 `RunState.ZONE_SCENES`。

## 碰撞层

定义在 `components/collision_layers.gd`，代码里不要直接写数字。

| 层 | 常量 | 放什么 |
| --- | --- | --- |
| 1 | `WORLD` | 场景几何和道具 |
| 2 | `ACTORS` | 玩家和敌人的移动碰撞体 |
| 4 | `HITBOXES` | 受击判定 |

子弹（玩家的射线、敌人的慢速弹）只检测 `WORLD | HITBOXES`。角色的移动碰撞体和受击判定位置重叠，子弹如果检测 `ACTORS`，会先打在移动碰撞体上而打不到受击判定。

## 从旧工程迁移

旧工程在 `../origin/sheji`，只当参考，不修改。迁移顺序和原因见 `docs/adr/0001-rebuild-on-clean-skeleton.md`。


## 2026-10-24 素材接入补充

- `zone/city_dressing.gd`只布置真实模型和材质，不管理RunState；地图仍由gen_zones.py生成。
- `components/breakable.gd`发`broken(kind,position)`，不自行找玩家或发奖励；`ZoneDirector`注入并监听，生成区域补给后按玩家身体进入结算。
- 新增`CollisionLayers.DEBRIS = 1 << 4`（16）与`PROJECTILES = 1 << 5`（32）。DEBRIS只检测WORLD，角色/射线不检测DEBRIS；保留原HITBOXES=8。
- 玩家暴露`grenades_remaining`、`grenades_changed`、`throw_grenade()`与`add_grenades()`，HUD只读取或订阅；手雷不访问RunState。
- 可破坏物容器属于导航采集组，破坏后在删除生效后重烘焙，碎片的父容器在该组之外；首次导航同步后才启用敌人AI。薄墙仍放侧路，未增加建筑整体实时断裂。
