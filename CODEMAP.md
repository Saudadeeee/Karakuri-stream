# CODEMAP — Karakuri Stream

Bản đồ codebase để maintain/sửa đổi. Đọc file này trước khi đụng vào code — đặc biệt phần "Quy ước cốt lõi" (sai 1 chỗ là toang cả hệ thống).

Xem `plan.md` cho lịch sử quyết định/bugfix theo từng phiên làm việc. File này chỉ nói **hiện trạng**, không nói **quá trình**.

## Stack

Godot 4.7, GDScript, renderer `gl_compatibility` (bắt buộc — quyết định luôn cả cách viết shader, xem phần Shader bên dưới). Không dùng plugin/addon ngoài.

## Cấu trúc thư mục

```
project.godot           Cấu hình engine + danh sách autoload (thứ tự load quan trọng, xem dưới)
CODEMAP.md              File này
plan.md                 Nhật ký thiết kế/bugfix theo phiên — lịch sử, không phải tài liệu tham chiếu

scenes/
  main.tscn             Scene chính (duy nhất) — camera, ground, PlacementController, UI
  pause_menu.tscn       Instance con trong main.tscn/UI — pause, xoá build, âm lượng
  blocks/
    wood_block.tscn      StaticBody3D + BoxMesh (bị BlockMergeManager build lại mesh runtime)
    water_block.tscn     StaticBody3D + BoxMesh + ShaderMaterial (water.gdshader) — mesh cũng bị build lại
    gear_block.tscn      StaticBody3D + CylinderMesh 8 cạnh — KHÔNG bị merge system đụng vào
    bell_block.tscn      StaticBody3D + CylinderMesh hình nón cụt — KHÔNG bị merge system đụng vào

scripts/
  autoload/              11 singleton, load theo đúng thứ tự khai báo trong project.godot
  data/                  class_name thuần data/utility, KHÔNG phải autoload, KHÔNG có scene tree riêng
  player/                Script gắn trực tiếp vào node trong main.tscn (camera, đặt/gỡ khối)
  ui/                    Script UI
  blocks/                Script gắn vào .tscn khối cụ thể (vd gear_block.gd dựng răng bánh răng)

shaders/
  water.gdshader         Spatial shader dùng chung cho MỌI mặt nước (khối đặt tay lẫn ô flow BFS)
  wood.gdshader          Vân gỗ procedural (world-pos noise) + rim-light, cho wood_block
  metal.gdshader         Kim loại toy (rim sheen + emissive nhẹ cho bloom) cho gear/bell

assets/
  sounds/                4 file audio đang dùng thật (xem Audio bên dưới)
  unused/                Asset đã tải về nhưng không dùng (rain ambience, giữ lại phòng khi cần, không xoá)

default_bus_layout.tres  Audio bus Master + Reverb, đăng ký trong project.godot [audio]
export_presets.cfg       Cấu hình export Windows Desktop + Web (xem mục Export bên dưới)
builds/                  Output export — KHÔNG commit (.gitignore), tự tạo lại bằng lệnh export
```

## Quy ước cốt lõi (đọc kỹ trước khi sửa)

### 1. Lưới toạ độ — trục Y lấy MẶT ĐẤT làm sàn, X/Z đối xứng quanh số nguyên

`GridManager.cell_to_world(cell)` trả về **tâm** khối:
- Y: `(cell.y + 0.5) * CELL_SIZE` — cell y=0 chiếm world y trong khoảng `[0, 1)`, đáy khối nằm đúng trên mặt đất (y=0)
- X/Z: `cell.x * CELL_SIZE`, `cell.z * CELL_SIZE` — khối trải đối xứng quanh toạ độ nguyên (giống Y trong bản cũ, đã bỏ)

`GridManager.world_to_cell(pos)` là chiều ngược lại: `floori()` cho Y (khoảng nửa-mở, không đối xứng), `roundi()` cho X/Z.

**Vì sao khác nhau giữa Y và X/Z**: Y có một mặt phẳng tham chiếu vật lý thật (mặt đất tại y=0, không có "world y=-1"), còn X/Z là mặt phẳng vô hạn không có biên tham chiếu tự nhiên. Đừng "sửa cho đồng bộ" — logic khác nhau có chủ đích.

Nếu bạn sửa công thức này, phải verify lại: đặt khối tầng đầu tiên không được chìm/nổi so với mặt đất, và raycast-đặt-khối từ chuột phải cho đúng cell (xem cách test ở cuối file).

### 2. BlockData — struct trung tâm, GridManager là nguồn sự thật duy nhất

`scripts/data/block_data.gd` (`class_name BlockData`):
```gdscript
enum Type { WOOD, WATER, GEAR, BELL }
var type: Type
var state: Dictionary   # chưa dùng tới, để dành cho state phức tạp hơn sau này
var node: Node3D         # root StaticBody3D thật trong scene tree
```

`GridManager._blocks: Dictionary` (`Vector3i -> BlockData`) là nơi DUY NHẤT lưu trạng thái lưới. Mọi hệ thống khác (merge, flow, decor, gear...) đều **đọc lại** từ đây, không tự giữ bản sao trạng thái lưới song song.

### 3. Pattern kiến trúc: autoload phản ứng theo signal — 2 biến thể

Mọi autoload connect vào `block_placed`/`block_removed`, nhưng phạm vi tính lại chia 2 nhóm rõ ràng (đã đo hiệu năng thật, xem PHẦN 12 trong `plan.md`):

**(a) Incremental — chỉ tính lại ô đổi + hàng xóm** (`BlockMergeManager`, `DecorManager`, `PondDecorManager`):
```gdscript
func _on_grid_changed(cell: Vector3i) -> void:
    _check_cell(cell)
    for dir in RELEVANT_DIRS:   # 6 hướng hoặc 4 hướng ngang tuỳ hệ thống
        _check_cell(cell + dir)
```
Đúng vì trạng thái của các hệ thống này (mặt ẩn/hiện, timer rêu, ring pond) chỉ phụ thuộc vào Ô ĐANG XÉT + hàng xóm trực tiếp — không bao giờ phụ thuộc khối ở xa. Bắt buộc dùng cách này cho hệ thống mới có tính chất tương tự — full-rescan-mỗi-lần-đổi-1-khối sẽ biến việc dựng 1 build lớn thành O(n²) (đã đo thật: 3000 khối từ 55s xuống 1.6s sau khi sửa 2 chỗ này).

**(b) Full rescan — có chủ đích, KHÔNG rút gọn được** (`WaterFlowManager`):
```gdscript
func _on_grid_changed(_cell: Vector3i) -> void:
    _refresh()   # tính lại BFS từ MỌI nguồn nước, không chỉ vùng gần cell đổi
```
Lý do KHÔNG thu hẹp phạm vi: chặn 1 hướng chảy phải khiến nước tìm đường khác CÓ THỂ đi qua vùng hoàn toàn khác trong lưới (xem PHẦN 8 — bug rerouting đã sửa). Thu hẹp phạm vi quét ở đây có nguy cơ tái phát bug đó. Đã tối ưu gián tiếp qua fix (1) bên dưới (quét ít hơn, không phải quét khôn hơn).

**`GearManager` không nghe signal nào, chỉ poll `_process()` mỗi frame** — cần animate liên tục (xoay) kể cả khi lưới không đổi, nên không hợp với pattern signal-driven.

### 4. GridManager có index phụ theo loại khối — ĐỪNG bỏ qua khi thêm hàm mới

`GridManager._cells_by_type: Dictionary[BlockData.Type, Dictionary[Vector3i, true]]` — mọi `set_block`/`remove_block`/`clear_all` phải cập nhật đồng bộ (qua `_index()`/`_unindex()`, đã có sẵn, chỉ cần gọi đúng chỗ nếu sửa 2 hàm này). `get_all_cells_of_type()` đọc từ index này, KHÔNG quét `_blocks` — nếu thêm hàm mới cần lọc theo loại, dùng lại `get_all_cells_of_type()`/index có sẵn, đừng viết vòng lặp quét `_blocks` trực tiếp (quay lại bug O(n) cũ). `get_all_cells()` (không lọc type, dùng cho `SaveManager`) thì vẫn quét `_blocks` trực tiếp — chấp nhận được vì chỉ gọi lúc Lưu, không phải mỗi frame/mỗi lần đổi khối.

### 5. Tạo node của 1 khối — CHỈ qua `BlockFactory`, đừng gọi `.instantiate()` trực tiếp nơi khác

`scripts/data/block_factory.gd` (`class_name BlockFactory`, static) là nơi DUY NHẤT biết cách map `BlockData.Type -> PackedScene` và xử lý phần việc riêng của từng loại (khối Nước cần `_make_material_unique()` để `edge_mask` không dính chung giữa các khối — xem mục Shader). `PlacementController` (đặt tay) và `SaveManager` (tải file) đều gọi `BlockFactory.instantiate(type)` — thêm loại khối mới chỉ cần sửa `BlockFactory.SCENES_BY_TYPE`, không phải sửa 2 nơi.

## Autoload (thứ tự load = thứ tự khai báo trong `project.godot`)

| # | Tên | File | Vai trò |
|---|-----|------|---------|
| 1 | `GridManager` | `autoload/grid_manager.gd` | Nguồn sự thật duy nhất của lưới. `set_block`/`remove_block`/`get_block`/`has_block`/`get_neighbors`/`get_all_cells_of_type`. Bắn signal `block_placed(cell)`/`block_removed(cell)`/`grid_cleared` (khi gọi `clear_all()` — xoá 1 lần, KHÔNG lặp `remove_block()` per-cell vì sẽ trigger rescan dây chuyền ở mọi autoload bên dưới). |
| 2 | `BlockMergeManager` | `autoload/block_merge_manager.gd` | Khi lưới đổi: rebuild mesh của ô đổi + 6 hàng xóm bằng `BlockMeshBuilder`, ẩn mặt giáp khối CÙNG LOẠI (Townscaper-style). Chỉ áp dụng `MERGEABLE_TYPES = [WOOD, WATER]` — Gear/Bell giữ mesh riêng. Nếu là Nước, còn set `edge_mask` shader param (xem phần Shader). |
| 3 | `AudioManager` | `autoload/audio_manager.gd` | Pool 20 `AudioStreamPlayer3D`. `play_wood_hit(pos)`, `play_chime(pos, note_index=-1)` (5 nốt ngũ cung, xem `PENTATONIC_RATIOS`), `make_water_loop_player()` (trả player chưa `.play()`, gọi nơi khác tự play). |
| 4 | `WaterFlowManager` | `autoload/water_flow_manager.gd` | BFS thật từ mọi khối Nước "đỉnh chuỗi + y>0" qua ô rỗng — ưu tiên rơi thẳng, bị chặn thì tràn MỌI hướng ngang còn mở (không phải 1 hướng — xem plan.md PHẦN 8 lý do). BFS tính 1 lần nhưng các ô KHÔNG hiện cùng lúc: đẩy vào `_reveal_queue` rồi `_process` tiết lộ từng ô mỗi `REVEAL_INTERVAL` (~0.09s) theo thứ tự BFS → nước chảy dần từng tí, không pop hết 1 frame. Mỗi ô = 1 `MeshInstance3D` (`water.gdshader`, `flow_amount=1`) + tween scale-in "giọt rơi"; ô rơi chạm khối/đất → `_spawn_splash` (hạt cầu trắng scale-to-0). `_active_flows: Dictionary[Vector3i, MeshInstance3D]` — **các autoload khác đọc trực tiếp dict này** (xem `GearManager._is_wet`). |
| 5 | `DecorManager` | `autoload/decor_manager.gd` | 2 rule độc lập trên Gỗ: (a) cạnh Nước liên tục 10s → mọc rêu; (b) `cell.y > 5` → gắn cờ đung đưa. |
| 6 | `PondDecorManager` | `autoload/pond_decor_manager.gd` | Nước có đủ 4 hàng xóm ngang bị chiếm → hoa súng (bob lên xuống) + cá Koi (bơi vòng tròn). |
| 7 | `FireflyManager` | `autoload/firefly_manager.gd` | `burst_at(pos)` — chớp hạt sáng 1 lần, gọi từ `GearManager` mỗi khi Chuông kêu. |
| 8 | `GearManager` | `autoload/gear_manager.gd` | `_process` mỗi frame: Gear cạnh Nước (đặt tay HOẶC đang là `WaterFlowManager._active_flows`) → quay + bụi lấp lánh. Đếm góc quay, đủ 2π → gõ Chuông kề bên (`AudioManager.play_chime` + `FireflyManager.burst_at`). |
| 9 | `SaveManager` | `autoload/save_manager.gd` | `save_game()`/`load_game()`/`has_save()`. KHÔNG có `_ready()` nghe signal gì — chỉ 3 hàm gọi trực tiếp từ `pause_menu.gd`. Xem mục Save/Load riêng bên dưới. |
| 10 | `AmbientLeaves` | `autoload/ambient_leaves.gd` | Thuần trang trí — spawn 1 `GPUParticles3D` lá phong cam rơi lơ lửng trên đảo lúc khởi động, KHÔNG nghe signal/gắn gameplay. Điểm nhấn cam của bảng màu wabi-sabi. |

**Quan trọng khi thêm autoload mới**: đăng ký trong `project.godot` [autoload] — nếu autoload mới cần đọc `GridManager`/`AudioManager`/`WaterFlowManager` trong `_ready()`, đặt SAU chúng trong danh sách (autoload load tuần tự theo thứ tự khai báo).

**Quan trọng khi autoload mới tự giữ Dictionary theo cell** (như `_active_flows`, `_ponds`, `_sparkles`): PHẢI connect thêm `GridManager.grid_cleared` để dọn dict + free node khi user bấm "Xoá toàn bộ" (`PauseMenu`). Nếu node được tạo là con của CHÍNH autoload đó (không phải con của `block.node`) thì `GridManager.clear_all()` không tự free được — phải tự `queue_free()` trong handler `grid_cleared` của autoload đó (xem `WaterFlowManager`/`PondDecorManager`). Nếu chỉ giữ dict tham chiếu tới node vốn đã là con của `block.node` (như moss/flag trong `DecorManager`, sparkle trong `GearManager`) thì node tự bị free theo khối, chỉ cần `.clear()` dict cho sạch — không leak node thật, chỉ leak entry dict nếu bỏ qua bước này. `GearManager` còn cần connect cả `block_removed` (không chỉ `grid_cleared`) vì nó gỡ từng khối lẻ thường xuyên hơn xoá toàn bộ.

## `scripts/data/` — utility thuần, không phải autoload

- **`block_data.gd`** — struct, xem trên.
- **`block_mesh_builder.gd`** (`class_name BlockMeshBuilder`) — `static func build(hidden_dirs: Dictionary) -> ArrayMesh`. Dựng cube bằng `SurfaceTool`, bỏ qua mặt nào có trong `hidden_dirs`. **Cạm bẫy đã từng dính**: thứ tự index tam giác `[0,2,1, 0,3,2]` — ĐỪNG đổi lại thành `[0,1,2, 0,2,3]` trông "tự nhiên" hơn, đã verify bằng ảnh thật là sai chiều winding (mesh lộn ngược, nhìn xuyên vào trong). Nếu thêm mặt/hình dạng mới trong file này, luôn chụp ảnh cận cảnh 1 khối đơn lẻ để verify (xem phần Cách test).
- **`block_factory.gd`** (`class_name BlockFactory`) — xem mục 5 "Quy ước cốt lõi" ở trên. Dùng chung bởi `PlacementController` và `SaveManager`.

## `scripts/player/` — input & tương tác

- **`orbit_camera.gd`** (gắn `OrbitRig` trong main.tscn) — xoay bằng kéo chuột giữa, zoom bằng lăn chuột, điều khiển qua `SpringArm3D` con. `SpringArm3D.collision_mask = 0` (tắt tự né vật cản — nếu bật lại sẽ bị bug "camera dính zoom" khi khối cản tia dò của spring arm, đã từng gặp).
- **`placement_controller.gd`** (gắn `PlacementController` trong main.tscn) — raycast chuột → `GridManager.world_to_cell`/`cell_to_world` → ghost block preview → đặt/gỡ khối. Tạo node khối qua `BlockFactory.instantiate(type)` (KHÔNG tự map scene nữa, xem mục 5 "Quy ước cốt lõi"). Phím `1`/`2`/`3`/`4` chọn Gỗ/Nước/Bánh răng/Chuông (`select_material`, bắn signal `material_changed` cho UI đồng bộ).

## `scripts/ui/`

- **`material_ui.gd`** (gắn `UI/MaterialPicker` trong main.tscn — 1 `Control` rỗng, TẤT CẢ node con dựng bằng code trong `_ready()`, KHÔNG khai báo trong .tscn) — dải dọc mép TRÁI màn hình, 4 icon. Mỗi icon là 1 `Button` chứa `SubViewportContainer` → `SubViewport` (own_world_3d, transparent_bg) render CHÍNH mesh khối thật (`BlockFactory.instantiate(type)`) + 2 `DirectionalLight3D` (key/fill) + `Camera3D`, khối tự xoay chậm trong `_process`. Không có sprite/art vẽ tay — đổi look khối là icon đổi theo. Auto-fade: `_process` đọc `get_viewport().get_mouse_position().x`, chuột gần mép trái (`< REVEAL_ZONE`) → `modulate.a` lerp về 1.0, xa → về `FADE_MIN_ALPHA` (0.18, mờ chứ không ẩn hẳn để vẫn bấm được). Phím `1-4` vẫn chọn vật liệu như cũ (xử lý ở `placement_controller`), UI đồng bộ qua signal `material_changed`.
- **`pause_menu.gd`** (gắn root `Control` của `scenes/pause_menu.tscn`, instance trong `main.tscn` UI CanvasLayer) — `process_mode = PROCESS_MODE_ALWAYS` (bắt buộc, nếu không sẽ tự đóng băng theo `paused` và không bao giờ resume được). Toggle bằng phím `ui_cancel` (ESC, action mặc định của Godot) HOẶC nút "⏸" góc trên-phải (`UI/PauseButton`, nối qua `[connection]` trong `main.tscn`, không qua script — không cần thêm script mới chỉ để nối 1 signal). `toggle()` set `visible` + `get_tree().paused`; mọi node khác dùng `process_mode` mặc định (`INHERIT`) nên tự dừng animate khi pause (Gear ngừng quay, nước ngừng cuộn), không cần sửa gì thêm.
  - Nút "💾 Lưu" → `SaveManager.save_game()`. Nút "📂 Tải" → `ConfirmationDialog` (cảnh báo mất công trình hiện tại chưa lưu) → `SaveManager.load_game()`. Nút "🗑️ Xoá toàn bộ" → `ConfirmationDialog` riêng → `GridManager.clear_all()`. Cả 3 thao tác đều có `StatusLabel` fade-in/out báo kết quả (`_show_status()`).
  - Slider âm lượng ghi/đọc `user://settings.cfg` qua `ConfigFile` — **khác hoàn toàn** `SaveManager` (setting cá nhân vs. dữ liệu gameplay, xem mục Save/Load bên dưới, đừng nhầm lẫn 2 cơ chế lưu này).

## Shader — `shaders/water.gdshader`

Dùng CHUNG cho: (a) `water_block.tscn` (khối Nước đặt tay), (b) mọi `MeshInstance3D` do `WaterFlowManager` tạo động cho ô flow BFS.

Uniform quan trọng:
- `flow_amount` (0.0 mặc định = nước tĩnh, sóng ĐA HƯỚNG đứng yên nhẹ; 1.0 = ô flow, sóng LAN theo `flow_dir` + vệt bọt cuộn chạy)
- `flow_dir: Vector2` — hướng dòng chảy (chỉ set khi `flow_amount>0`, do `WaterFlowManager` set theo hướng BFS thực tế đi qua ô đó)
- `edge_mask: Vector4` (+X,-X,+Z,-Z) — do `BlockMergeManager` set cho khối Nước đặt tay: 1.0 = biên thật (hiện foam), 0.0 = giáp ô Nước khác (tắt foam) — chỉ áp dụng mặt TRÊN (`v_is_top`, tính từ `VERTEX.y` trước khi bị sóng làm lệch)
- `deep_color`/`caustic_strength`/`sparkle_strength` — nâng cấp visual: gradient độ-sâu-giả theo fresnel (nhìn thẳng = jade đậm, nhìn nghiêng = sáng), caustic shimmer bò trên mặt (chỉ mặt TRÊN), tia sáng trên đỉnh sóng (emissive → bloom bắt sáng). CHỈ mặt trên (`v_is_top`) đội sóng, mặt bên phẳng để cột nước không rách seam dọc.

**Ràng buộc cứng**: KHÔNG được dùng `SCREEN_TEXTURE`/`DEPTH_TEXTURE` trong shader này — renderer `gl_compatibility` không hỗ trợ đọc screen/depth texture trong spatial shader. Mọi hiệu ứng foam/edge đều phải dựa trên UV cục bộ hoặc uniform truyền vào, không dựa depth buffer.

## Art direction — "Floating Diorama" (Wabi-sabi)

Hướng nghệ thuật: đảo nổi trong không gian vô cực kiểu Townscaper/Ghibli, bảng màu mộc mạc bão hoà vừa. Tất cả bằng mesh nguyên thuỷ Godot + shader + particle — KHÔNG có sprite/texture vẽ tay (không phụ thuộc công cụ ngoài).

- **Bầu trời**: `main.tscn` WorldEnvironment dùng `ProceduralSkyMaterial` (built-in), gradient xanh ngọc (đỉnh) → hồng pastel (chân trời/hoàng hôn). Ambient dùng màu CỐ ĐỊNH (`ambient_light_source = COLOR`, energy ~0.45), **KHÔNG** dùng `ambient_light_source = SKY` — đã thử, bầu trời hồng quá sáng làm cháy trắng toàn cảnh (over-expose). Đừng đổi lại SKY hay bật tonemap Filmic mà không kiểm tra lại phơi sáng bằng ảnh thật.
- **Đảo**: node `Ground` = 2 `CylinderMesh` (đĩa mặt trên mỏng + côn cụt thân dưới thu nhỏ) cho cảm giác đảo lơ lửng. Mặt trên vẫn đúng world y=0 (collision box giữ nguyên cho raycast đặt khối) — chỉ đổi visual, không đụng quy ước lưới.
- **Bảng màu + bề mặt chi tiết**: Gỗ dùng `wood.gdshader` (vân procedural theo world-pos → cột gỗ xếp chồng có vân liền mạch, + rim-light cạnh). Nước ngọc bích — đổi màu ở CẢ `water.gdshader` uniform default LẪN override trong `water_block.tscn` (2 nơi, quên 1 là lệch màu giữa khối đặt tay và ô flow). Gear/Bell dùng `metal.gdshader` (đồng/bạc + rim sheen + emissive nhẹ). Lá phong cam (`AmbientLeaves`).
- **Mesh chi tiết (không phải primitive trơn)**: Gear = hub cylinder + 10 răng box dựng bằng `scripts/blocks/gear_block.gd` (răng là con của MeshInstance3D nên quay cùng khi GearManager xoay). Bell = nón cụt + quai (torus) + đỉnh (sphere) + quả lắc, author trong `bell_block.tscn`. Koi có đuôi (prism), lá sen có khía + đôi khi hoa súng hồng, rêu là cụm 4-6 blob nhiều sắc xanh — tất cả trong `pond_decor_manager.gd`/`decor_manager.gd`.
- **Post-processing (`main.tscn` Environment)**: glow/bloom (bắt sáng foam/sparkle/emissive — `glow_hdr_threshold=1.0` để chỉ vùng thật sáng mới bloom, tránh cháy trắng), fog mật độ thấp cho không khí xa, adjustment color-grade (saturation 1.15). Đều chạy trên `gl_compatibility` (glow/fog/adjustment được hỗ trợ; SSAO/SSR/SDFGI thì KHÔNG).
- **Squash & stretch**: `placement_controller._animate_drop` — lún sâu (y 0.55) rồi nảy `TRANS_ELASTIC` cho cảm giác thạch dẻo.
- **AO & soft shadow — HÀNG GIẢ, ghi rõ để không nhầm**: renderer `gl_compatibility` KHÔNG có SSAO/SSIL/SDFGI thật (chỉ Forward+ mới có). "Đổ bóng mềm" hiện làm bằng `DirectionalLight3D.shadow_blur` + PSSM 4-split, KHÔNG phải AO thật. "AO góc kẹt" giữa 2 khối chỉ có gián tiếp nhờ merge system ẩn mặt trong (khe hở tự tối). Rim-light trong `wood`/`metal` shader cũng là mẹo làm cạnh khối "nổi" mềm, KHÔNG phải bevel/AO thật. Muốn AO/soft-shadow thật phải đổi sang Forward+ — nhưng thế thì mất khả năng export Web/Mobile nhẹ (đánh đổi đã chọn từ đầu dự án).
- **Particle cast_shadow OFF cho fluff**: lá phong (`AmbientLeaves`) tắt đổ bóng — billboard nhỏ đổ bóng sẽ rải đốm tối khắp đảo (đã dính, đã sửa). Khi thêm particle trang trí mới nhớ tắt shadow nếu không muốn đốm bóng.

## Vòng đời đặt 1 khối (đọc để hiểu data flow tổng thể)

1. `PlacementController._place_block()` — raycast, xác định `_ghost_cell`, tạo node qua `BlockFactory.instantiate(type)`, tween rơi+nảy, gọi `GridManager.set_block(cell, BlockData.new(...))`
2. `GridManager.set_block()` lưu vào `_blocks`, bắn `block_placed(cell)`
3. Tất cả autoload đã `connect()` vào signal này chạy `_refresh()` gần như đồng thời trong cùng frame: `BlockMergeManager` rebuild mesh ô này + 6 hàng xóm; `WaterFlowManager` tính lại toàn bộ BFS; `DecorManager`/`PondDecorManager` quét lại điều kiện rêu/hoa súng/cờ; `GearManager` sẽ thấy trạng thái mới ở `_process` frame kế tiếp (không nghe signal trực tiếp, tự poll `is_powered` mỗi frame vì cần animate liên tục dù không có gì thay đổi ở lưới)

## Save/Load (`scripts/autoload/save_manager.gd`)

Lưu **toàn bộ dữ liệu gameplay** (vị trí + loại từng khối) — khác hoàn toàn setting âm lượng (`user://settings.cfg` qua `ConfigFile`, xem `pause_menu.gd`). 2 file riêng biệt, đừng gộp.

- Định dạng: JSON array tại `user://save_data.json`, mỗi phần tử `{"x":int,"y":int,"z":int,"type":int}` (`type` là giá trị số của `BlockData.Type`).
- `save_game()`: `GridManager.get_all_cells()` (KHÔNG lọc theo type — quét toàn bộ `_blocks`, chấp nhận được vì chỉ chạy lúc bấm Lưu, không phải mỗi frame) → serialize → ghi file.
- `load_game()`: đọc file → `GridManager.clear_all()` (xoá sạch lưới hiện tại trước, không merge với build cũ) → với mỗi entry: `BlockFactory.instantiate(type)` → add làm con của `get_tree().current_scene` (KHÔNG phải con của `SaveManager` — `SaveManager` là autoload, cha của nó là `/root`, không phải "Main") → `GridManager.set_block(...)`. Trả `false` nếu file không tồn tại hoặc JSON hỏng (`data == null` hoặc không phải `Array`) — gọi ở nơi khác PHẢI check giá trị trả về, đừng giả định luôn thành công.
- **Decor tự regenerate, không cần lưu riêng**: rêu/hoa súng/cá/cờ/sparkle KHÔNG nằm trong file save — vì `load_game()` gọi `GridManager.set_block()` y hệt lúc đặt tay, mọi autoload phản ứng signal (`DecorManager`, `PondDecorManager`, `GearManager`...) tự tính lại từ đầu theo đúng rule của chúng. Đây là lợi ích trực tiếp của kiến trúc reactive — đừng thêm state decor vào file save, sẽ chỉ làm phức tạp hoá và có nguy cơ lệch dữ liệu.
- Verify bằng test thật: dựng cấu trúc đa dạng (cột nước chảy, pond, gear+bell) → save → `clear_all()` → load → so khớp CHÍNH XÁC từng cell+type với trước đó, xác nhận pond/gear tự regenerate đúng sau khi load, xác nhận `load_game()` trả `false` sạch (không crash) khi không có file.

## Cách thêm 1 loại khối mới (checklist)

1. Thêm vào `BlockData.Type` enum (`scripts/data/block_data.gd`)
2. Tạo `scenes/blocks/xxx_block.tscn`: `StaticBody3D` root + `MeshInstance3D` (con tên đúng `"MeshInstance3D"` nếu muốn tương thích `BlockMergeManager`/animation lookup pattern) + `CollisionShape3D` (BoxShape3D 1x1x1 để raycast đặt/gỡ nhất quán, kể cả nếu mesh nhìn không phải hình hộp)
3. Nếu khối này KHÔNG nên bị merge/ẩn mặt (hình dạng riêng như Gear/Bell): đừng thêm vào `BlockMergeManager.MERGEABLE_TYPES`
4. `BlockFactory`: thêm `const XXX_SCENE`, thêm vào `SCENES_BY_TYPE` (KHÔNG sửa `PlacementController` hay `SaveManager` — cả 2 đều gọi qua `BlockFactory.instantiate()`). Thêm phím tắt trong `PlacementController._unhandled_input`
5. `material_ui.gd` + `main.tscn`: thêm 1 `Button` mới trong `HBoxContainer`, thêm vào `buttons` dictionary trong script (khớp tên node)
6. Nếu khối cần logic riêng theo thời gian/trạng thái lưới (như Gear xoay, Bell kêu): tạo autoload mới theo đúng pattern ở trên, đăng ký trong `project.godot` SAU `GridManager` (và sau bất kỳ autoload nào nó cần đọc trong `_ready`)

## Audio

| File | Dùng cho | Ghi chú |
|------|----------|---------|
| `218460__thomasjaunism__wood-block-hit.wav` | `AudioManager.play_wood_hit` | Đã kiểm khoảng lặng đầu bằng `ffmpeg silencedetect`, sạch |
| `517660__samuelgremaud__chimes-5.wav` | `AudioManager.play_chime` (Bell) | Đã cắt 161ms lặng đầu bằng `ffmpeg atrim` |
| `249666__tymorafarr__water-stream-looped.ogg` | `AudioManager.make_water_loop_player` | Convert từ `.flac` gốc bằng ffmpeg — Godot 4 không import `.flac` native. File `.flac` gốc vẫn giữ trong `assets/sounds/` làm bản gốc tham chiếu |
| `default_bus_layout.tres` | Bus Master + `AudioEffectReverb` | Thông số `room_size`/`wet`/`damping` là ước lượng, CHƯA nghe thử thật — cần tinh chỉnh bằng tai |

`assets/unused/79272__ra_gun__ambience-summer-rain-07-090718.wav` — tải về ban đầu định dùng làm tiếng nước, sau tìm ra file nước chuyên dụng nên đổi, file rain không còn ref trong code nữa nhưng giữ lại (không xoá) phòng khi cần ambience sau này.

## Export (Windows Desktop + Web)

`export_presets.cfg` có 2 preset: `"Windows Desktop"` và `"Web"`. Export template đã bundle sẵn theo bản Godot cài qua Steam (`.../Godot Engine/editor_data/export_templates/4.7.1.stable/`) — không cần tải thêm nếu dùng đúng install này.

Lệnh export (chạy từ thư mục project, headless không cần mở editor):
```
godot --headless --export-release "Windows Desktop" "builds/windows/karakuri-stream.exe"
godot --headless --export-release "Web" "builds/web/index.html"
```

**Web — bắt buộc serve qua HTTP, không mở trực tiếp file `index.html`** (WASM/CORS sẽ chặn nếu mở qua `file://`). Web export cần header `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp` (do `GODOT_CONFIG.ensureCrossOriginIsolationHeaders=true` trong `index.html`) — server tĩnh trần (`python -m http.server`) KHÔNG tự gắn 2 header này, cần server tuỳ chỉnh set thêm (xem ví dụ inline trong `end_headers()` override của `http.server.SimpleHTTPRequestHandler`). Các host thật như itch.io/GitHub Pages (qua service worker) thường tự lo việc này.

`variant/thread_support=false` trong preset Web — cố tình tắt threading để tương thích rộng hơn (không cần server đặc biệt nào khác ngoài 2 header COOP/COEP ở trên). Nếu sau này cần threading (đa luồng thật trong WASM), phải bật lại field này VÀ đảm bảo host set đúng header, nếu không trang sẽ load được nhưng game treo/lỗi khi khởi tạo.

**Giới hạn khi verify**: đã build + chạy thử Windows .exe chuẩn (đứng vững qua 90 frame, không crash, render GPU thật). Web export đã verify: file size trong `index.html` khớp đúng `index.pck`/`index.wasm` trên đĩa (không hỏng khi đóng gói), server local trả đúng header. **CHƯA verify được**: thực sự mở trang Web trong trình duyệt và chạy WASM (không có tool điều khiển browser thật trong phiên làm việc này) — bạn cần tự mở bằng trình duyệt để xác nhận game load/chơi được trên Web.

## Cách test/verify (quan trọng — dự án KHÔNG có unit test framework, dùng pattern sau)

Vì không có CI/test framework, mọi thay đổi lớn trong phiên làm việc trước đều verify bằng 3 kỹ thuật, lặp lại khi cần:

1. **Headless parse check**: `godot --headless --import` (rescan, bắt lỗi parse/class-cache) rồi `godot --headless --quit-after 60` (chạy thật `main.tscn` N frame, bắt lỗi runtime khi autoload/scene load).
2. **Test scene tạm**: tạo `scenes/_test_xxx.tscn` + `scripts/_test_xxx_runner.gd` (tiền tố `_test_` để dễ nhận diện/xoá), dùng `GridManager.set_block()` trực tiếp giả lập tình huống, `print()` kết quả so với kỳ vọng, `get_tree().quit()`. XOÁ file này (+ `.uid` đi kèm) ngay sau khi verify xong — không được để sót trong repo.
3. **Screenshot GPU thật**: chạy KHÔNG headless (`godot --position 3000,3000 res://scenes/_test_xxx.tscn` — offset cửa sổ ra ngoài màn hình để đỡ phiền), script tự `get_viewport().get_texture().get_image().save_png(...)` rồi quit. Bắt buộc dùng cách này khi cần verify HÌNH ẢNH (mesh, shader, animation) — headless không có GPU context nên không render thật. Đã từng bắt được bug thật (mesh lộn ngược, dòng nước vô hình trong khối gỗ) chỉ nhờ nhìn ảnh, đọc code không thấy được.

**Bài học rút ra**: ảnh chụp toàn cảnh (camera xa) dễ che giấu lỗi hình học — luôn chụp thêm 1 ảnh cận cảnh 1 khối đơn lẻ khi verify mesh tự dựng.

## Giới hạn đã biết (chưa làm / đơn giản hoá có chủ đích)

- Mặt TRÊN của các khối Nước liền kề: đã hết viền foam nhờ `edge_mask`, nhưng vẫn là các mesh riêng biệt (không greedy-mesh thật thành 1 mặt phẳng lớn) — chấp nhận được vì shader đã che giấu seam thị giác.
- Đom đóm không có chu kỳ ngày/đêm thật (dự án chưa có hệ thống ngày/đêm) — trigger theo mỗi lần Chuông kêu thay vì "chỉ ban đêm".
- Cờ/chong chóng dùng sine sway đơn giản, chưa phải Wind Shader thật.
- Chưa test bằng ảnh thật ngưỡng `cell.y > 5` cho cờ (đã verify qua code/logic, chưa dựng cảnh cao 6+ tầng để chụp).
- Reverb (`default_bus_layout.tres`) và cảm giác thẩm mỹ tổng thể của hình dạng nước đa hướng — cần bạn tự nghe/nhìn thật, ngoài khả năng tự động hoá.
- Export Web/Desktop, Hiệu năng lưới lớn, Save/Load công trình — cả 3 ĐÃ làm (xem PHẦN 12/13/14 `plan.md`). Chưa deploy lên host thật (itch.io/GitHub Pages), chưa có icon riêng cho bản Windows export.
- 1 slot save duy nhất (`user://save_data.json`, đè lên mỗi lần Lưu) — không có multi-slot/named-save. Đủ dùng cho sandbox toy 1 công trình tại 1 thời điểm; nếu cần nhiều slot sau này, đổi tên file theo slot index là đủ, không cần đổi format.
- `WaterFlowManager` vẫn quét toàn bộ khối Nước mỗi lần đổi 1 khối bất kỳ (có chủ đích, không phải sót tối ưu — xem mục 3(b) "Pattern kiến trúc"). Nếu 1 build có hàng chục nghìn khối Nước, đây sẽ là điểm nghẽn tiếp theo cần đo lại.
