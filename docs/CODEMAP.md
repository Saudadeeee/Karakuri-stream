# CODEMAP — Karakuri Stream

Bản đồ codebase để maintain/sửa đổi. Đọc file này trước khi đụng vào code — đặc biệt phần "Quy ước cốt lõi" (sai 1 chỗ là toang cả hệ thống).

Xem `plan.md` cho lịch sử quyết định/bugfix theo từng phiên làm việc. File này chỉ nói **hiện trạng**, không nói **quá trình**.

## Stack

Godot 4.7, GDScript, renderer `gl_compatibility` (bắt buộc — quyết định luôn cả cách viết shader, xem phần Shader bên dưới). Không dùng plugin/addon ngoài.

## Cấu trúc thư mục

```
project.godot           Cấu hình engine + danh sách autoload (thứ tự load quan trọng, xem dưới)
docs/CODEMAP.md         File này
docs/plan.md            Nhật ký thiết kế/bugfix theo phiên — lịch sử, không phải tài liệu tham chiếu

scenes/
  main_menu.tscn        **MAIN SCENE** (khởi động ở đây). `main_menu.gd`: backdrop 3D vườn sống (env+đảo+camera xoay chậm, scenery autoload trang trí) + UI biển gỗ title + nút Chơi/Cài đặt/Thoát + panel volume theo bus. Chơi → main.tscn
  main.tscn             Scene sandbox — camera, ground, PlacementController, UI
  pause_menu.tscn       Instance con trong main.tscn/UI — pause, save/load/xoá, âm lượng, "Về menu chính"
ui/
  karakuri_theme.tres   Theme project-wide (`gui/theme/custom`) — **FILE SINH RA, ĐỪNG SỬA TAY**.
                        Nguồn: `tools/gen_theme.gd` (`godot --headless --path . --script tools/gen_theme.gd`).
                        Sửa tay 200 dòng StyleBox là cách 4 trạng thái button lệch nhau.
                        Button bo góc 20, viền 3, bóng đổ LỆCH và **xẹp khi nhấn** (đó là thứ tạo cảm
                        giác nút lún xuống). 4 state chỉ khác fill/viền/bóng, **content_margin GIỐNG HỆT
                        nhau** — khác margin thì chữ bị reflow và nhảy khi rê chuột qua.
tests/
  regression.tscn       FULL REGRESSION 12 section (mọi type×variant, save/load, undo chains, chuỗi karakuri live, gear 6 trục, pipe shapes, xóa giữa hoạt động, **NHÀ ghép theo ngữ cảnh + gộp mái cả toà nhà**, **wildlife gating**, **save hỏng không được xoá công trình**, 4 theme leak-check, photo/settings). Chạy: `godot --path . tests/regression.tscn` → mong "REGRESS ALL OK" + 0 error. Chạy sau MỌI thay đổi lớn.
  blocks/
    wood_block.tscn      StaticBody3D + CollisionShape3D THUẦN (KHÔNG mesh) — gỗ là 1 occupancy-isosurface gộp, xem VoxelSurfaceManager
    water_block.tscn     StaticBody3D + CollisionShape3D THUẦN (KHÔNG mesh) — nước là 1 occupancy-isosurface gộp, xem VoxelSurfaceManager
    gear_block.tscn      StaticBody3D + con "MeshInstance3D" (pivot rỗng, GearManager xoay) + collision. `gear_block.gd` nạp `generated/gear.glb` vào pivot, `MeshFit.fit_centered` (đường kính ~1.15 → răng tip ~0.57 lồng gear kề). `apply_axis(Vector3i)` orient ROOT theo trục đặt. Driven khi STREAM rơi trúng (xem StreamManager)
    bell_block.tscn      StaticBody3D + collision. `bell_block.gd` nạp `generated/bell.glb`, `fit_bottom`. Visual — kêu khi stream rơi trúng (StreamManager) hoặc gear kề gõ
    source_block.tscn    StaticBody3D + collision. `source_block.gd` nạp `generated/source.glb` (ống tre ĐỨNG CĂN TÂM, miệng đáy-tâm, lá đối xứng ±Z → thẳng hàng ống dưới + stream tâm ô). Model đối xứng nên `face_adjacent_water()` chỉ còn trang trí. StreamManager phun dòng thẳng xuống từ tâm ô
    pipe_block.tscn      Ống tre TỰ NỐI (kín/hở variant, `pipe_block.gd`). `build_visual(dirs,open)`: run THẲNG (2 hướng đối) → 1 tube liền `_add_tube_through` (KHÔNG hub); rẽ/T/thập/xuống/lẻ → hub + 1 stub/hướng (**KÍN=SphereMesh tròn**, **HỞ=box phẳng** lấp góc máng, không dùng cầu tròn). Hở → máng U `_add_trough` (đáy+2 vách). `PipeRouting.connections(cell)`; nghe grid đổi → `refresh_shape()`. `static build_visual` dùng chung ghost. `grid_cell` do Placement/Save set
    house_block.tscn     **NHÀ (Townscaper-style)** — người chơi đặt 1 Ô NHÀ, toà nhà tự lắp. Logic "cái gì mọc ở đâu" nằm HẾT ở `HouseShape` (data class), `house_block.gd` chỉ dựng hình — đúng cặp `PipeRouting`/`pipe_block`. Tường CHỈ mọc ở mặt không có nhà kề (tường chung biến mất → 1 dãy đọc thành MỘT toà nhà dài, không phải 3 cái lều). **Mái KHÔNG phải hình của từng ô** — là 1 TRƯỜNG ĐỘ CAO của cả toà nhà (xem `house_shape.gd`), mỗi ô chỉ dựng miếng vá 3×3 sample của mình; ô lơ lửng mọc **cột chống** hoặc **thanh chống nghiêng** (không được phép lơ lửng); cửa/ống khói mỗi toà nhà đúng 1 cái, lấy theo ô đầu/cuối thứ tự lexicographic của component; ban công ở tầng trên. Tất cả DETERMINISTIC (`HouseShape._h()` hash ô, KHÔNG randf) → reload ra đúng ngôi nhà cũ. Đục 1 ô giữa dãy → 2 đầu tự mọc tường + đầu hồi. Gộp mesh qua `MeshBatch` (xem dưới)
    pipe_bend_block.tscn **Khuỷu tre 90°** (type PIPE_BEND, đang dùng thật). `pipe_bend_block.gd` nạp `generated/pipe_elbow.glb`, `MeshFit.fit_centered`. Nước vào cổng TRÊN (+Y), ra 1 cổng CẠNH; `apply_ports` xoay model quanh Y (model author sẵn cổng {+Y, +X}), phím R lúc đặt để đổi cạnh
    shishi_block.tscn    **Shishi-odoshi** — stream rót → `fill()` 2 tick → LẬT đổ nước tiếp (`add_temp_source`) + "cộc-cốc". Art: `shishi_base.glb` (đá+cột) + `shishi_arm.glb` dưới pivot `_arm` (tip anim)
    drum_block.tscn      **Trống taiko** — stream/gear-vòng gõ → `hit()` "tùm" trầm + squash. Art: `drum.glb` (thùng+da+đinh+chân)
    chime_block.tscn     **Phong linh** — 5 variant = 5 nốt pentatonic (màu theo nốt) → `ring()`. Art: `chime_frame.glb` + `chime_tube.glb` dưới `_swing` (lắc), tube TINT theo nốt + fatten ×1.7
    music_box_block.tscn **Hộp nhạc** — gear kề powered → giai điệu 8 nốt preset. Art: `music_box.glb` (trục nhạc pin lộ), knob quay procedural
    scoop_block.tscn     **Gầu múc** — kề HỒ + gear powered → TẠO dòng mới (`is_scoop_active`). Art: `scoop_mast.glb` + `scoop_wheel.glb` dưới `_wheel` (quay trục Z)

scripts/
  autoload/              19 singleton, load theo đúng thứ tự khai báo trong project.godot
  data/                  class_name thuần data/utility, KHÔNG phải autoload, KHÔNG có scene tree riêng
  player/                Script gắn trực tiếp vào node trong main.tscn (camera, đặt/gỡ khối)
  ui/                    Script UI
  blocks/                Script gắn vào .tscn khối cụ thể (vd gear_block.gd dựng răng bánh răng)

shaders/
  water.gdshader         Spatial shader cho mặt nước occupancy-isosurface gộp (world-space, alpha vừa để thấy đáy, depth_draw_always chống xuyên)
  wood.gdshader          Vân gỗ procedural (world-pos noise) + rim-light — chạy trên occupancy-isosurface gỗ (world-pos nên không cần UV)
  stream.gdshader        Dòng nước rơi (StreamManager)
  cloudsea.gdshader      Biển mây quanh đảo (CloudSea)

  (`metal.gdshader` ĐÃ XOÁ — 0 ref, gear/bell dùng material trong glb. Lấy lại từ git history nếu cần.)

  (scripts/data/iso_surface.gd — `class_name IsoSurface`, thuật toán Surface Nets dựng mesh isosurface cho CẢ gỗ + nước)

assets/
  sounds/                7 file audio, TẤT CẢ đang dùng thật (xem Audio bên dưới). Không giữ file thừa ở đây
  fonts/                 **Fredoka.ttf** (OFL) + `fredoka_chunky.tres` + `OFL.txt`. `gui/theme/custom_font`
                         trỏ vào **.tres CHỨ KHÔNG PHẢI .ttf**: Fredoka là VARIABLE font, Godot nạp nó ở
                         vị trí trục mặc định = **Light** → chữ mảnh như dây, đúng ngược lại lý do chọn nó.
                         `FontVariation` ghim trục weight=600. **Key của `variation_opentype` là OpenType
                         TAG dạng SỐ NGUYÊN, không phải chuỗi `"wght"`** — ghi chuỗi vào .tres thì parse
                         vẫn qua nhưng KHÔNG có tác dụng gì, rất dễ tưởng đã sửa rồi mà vẫn ship bản Light.
                         `tools/gen_theme.gd` sinh file này VÀ đo bề rộng chuỗi light-vs-600 để chứng minh
                         trục đã đổi thật. Cũng là `ThemeDB.fallback_font` → wordmark TextMesh dùng chung.
                         **Wordmark PHẢI toàn chữ HOA** — TextMesh convex-decompose lỗi ở descender chữ
                         thường (`g`,`y`). Đây là giới hạn của TextMesh, không phải của font (Baloo 2 cũ y hệt).
  3DModel/               CHỈ còn `generated/` + `blockbench/` (source authoring). Mọi model legacy tải về đã xoá — in-game 100% dùng `generated/*.glb`
  3DModel/generated/     Bộ asset Blender sinh (`stylekit.py` + `gen_assets.py` + `gen_fix.py`, chạy `blender --background --python`). Theo artstyle.md: chunky+bevel, matte flat, palette hex. **LƯU Ý Z-up**: Blender Z-up → Godot Y-up (glTF đổi (x,y,z)→(x,z,-y)); author "cao" theo Blender Z, wheel phẳng trong Blender X-Y. DÙNG in-game: gear (Gear), bell (Bell), source/pipe_straight/pipe_elbow (Source/Pipe/Pipe_bend), grass_tuft (Decor), lily_pad (Pond), pine_tree/bush/reeds/rock_cluster/lantern/bonsai (SceneryManager)
  3DModel/blockbench/    Source authoring cho pipeline Blockbench→GLB: `*.obj` + `*_cmap.json` + `bb_bridge.py` + README. GLB thành phẩm được copy sang `generated/`, KHÔNG giữ bản trung gian ở đây

default_bus_layout.tres  3 bus: Master (Reverb) ← Music (-10dB) + SFX. Đăng ký trong project.godot [audio]
export_presets.cfg       Cấu hình export Windows Desktop + Web (xem mục Export bên dưới)
build/                   Output export DUY NHẤT — KHÔNG commit (.gitignore), tự tạo lại bằng lệnh export.
                         `build/.gdignore` được commit CÓ CHỦ Ý (`git add -f`): thiếu nó Godot quét lại
                         PNG trong output export thành asset project → import ngược vào .godot/imported →
                         bị nhồi vào lần export sau (vòng lặp phình dung lượng). ĐỪNG xoá file đó
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

**(a) Incremental — chỉ tính lại ô đổi + hàng xóm** (`DecorManager`, `PondDecorManager`):
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

`scripts/data/block_factory.gd` (`class_name BlockFactory`, static) là nơi DUY NHẤT map `BlockData.Type -> PackedScene`. `PlacementController` (đặt tay) và `SaveManager` (tải file) đều gọi `BlockFactory.instantiate(type)` — thêm loại khối mới chỉ sửa `BlockFactory.SCENES_BY_TYPE`, không sửa 2 nơi. (Trước đây có `_make_material_unique` cho Nước; bỏ rồi vì Nước không còn material per-block — nó là isosurface gộp.)

## Autoload (thứ tự load = thứ tự khai báo trong `project.godot`)

| # | Tên | File | Vai trò |
|---|-----|------|---------|
| 1 | `GridManager` | `autoload/grid_manager.gd` | Nguồn sự thật duy nhất của lưới. `set_block`/`remove_block`/`get_block`/`has_block`/`get_neighbors`/`get_all_cells_of_type`. Bắn signal `block_placed(cell)`/`block_removed(cell)`/`grid_cleared` (khi gọi `clear_all()` — xoá 1 lần, KHÔNG lặp `remove_block()` per-cell vì sẽ trigger rescan dây chuyền ở mọi autoload bên dưới). |
| 2 | `AudioManager` | `autoload/audio_manager.gd` | Pool 24 player trên bus **SFX**. `play_wood_pitch`/`play_chime` (ngũ cung `PENTATONIC_RATIOS` + humanization pitch/vol ngẫu nhiên), `play_jelly_bounce` (boing khi đặt jelly / stream chạm jelly), `make_water_loop_player` (tiếng suối, loop), `make_gear_loop_player` (rattle gỗ "kẽo kẹt", loop), `play_ambient_note` (nốt ngũ cung mềm, bus **Music**, cho AmbientMusic). Files thật trong `assets/sounds/`. |
| 2b | `AmbientMusic` | `autoload/ambient_music.gd` | 3 lớp bus Music: (1) bed nhạc CHILL loop (CC0, random 1/2 track, -17dB), (2) lớp MƯA loop — `apply_theme_mix()` tween vol theo MAP (Thu -18 / Đêm -24 / Xuân -28 / Tuyết -44), (3) nốt ngũ cung GENERATIVE mỗi 2.2–5.5s. **Bus chain**: Master[HardLimiter] ← Music[-10, LowPass 900Hz bật khi PAUSE] + SFX[Compressor→Reverb — reverb CHỈ SFX, bed khô]. AudioManager dedupe 35ms wood knocks (anti machine-gun, chime miễn — hợp âm); StreamManager stagger impacts 0-120ms (humanize). |
| 3 | `WaterFlowManager` | `autoload/water_flow_manager.gd` | Flow CỤC BỘ (PHẦN 26): khối WATER lan sang ô lân cận + tiếng nước loop + waterfall ở rìa, caps NHỎ (`MAX_FALL=40, MAX_POOL=18`) → KHÔNG flood cả đảo. Spill source = mọi ô nước hở đỉnh (kể cả y=0 → lan ngang tới hàng xóm). Dòng đường-xa CHỦ ĐÍCH = StreamManager. `_active_flows` cấp cho VoxelSurface render. |
| 4 | `StreamManager` | `autoload/stream_manager.gd` | **CƠ CHẾ CHÍNH (karakuri)**: mỗi khối SOURCE phun dòng thẳng xuống; trace ô-theo-ô: qua PIPE/PIPE_BEND thì vào 1 port ra port kia (đọc `state["ports"]`), else rơi theo trọng lực tới khi trúng khối. `_trace()` gom `_segments` (dựng cylinder nước cyan) + `_impacts` (ô đích) + `_driven_gears`. Ô đích phát âm theo loại (gỗ/pipe→wood_hit, bell→chime+firefly, gear→clack+quay) mỗi `IMPACT_INTERVAL=0.55s` + splash. Rebuild throttled khi lưới đổi. |
| 5 | `VoxelSurfaceManager` | `autoload/voxel_surface_manager.gd` | Dựng CẢ Gỗ + Nước thành isosurface gộp mịn — 2 `MeshInstance3D` riêng (wood/water), mỗi loại 1 material. Trường mật độ là **"union of rounded boxes" (KHÔNG phải metaball điểm)**: mỗi ô LẤP ĐẦY cube của nó, bo góc bán kính `ROUND_R`, các ô CỘNG lại (`d += min(ax,ay,az)`) nên ô kề fuse thành 1 khối liền (mặt phẳng chỗ dày, bo ở cạnh lộ) — đổ đầy ô như vật liệu thật, KHÔNG phình "bong bóng" như metaball. Gộp: Gỗ = ô WOOD; Nước = ô WATER + `WaterFlowManager._active_flows`. Rebuild throttled (`REBUILD_INTERVAL` 0.05s), chỉ loại bị đổi. `SAMPLES_PER_CELL=3`, `ISO=0.5`. Dùng `IsoSurface.build` (Surface Nets). |
| 6 | `DecorManager` | `autoload/decor_manager.gd` | 2 rule độc lập trên Gỗ: (a) cạnh Nước liên tục 10s → mọc **cụm cỏ** (model `grass_tuft.glb` + blob rêu gốc, grow tween, **đung đưa gió** qua `_grass_data` trong `_process`); (b) `cell.y > 5` → gắn cờ đung đưa. |
| 7 | `PondDecorManager` | `autoload/pond_decor_manager.gd` | Nước có đủ 4 hàng xóm ngang bị chiếm → **lá sen** (model `lily_pad.glb`, bob `y=0.62` trên mặt opaque) + cá Koi (bơi vòng `swim_y=0.56` mặt nước, lưng nhô, có đuôi). Spawn thưa (lily 0.45 / koi 0.55 mỗi ô). |
| 8 | `FireflyManager` | `autoload/firefly_manager.gd` | `burst_at(pos)` — chớp hạt sáng 1 lần, gọi từ `GearManager`/`StreamManager` mỗi khi Chuông kêu. |
| 9 | `GearManager` | `autoload/gear_manager.gd` | **Hệ truyền động**: mỗi frame dựng đồ thị liên thông Gear (6 hướng); 1 component quay nếu CÓ gear là driver. `_is_driver` = gear bị **STREAM rơi trúng** (`StreamManager._driven_gears`) HOẶC kề khối Nước tĩnh. Chiều quay = parity `(x+y+z)` → gear kề nhau tự quay NGƯỢC chiều (lưới bipartite). Răng ĂN KHỚP: gear parity lẻ lệch pha `HALF_TOOTH=TAU/20` (răng khớp vào khe, không đụng răng-răng), set 1 lần qua `_phased`. Xoay bằng `mesh_instance.rotate_y` — vì gear_block đã orient ROOT theo trục đặt (xem dưới), trục local-Y của mesh = trục đặt, nên quay quanh đúng trục. Bụi lấp lánh + gõ Chuông kề bên mỗi vòng. |
| 10b | `UndoManager` | `autoload/undo_manager.gd` | Undo/redo đặt-xóa khối (stack 200). Placement record place/remove (type+variant+axis); Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z); undo remove RESTORE đủ (đường recreate như SaveManager). |
| 10 | `SaveManager` | `autoload/save_manager.gd` | `save_game()`/`load_game()`/`has_save()`. KHÔNG `_ready()` nghe signal, và KHÔNG bắn signal — 3 hàm gọi từ `pause_menu.gd`, nó tự hiện toast. (`signal saved`/`signal loaded` đã XOÁ: emit nhưng không ai connect. Cần thì thêm lại kèm listener thật.) Lưu thêm `axis` cho Gear + `ports` cho Pipe/Pipe_bend (`{x,y,z,type,axis?,ports?}`; save cũ thiếu → mặc định). Xem mục Save/Load. |
| 11 | `AmbientLeaves` | `autoload/ambient_leaves.gd` | Thuần trang trí — lá phong cam rơi lơ lửng lúc khởi động, cast_shadow OFF. |
| 12 | `SceneryManager` | `autoload/scenery_manager.gd` | `rebuild()` rải prop quanh rìa THEO MAP THEME (`MapThemes`): thông/bụi/lau/đá/đèn/bonsai + slot "feature" (sakura/maple/pine tuyết); lá recolor `MeshFit.recolor_foliage`; ring 8 núi backdrop nhận `mountain_tint`; lantern GLB nằm ngang → heuristic AABB dựng đứng (xoay ở CON, fit qua wrapper). Gọi lại khi menu đổi theme. Thuần backdrop. |
| 12b | `AmbientLeaves` | `autoload/ambient_leaves.gd` | Hạt drift THEO THEME (`rebuild()`): cánh sakura hồng / lá phong cam / bông tuyết / đom đóm vàng (bay LÊN + emissive ăn bloom). |
| 13 | `WildlifeManager` | `autoload/wildlife_manager.gd` | **Động vật đọc thế giới**, không chỉ đi lang thang. Mỗi loài bị GATE bởi thứ người chơi XÂY, và làm ngược lại điều gì đó — liên kết 2 chiều đó mới là trọng tâm, thiếu nó chỉ là trang trí biết nhúc nhích. **Chim**: cần ≥1 NHÀ; đậu trên mái, và khi đậu trúng BELL/CHIME/DRUM thì **GÕ THẬT** (gọi `ring()`/`hit()`) → vườn có thêm 1 nhạc công bạn không lập trình; đặt khối gần → bay tán loạn (`scatter_near`). **Mèo**: cần ≥2 nhà; đi trên mặt trên, **không bao giờ bước xuống nước** (nước không nằm trong `_walkable`, nên nó không thể "quyết định" bơi); đêm thì ra ngồi cạnh đèn đá; `look_near()` cho nó quay đầu nhìn chỗ vừa click. **Vịt**: cần hồ ≥3 ô nước hở; bơi vòng, rúc đầu kiếm ăn → `_spawn_splash`. **Hươu**: CHỈ ra khi máy IM LẶNG >12s, biến mất ngay khi có dòng chảy → tắt máy mới thấy được. Quét lưới 1 lần, dirty-flag + throttle 0.4s (như `VoxelSurfaceManager`); sĩ số có trần và **trần giảm nửa trên web LITE** qua `QualityManager.lite`. |
| 12d | — | **MÀU TỔNG THỂ (colour grade)** | `MapThemes.apply_grade(env)` là **NƠI DUY NHẤT** set tonemap/glow/adjustment. Trước đây menu tự dựng env với thông số khác main.tscn → 2 màn hình khác màu, bấm Play là ảnh nhảy. **Giá trị baked trong `main.tscn` giờ chỉ là preview trong editor — runtime bị `apply_environment()` ghi đè.** Đã sửa cảnh bạc màu: `glow_bloom 0.15` là thủ phạm chính (bloom thấp thế bắt đầu rỉ từ MID-TONE, mà palette pastel thì gần như mọi thứ đều là mid-tone sáng → pass glow bôi trắng cả khung hình); cộng ambient 0.45 + sun 0.9 + fill 0.22 vượt 1.0 nên albedo nhạt clip trước khi tonemap kịp xử lý; FILMIC lại nhả highlight kèm mất bão hoà. Fix: `glow_bloom=0`, `glow_hdr_threshold=1.05` (CHỈ thứ thật sự quá sáng mới glow — đèn lồng/cửa sổ đêm vẫn glow), ambient ×0.62 mọi theme, đổi sang **AGX** (giữ hue/saturation vào vùng sáng tốt hơn FILMIC nhiều), contrast 1.12 / saturation 1.34. **Đổi 1 trong các số này thì phải chụp lại CẢ 4 theme** — Đêm và Tuyết hỏng theo 2 hướng ngược nhau. |
| 12c | — | `data/map_themes.gd` | `MapThemes` registry 4 map theme (Xuân/Thu/Tuyết/Đêm): sky/fog/sun/island/mountain_tint/foliage/drift. `current` persist settings.cfg `[map] theme`. `apply_environment(env, sun)` dùng chung menu + `main_scene.gd` (script root main.tscn — repaint env + 2 material đảo lúc vào game). Picker = 4 card màu trời ở main menu. |

**Quan trọng khi thêm autoload mới**: đăng ký trong `project.godot` [autoload] — nếu autoload mới cần đọc `GridManager`/`AudioManager`/`WaterFlowManager` trong `_ready()`, đặt SAU chúng trong danh sách (autoload load tuần tự theo thứ tự khai báo). `VoxelSurfaceManager` đặt SAU `WaterFlowManager` vì đọc `_active_flows` của nó.

**Quan trọng khi autoload mới tự giữ Dictionary theo cell** (như `_active_flows`, `_ponds`, `_sparkles`): PHẢI connect thêm `GridManager.grid_cleared` để dọn dict + free node khi user bấm "Xoá toàn bộ" (`PauseMenu`). Nếu node được tạo là con của CHÍNH autoload đó (không phải con của `block.node`) thì `GridManager.clear_all()` không tự free được — phải tự `queue_free()` trong handler `grid_cleared` của autoload đó (xem `WaterFlowManager`/`PondDecorManager`). Nếu chỉ giữ dict tham chiếu tới node vốn đã là con của `block.node` (như moss/flag trong `DecorManager`, sparkle trong `GearManager`) thì node tự bị free theo khối, chỉ cần `.clear()` dict cho sạch — không leak node thật, chỉ leak entry dict nếu bỏ qua bước này. `GearManager` còn cần connect cả `block_removed` (không chỉ `grid_cleared`) vì nó gỡ từng khối lẻ thường xuyên hơn xoá toàn bộ.

## `scripts/data/` — utility thuần, không phải autoload

- **`block_data.gd`** — struct, xem trên. `state: Dictionary` chứa dữ liệu per-khối (vd `state["axis"]` cho Gear = trục đặt Vector3i).
- **`pipe_routing.gd`** (`class_name PipeRouting`) — `static ports_for(cell)`: 2 đầu mở của ống từ hàng xóm (PIPE/SOURCE) theo 6 hướng, kiểu ray Minecraft (0 hàng xóm→dọc; 1→nối nó + đầu kia xuống; 2+→ưu tiên feed từ trên + đầu ra kế). Nguồn logic CHUNG cho `pipe_block` (visual) + `StreamManager` (routing).
- **`mesh_fit.gd`** (`class_name MeshFit`) — `fit_centered(model, target)` / `fit_bottom(model, height, floor_y)` + `local_aabb(root)` + `matte(root)` + **`flat(col)`**. Scale/đặt lại model art nhập cho vừa ô; `matte()` duplicate mọi StandardMaterial của model → ép `metallic=0, metallic_specular=0, roughness=1` (glTF import mặc định specular 0.5 làm bề mặt mượt bị chói/cháy trắng — vd chuông đá thành trắng). Gear/Bell/lily/grass đều route qua fit + matte.
  **`MeshFit.flat(col)`** = bản cho geometry TỰ DỰNG BẰNG CODE: tạo StandardMaterial3D `albedo=col, roughness=1, metallic=0`. NƠI DUY NHẤT dựng material phẳng từ màu — trước đây 8 file mỗi file 1 bản y hệt (`_mat`/`_flat`/`_matte` + 2 chỗ viết inline), look dễ lệch. Cần material phẳng → gọi hàm này, ĐỪNG viết `StandardMaterial3D.new()` mới. CỐ Ý không set `metallic_specular` (roughness 1.0 đã dập highlight; giữ đúng hành vi 8 bản gốc → không đổi hình).
  **Ngoại lệ hợp lệ**, KHÔNG dùng `flat()`: `main_menu._flat3` (unshaded cho chữ 3D), `gear_mesh.material()` (vertex-color), particle/billboard/transparent material (placement_controller, water_flow, firefly, stream…) — chúng cần cờ khác.
- **`iso_surface.gd`** (`class_name IsoSurface`) — `static func build(samples, dims, cell_size, iso) -> ArrayMesh`. Thuật toán Surface Nets (chọn thay Marching Cubes để khỏi bảng 256-entry, cho mặt blob mượt). Thuần toán, không phụ thuộc scene. Dùng bởi `VoxelSurfaceManager` để gộp CẢ gỗ + nước thành mặt liền. Density convention: "inside" khi value > iso. Sau khi dựng tam giác → `_smooth()` chạy **Taubin** (`SMOOTH_PASSES=2` × 2 bước: co +λ0.5 rồi phồng -μ0.53) dẹp scallop mà KHÔNG co thể tích — Laplacian thuần trước đây co mesh làm hở/xuyên mối nối. `VoxelSurfaceManager` dùng `ROUND_R=0.26`, `ISO=0.42` (<0.5 để phồng nhẹ, bắc cầu ô kề CHÉO → bậc thang merge liền, không hở).
- **`house_shape.gd`** (`class_name HouseShape`) — TOÀN BỘ luật kiến trúc của nhà, tách khỏi phần dựng hình.
  **TƯỜNG** thì per-cell, tầm thường: mặt nào có nhà kề thì không mọc tường.
  **MÁI mới là chỗ khó, và là lý do file này có hình dạng như vậy.** Cách hiển nhiên — mỗi ô trên cùng 1 cái mái nhỏ — SAI ngay khi toà nhà rộng hơn 1 ô: 2×2 ra 2 mái song song, 3×3 ra 3 mái, hình L ra 2 cánh có sống mái đâm nhau không máng xối. Đọc thành dãy lều, không phải nhà. (Đã đo thật trước khi sửa.)
  Nên mái KHÔNG phải hình của ô. Nó là **TRƯỜNG ĐỘ CAO** lấy mẫu trên lưới NỬA Ô, độ cao = mẫu đó nằm sâu bao nhiêu trong footprint mái — tức **distance transform**, họ hàng rời rạc của straight skeleton. Mọi dạng mái rơi ra từ MỘT luật, không case đặc biệt:
  rộng 1 ô → chỉ đường tâm là interior → **sống mái (gable)**; rộng 2 ô → chỉ đường ghép là interior → **1 sống mái giữa**; 3×3 → tâm đạt độ sâu 2 → **mái chóp/hip**; hình L → góc trong sâu, khe không sâu → **máng xối tự có**; mọi đầu hồi → độ sâu tắt dần → **hip tự có**.
  Ô kề nhau lấy mẫu ĐÚNG CÙNG các điểm chung → mỗi ô tự dựng miếng vá của mình mà vẫn khớp liền, không cần ô nào nói chuyện với ô nào. `ROOF_LEVELS=2`.
  **TRỤC DỌC (3D)** — `support_drop(cell)` đếm số ô KHÔNG KHÍ dưới ô này trước khi chạm vật rắn (bất kỳ khối nào, không riêng nhà) hoặc mặt đảo y=0; 0 = đang tựa lên cái gì đó. Ô lơ lửng có 2 xử lý KHÁC NHAU, đổi chỗ là nhìn sai ngay:
  • **lơ lửng + không có nhà kề nào đứng vững → CỘT CHỐNG** (`_build_stilts`) thả xuống tới vật rắn đầu tiên. Góc chung được `owns_corner()` khử trùng: 4 ô của sàn 2×2 chung góc → **9 cột** (lưới góc 3×3), không phải 16 cột chồng lên nhau cùng lỗ. `MAX_STILT=16` chặn nhà thả ở y=200 mọc trụ 200 ô.
  • **lơ lửng + có nhà kề đứng vững → THANH CHỐNG NGHIÊNG** (`_build_corbels`, `is_overhang`/`corbel_sides`): tầng nhô ra là dầm hẫng, phải chống chéo ngược vào bức tường nó mọc ra, KHÔNG phải cắm cột xuống đất.
  `has_above` → **đai tầng** ở đỉnh tường: thiếu nó thì tháp 4 tầng đọc thành 1 cái hộp cao.
  **CỬA/ỐNG KHÓI cần điều ngược lại với tính cục bộ**: đúng 1 cái mỗi toà nhà, bất kể hình dạng. Nên `_component()` flood-fill toà nhà (3D, để tháp + tầng trệt là một), **cache theo `GridManager.version`** — mọi ô của một toà nhà đều rebuild trong cùng 1 lần đổi lưới nên chúng dùng chung 1 lần flood. Cửa = ô nhỏ nhất theo thứ tự lexicographic (y trước → luôn ở tầng thấp nhất), ống khói = ô lớn nhất. Luật "góc gần/góc xa" cũ cho **2 cửa** trên hình chữ thập.
  **DETERMINISTIC tuyệt đối**: `_h(cell, salt)` hash toạ độ ô, KHÔNG dùng `randf()` — thay bằng randf thì mỗi lần rebuild/reload cả khu phố tự sắp xếp lại cửa sổ. `lone_context()` = nhà đứng một mình, dùng cho icon hotbar + ghost (chúng chưa có ô trong lưới, không có nó sẽ đọc nhầm thứ nằm ở (0,0,0)).
- **`mesh_batch.gd`** (`class_name MeshBatch`) — gom nhiều hộp nhỏ thành MỘT `ArrayMesh`, 1 surface / 1 MÀU. **Lý do tồn tại**: 1 ô nhà là ~37 mảnh rời (tường, khung cửa sổ, kính, chậu hoa, cửa, bậc, mái, sống mái, ống khói). Để rời = ~37 draw call MỖI Ô → làng 20 nhà là 700+ draw call, và ĐÓ mới là con số giết hiệu năng trên gl_compatibility/web, chứ không phải số tam giác. Gom theo màu còn **3.9 draw call/ô** (đo thật: làng 12 ô = 47 draw call, 2090 tri). Hệ quả thiết kế: **thêm màu = thêm draw call** — 3 sắc `darkened()` gần giống nhau đã được gộp làm 1 (`_dark()`) vì mắt không phân biệt được ở khoảng cách chơi. Normal phẳng/tam giác, khớp art style.
- **`tools/shoot.gd`** (KHÔNG export, `tools/*` nằm trong exclude_filter) — boot 1 scene bằng renderer THẬT, đợi ổn định rồi lưu PNG. Headless dùng dummy driver, KHÔNG render gì cả → không có file này thì không cách nào nhìn thấy game từ script, và mọi lỗi hình trong đợt này (đặc biệt là font bị nạp bản Light) đều vô hình cho tới khi có ai đó render 1 frame rồi NHÌN. Có `crop=x,y,w,h` (phóng 3× để soi UI nhỏ), `build` (dựng sẵn 1 xóm mẫu), `theme=N` (đi qua settings.cfg vì `main_scene._ready()` gọi `load_current()` ghi đè, và trả lại giá trị cũ sau khi chụp).
  `godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/shoot.tscn -- scene=... out=... build crop=...`
- **`cute_button.gd`** (`class_name CuteButton`, static) — biến Button thường thành thứ bấm vào thấy đàn hồi: hover phồng + nghiêng, nhấn thì BẸT ra và lún, thả thì nảy quá đà rồi mới về (`TRANS_BACK` — bật thẳng về 1.0 là mất hết cảm giác đồ chơi). `apply_all(root)` quét cả cây, `wire(b, quiet_hover)` cho từng cái.
  **CHỈ ĐỘNG VÀO `scale`/`rotation`, TUYỆT ĐỐI KHÔNG `position`/`size`** — nút nằm trong `VBoxContainer`, mà container ghi đè position/size mỗi lần layout → animate 2 thứ đó là đánh nhau với container và giật. `pivot_offset` phải bám theo size (nối `resized`), không thì nút phóng từ góc trên-trái và trượt ngang.
  `quiet_hover=true` cho hotbar: rê chuột qua 16 icon mà kêu 16 tiếng thì hết dễ thương ngay.
- **`critter_mesh.gd`** (`class_name CritterMesh`) — chim/mèo/vịt/hươu dựng bằng code (cầu + hộp, flat matte) thay vì .glb: tint được theo map theme, ~vài trăm tri mỗi con. Quy ước MỌI con: **+X là HƯỚNG TRƯỚC (đầu)**, gốc toạ độ nằm SÁT ĐẤT giữa 2 chân → `WildlifeManager` chỉ việc quay +X theo hướng đi và thả gốc lên mặt, không cần offset riêng từng loài.
- **`block_factory.gd`** (`class_name BlockFactory`) — xem mục 5 "Quy ước cốt lõi". Dùng chung bởi `PlacementController` và `SaveManager`.

## `scripts/player/` — input & tương tác

- **`orbit_camera.gd`** (gắn `OrbitRig` trong main.tscn) — xoay bằng kéo chuột giữa, zoom bằng lăn chuột, điều khiển qua `SpringArm3D` con. `SpringArm3D.collision_mask = 0` (tắt tự né vật cản — nếu bật lại sẽ bị bug "camera dính zoom" khi khối cản tia dò của spring arm, đã từng gặp).
- **`placement_controller.gd`** (gắn `PlacementController` trong main.tscn) — raycast chuột → `GridManager.world_to_cell`/`cell_to_world` → ghost block preview → đặt/gỡ khối. Tạo node khối qua `BlockFactory.instantiate(type)`. Khi khối CHẠM đất (tween callback) spawn `_spawn_place_effect(type)`: Gỗ→bụi đất, Nước→tia bắn, Gear/Bell→tia kim loại — CHỈ ở đặt-tay, KHÔNG ở `SaveManager.load` (tránh nổ particle hàng loạt). Phím `1`/`2`/`3`/`4` chọn vật liệu (signal `material_changed`).

## `scripts/ui/`

- **`material_ui.gd`** (gắn `UI/MaterialPicker` trong main.tscn — 1 `Control` rỗng, TẤT CẢ node con dựng bằng code trong `_ready()`, KHÔNG khai báo trong .tscn) — dải dọc mép TRÁI màn hình, 4 icon. Mỗi icon là 1 `Button` chứa `SubViewportContainer` → `SubViewport` (own_world_3d, transparent_bg) render CHÍNH mesh khối thật (`BlockFactory.instantiate(type)`) + 2 `DirectionalLight3D` (key/fill) + `Camera3D`, khối tự xoay chậm trong `_process`. **PERF**: viewport mặc định `UPDATE_ONCE` (đóng băng frame đầu) — chỉ icon ĐANG CHỌN/hover `UPDATE_ALWAYS` + quay (`_refresh_viewport_modes`); fade mờ → đóng băng hết (7 world 3D re-render mỗi frame quá nặng cho web/mobile). Không có sprite/art vẽ tay — đổi look khối là icon đổi theo. Auto-fade: `_process` đọc `get_viewport().get_mouse_position().x`, chuột gần mép trái (`< REVEAL_ZONE`) → `modulate.a` lerp về 1.0, xa → về `FADE_MIN_ALPHA` (0.18, mờ chứ không ẩn hẳn để vẫn bấm được). Phím `1-4` vẫn chọn vật liệu như cũ (xử lý ở `placement_controller`), UI đồng bộ qua signal `material_changed`.
- **`pause_menu.gd`** (gắn root `Control` của `scenes/pause_menu.tscn`, instance trong `main.tscn` UI CanvasLayer) — `process_mode = PROCESS_MODE_ALWAYS` (bắt buộc, nếu không sẽ tự đóng băng theo `paused` và không bao giờ resume được). Toggle bằng phím `ui_cancel` (ESC, action mặc định của Godot) HOẶC nút "⏸" góc trên-phải (`UI/PauseButton`, nối qua `[connection]` trong `main.tscn`, không qua script — không cần thêm script mới chỉ để nối 1 signal). `toggle()` set `visible` + `get_tree().paused`; mọi node khác dùng `process_mode` mặc định (`INHERIT`) nên tự dừng animate khi pause (Gear ngừng quay, nước ngừng cuộn), không cần sửa gì thêm.
  - Nút "💾 Lưu" → `SaveManager.save_game()`. Nút "📂 Tải" → `ConfirmationDialog` (cảnh báo mất công trình hiện tại chưa lưu) → `SaveManager.load_game()`. Nút "🗑️ Xoá toàn bộ" → `ConfirmationDialog` riêng → `GridManager.clear_all()`. Cả 3 thao tác đều có `StatusLabel` fade-in/out báo kết quả (`_show_status()`).
  - Slider âm lượng ghi/đọc `user://settings.cfg` qua `ConfigFile` — **khác hoàn toàn** `SaveManager` (setting cá nhân vs. dữ liệu gameplay, xem mục Save/Load bên dưới, đừng nhầm lẫn 2 cơ chế lưu này).

## Shader — `shaders/water.gdshader`

Áp cho 1 mesh DUY NHẤT: isosurface nước gộp do `VoxelSurfaceManager` dựng. **Hoàn toàn world-space** — isosurface không có UV/mặt-ô đáng tin, nên foam/sóng/caustic/sparkle/fresnel đều key theo world position + surface normal. `edge_mask`/`v_is_top`/`flow_dir` của bản per-block cũ ĐÃ BỎ (mặt isosurface vốn liền, không có seam nội bộ). Alpha để VỪA (water_color ~0.6, deep_color ~0.8) để thấy đáy/đất qua 1 vách nước; `depth_draw_always` để vách gần ghi depth che vách xa (không nhìn xuyên sang mặt bên kia của vũng vòng).

- Sóng: đội đỉnh theo `layered_waves(world.xz)` chỉ phần mặt hướng lên (`world_normal.y>0`) để cạnh bên không rung.
- Foam: gom theo fresnel rim + đỉnh sóng (giữ nhẹ `foam_amount`~0.28 để thân vẫn teal, không trắng đục trên mặt mỏng).
- `deep_color`: gradient độ-sâu-giả theo fresnel. Caustic/sparkle world-space (emissive → bloom bắt).

- **`depth_draw_always` trong render_mode** (BẮT BUỘC giữ): nước trong suốt vẫn ghi depth → vũng dạng vòng, vách gần che vách xa, KHÔNG nhìn xuyên (X-ray). Bỏ đi là bug "nhìn xuyên nước" quay lại. Opacity cao (water_color.a ~0.9) để vách đủ đục.

**Ràng buộc cứng**: KHÔNG dùng `SCREEN_TEXTURE`/`DEPTH_TEXTURE` — `gl_compatibility` không hỗ trợ đọc screen/depth texture trong spatial shader. Mọi hiệu ứng dựa world-pos/normal/uniform, không depth buffer.

## Art direction — "Floating Diorama" (Wabi-sabi)

Hướng nghệ thuật: đảo nổi trong không gian vô cực kiểu Townscaper/Ghibli, bảng màu mộc mạc bão hoà vừa. Tất cả bằng mesh nguyên thuỷ Godot + shader + particle — KHÔNG có sprite/texture vẽ tay (không phụ thuộc công cụ ngoài).

- **Bầu trời**: `main.tscn` WorldEnvironment dùng `ProceduralSkyMaterial` (built-in), gradient xanh ngọc (đỉnh) → hồng pastel (chân trời/hoàng hôn). Ambient dùng màu CỐ ĐỊNH (`ambient_light_source = COLOR`, energy ~0.45), **KHÔNG** dùng `ambient_light_source = SKY` — đã thử, bầu trời hồng quá sáng làm cháy trắng toàn cảnh (over-expose). Đừng đổi lại SKY hay bật tonemap Filmic mà không kiểm tra lại phơi sáng bằng ảnh thật.
- **Đảo**: node `Ground` = 2 `CylinderMesh` (đĩa mặt trên mỏng + côn cụt thân dưới thu nhỏ) cho cảm giác đảo lơ lửng. Mặt trên vẫn đúng world y=0 (collision box giữ nguyên cho raycast đặt khối) — chỉ đổi visual, không đụng quy ước lưới.
- **Bảng màu + bề mặt chi tiết**: Gỗ dùng `wood.gdshader` (vân procedural world-pos + rim-light) trên occupancy-isosurface gộp; Nước qua `water.gdshader` (1 material trên isosurface gộp). Màu Gỗ/Nước là hằng trong `map_themes.gd`/shader (gốc lấy từ model art legacy `wooden-foundation-block.mtl` / `teal-water-block.mtl` — các model đó ĐÃ XOÁ, màu đã hardcode nên không phụ thuộc nữa). Cả Gỗ + Nước dựng bởi `VoxelSurfaceManager`. Gear/Bell dùng material trong `generated/gear.glb` / `generated/bell.glb`. Lá phong cam (`AmbientLeaves`).
- **Mesh chi tiết (không phải primitive trơn)**: Gear = hub cylinder + 10 răng box dựng bằng `scripts/blocks/gear_block.gd` (răng là con của MeshInstance3D nên quay cùng khi GearManager xoay). Bell = nón cụt + quai (torus) + đỉnh (sphere) + quả lắc, author trong `bell_block.tscn`. Koi = model Blockbench `generated/koi.glb` (thân box thon trắng + đốm đỏ Kohaku + vây đuôi/lưng/ngực + mắt đen; `_add_koi` fit theo CHIỀU DÀI, `_process` xoay đầu +X theo hướng bơi), lá sen có khía + đôi khi hoa súng hồng, rêu là cụm 4-6 blob nhiều sắc xanh — tất cả trong `pond_decor_manager.gd`/`decor_manager.gd`.
- **Post-processing (`main.tscn` Environment)**: glow/bloom (bắt sáng foam/sparkle/emissive — `glow_hdr_threshold=1.0` để chỉ vùng thật sáng mới bloom, tránh cháy trắng), fog mật độ thấp cho không khí xa, adjustment color-grade (saturation 1.15). Đều chạy trên `gl_compatibility` (glow/fog/adjustment được hỗ trợ; SSAO/SSR/SDFGI thì KHÔNG).
- **Squash & stretch**: `placement_controller._animate_drop` — lún sâu (y 0.55) rồi nảy `TRANS_ELASTIC` cho cảm giác thạch dẻo.
- **AO & soft shadow — HÀNG GIẢ, ghi rõ để không nhầm**: renderer `gl_compatibility` KHÔNG có SSAO/SSIL/SDFGI thật (chỉ Forward+ mới có). "Đổ bóng mềm" hiện làm bằng `DirectionalLight3D.shadow_blur` + PSSM 4-split, KHÔNG phải AO thật. "AO góc kẹt" giữa 2 khối chỉ có gián tiếp nhờ merge system ẩn mặt trong (khe hở tự tối). Rim-light trong `wood`/`metal` shader cũng là mẹo làm cạnh khối "nổi" mềm, KHÔNG phải bevel/AO thật. Muốn AO/soft-shadow thật phải đổi sang Forward+ — nhưng thế thì mất khả năng export Web/Mobile nhẹ (đánh đổi đã chọn từ đầu dự án).
- **Particle cast_shadow OFF cho fluff**: lá phong (`AmbientLeaves`) tắt đổ bóng — billboard nhỏ đổ bóng sẽ rải đốm tối khắp đảo (đã dính, đã sửa). Khi thêm particle trang trí mới nhớ tắt shadow nếu không muốn đốm bóng.

## Vòng đời đặt 1 khối (đọc để hiểu data flow tổng thể)

1. `PlacementController._place_block()` — raycast, xác định `_ghost_cell`, tạo node qua `BlockFactory.instantiate(type)`, tween rơi+nảy, gọi `GridManager.set_block(cell, BlockData.new(...))`
2. `GridManager.set_block()` lưu vào `_blocks`, bắn `block_placed(cell)`
3. Tất cả autoload đã `connect()` vào signal này chạy `_refresh()` gần như đồng thời trong cùng frame: `VoxelSurfaceManager` đánh dấu dirty để rebuild mặt Gỗ/Nước (throttled); `WaterFlowManager` tính lại toàn bộ BFS; `DecorManager`/`PondDecorManager` quét lại điều kiện rêu/hoa súng/cờ; `GearManager` sẽ thấy trạng thái mới ở `_process` frame kế tiếp (không nghe signal trực tiếp, tự poll `is_powered` mỗi frame vì cần animate liên tục dù không có gì thay đổi ở lưới)

## Save/Load (`scripts/autoload/save_manager.gd`)

Lưu **toàn bộ dữ liệu gameplay** (vị trí + loại từng khối) — khác hoàn toàn setting âm lượng (`user://settings.cfg` qua `ConfigFile`, xem `pause_menu.gd`). 2 file riêng biệt, đừng gộp.

- Định dạng: JSON array tại `user://save_data.json`, mỗi phần tử `{"x":int,"y":int,"z":int,"type":int}` (`type` là giá trị số của `BlockData.Type`). Gear thêm `"axis":[ax,ay,az]` (trục đặt); khi load, entry có axis + type GEAR → set `block.state["axis"]` + gọi `instance.apply_axis()`. Save cũ thiếu `axis` → gear nằm ngang mặc định (+Y) — backward-compatible.
- `save_game()`: `GridManager.get_all_cells()` (KHÔNG lọc theo type — quét toàn bộ `_blocks`, chấp nhận được vì chỉ chạy lúc bấm Lưu, không phải mỗi frame) → serialize → ghi file.
- `load_game()`: đọc file → `GridManager.clear_all()` (xoá sạch lưới hiện tại trước, không merge với build cũ) → với mỗi entry: `BlockFactory.instantiate(type)` → add làm con của `get_tree().current_scene` (KHÔNG phải con của `SaveManager` — `SaveManager` là autoload, cha của nó là `/root`, không phải "Main") → `GridManager.set_block(...)`. Trả `false` nếu file không tồn tại hoặc JSON hỏng (`data == null` hoặc không phải `Array`) — gọi ở nơi khác PHẢI check giá trị trả về, đừng giả định luôn thành công.
- **Decor tự regenerate, không cần lưu riêng**: rêu/hoa súng/cá/cờ/sparkle KHÔNG nằm trong file save — vì `load_game()` gọi `GridManager.set_block()` y hệt lúc đặt tay, mọi autoload phản ứng signal (`DecorManager`, `PondDecorManager`, `GearManager`...) tự tính lại từ đầu theo đúng rule của chúng. Đây là lợi ích trực tiếp của kiến trúc reactive — đừng thêm state decor vào file save, sẽ chỉ làm phức tạp hoá và có nguy cơ lệch dữ liệu.
- Verify bằng test thật: dựng cấu trúc đa dạng (cột nước chảy, pond, gear+bell) → save → `clear_all()` → load → so khớp CHÍNH XÁC từng cell+type với trước đó, xác nhận pond/gear tự regenerate đúng sau khi load, xác nhận `load_game()` trả `false` sạch (không crash) khi không có file.

## Cách thêm 1 loại khối mới (checklist)

1. Thêm vào `BlockData.Type` enum (`scripts/data/block_data.gd`)
2. Tạo `scenes/blocks/xxx_block.tscn`: `StaticBody3D` root + `MeshInstance3D` (con tên đúng `"MeshInstance3D"` nếu cần GearManager/animation lookup) + `CollisionShape3D` (BoxShape3D 1x1x1 để raycast đặt/gỡ nhất quán). Khối render bằng isosurface gộp (kiểu Gỗ/Nước) thì KHÔNG có mesh — chỉ CollisionShape.
3. Nếu khối muốn merge liền kiểu Gỗ/Nước (occupancy-isosurface): thêm loại vào `VoxelSurfaceManager` (một cặp `MeshInstance3D` + hàm gom centers riêng). Hình dạng riêng có mesh thật (Gear/Bell): ĐỪNG thêm.
4. `BlockFactory`: thêm `const XXX_SCENE` + vào `SCENES_BY_TYPE` (KHÔNG sửa `PlacementController`/`SaveManager` — đều qua `BlockFactory.instantiate()`). Thêm phím tắt trong `PlacementController._unhandled_input`
5. `material_ui.gd`: thêm loại vào mảng `ENTRIES`. Icon dựng qua `_build_icon_visual(type)` — khối CÓ mesh thật (Gear/Bell) instance scene; khối meshless (Gỗ/Nước) dựng BoxMesh đại diện + shader tương ứng.
6. Nếu khối cần logic riêng theo thời gian/trạng thái lưới (như Gear xoay, Bell kêu): tạo autoload mới theo đúng pattern ở trên, đăng ký trong `project.godot` SAU `GridManager` (và sau bất kỳ autoload nào nó cần đọc trong `_ready`)

## Audio

Mọi file trong `assets/sounds/` đều có ref thật trong code. Thêm file mà chưa `preload` → coi là rác, xoá.

| File | Dùng cho | Ghi chú |
|------|----------|---------|
| `218460__thomasjaunism__wood-block-hit.wav` | `AudioManager.play_wood_pitch` (Drum/Shishi/gõ gỗ) | 1 sample gỗ duy nhất, đổi `pitch_scale` ra cả bộ percussion. Đã kiểm khoảng lặng đầu bằng `ffmpeg silencedetect`, sạch |
| `517660__samuelgremaud__chimes-5.wav` | `AudioManager.play_chime` (Bell) | Đã cắt 161ms lặng đầu bằng `ffmpeg atrim` |
| `463590__mixtos__jellybounce.wav` | `AudioManager` (Jelly) | |
| `461166__hisoul__wooden-gear-lq-5-sprocket-rattling.ogg` | `AudioManager` gear creak (loop, -19dB, pitch 0.62–0.82) | **Đã nén từ WAV 22MB → OGG mono 395KB** (`-ac 1 -ar 44100 -c:a libvorbis -q:a 3`). Bản gốc là PCM 24-bit/96kHz stereo 40s — vô nghĩa cho 1 tiếng lặp phát ở -19dB, và làm web build phình ~20MB. Loop set trong code bằng `.loop = true` (AudioStreamOggVorbis), KHÔNG phải `loop_mode` (đó là API của AudioStreamWAV) |
| `249666__tymorafarr__water-stream-looped.ogg` | `AudioManager.make_water_loop_player` | Convert từ `.flac` gốc bằng ffmpeg — Godot 4 không import `.flac` native. File `.flac` gốc ĐÃ XOÁ (2.9MB, không dùng được, tải lại từ Freesound nếu cần bản master) |
| `chill_ambient.ogg` | `AmbientMusic` (nhạc nền) | |
| `rain_loop.ogg` | `AmbientMusic.RAIN_LAYER` (layer mưa) | |
| `default_bus_layout.tres` | Bus Master + `AudioEffectReverb` | Thông số `room_size`/`wet`/`damping` là ước lượng, CHƯA nghe thử thật — cần tinh chỉnh bằng tai |

## Export (Windows Desktop + Web)

`export_presets.cfg` có preset `"Windows Desktop"`, `"Web"`, `"Android"`, `"iOS"`. Dùng **binary Godot official**, KHÔNG dùng bản Steam (bản Steam nuốt text lỗi export → debug mù). Template ở `%APPDATA%/Godot/export_templates/4.7.1.stable/`. Chi tiết đầy đủ 3 nền tảng: `docs/BUILD.md`.

Lệnh export (chạy từ thư mục project, headless không cần mở editor). Output vào `build/` — thư mục output DUY NHẤT, khớp `export_path` trong preset:
```
godot --headless --path . --export-release "Windows Desktop" build/windows/karakuri-stream.exe
godot --headless --path . --export-release "Web" build/web/index.html
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
