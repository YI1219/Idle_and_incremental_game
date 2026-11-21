# 笔触与相机控制

仅修改 shihai_hud.gd、editor_camera.gd，并新增 terrain_controls_test.gd。

- 真实 Viewport.push_input 基线测试中，三个圆点中心都能够更新 radius，且没有绘制地形。因此未证实输入路由失效，调整集中在可发现性与可点击性。尺寸按钮扩大为40×58，常显「细／中／阔」，选择后显示提示，使用最近档位作为唯一高亮。默认1.6之前没有任何高亮。
- 滚轮同步设置高度与俯仰目标，6m对应19°、21m对应27°、100m对应68°。两个状态均沿既有平滑插值演进。右键拖拽仅改变yaw/pitch目标，保持height_goal。Q/E与中键路径保持。
- 相机沿用原高度与地面中心定位公式，因此右键俯仰时眼点到地面中心几何距离仍随俯仰变化。没有引入右键高度或滚轮高度的额外联动。
- Godot4.7.2 headless基线11项中2项失败，分别是近端和远端俯仰。修改后21/21通过，包括真实按钮文字区域点击、地形不变、平滑起步、单调缩放、默认视角、真实右键/中键事件路由。
- 日志为controls_before.log与controls_after.log。本分支未自行启动图形进程，按钮视觉质量仍需根任务实拍确认。

- 既有 terrain_editor_runtime_test.gd 22/22通过。

## 根任务整合后复核

- 只读确认editor radius setter先取消held draft再更新radius，并清空_brush_shape_key。三个UI token通过ed.set调用同一setter，兼容且不会绕开取消逻辑。相同值赋值保留当前草稿，符合无尺寸变化语义。
- 单次原生Forward+进程已自行退出。1280×720诊断图controls_native_token_0/2与controls_native_zoom_6/100保留。真实文字点击细/阔分别得到1.0/3.8，painting均false。文字可读，阔档有独立朱色圆环与文字高亮。
- 原生近/远端高度与俯仰为6/19°及100/68°，日志controls_native.log。诊断不是锁定日照/水相位的美术前后比较。
- 临时脚本DATA_UNCHANGED打印false，因为采集期间没有冻结水量演进，包含水状态的完整serialize比较不能作为床面变化证据。此前headless同帧点击不修改地形的断言已通过。本轮未重复运行未变测试，未修改生产实现。
- wheel改变height/pitch目标，right drag仅改yaw/pitch目标，两者共享平滑advance。原先已披露的高度定位几何距离边界仍在。

## 固定半径右拖修正

根任务澄清后，上一节的右拖几何距离边界已修复。新增_orbit_distance及其目标值。滚轮以既有height_goal缩放参数和19/27/68°自动俯仰决定半径，右拖只改yaw/pitch，在固定球面半径旋转。实际Y允许随俯仰变化。两者均通过同一平滑advance演进。

advance(0)保留采集工具显式_height/_pitch/_center锁定视角的约定，并同步球面半径；没有修改BASE采集工具。对焦距离使用实际球面半径。

- 实际眼点→focus半径新增回归，旧代码27项中6项失败，修改后29/29通过，覆盖真实viewport右拖连续5帧平滑半径、显式采集height/pitch、采集之后轨道半径。
- 既有runtime18/22。高度、平移、滚轮断言通过；4项失败均为east/south cliff owner指针与snapped viewport删除断言，与根任务本轮highest-ground拾取变更重叠，已交根任务审阅。未修改或删除既有断言。
- 日志controls_orbit_red/green/runtime.log。本轮只运行headless，无新图形进程。旧controls_native_zoom图片仅属前一次高度定位版本，不能用作固定球半径右拖的视觉证据。
