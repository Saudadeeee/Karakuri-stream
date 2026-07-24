📜 PLAYBOOK DỰ ÁN: KARAKURI STREAM (Vườn Thủy Cơ)PHẦN 1: TỔNG QUAN (CORE VISION)Thể loại: Sandbox thư giãn, Đồ chơi kỹ thuật số (Digital Toy), Procedural ASMR.Engine đề xuất: Godot 4.x (Hỗ trợ 3D nhẹ, Web Export tốt, xử lý Tween và Audio 3D xuất sắc).Core Loop: Người chơi đặt khối $\rightarrow$ Thuật toán tự động kết nối và tạo chuyển động $\rightarrow$ Hệ thống tự sinh âm thanh và chi tiết trang trí $\rightarrow$ Trải nghiệm ngắm nhìn/nghe thư giãn.PHẦN 2: HỆ THỐNG THUẬT TOÁN LÕI (THE LOGIC)Để game chạy mượt và không bị lỗi logic khi người chơi xây hàng ngàn khối, chúng ta chia hệ thống thành 3 lớp thuật toán riêng biệt:1. Thuật toán Lưới không gian (Spatial Hash Grid)Không dùng mảng 3D (Array[][][]) vì nó giới hạn kích thước bản đồ.Giải pháp: Dùng Dictionary với Key là tọa độ nguyên Vector3i (X, Y, Z) và Value là BlockData.BlockData Struct: Lưu trữ type (Gỗ, Ống, Bánh răng...), state (Đang xoay, Đang có nước chảy qua...), và mesh_ref (để xóa/thay đổi khi cần).2. Thuật toán Tự động khớp nối (3D Bitmasking / Context-Aware Swapping)Lấy cảm hứng từ Townscaper, chúng ta không dùng Wave Function Collapse (quá nặng và thiên về tạo map ngẫu nhiên), mà dùng Bitmasking 3D.Cách hoạt động:Khi đặt 1 ống trúc, thuật toán check 6 ô xung quanh (Trái, Phải, Trước, Sau, Trên, Dưới).Mỗi hướng có khối hợp lệ sẽ cộng vào một mã bit (ví dụ: Trái = 1, Phải = 2 $\rightarrow$ Tổng = 3).Tra bảng Dictionary: Mesh_Dictionary[3] = "ong_truc_thang.obj". Nếu Tổng = 5 (Trái + Trước) $\rightarrow$ Đổi thành mesh "ong_truc_goc_L.obj".3. Thuật toán Dòng chảy năng lượng (Breadth-First Search - BFS Flow)Để xác định bánh răng nào quay, chuông nào kêu, bạn cần một thuật toán quét mạng lưới lan truyền.Cách hoạt động:Mỗi khi có sự thay đổi khối, bắt đầu quét từ tất cả các khối "Nguồn Nước" (Source).Nước chỉ lan xuống ô bên dưới hoặc ô bên cạnh nếu đó là Ống/Máng.Đánh dấu các ô được nước đi qua là is_powered = true.Nếu ô is_powered nằm cạnh khối "Bánh Răng", cấp lệnh speed = 1.0 cho bánh răng đó quay.PHẦN 3: ĐỒ HỌA & THUẬT TOÁN TRANG TRÍ TỰ ĐỘNG (PROCEDURAL DECOR)Thay vì bắt người chơi tự trồng từng cành cây, hệ thống sẽ tự "mọc" ra chúng dựa trên quy tắc (Rule-based Spawning).Điều kiện (Context)Vật thể được sinh ra (Spawn)Vị trí / Hiệu ứng phụGỗ / Đá nằm cạnh Nguồn nước liên tục 10 giâyRêu phong (Moss)Phủ lên bề mặt, lerp scale từ 0 lên 1 (mọc từ từ).Có 4 khối Đá/Gỗ bao quanh 1 ô Nước tĩnhHoa súng & Cá KoiHoa súng nổi trên mặt nước; Cá bơi ngẫu nhiên trong phạm vi ô đó.Bánh răng đang quay speed > 0Bụi lấp lánh (Particles)Tỏa ra từ trục bánh răng, bay theo chiều gió nhẹ.Khối có độ cao Y > 5 (Khu vực cao)Cờ đuôi nheo / Chong chóngTự động gắn vào thành gỗ, đung đưa theo thuật toán Wind Shader.Khối có chuông đồng đang gõĐom đốm (Đêm)Spawn các hạt sáng vàng, chớp tắt (Sine wave opacity).PHẦN 4: HỆ THỐNG ÂM THANH PHÁT SINH (GENERATIVE ASMR)Biến các khối thành một bộ máy đánh nhịp (Sequencer).Audio Pool: Khởi tạo một mảng khoảng 20 node AudioStreamPlayer3D ẩn để tái sử dụng (Object Pooling), tránh giật lag khi có quá nhiều âm thanh phát ra cùng lúc.Xử lý va chạm: Khi Bánh răng gõ vào Chuông, hoặc Nước nhỏ giọt vào Đá, lấy 1 node âm thanh từ Pool, gán file âm thanh tương ứng.Thuật toán Humanization (Chống mệt mỏi thính giác):pitch_scale = randf_range(0.95, 1.05)volume_db = base_vol + randf_range(-2.0, 2.0)Phát âm thanh và đưa node trở lại Pool khi kết thúc.PHẦN 5: ROADMAP TRIỂN KHAI (Dành cho Coder)Dưới đây là trình tự lập trình để dự án không bị vướng "Tech Debt" (Nợ kỹ thuật) ngay từ đầu.1.Hệ thống Lưới & Tương tác chuột:Phase 1: Foundation.Setup Camera Isometric có thể xoay quanh tâm (Orbit Camera).Code chức năng bắn Raycast từ chuột, tính toán điểm chạm và Snap (làm tròn) về tọa độ lưới Vector3i.Vẽ một khối hộp mờ (Ghost Block) tại vị trí con trỏ chuột để người chơi biết họ sắp đặt khối ở đâu.2.Xây dựng Data & Bitmasking:Phase 2: Core Logic.Tạo GridManager lưu Dictionary các khối.Setup hàm kiểm tra hàng xóm (get_neighbors).Viết logic Bitmasking cơ bản cho 1 loại vật liệu (Ví dụ: Ống trúc). Nếu nối 2 ống thẳng $\rightarrow$ ra ống thẳng. Nếu nối rẽ nhánh $\rightarrow$ ra ống góc.3.Thuật toán Dòng chảy (BFS):Phase 3: The Engine.Viết hàm update_flow() gọi mỗi khi đặt/xóa khối.Tìm mọi "Nguồn nước", cho lan truyền (BFS) xuống dưới và xung quanh.Code logic xoay bánh răng: if is_powered: rotation.y += speed * delta.4.Hiệu ứng Animation & Decor:Phase 4: Game Juice.Dùng Tween khi đặt khối (Khối rớt từ trên cao xuống, scale lún xuống rồi nảy lên).Tích hợp hàm sinh chi tiết (Rule-based Spawning) vào sau bước update_flow(). Thêm lá cây, rêu.Chỉnh sửa Shader nước (Water material với hiệu ứng bọt trắng ở điểm giao cắt).5.Hệ thống ASMR:Phase 5: Audio & Polish.Thiết lập AudioStreamPlayer3D Pool.Code logic gõ nhịp: Gắn một vùng va chạm nhỏ (Area3D hoặc Raycast ngắn) trên bánh răng, khi chạm vào chuông thì trigger hàm play_sound() với Pitch/Volume ngẫu nhiên.Thêm UI tối giản (chỉ gồm icon chọn loại vật liệu).Bí kíp để hoàn thiện (Pro-tip): Hãy bắt đầu bằng những khối cơ bản nhất là "Cột Gỗ" và "Nước". Chỉ khi cảm giác click chuột đặt cột gỗ và nhìn nước chảy xuống đủ "đã", đủ mượt, bạn mới nên thêm các khối cơ khí (Bánh răng, chuông). Giữ cho dự án nhỏ gọn, tập trung vào chất lượng của cú click chuột (Game Feel) thay vì số lượng tính năng.

## PHẦN 6: AUDIO PLAYBOOK (Generative ASMR Sound Pipeline)

### Bước 1 — Sourcing (nhặt âm thanh, không tự làm)
- [x] Tiếng mộc: `assets/sounds/218460__thomasjaunism__wood-block-hit.wav`
- [x] Tiếng chuông: `assets/sounds/517660__samuelgremaud__chimes-5.wav` (chờ khối Chuông ở Phase mechanic sau mới trigger được)
- [x] Tiếng nước: `assets/sounds/249666__tymorafarr__water-stream-looped.flac` — Godot 4 không import `.flac` native, đã convert bằng ffmpeg → `.ogg` (33.6s, loop sẵn) để dùng trong engine
- [x] Rà khoảng lặng đầu file bằng `ffmpeg silencedetect` (đo được, không cần nghe): `wood-block-hit.wav` sạch, `water-stream.ogg` không có leading silence (chỉ có các khoảng ngắt tự nhiên giữa bài — bình thường). Riêng `chimes-5.wav` có 161ms lặng đầu → đã cắt (`atrim=start=0.15`), verify lại bằng silencedetect: hết lặng đầu, chỉ còn đuôi rung chuông tắt dần tự nhiên

### Bước 2 — Thang âm Ngũ cung (Pentatonic Scale)
- [x] Không tải 5 file chuông riêng — dùng 1 file `chimes-5.wav` gốc
- [x] Bảng tỷ lệ pitch 5 nốt C-D-E-G-A (equal temperament) trong `AudioManager.PENTATONIC_RATIOS`
- [x] Hàm `AudioManager.play_chime(pos, note_index)` — random nốt nếu không truyền index
- [x] Wiring vào khối Chuông thật — xem PHẦN 10, `GearManager._strike_adjacent_bells()`

### Bước 3 — Humanization (chống mệt mỏi thính giác)
- [x] `AudioManager` autoload, pool 20 `AudioStreamPlayer3D` (object pooling, tái sử dụng player rảnh)
- [x] `play_wood_hit(pos)`: `pitch_scale = randf_range(0.95, 1.05)`, `volume_db = randf_range(-2.0, 1.0)`
- [x] Đã gắn vào `placement_controller.gd`: đặt khối Gỗ → phát tiếng gõ mộc ngay tại vị trí khối
- [x] Nước: `WaterFlowManager` spawn `AudioStreamPlayer3D` loop riêng (không qua pool, vì cần chạy liên tục theo vòng đời dòng chảy) tại điểm nước đổ xuống, pitch humanize 1 lần lúc tạo

### Bước 4 — Audio Bus (Reverb cho không gian vang)
- [x] Tạo `default_bus_layout.tres`: bus Master + `AudioEffectReverb` (room_size 0.8, wet 0.28, damping 0.6)
- [x] Đăng ký trong `project.godot` (`audio/buses/default_bus_layout`)
- [ ] Tinh chỉnh thông số reverb bằng tai sau khi nghe thử trong editor (giá trị hiện tại là ước lượng, chưa test thật)

### Ghi chú triển khai
Files liên quan: `scripts/audio_manager.gd` (autoload), `scripts/water_flow_manager.gd` (autoload, quét lại khi `GridManager.block_placed`/`block_removed` bắn ra, dựng cột nước rơi từ khối Nước xuống đất + loop âm thanh chảy), `default_bus_layout.tres`.

### Bugfix log (sau khi test tay)
- Nước không chảy: điều kiện trigger sai (check ô dưới thay vì ô trên) + height tính ra 0 khi nước ngồi trên khối đặc → return sớm. Đã sửa: trigger khi nước là đỉnh 1 chuỗi (không có nước phía trên) và `y>0`, luôn chảy thẳng xuống đất bất kể có gì ở giữa.
- Nước không nghe tiếng: `max_distance=12` trong khi camera đứng cách ~15 unit → ngoài tầm nghe. Đổi `max_distance=0` (không giới hạn cứng), `unit_size=6.0`.
- Camera "dính" zoom khi click lung tung: `SpringArm3D` mặc định tự dò va chạm (né vật cản) trùng layer với khối đã đặt. Tắt hẳn (`collision_mask=0`) vì camera orbit tự do không cần né vật cản.

## PHẦN 7: GAME JUICE & DECOR (Phase 4, scope Gỗ+Nước)

### Tween khi đặt khối
- [x] Rơi từ trên cao xuống (0.22s, ease-in) → squash (0.06s) → bounce trở lại scale gốc (0.18s, back-ease) — `placement_controller._animate_drop()`

### Rule-based Decor
- [x] Rêu (Moss): Gỗ cạnh Nước liên tục 10s → mọc sphere rêu, lerp scale 0→1 (1s) — `scripts/decor_manager.gd` (autoload `DecorManager`)
- [x] Hoa súng & Cá Koi: nước có đủ 4 hàng xóm ngang bị chiếm (bao quanh) → spawn 2 hoa súng (đĩa phẳng, vị trí/xoay random) + 1-2 cá Koi bơi vòng tròn (bán kính/tốc độ/pha random) trong ô — `scripts/pond_decor_manager.gd` (autoload `PondDecorManager`)
- [x] Bụi lấp lánh, Cờ/chong chóng, Đom đóm — xem PHẦN 10 (`GearManager`, `DecorManager._spawn_flag`, `FireflyManager`)

### UI tối giản
- [x] 2 nút chọn vật liệu (Gỗ [1] / Nước [2]) góc dưới-trái, sync 2 chiều với phím tắt qua signal `material_changed` — `scripts/material_ui.gd`

### Water Shader
- [x] `shaders/water.gdshader` (spatial, ShaderMaterial trên `water_block.tscn`): sóng nhẹ animate theo TIME (vertex offset), fresnel (trong hơn nhìn thẳng, đục hơn nhìn nghiêng), foam trắng viền theo UV mỗi mặt — foam trùng đúng đường giao giữa các khối nước liền kề
- Lưu ý kỹ thuật: KHÔNG dùng SCREEN_TEXTURE/DEPTH_TEXTURE (kiểu foam giao cắt chuẩn) vì project set `renderer/rendering_method="gl_compatibility"` — Compatibility renderer không hỗ trợ đọc screen/depth texture trong spatial shader. Foam hiện tại dùng UV-edge (local, không cần depth) để tương thích Web/Mobile.
- [x] Verify hình ảnh thật: dựng scene test (cột gỗ 3 khối + nước trên đỉnh, và pond 4 gỗ bao 1 nước), chạy Godot **không headless** (GPU thật, cửa sổ đặt off-screen) và chụp screenshot qua `get_viewport().get_texture().get_image().save_png()`. Nhìn ảnh: foam trắng + fresnel + gradient xanh render đúng, sạch không lỗi shader.
- Bug phát hiện qua ảnh (không thấy được nếu chỉ đọc code): dòng nước chảy (`WaterFlowManager`) đặt đúng tâm cột gỗ → ống nước bán kính 0.08 bị nuốt trọn bên trong khối gỗ đặc (bán kính 0.5), **vô hình hoàn toàn** dù logic chạy đúng. Đây chính là case phổ biến nhất (cột gỗ + nước trên đỉnh). Đã sửa: dịch ống ra ngoài rìa cột (`edge_offset = 0.5*CELL_SIZE + 0.1`) — verify lại bằng ảnh, giờ thấy rõ dòng chảy chạy dọc mặt ngoài cột.

### Còn treo (cần tai/mắt thật của bạn — ngoài khả năng tự động)
- [ ] Nghe thử reverb bằng tai thật trong editor, tinh chỉnh `room_size`/`wet`/`damping` theo cảm nhận (giá trị hiện tại chỉ là ước lượng)
- [ ] Nhìn animation sóng nước theo thời gian thực (ảnh chụp chỉ là 1 khung hình tĩnh, không thấy được chuyển động) — chỉnh `wave_height`/`wave_speed` bằng mắt nếu thấy chưa vừa ý

## PHẦN 8: BFS FLOW THẬT, MERGE KHỐI (Townscaper-style), FIX LƯỚI TỌA ĐỘ

### Bug nền tảng: khối tầng 1 chìm nửa khối
- **Nguyên nhân**: `GridManager.cell_to_world` cũ đặt tâm khối tại `cell*CELL_SIZE` — cell y=0 có tâm tại world y=0, khối (kích thước 1) trải từ -0.5 đến 0.5, tức nửa dưới chìm dưới mặt đất (mặt đất ở y=0). Đây cũng là nguồn gốc cảm giác "khối bị đặt sai tầng" — hình ảnh và logic lệch nhau nửa block khiến người chơi click nhầm.
- **Fix**: quy ước mới — trục Y lấy mặt đất làm mốc sàn: cell y=n chiếm khoảng world y `[n, n+1)`, tâm tại `(n+0.5)*CELL_SIZE`. Trục X/Z không đổi (vẫn đối xứng quanh tọa độ nguyên). `world_to_cell` dùng `floori()` cho Y (khoảng nửa-mở) thay vì `roundi()`.
- Verify bằng test: `cell_to_world(0,0,0).y == 0.50` ✓; raycast mặt đất lần click đầu tiên ra đúng `place_cell.y=0` ✓ (test giả lập, không phải chỉ đọc code).

### Merge khối cùng loại (Townscaper-style)
- [x] `scripts/block_mesh_builder.gd` (`class_name BlockMeshBuilder`): dựng mesh cube bằng `SurfaceTool`, bỏ qua các mặt hướng về khối cùng loại (6 hướng, kiểm tra qua `GridManager.get_neighbors`)
- [x] `scripts/block_merge_manager.gd` (autoload `BlockMergeManager`): nghe `block_placed`/`block_removed`, rebuild mesh của ô thay đổi + 6 hàng xóm mỗi lần — khối mới đặt cạnh khối cũ cùng loại tự ẩn mặt chung ở CẢ HAI bên
- Verify: 2 khối gỗ đặt cạnh nhau — số vertex giảm đúng từ 36→30 (ẩn đúng 1 mặt/6 mặt) ở cả 2 khối, đo bằng test thật không phải suy luận
- **Giới hạn đã biết (đã fix — xem PHẦN 9)**: ~~chỉ ẩn mặt DỌC/mặt tiếp giáp giữa 2 ô... mặt trên mỗi ô Nước vẫn còn thấy viền foam riêng~~

### BFS Flow thật (thay hoàn toàn phiên bản "chảy thẳng xuống đất" cũ)
- [x] Viết lại `scripts/water_flow_manager.gd`: BFS thật từ mọi khối Nước "đỉnh chuỗi" (không có nước phía trên, y>0) qua các ô RỖNG — ưu tiên rơi thẳng xuống, nếu bị chặn thì tràn sang **1** hướng ngang duy nhất (không tràn cả 4 hướng — tràn 4 hướng nhìn giống đài phun nước/tháp đối xứng chứ không phải dòng suối một chiều)
- [x] Mỗi ô trên đường BFS đi qua = 1 khối nước động (mesh + shader riêng), các ô liền kề tự nhiên nối liền thành 1 dải — đúng yêu cầu "cả một dải như dòng suối" thay vì 1 tia mỏng
- [x] Ngân sách tách riêng: `MAX_FALL_CELLS=60` (rơi thẳng, tự giới hạn theo độ cao) và `MAX_POOL_CELLS=24` (tràn ngang, giới hạn để không biến thành hồ vô hạn trên nền đất phẳng mở)
- [x] Âm thanh: 1 loop riêng mỗi nguồn đang tràn (không phải mỗi ô), tránh chồng tiếng
- **Đã tune qua verify ảnh thật 4 lần** (xem "Sửa lại theo vật lý thật" bên dưới — vòng 3 từng thử "chỉ tràn 1 hướng" cho đẹp mắt nhưng **sai vật lý**, đã revert)

### Chuyển động liên tục (không chỉ chảy 1 lần)
- [x] Shader nước thêm `flow_dir`/`flow_speed`/`flow_amount`: nước tĩnh (đặt tay) giữ sóng nhẹ đứng yên như cũ; ô flow (BFS) có sóng LAN THEO HƯỚNG CHẢY + vệt bọt trắng cuộn chạy dọc hướng đó — nước nhìn "có hướng chảy" thật chứ không chỉ nhấp nhô tại chỗ
- [x] Lá sen: thêm bob lên-xuống (sin wave, biên độ nhỏ, tốc độ/pha random mỗi lá) + lắc nhẹ — `pond_decor_manager.gd`, nhìn "nổi lềnh bềnh" thay vì đứng yên tuyệt đối sau khi mọc
- Cá Koi: đã có bơi vòng tròn từ trước (PHẦN 7), không đổi

### Files thêm mới
`scripts/block_mesh_builder.gd`, `scripts/block_merge_manager.gd` (autoload). `scripts/water_flow_manager.gd` viết lại hoàn toàn. `scripts/grid_manager.gd`, `scripts/pond_decor_manager.gd`, `shaders/water.gdshader` sửa tại chỗ.

### Sửa lại theo vật lý thật (feedback sau khi test tay vòng 2)
- **Bug báo cáo**: nước chảy về 1 hướng; chặn hướng đó lại thì nước KHÔNG chảy sang hướng khác — dừng hẳn.
- **Nguyên nhân**: bản trước cố tình chỉ tràn sang **1** hướng ngang (`break` sau khi tìm thấy hướng mở đầu tiên) để tránh nhìn giống đài phun nước đối xứng — đây là đánh đổi thẩm mỹ nhưng sai bản chất vật lý: nước thật tự tìm MỌI hướng còn mở khi bị chặn, không "cố chấp" 1 hướng rồi bỏ cuộc.
- **Fix**: bỏ `break`, BFS tràn vào **tất cả** hướng ngang còn mở (giữ nguyên logic ưu tiên rơi thẳng xuống trước). `MAX_POOL_CELLS` tăng 16→24 để có đủ ngân sách khám phá đường vòng khi bị chặn.
- **Verify bằng test thật** (không chỉ đọc code): dựng cột 1 khối + nguồn nước — trước khi chặn, cả 4 hướng (+X/-X/+Z/-Z) đều có nước chảy tới. Chặn riêng hướng +X → `+X` hết nước ✓, còn lại 3 hướng vẫn chảy bình thường ✓ (đúng yêu cầu, không dừng hẳn nữa). Có chụp ảnh GPU thật xác nhận nước chảy vòng qua khối chặn.
- **Đánh đổi đã chấp nhận**: quay lại tràn đa hướng khiến hình dạng chảy quanh 1 cột đơn lẻ trên nền mở lại nhìn "khối/tháp" hơn là dải suối 1 chiều thẳng tắp (như bản trước đây) — nhưng đây là cái giá đúng để có vật lý thật; ưu tiên đúng theo yêu cầu mới nhất của bạn.

### Còn treo
- [ ] Nhìn hình dạng chảy đa hướng bằng mắt thật trong editor — ảnh chụp tĩnh xác nhận đúng logic, nhưng thẩm mỹ tổng thể (có "đẹp" theo ý bạn không) cần bạn tự đánh giá

## PHẦN 9: MẶT NƯỚC LIỀN MẠCH (thay giải pháp greedy-meshing đầy đủ)

### Vấn đề
Sau PHẦN 8, khối Gỗ merge liền mạch hoàn toàn (kể cả mặt trên, vì không có hoạ tiết UV), nhưng mặt TRÊN của các khối Nước liền kề vẫn hiện viền foam riêng từng ô — vì `water.gdshader` tính foam dựa trên UV cục bộ (0..1) của mỗi mặt, không biết cạnh nào là biên thật của cả vũng nước, cạnh nào chỉ là ranh giới nội bộ giữa 2 ô nước. Full greedy-meshing (gộp hình học nhiều ô thành 1 mặt phẳng lớn) là việc lớn, cần đổi kiến trúc (1 mesh cho cả vùng liên thông thay vì 1 mesh/khối).

### Giải pháp nhẹ hơn: che foam theo mask, không cần đổi kiến trúc
Tận dụng lại đúng dữ liệu "hàng xóm cùng loại theo 6 hướng" mà `BlockMergeManager` đã tính sẵn để ẩn mặt hình học — dùng THÊM dữ liệu đó để tắt foam ở các cạnh nội bộ trên mặt trên, chỉ giữ foam ở cạnh chạm không khí/khối khác loại thật sự.

- [x] `shaders/water.gdshader`: thêm `uniform vec4 edge_mask` (thứ tự +X, -X, +Z, -Z — 1.0 = biên thật hiện foam, 0.0 = giáp nước khác, tắt foam). Chỉ áp dụng cho mặt TRÊN (`v_is_top`, tính bằng `step(0.49, VERTEX.y)` ở vertex trước khi bị sóng làm lệch); mặt bên vẫn dùng logic edge cũ (đã đúng nhờ mặt bên đã bị ẩn hình học khi giáp nước khác ở PHẦN 8)
- [x] `placement_controller.gd`: mỗi khối Nước khi đặt được `duplicate()` riêng `ShaderMaterial` — tránh việc set `edge_mask` của 1 khối ảnh hưởng tới TẤT CẢ khối Nước khác (mặc định `surface_material_override` trong `.tscn` là resource dùng chung)
- [x] `block_merge_manager.gd`: sau khi build mesh, nếu là khối Nước thì tính `edge_mask` từ đúng `hidden_dirs` đã tính (hàng xóm cùng loại 4 hướng ngang) và set vào material riêng của khối đó
- **Verify logic bằng test thật**: dải nước 3 ô liên tiếp theo +X — ô trái `(0,1,1,1)` (bịt +X, hở -X) ✓, ô giữa `(0,0,1,1)` (bịt cả 2 X) ✓, ô phải `(1,0,1,1)` (hở +X, bịt -X) ✓ — khớp chính xác dự đoán toán học, không phải suy luận suông
- **Verify hình ảnh thật**: dựng pond 3x3 Nước bao bởi vành Gỗ, chụp ảnh GPU thật — mặt nước bên trong liền mạch hoàn toàn, không còn lưới foam giữa các ô, chỉ còn viền foam ở đúng vành ngoài giáp Gỗ

### Còn treo
- [ ] Foam trên mặt BÊN của các ô flow (WaterFlowManager) chưa áp dụng edge_mask tương tự (chủ yếu là mặt dọc/rơi, ít bị nhìn từ trên nên ưu tiên thấp hơn) — có thể làm thêm nếu cần

### Bug nghiêm trọng phát hiện khi tự verify bằng ảnh cận cảnh
- **Phát hiện**: chụp cận cảnh 1 khối Nước đơn lẻ (test animation sóng) → khối hiện RỖNG BÊN TRONG, mặt trước biến mất, nhìn xuyên vào mặt sau/mặt bên từ trong ra — không phải "trong suốt vì nước", mà là hình học sai thật sự.
- **Nguyên nhân**: `BlockMeshBuilder` (viết ở PHẦN 8, thay thế TOÀN BỘ mesh của MỌI khối Gỗ/Nước qua `BlockMergeManager`) dựng tam giác sai chiều winding — dù đã tính cross-product tay để verify hướng normal ra ngoài cho cả 6 mặt lúc viết code, thực tế chiều winding Godot cần lại ngược với giả định. Vì `render_mode` có `cull_back`, mặt "trước" bị coi là mặt sau (bị ẩn), và ngược lại.
- **Vì sao không phát hiện sớm hơn**: các ảnh chụp trước đó (cột gỗ, platform, pond 3x3) đều dùng góc camera xa/cao, nhìn chủ yếu mặt trên + 2 mặt bên của cụm khối lớn — ở khoảng cách đó và với vật liệu màu phẳng (đặc biệt là Gỗ, không hoạ tiết), hình rỗng-bên-trong vô tình vẫn "trông" giống khối đặc, dễ bị bỏ qua. Chỉ khi test cận cảnh 1 khối đơn lẻ mới lộ rõ.
- **Fix**: đảo thứ tự index tam giác trong `block_mesh_builder.gd` (`[0,1,2, 0,2,3]` → `[0,2,1, 0,3,2]`) cho cả 6 mặt.
- **Verify**: chụp lại ảnh cận cảnh — khối hiện đặc/solid đúng. Chụp lại toàn bộ scene tổng hợp (cột+platform+pond) — không có hồi quy, mọi thứ khác vẫn đúng như trước.
- **Bài học**: từ nay verify mesh tự dựng (không dùng BoxMesh có sẵn) LUÔN cần chụp cận cảnh 1 khối đơn lẻ trước, không chỉ chụp toàn cảnh — toàn cảnh dễ che giấu lỗi hình học ở khoảng cách xa.
## PHẦN 10: BÁNH RĂNG + CHUÔNG (mở rộng scope, quyết định cùng bạn)

Sau khi Gỗ+Nước ổn định qua nhiều vòng test/fix (đúng pro-tip gốc), mở khoá 2 khối cơ khí còn lại.

### Khối mới
- [x] `BlockData.Type` thêm `GEAR`, `BELL`
- [x] `scenes/blocks/gear_block.tscn`: đĩa trụ 8 cạnh (gợi hình bánh răng), màu xám kim loại
- [x] `scenes/blocks/bell_block.tscn`: hình nón cụt (dáng chuông), màu đồng
- [x] `block_merge_manager.gd`: thêm `MERGEABLE_TYPES` — chỉ Gỗ/Nước được merge/ẩn mặt; Gear/Bell giữ nguyên mesh riêng (không bị build lại thành box)
- [x] `placement_controller.gd`: `SCENES_BY_TYPE` dictionary thay ternary, phím `[3]`/`[4]`; UI thêm 2 nút "⚙️ Bánh răng"/"🔔 Chuông"

### GearManager (autoload mới)
- [x] `is_powered`: Gear có 1 trong 6 hàng xóm là Nước (đặt tay HOẶC đang là ô flow BFS đang chảy) → quay `mesh_instance.rotate_y(speed*delta)`
- [x] Gõ chuông: đếm dồn góc quay, mỗi khi đủ 1 vòng (2π) → tìm Bell ở 6 hàng xóm, gọi `AudioManager.play_chime()` (random nốt ngũ cung có sẵn từ PHẦN 6 — giờ mới thật sự dùng tới)
- [x] Bụi lấp lánh: `GPUParticles3D` gắn vào trục Gear khi đang quay, tự xoá khi hết powered
- **Verify bằng test thật**: Nước-Gear-Chuông liền kề → `is_powered=true`, mesh rotation đổi sau 1 tick, sparkle spawn đúng lúc. Fast-forward đủ 1 vòng quay → 1 player trong AudioManager pool đang phát đúng stream Chime. Gỡ Nước → hết powered, sparkle dọn sạch.

### FireflyManager (autoload mới)
- [x] `burst_at(pos)`: chớp hạt sáng vàng một lần khi Chuông được gõ (gọi từ `GearManager._strike_adjacent_bells`)
- **Đơn giản hoá đã chấp nhận**: plan gốc ghi "Đêm" (chỉ xuất hiện ban đêm) — dự án chưa có chu kỳ ngày/đêm, nên đom đóm phát mỗi lần chuông kêu (không phân biệt ngày/đêm), fade theo particle lifetime thay vì true sine-wave flicker liên tục.

### Cờ/Chong chóng (thêm vào `decor_manager.gd` có sẵn)
- [x] Gỗ ở `cell.y > 5` → tự gắn cột cờ nhỏ, lá cờ đung đưa `sin(t*2+phase)*0.3` quanh trục Z (thay cho Wind Shader thật)

### Verify hình ảnh thật
Dựng hàng Gỗ-Nước-Gear-Chuông, chụp GPU thật: Gear hiện đúng dạng đĩa 8 cạnh, Chuông hiện đúng dạng nón cụt màu đồng — xác nhận `MERGEABLE_TYPES` hoạt động đúng, không bị merge system ép thành khối vuông.

### Còn treo
- [ ] Chu kỳ ngày/đêm thật cho đom đóm (hiện chỉ trigger theo chuông, không theo giờ trong game)
- [ ] Cờ/chong chóng dùng sine sway đơn giản, chưa phải Wind Shader thật (shader gió tương tác theo nhiều lá đồng thời)
- [ ] Chưa test threshold `Y>5` bằng ảnh thật (cần xây cao 6+ tầng — logic đã verify qua code, chưa qua ảnh do tốn thời gian dựng cảnh)

## PHẦN 11: UI/UX HOÀN CHỈNH (Pause, Xoá build, Âm lượng)

User yêu cầu "đừng để đây là demo" — hỏi ưu tiên trong 4 lựa chọn (export, save/load, UI/UX, hiệu năng), chỉ chọn **UI/UX hoàn chỉnh**. 3 mục còn lại KHÔNG làm lần này, ghi rõ trong CODEMAP.md để không quên.

### Phát hiện rò rỉ khi audit trước khi code (không phụ thuộc tính năng mới)
`WaterFlowManager._active_flows`/`_source_audio`, `PondDecorManager._ponds` — node con của CHÍNH autoload, không phải con khối, nên `GridManager` free khối không tự dọn được. `GearManager` không nghe signal nào cả (chỉ poll `_process`) → gỡ 1 Gear lẻ để lại dict entry treo (`_sparkles`/`_rotation_progress`) trỏ node đã free.

### Fix
- [x] `GridManager`: thêm `signal grid_cleared` + `func clear_all()` — free hết node rồi `_blocks.clear()` rồi emit 1 lần (KHÔNG lặp `remove_block()` per-cell, tránh rescan dây chuyền ở 4 autoload mỗi lần xoá 1 khối trong lúc xoá hàng loạt)
- [x] `WaterFlowManager`, `PondDecorManager`: connect `grid_cleared`, tự free node con của mình + clear dict
- [x] `DecorManager`: connect `grid_cleared`, chỉ cần clear dict (moss/flag là con của khối Gỗ, tự free theo)
- [x] `GearManager`: **thêm mới** connect cả `block_removed` (fix rò rỉ per-cell) VÀ `grid_cleared` (fix rò rỉ hàng loạt)

### Pause Menu (`scenes/pause_menu.tscn` + `scripts/ui/pause_menu.gd`)
- [x] Toggle bằng phím ESC (`ui_cancel`, action mặc định Godot) hoặc nút "⏸" góc trên-phải (nối qua `[connection]` trực tiếp trong `main.tscn`, không cần script riêng)
- [x] `process_mode = PROCESS_MODE_ALWAYS` để menu vẫn nhận input khi `get_tree().paused = true` — mọi node khác dùng default nên tự dừng animate (Gear/nước) khi pause, không cần sửa gì thêm
- [x] Nút "Xoá toàn bộ" → `ConfirmationDialog` cảnh báo không thể hoàn tác → `GridManager.clear_all()`
- [x] Slider âm lượng → `AudioServer.set_bus_volume_db` + lưu qua `ConfigFile` vào `user://settings.cfg` (chỉ là setting âm lượng, KHÔNG phải save/load công trình — 2 việc khác nhau, đừng nhầm)

### Verify bằng test thật
Dựng đủ trạng thái để mọi dict không rỗng (cột gỗ+nước chảy, pond, gear+bell đang xoay+sparkle) → in số liệu trước/sau:
```
before: active_flows=36 source_audio=1 ponds=1 sparkles=1
gỡ riêng 1 Gear → sparkle_after_single_remove=false (đúng, fix leak per-cell)
clear_all() → tất cả về 0, kể cả get_child_count() của WaterFlowManager/PondDecorManager/GearManager (không còn node mồ côi)
```
Test `pause_menu.gd`: `toggle()` 2 lần → `paused`/`visible` đổi đúng cả 2 chiều; `_on_volume_changed(0.5)` → `AudioServer` khớp `linear_to_db(0.5)` chính xác; `ConfigFile` round-trip save/load khớp giá trị.

### Còn treo (không tự làm — user không chọn ở bước hỏi ưu tiên)
- [x] Export Web/Desktop — xem PHẦN 13
- [ ] Save/Load công trình đã xây (khác slider âm lượng — âm lượng có lưu, công trình thì chưa) — **duy nhất còn lại chưa làm trong 3 mục ban đầu**
- [x] Tối ưu hiệu năng quét-toàn-lưới khi build lớn — xem PHẦN 12
- [ ] Cảm giác bấm nút/kéo slider bằng chuột thật — cần bạn tự thử tay, ngoài khả năng tự động hoá (giống việc tune reverb)

## PHẦN 12: TỐI ƯU HIỆU NĂNG LƯỚI LỚN

User chọn tiếp "Tối ưu hiệu năng lưới lớn" trong 3 mục còn treo (export, save/load, hiệu năng). Đo thật bằng benchmark trước khi sửa (đúng nguyên tắc đã ghi trong CODEMAP.md: "đừng tối ưu sớm trước khi đo được là chậm thật").

### Benchmark BASELINE (chưa sửa) — dựng 3000 khối (Gỗ/Nước/Gear trộn, rải trên lưới 60xN)
```
placed 0..499    in  1068 ms
placed 500..999  in  4171 ms
placed 1000..1499 in 7883 ms
placed 1500..1999 in 10431 ms
placed 2000..2499 in 14201 ms
placed 2500..2999 in 17020 ms
gear_manager_process_avg_us = 5130.5   (127 Gear / 3000 khối)
single_placement_at_scale_us = 37819   (đặt 1 khối lúc lưới đã 3000 khối = 37.8ms, giật rõ)
```
Xác nhận: chậm dần cấp số nhân (O(n²)) — batch cuối chậm gấp 16x batch đầu dù cùng kích thước 500.

### Nguyên nhân
`GridManager.get_all_cells_of_type(type)` quét TOÀN BỘ `_blocks` bất kể type, rồi lọc — O(tổng số khối) thay vì O(số khối đúng loại). Hàm này được gọi:
- `WaterFlowManager`, `DecorManager`, `PondDecorManager`: mỗi lần có 1 khối bất kỳ đổi (đặt/gỡ) ở BẤT KỲ ĐÂU trong lưới
- `GearManager`: MỖI FRAME (60 lần/giây), không phải chỉ khi lưới đổi

→ `DecorManager`/`PondDecorManager` còn quét toàn bộ Gỗ/Nước dù chỉ cần biết trạng thái của 1 vài ô cạnh chỗ vừa đổi — full-rescan-không-cần-thiết, không chỉ là hàm `get_all_cells_of_type` chậm.

### Fix
- [x] `GridManager`: thêm `_cells_by_type: Dictionary[BlockData.Type, Dictionary]` — index phụ cập nhật đồng bộ trong `set_block`/`remove_block`/`clear_all` (`_index()`/`_unindex()`). `get_all_cells_of_type()` đọc từ index, O(số khối đúng loại) thay vì O(tổng số khối).
- [x] `DecorManager`: `_on_grid_changed(cell)` giờ chỉ check `cell` + 6 hàng xóm (không quét lại mọi Gỗ) — đúng vì trạng thái rêu/cờ của 1 ô Gỗ chỉ phụ thuộc chính nó + hàng xóm trực tiếp, không bao giờ phụ thuộc khối ở xa.
- [x] `PondDecorManager`: tương tự, chỉ check `cell` + 4 hàng xóm ngang.
- [x] `WaterFlowManager`: **giữ nguyên** full-rescan (không thu hẹp phạm vi) — chặn 1 hướng chảy phải cho nước tìm đường qua vùng khác trong lưới (đúng theo fix vật lý ở PHẦN 8), thu hẹp phạm vi quét có nguy cơ tái phát bug rerouting. Chỉ hưởng lợi gián tiếp từ index (quét theo số khối Nước, không phải tổng số khối).

### Benchmark SAU KHI SỬA (cùng kịch bản 3000 khối)
```
placed 0..499    in 240 ms
placed 500..999  in 253 ms
placed 1000..1499 in 252 ms
placed 1500..1999 in 270 ms
placed 2000..2499 in 292 ms
placed 2500..2999 in 281 ms
gear_manager_process_avg_us = 2356.8
single_placement_at_scale_us = 1865
```
Phẳng theo batch (không còn tăng dần) — xác nhận từ O(n²) về O(n). Tổng thời gian dựng 3000 khối: ~55s → ~1.6s (**~34 lần**). Đặt 1 khối lúc lưới lớn: 37.8ms → 1.9ms (**~20 lần**, giờ nằm gọn trong 1 frame budget 16.6ms @60fps). Gear per-frame: giảm hơn nửa.

### Verify KHÔNG hồi quy logic (đổi cách trigger, không chỉ đổi cấu trúc dữ liệu — bắt buộc test lại đúng/sai)
```
timer_near_water=true, timer_lone_wood=false, timer_after_water_removed=false   ✓ (rêu)
flag_spawned_above_y5=true                                                      ✓ (cờ)
pond_spawned=true, pond_removed_after_breaking_ring=true                        ✓ (pond)
```

### Còn treo
- [x] Export Web/Desktop — xem PHẦN 13. [ ] Save/Load công trình đã xây — vẫn chưa làm
- [ ] `WaterFlowManager` vẫn O(số khối Nước) mỗi lần đổi 1 khối bất kỳ (có chủ đích) — nếu build có hàng chục nghìn khối Nước, đo lại xem có cần tối ưu tiếp không (chưa đo ở quy mô đó)

## PHẦN 13: EXPORT WEB/DESKTOP

Mục cuối trong danh sách "không để là demo" — user chọn làm sau khi đã xong UI/UX và hiệu năng.

### Setup
- Export template: đã bundle sẵn theo bản Godot cài qua Steam (`editor_data/export_templates/4.7.1.stable/`), đúng version project đang dùng — không cần tải/cài thêm gì.
- [x] Viết `export_presets.cfg`: 2 preset "Windows Desktop" (x86_64) và "Web"
- [x] Export Windows: `godot --headless --export-release "Windows Desktop" "builds/windows/karakuri-stream.exe"` — **thành công lần đầu, không lỗi**
- [x] Export Web: `godot --headless --export-release "Web" "builds/web/index.html"` — **thành công lần đầu, không lỗi**
- [x] Thêm `/builds/` vào `.gitignore` (output export, không phải source)

### Verify bằng chạy thật (không chỉ đọc log export)
- **Windows**: chạy trực tiếp `karakuri-stream.exe --position 3000,3000 --quit-after 90` — launch sạch, render GPU thật (Compatibility renderer, NVIDIA), 90 frame không lỗi, exit code 0. Đây là file .exe độc lập, không cần Godot editor để chạy.
- **Web**: serve local bằng Python (`http.server` tuỳ chỉnh, tự thêm header `Cross-Origin-Opener-Policy`/`Cross-Origin-Embedder-Policy` vì Godot Web export yêu cầu — `python -m http.server` trần không tự gắn). Check bằng `curl`: HTTP 200, `index.html` chứa đúng `<canvas>`, kích thước `index.pck`/`index.wasm` trong `GODOT_CONFIG` khớp chính xác file thật trên đĩa (không hỏng khi đóng gói).
- **Giới hạn thật sự**: không có tool điều khiển trình duyệt thật trong phiên này (không chạy được WASM để xác nhận game thực sự load/chơi được trên Web) — đã verify tối đa những gì làm được từ dòng lệnh (server, header, tính toàn vẹn file), phần còn lại (mở bằng trình duyệt thật) cần bạn tự làm.

### Ghi chú kỹ thuật quan trọng
- `variant/thread_support=false` trong preset Web — cố tình tắt để đơn giản hoá yêu cầu server (không cần threading thật trong WASM cho 1 sandbox game nhỏ). Nếu sau này cần bật, phải đảm bảo host set đúng COOP/COEP, nếu không trang load được nhưng game treo lúc khởi tạo.
- Renderer `gl_compatibility` (quyết định từ đầu dự án) chính là thứ giúp export Web/Desktop suôn sẻ ngay lần đầu — không cần đổi gì ở phần render để export.

### Còn treo
- [ ] Tự mở `builds/web/index.html` (qua server local hoặc host thật) bằng trình duyệt thật để xác nhận chơi được — ngoài khả năng tự động hoá của phiên này
- [ ] Chưa cấu hình icon ứng dụng riêng cho bản Windows export (`application/icon=""` để trống, dùng icon Godot mặc định)
- [ ] Chưa deploy lên host thật nào (itch.io/GitHub Pages) — mới chỉ export ra file cục bộ

## PHẦN 14: SAVE/LOAD CÔNG TRÌNH

Mục cuối cùng còn lại trong danh sách "không để là demo" (export ✓ PHẦN 13, hiệu năng ✓ PHẦN 12, save/load — mục này).

### Thiết kế
- Định dạng: JSON array `[{"x","y","z","type"}, ...]` tại `user://save_data.json` — tách biệt hoàn toàn với `user://settings.cfg` (setting âm lượng, không phải dữ liệu gameplay).
- **Không lưu state decor** (rêu/hoa súng/cá/cờ/sparkle) — cố tình. Nhờ kiến trúc reactive (mọi decor tự tính lại từ `block_placed` signal), load lại đúng danh sách khối là đủ để TẤT CẢ decor tự regenerate đúng như cũ, không cần lưu riêng và không có nguy cơ lệch dữ liệu giữa 2 nguồn.

### Refactor trước khi thêm tính năng
Phát hiện: logic "map `BlockData.Type` → `PackedScene` + xử lý riêng cho Nước (duplicate material)" nằm trong `PlacementController._place_block()` — nếu `SaveManager` cần tạo lại node y hệt lúc load, sẽ phải copy-paste logic này, vi phạm DRY và dễ lệch nếu sau sửa 1 chỗ quên chỗ kia.
- [x] Tách ra `scripts/data/block_factory.gd` (`class_name BlockFactory`, static `instantiate(type)`) — cả `PlacementController` (đặt tay) và `SaveManager` (load file) đều gọi hàm này. Thêm khối mới giờ chỉ sửa 1 chỗ (`BlockFactory.SCENES_BY_TYPE`).

### `SaveManager` (autoload mới)
- [x] `save_game()`: `GridManager.get_all_cells()` (thêm mới, quét toàn bộ không lọc type) → serialize → ghi file
- [x] `load_game() -> bool`: đọc file → `GridManager.clear_all()` → với mỗi entry: `BlockFactory.instantiate()` → add con của `get_tree().current_scene` (KHÔNG phải con của SaveManager, autoload nằm dưới `/root`) → `GridManager.set_block()`. Trả `false` sạch nếu file không tồn tại/JSON hỏng.
- [x] `pause_menu.tscn`/`.gd`: thêm nút "💾 Lưu", "📂 Tải" (có `ConfirmationDialog` cảnh báo mất công trình chưa lưu), `StatusLabel` fade báo kết quả từng thao tác

### Verify bằng test thật (round-trip đầy đủ, không chỉ "file ghi ra được")
Dựng cấu trúc đa dạng (cột nước chảy 3 tầng, pond 4 gỗ bao nước, gear+bell) — 11 khối:
```
blocks_before=11, has_save=true
clear_all() → blocks_after_clear=0
load_game() → load_ok=true, blocks_after_load=11
all_cells_match=true          (so khớp CHÍNH XÁC từng cell+type, không chỉ đếm số lượng)
pond_regenerated=true         (decor tự tính lại đúng từ blocks load lại, không cần lưu riêng)
load_with_no_file=false       (xoá file rồi gọi load — trả false sạch, không crash)
```
Một assertion viết sai lúc đầu (`gear_powered_after_load` — quên đặt Nước cạnh Gear trong setup nên kỳ vọng sai) — không phải bug thật, đã xác nhận lại bằng cách soi 6 hàng xóm của Gear trong test đều không có Nước cả trước lẫn sau load.

### Còn treo
- [ ] Chỉ 1 save slot (đè mỗi lần Lưu) — chưa có multi-slot/named-save, chưa cần cho MVP
- [ ] Chưa test bằng tay: bấm nút Lưu/Tải thật trong game, tắt/mở lại game xem có load đúng công trình cũ không (chỉ verify được qua code trực tiếp gọi `SaveManager`, chưa qua click chuột thật)

## PHẦN 15: ĐẠI TU ĐỒ HOẠ "FLOATING DIORAMA" (WABI-SABI) + NƯỚC CHẢY TỪ TỪ

User yêu cầu đổi diện mạo hoàn toàn sang phong cách sa bàn lơ lửng kiểu Townscaper/Ghibli, và sửa nước chảy dần từng tí thay vì hiện hết 1 lúc.

### 2 điều chỉnh vs yêu cầu gốc (đã báo user trước khi làm)
- **Aseprite MCP không dùng**: MCP có tồn tại thật (`D:\Code\SourceCode\Project\Godot x Aseprite MCP`) nhưng (a) chưa đăng ký vào session Claude Code, (b) `ASEPRITE_PATH` trỏ tới bản Aseprite bẻ khoá — thư mục cài chứa Goldberg Steam Emulator + loader "LinkNeverDie" (bằng chứng crack rõ ràng, không phải suy đoán). Từ chối dùng binary lậu dù user nói "nội bộ/đã duyệt" — không có ngoại lệ cho phần mềm trả phí bị crack. → Toàn bộ hình ảnh bằng mesh nguyên thuỷ + shader + particle, không sprite vẽ tay.
- **AO/depth-fade thật không làm được**: renderer `gl_compatibility` (chọn từ đầu cho Web/Mobile) không hỗ trợ SSAO/DEPTH_TEXTURE. Làm xấp xỉ bằng shadow_blur + merge-seam-tối. Ghi rõ trong CODEMAP để không ai tưởng là hàng thật.

### Phase A — Nước chảy từ từ [x]
`water_flow_manager.gd`: BFS vẫn tính 1 lần (giữ logic rerouting PHẦN 8), nhưng thay vì `_add_segment` tất cả trong 1 frame → đẩy vào `_reveal_queue`, `_process` tiết lộ từng ô mỗi `REVEAL_INTERVAL=0.09s` theo thứ tự BFS (dict giữ insertion order = BFS order). Mỗi ô hiện kèm tween scale-in "giọt rơi". Verify bằng test thật: đặt cột 8 tầng + nước → total 56 ô, ngay sau đặt active=0, mỗi tick +1 (1→2→3→4), drain hết ra đủ 56, queue rỗng sạch.

### Phase B — Bầu trời gradient + đảo nổi [x]
`main.tscn`: WorldEnvironment BG_SKY + `ProceduralSkyMaterial` (xanh ngọc→hồng pastel). Ground = 2 CylinderMesh (đĩa trên + côn cụt dưới) cho cảm giác lơ lửng, mặt trên vẫn y=0. Verify ảnh GPU thật.

### Phase C — Bảng màu Wabi-sabi [x]
Gỗ vàng cát, Nước ngọc bích (đổi cả shader default + water_block override), Gear/Bell đồng, đảo xanh sage muted. Thêm `AmbientLeaves` autoload (lá phong cam rơi). **Bug bắt qua ảnh**: lần đầu đảo cháy trắng + lá vàng — do `ambient_light_source=SKY` (bầu trời hồng quá sáng) + tonemap Filmic over-expose, và lá per-pixel bị ánh sáng rửa trôi màu. Fix: ambient màu cố định vừa phải, bỏ tonemap, lá unshaded giữ màu cam. Re-verify ảnh: đúng.

### Phase D — Splash particle + jelly [x]
`water_flow_manager._spawn_splash`: ô nước rơi chạm khối/đất → chùm hạt cầu trắng scale-to-0 (curve). `placement_controller._animate_drop`: lún sâu hơn (y 0.55) + nảy `TRANS_ELASTIC` cho dẻo. Verify smoke (splash transient khó bắt ảnh tĩnh, logic giống Firefly/Gear đã verified).

### Phase E — UI icon-only ẩn hiện [x]
Viết lại `material_ui.gd` (dựng toàn bộ bằng code, main.tscn chỉ còn Control rỗng): dải dọc mép trái, 4 icon = `SubViewport` render CHÍNH mesh khối thật (Gỗ/Nước/Gear/Bell) + đèn key/fill + camera, khối tự xoay. Auto-fade theo khoảng cách chuột-mép trái (mờ còn 0.18, không ẩn hẳn). Verify ảnh: 4 icon 3D hiện đúng từng loại khối, dải dọc trái, cảnh tổng thể đúng phong cách.

### Còn treo
- [ ] Auto-fade khi chuột xa mép: chỉ verify được trạng thái hiện-rõ bằng ảnh tĩnh; hiệu ứng mờ dần cần bạn tự rê chuột thật để cảm nhận
- [ ] Splash + jelly + lá rơi + xoay icon: chuyển động thật cần mắt bạn xem real-time (ảnh tĩnh không thấy)
- [ ] AO/soft-shadow thật (cần đổi Forward+, mất Web/Mobile nhẹ — đánh đổi lớn, chưa làm)
- [ ] Base cone đảo chỉ thấy khi orbit camera xuống thấp; camera mặc định nhìn từ trên chưa lộ hết hiệu ứng "lơ lửng"

## PHẦN 16: BIG UPDATE ĐỒ HOẠ (shader bề mặt + nước + post + mesh chi tiết)

User yêu cầu "big update toàn bộ hình ảnh, vẽ thật đẹp chi tiết". Hỏi ưu tiên → chọn CẢ 4 (shader bề mặt, nước, không khí/post, mesh & decor). Làm 4 phase, verify từng phase bằng ảnh GPU thật. Vì Aseprite crack không dùng → toàn bộ bằng shader procedural + mesh + particle.

### Phase 1 — Shader bề mặt [x]
`shaders/wood.gdshader` (vân gỗ procedural theo world-pos + value-noise, rim-light cạnh) cho wood_block. `shaders/metal.gdshader` (rim sheen + emissive nhẹ) cho gear/bell. Đổi 3 block tscn từ StandardMaterial sang ShaderMaterial. Verify ảnh: icon UI hiện rõ vân gỗ/kim loại.
- **Bug bắt qua ảnh**: lá phong đổ bóng → rải đốm tối khắp đảo. Fix: `particles.cast_shadow = OFF`.

### Phase 2 — Nước nâng cấp [x]
`water.gdshader`: sóng đa hướng (3 sine khác hướng), gradient độ-sâu-giả theo fresnel (`deep_color`), caustic shimmer mặt trên, sparkle đỉnh sóng (emissive cho bloom). Giữ nguyên uniform cũ (flow/edge_mask) cho tương thích. CHỈ mặt trên đội sóng (mặt bên phẳng tránh rách seam). Verify ảnh: nước có chiều sâu jade.

### Phase 3 — Không khí & post [x]
`main.tscn` Environment: glow/bloom (`glow_hdr_threshold=1.0` tránh cháy), fog mật độ thấp, adjustment color-grade (saturation 1.15). Đều chạy trên gl_compatibility. Verify ảnh.
- **Tune qua ảnh**: glow lần đầu quá mạnh (cột nước cháy trắng) → giảm intensity 0.5→0.35, threshold 0.92→1.0.

### Phase 4 — Mesh chi tiết [x]
Gear răng thật (`scripts/blocks/gear_block.gd` dựng 10 răng con của MeshInstance3D → quay cùng). Bell quai + đỉnh + quả lắc (author trong tscn). Koi đuôi prism, lá sen khía + hoa súng hồng (50%), rêu cụm 4-6 blob nhiều sắc xanh. Verify: isolation test `mesh_child_count=10` cho gear, ảnh cận cảnh hiện răng gear + chuông chi tiết + vân gỗ chevron rõ.
- **Bug harness (không phải bug game)**: dev_shot ban đầu dùng `get_tree().current_scene.add_child` → khối đặt sai về (0,0,0). Isolation test chứng minh path thật (`add_child` self, đúng như PlacementController/SaveManager làm) hoạt động chuẩn (pos đúng, 10 răng). Đổi harness sang add_child self → mọi khối render đúng vị trí.

### Files
Mới: `shaders/wood.gdshader`, `shaders/metal.gdshader`, `scripts/blocks/gear_block.gd`, `scripts/autoload/ambient_leaves.gd` (đã có từ PHẦN 15). Sửa: `water.gdshader`, `main.tscn` (Environment + Ground), 4 block tscn, `decor_manager.gd`, `pond_decor_manager.gd`, `placement_controller.gd`.

### Còn treo
- [ ] Toàn bộ chuyển động (sóng/caustic/sparkle nước, gear quay, lá rơi, koi bơi, glow) cần mắt xem real-time — ảnh tĩnh không thể hiện
- [ ] Vân gỗ hơi đậm (chevron rõ) — nếu thấy rối mắt, giảm `grain_strength` trong wood_block.tscn
- [ ] Vẫn không có AO/soft-shadow/reflection thật (giới hạn gl_compatibility, đánh đổi cho Web/Mobile)

## PHẦN 17: NƯỚC ISOSURFACE + BÁNH RĂNG TRUYỀN ĐỘNG + KHỐI PHỒNG (Overhaul 2)

User vẫn thấy "block vô hồn" → chọn bản tham vọng: nước 1 thực thể liền, bánh răng ăn khớp truyền động, bo tròn cả Gỗ+Nước. 3 phase, verify từng phase bằng ảnh GPU thật + benchmark.

### Phase 1 — Nước isosurface (metaball) [x]
- `scripts/data/iso_surface.gd` (`class_name IsoSurface`): **Surface Nets** (chọn thay Marching Cubes để khỏi bảng 256-entry, ít lỗi transcription, mặt blob mượt hợp nước). Test riêng: 2 metaball → fuse thành 1 blob liền, 636 vert, no NaN.
- `scripts/autoload/water_surface_manager.gd`: gom mọi ô nước (khối đặt + `WaterFlowManager._active_flows`) → density field → 1 isosurface gộp → gán `water.gdshader`. Throttled rebuild 0.05s.
- `WaterFlowManager` viết lại: KHÔNG render segment nữa, chỉ track tập ô + bắn `flow_changed`. `water_block.tscn` bỏ mesh (giữ collision). Nước gỡ khỏi `MERGEABLE_TYPES`. `water.gdshader` viết lại world-space (bỏ UV/edge_mask/v_is_top).
- **Bug bắt qua benchmark**: metaball `K/d²` (support vô hạn) → density tích luỹ trên pool dày → surface phình quá vùng mẫu, bị clip → 64 ô chỉ ra 56 vert. Fix: falloff HỮU HẠN `(1-(d/R)²)²` (bounded) + cull khoảng cách + margin ≥ R. Sau fix: 64 ô → 1644 vert đúng.
- **Benchmark/tune**: res 3 → 62ms (chậm cho rebuild mỗi flow-tick). Giảm `SAMPLES_PER_CELL` 3→2 → 20.7ms cho pool 64 ô (worst-case hiếm; pool thường <20 ô → <5ms). Chấp nhận.
- Verify ảnh: nước là khối liquid teal liền mạch (thác cong bao cột, pool bao viền khay) — đúng "thực thể nước thật".

### Phase 2 — Bánh răng truyền động [x]
`gear_manager.gd` viết lại: mỗi frame dựng đồ thị liên thông Gear (BFS 6 hướng), component quay nếu ≥1 gear `_is_driver` (chạm nước). Chiều quay = parity `(x+y+z)` — lưới 6-hướng là **bipartite** nên ô kề tự động ngược chiều, KHÔNG cần BFS chiều. Verify test: hàng 4 gear + 1 nước đầu → deltas `[+0.6,-0.6,+0.6,-0.6]` (cả 4 quay, xen kẽ chiều = ăn khớp thật), gear lẻ không nước đứng yên.

### Phase 3 — Khối gỗ phồng (pillow) [x]
`block_mesh_builder.gd`: mỗi mặt lộ chia lưới `SUBDIV=4`, đẩy đỉnh giữa ra theo normal `PILLOW=0.06`, đỉnh mép giữ nguyên → khối mềm kiểu Townscaper mà mép chung không xê dịch (merge khít, không hở góc). Đây là cách Townscaper thật làm (khối phồng, không phải bevel cứng). **Bug winding sub-cell** (đảo p01/p10 → lộn mặt) — sửa, verify ảnh cận cảnh: khối solid mềm mại, cầu thang merge khít.

### Còn treo
- [ ] Rebuild isosurface worst-case (pool ~64 ô đang đổ đầy) ~20ms/lần → có thể giật nhẹ 1 frame khi vừa đổ đầy pool cực lớn; nếu cần, tối ưu bằng scatter (splat per-cell thay vì gather per-sample) hoặc rebuild vùng đổi. Chưa cần cho quy mô thường.
- [ ] Nước isosurface hơi phồng/bulbous (metaball R=1.4) — nếu muốn nước "gọn" hơn, giảm `METABALL_R` (nhưng phải giữ đủ để ô kề fuse).
- [ ] Chuyển động thật (nước chảy/sóng, gear quay ăn khớp, gỗ phồng khi orbit) cần mắt xem real-time — ảnh tĩnh không thể hiện.

## PHẦN 18: FIX 3 PHẢN HỒI (nước xuyên, particle đặt khối, gear ăn khớp)

Feedback sau khi xem Overhaul 2:
1. **Nước nhìn xuyên qua vách xa** (X-ray). Nguyên nhân: mặt nước trong suốt không ghi depth → vũng dạng vòng nhìn qua vách gần thấy vách xa. Fix: `water.gdshader` thêm `depth_draw_always` (vách gần ghi depth che vách xa, vẫn blend với nền sau) + tăng opacity (water_color.a 0.72→0.9, deep 0.9→0.97), giảm foam 0.28→0.22. Verify ảnh: vách nước đục hoàn toàn, hết xuyên.
2. **Thiếu phản hồi môi trường khi đặt khối**. Thêm `placement_controller._spawn_place_effect(type, pos)` gọi qua tween callback đúng lúc khối CHẠM đất: Gỗ→bụi đất nâu, Nước→tia nước sáng bắn, Gear/Bell→tia kim loại. Chỉ ở đặt-tay (PlacementController), KHÔNG ở SaveManager.load (tránh nổ particle hàng loạt lúc tải).
3. **Bánh răng đặt cạnh nên khớp để quay**. `gear_manager.gd`: lệch pha nửa răng (`HALF_TOOTH = TAU/20`, 10 răng) theo parity `(x+y+z)` — răng của bánh này khớp vào KHE của bánh kia (không đụng răng-với-răng), kết hợp quay ngược chiều sẵn có → ăn khớp thật. Set 1 lần khi gear xuất hiện (`_phased`), dọn theo remove/clear.

### Còn treo
- [ ] Particle đặt khối verify bằng smoke (không lỗi) + code y hệt pattern splash/sparkle đã chạy; chưa bắt được bằng ảnh tĩnh (transient) — user tự xem live.
- [ ] Nước vẫn hơi nhợt ở mặt trên hứng sáng trời (opaque rồi nhưng foam+ambient làm sáng) — giảm thêm foam/ambient nếu muốn teal đậm hơn.
- [ ] Phase gear khớp hoàn hảo lúc đặt; nếu thêm gear vào 1 hệ ĐANG quay, gear mới vào đúng pha gốc chứ chưa khớp pha tức thời với hệ (lệch nhỏ, chấp nhận được).

## PHẦN 19: OCCUPANCY-ISOSURFACE (Gỗ+Nước) + GEAR ĐỊNH HƯỚNG THEO MẶT + RĂNG KHỚP (Overhaul 3)

Feedback sau Overhaul 2 — 4 vấn đề ở tầng thiết kế. Chốt với user: (a) Nước + Gỗ đều dựng bằng **occupancy-isosurface** (đổ đầy ô, bo góc, merge liền — KHÔNG phình bong bóng); (b) Nước trong nhẹ (thấy đáy) + chống xuyên vách; (c) Gear trục = pháp tuyến mặt đặt.

### Phase 1 — Occupancy isosurface cho CẢ Gỗ + Nước [x]
- **Trường mật độ mới "union of rounded boxes"** (thay metaball điểm — thủ phạm bong bóng): mỗi ô LẤP ĐẦY cube của nó `inside = min_axes(1 - smoothstep(0.5-r, 0.5+r, |p-c|.axis))`, các ô CỘNG lại (`d += ...`) → 1 ô ra cube bo góc lấp đầy (không phình), nhiều ô liền → 1 KHỐI mịn (mặt phẳng chỗ dày, bo cạnh lộ). Test toán riêng: 1 ô=56 vert (cube bo), 2 ô kề=110 vert (bar liền), 3 ô=164 vert (cột liền) — KHÔNG phình, merge solid. Đúng Townscaper + đúng vật lý nước.
- `scripts/autoload/voxel_surface_manager.gd` (autoload MỚI, thay CẢ `water_surface_manager.gd` lẫn `block_merge_manager.gd`): 2 `MeshInstance3D` (wood/water), mỗi loại gom centers riêng (Nước = ô WATER + `_active_flows`), dựng trường occupancy, `IsoSurface.build`, throttled 0.05s, chỉ rebuild loại dirty. `HALF=0.5, ROUND_R=0.2, ISO=0.5, SAMPLES_PER_CELL=3`.
- Đổi kèm: XOÁ `water_surface_manager.gd` + `block_merge_manager.gd` + `block_mesh_builder.gd` (pillow không còn dùng). `wood_block.tscn` bỏ mesh (chỉ collision, như water). `project.godot`: bỏ 2 autoload cũ, thêm `VoxelSurfaceManager` sau `WaterFlowManager`. `material_ui.gd`: Gỗ/Nước meshless → icon dựng BoxMesh đại diện + shader (`_build_icon_visual`); Gear/Bell vẫn instance scene thật.
- Verify ảnh GPU (vũng vòng gỗ+nước): gỗ merge solid liền, nước đổ đầy ô merge liền — KHÔNG bong bóng (wood 904 vert, water 1482 vert).

### Phase 2 — Water shader trong nhẹ + không xuyên vách [x]
`water.gdshader`: hạ alpha (water_color 0.9→0.6, deep 0.97→0.8) để thấy đáy/đất qua 1 vách nước, giữ `depth_draw_always` để vách gần ghi depth che vách xa (vũng vòng không nhìn xuyên sang mặt bên kia). Verify ảnh: thấy sàn gỗ qua vách nước trước, không lộ vách xa. (2 ô vuông cam trong ảnh = đom đóm decor, không phải bug.)

### Phase 3 — Gear định hướng theo pháp tuyến mặt đặt [x]
- `placement_controller.gd`: lưu `_ghost_normal`; khi đặt GEAR → `axis = Vector3i(round(normal))`, set `block.state["axis"]`, gọi `instance.apply_axis(axis)`.
- `gear_block.gd`: `apply_axis(axis)` orient ROOT (StaticBody3D) qua `_basis_for_axis` (6 pháp tuyến cardinal → xoay 90°/180° cố định) sao cho local-Y (trục đĩa) = axis. Mặt trên (+Y)→nằm ngang; mặt bên (±X/±Z)→dựng đứng như guồng nước.
- `gear_manager.gd` KHÔNG đổi: `mesh_instance.rotate_y` quay quanh Y của KHÔNG GIAN CHA (= root-local Y = axis) nên tự quay đúng trục sau khi root đã orient. Parity counter-rotate vẫn đúng cho gear đồng phẳng kề nhau.
- `save_manager.gd`: lưu `axis:[ax,ay,az]` cho Gear; load → set state + `apply_axis`; save cũ thiếu axis → mặc định +Y (backward-compatible). Test headless save→clear→load: cả 3 gear giữ đúng `state.axis` + orient local-Y (STATE_OK + ORIENT_OK cho +X/+Z/+Y).

### Phase 4 — Răng gear thật sự ăn khớp [x]
`gear_block.gd`: tip răng ra `TOOTH_RADIUS(0.45)+TOOTH_LENGTH/2(0.11)=0.56` — VƯỢT ranh giới ô 0.5, thò sang ô kề. 2 gear đồng phẳng (tâm cách 1.0) overlap band 0.44..0.56; kết hợp lệch pha nửa răng (`HALF_TOOTH`) + quay ngược chiều → răng bánh này LỒNG vào khe bánh kia. Verify ảnh top-down 2 gear kề: răng lồng vào khe, không đụng đầu-đầu.

### Còn treo
- [ ] Mặt trên occupancy hơi lượn sóng (scallop do `SAMPLES_PER_CELL=3` + `ROUND_R`) — đọc như sóng nước nhẹ (ổn cho nước, hơi rõ cho gỗ). Tăng samples sẽ mượt hơn nhưng tốn hơn; chưa cần.
- [ ] `_on_grid_changed` đánh dấu CẢ wood+water dirty (không biết loại ô bị gỡ) → rebuild dư 1 mặt mỗi lần đặt/gỡ. Đặt khối không thường xuyên nên chấp nhận; nếu cần, truyền type qua signal.
- [ ] Gear thêm vào hệ ĐANG quay vào đúng pha gốc, chưa khớp pha tức thời (như PHẦN 18, lệch nhỏ chấp nhận được).

## PHẦN 20: FIX XUYÊN + POLISH HÌNH ẢNH + WATERFALL VÔ HẠN (Overhaul 4)

Feedback sau Overhaul 3: (1) khối merge nhìn xuyên thấu; (2) nước trong suốt quá mức; (3) răng 2 gear phải thực sự đan xen để chạy; (4) cập nhật toàn diện hình ảnh; (5) nước chảy vô hạn ra ngoài map như thác (giữ cơ chế chặn). Chốt với user: waterfall = **particle** ở rìa (isosurface giữ trong map), art = **tinh chỉnh style hiện tại**.

### Chẩn đoán "nhìn xuyên" [x]
Test ảnh cụm gỗ: gỗ KHÔNG xuyên (đặc, cull_back opaque) — vệt trắng là rim-light cháy (bloom threshold 1.0). Thủ phạm "xuyên khi merge" thật ra là NƯỚC quá trong (alpha 0.6 từ PHẦN 19 để "thấy đáy") → nhìn xuyên sang mặt bên kia. Nên bản này ĐẢO lại: nước đục hơn.

### Fix [x]
1. **Nước đục hơn** (`water.gdshader`): water_color.a 0.6→0.88, deep_color.a 0.8→0.97. Giữ `depth_draw_always`. Đọc như khối nước đặc, hết X-ray, vẫn hơi trong ở góc xiên.
2. **Rim-light gỗ hết cháy** (`wood.gdshader` + override trong `voxel_surface_manager._configure_wood_material` + `material_ui.gd`): rim_strength 0.35→0.16, rim_color bớt trắng (1.0,0.92,0.78)→(0.95,0.85,0.68), rim_power 3.5→4.0. (Nhớ: material do manager set_shader_parameter ghi đè default shader — phải sửa CẢ 3 chỗ.)
3. **Dẹp scallop mặt gộp** (`iso_surface.gd`): thêm `_smooth()` — 2 vòng Laplacian (kéo đỉnh về trung bình hàng xóm cạnh, factor 0.5) trước khi tính normal. Mặt gộp mịn hẳn ở `SAMPLES_PER_CELL=3` (không phải tăng sample = không tốn thêm nhiều). Verify ảnh: gỗ + nước mịn, không lồi lõm facet.
4. **Răng gear đan xen thật** (`gear_block.gd` + `gear_block.tscn`): thu hub 0.36→0.28 (răng lộ rõ, đọc thành bánh RĂNG chứ không phải đĩa), răng tip `0.44+0.34/2=0.61` (>0.5, thò sang ô kề), inner 0.27 (tụt dưới hub 0.28 = liền khối). Verify ảnh top-down 2 gear kề + lệch pha giả lập giữa-chừng-quay: răng lồng sâu vào khe nhau, giữ khớp khi quay.

### Waterfall vô hạn (particle) [x]
`water_flow_manager.gd`:
- Cap CAO: `MAX_FALL_CELLS` 60→200, `MAX_POOL_CELLS` 24→260 → nước tràn khắp đảo (bán kính đảo `MAP_RADIUS=8.5`, xem `main.tscn` IslandTop=9.0).
- BFS pooling: ô mà hàng xóm ngang ra ngoài `MAP_RADIUS` (`_beyond_rim`) = **pour cell** → KHÔNG pool isosurface ra trời (giữ mesh bounded/nhanh), đánh dấu `_pour_candidates`, dừng lan hướng đó. Cơ chế chặn dòng (has_block) giữ nguyên.
- `_refresh_waterfalls()` (quản như `_source_audio`): pour candidate nào ĐÃ được reveal (`_active_flows`) → spawn `_make_waterfall()` (GPUParticles3D giọt nước đổ thẳng xuống, lifetime 2.2s, gravity -9, visibility_aabb cao 15 để không bị cull), cap `MAX_WATERFALLS=48`. Ô khô/biến mất → free. Dọn ở `grid_cleared`.
- Test headless (nguồn nước gần rìa): active_flows=20, pour_candidates=48, waterfalls=3 (số pour đã reveal), **active_beyond_rim=0** (isosurface đúng là chỉ nằm trong đảo, phần ra ngoài là particle).

### Còn treo
- [ ] Flood cả đảo (200+ ô) reveal tuần tự ~0.09s/ô → mất ~20s mới đầy hẳn (hiệu ứng trickle — hợp game thư giãn, nhưng ai muốn nhanh thì giảm `REVEAL_INTERVAL`).
- [ ] Waterfall particle đổ xuống "trời" vô tận (lifetime giới hạn nên biến mất sau ~2.2s rơi) — trông như thác đổ vào mây, không có bể hứng. Đúng ý "đổ ra ngoài map".
- [ ] `_smooth()` Laplacian có thể co nhẹ silhouette ở chi tiết rất nhỏ (1 ô lẻ) — không đáng kể ở `factor=0.5, passes=2`; tăng passes sẽ co nhiều hơn.
- [ ] Chuyển động thật (gear quay khớp, nước chảy + waterfall, sóng) cần xem real-time — ảnh tĩnh chỉ xác nhận hình học/màu.

## PHẦN 21: ÁP MODEL 3D ART (assets/3DModel) — zen gỗ

User có sẵn model art trong `assets/3DModel` (form ý tưởng thiết kế = moodboard: zen-garden diorama gỗ ấm). Chốt: **Hybrid** cho Gỗ/Nước (giữ merge+flow, chỉ lấy PALETTE từ model), swap model cho Gear/Bell.

### Preview model (đo AABB + render lưới)
wooden-foundation-block.obj = slab dẹt 1.1×0.42 (xám, obj không load .mtl); teal-water-block.glb = cube nước teal + foam + lá sen; wooden-cogwheel.glb = bánh răng gỗ TO (2.4); zen-chime.glb = chuông trên giá (~1 cao); bamboo-water-pipe = ống tre tí (0.32); zen-garden.glb = cả diorama đảo (2.5×4.5). → Gỗ/Nước là isosurface meshless nên KHÔNG thay được bằng model per-block (mất merge+flow); chỉ Gear/Bell (có mesh thật) swap được.

### Làm [x]
- `scripts/data/mesh_fit.gd` (`class_name MeshFit`): `local_aabb` (AABB mọi MeshInstance3D con, không cần vào tree) + `fit_centered(model, target)` (scale theo max ngang, dời tâm về gốc — cho gear xoay quanh tâm) + `fit_bottom(model, height, floor_y)` (scale theo cao, đáy chạm sàn ô — cho bell đứng). Robust với model có pivot/scale bất kỳ.
- **Gear** (`gear_block.tscn` + `gear_block.gd`): bỏ răng parametric, con "MeshInstance3D" thành pivot RỖNG (GearManager vẫn xoay/phase nó), `_ready` nạp `wooden-cogwheel.glb` vào pivot + `MeshFit.fit_centered(.., 1.15)` (răng tip ~0.57 > 0.5 → lồng gear kề). Giữ `apply_axis` (orient ROOT theo trục đặt). GearManager KHÔNG đổi.
- **Bell** (`bell_block.tscn` + `bell_block.gd` MỚI): bỏ mesh dựng tay, `_ready` nạp `zen-chime.glb` + `MeshFit.fit_bottom(.., 0.95, -0.5)`. Thuần visual; GearManager gõ chuông qua type + `node.global_position` (không đổi).
- **Palette Gỗ/Nước** (giữ merge): `wood.gdshader` base/grain theo `wooden-foundation-block.mtl` (wood_top 0.571,0.323,0.109 / wood_side 0.462,0.234,0.068); `water.gdshader` color/foam theo `teal-water-block.mtl` (Kd 0.028,0.468,0.434 / foam 0.93,0.90,0.84). Sửa CẢ shader default + `voxel_surface_manager._configure_wood_material` + `material_ui` icon (material do manager ghi đè default).
- Verify ảnh: 2 gear gỗ nằm ngang lồng răng nhau + 1 gear dựng đứng (guồng nước, trục chìa ra) + chuông zen trên giá + gỗ nâu ấm merge + vũng nước teal — đồng bộ style moodboard.

### Còn treo
- Gear model ~12 răng (không phải 10 như `GearManager.TOOTH_COUNT`) → lệch pha `HALF_TOOTH` không khớp khe tuyệt đối, nhưng counter-rotate + overlap vẫn đọc như ăn khớp. Muốn chuẩn: đếm răng model, set `TOOTH_COUNT` khớp.
- Model cogwheel material sáng (kem) + bloom → gear hơi chói; giảm glow threshold nếu muốn trầm hơn.
- zen-garden.glb + bamboo-water-pipe CHƯA đặt in-game (moodboard). Sau này có thể: bamboo-pipe = decor vòi nước ở nguồn (spill source), zen-garden = vật trang trí trung tâm.
- `metal.gdshader` giờ không còn ai dùng (gear/bell theo model); giữ lại phòng khi cần.

## PHẦN 22: SINH TOÀN BỘ ASSET BẰNG BLENDER THEO artstyle.md

User có `artstyle.md` (chunky+bevel, matte flat, palette hex, fit 2×2×2) + Blender (`D:\Apps\Blender\blender.exe` 5.2). Yêu cầu: dùng Blender làm lại TOÀN BỘ object đồng bộ, cả cây cỏ + nước.

### Pipeline Blender headless (đã dựng)
- `scratchpad/stylekit.py` (copy vào `assets/3DModel/generated/`): style kit đúng master prompt — `hexc()` sRGB→linear cho palette (Wood D4A373 / Bamboo 8CB369 / Water 48CAE4 / Stone BDBDBD / Accent E07A5F), builder primitive (cyl/box/cone/ico/uvsphere), `finish()` = Bevel modifier (limit angle) apply + Shade Auto Smooth, `mat()` matte (roughness 1, metallic 0, spec 0.1), `export()` glb.
- `gen_assets.py`: 1 hàm/asset → 11 glb. Chạy `blender --background --python gen_assets.py -- <outdir>`.
- `contact.py`: import 11 glb thành lưới, render Cycles iso-ortho nền beige → `_contact_sheet.png`.
- Vòng lặp render→xem→sửa: grass ban đầu xòe ngang (Y-rotation sai) → sửa nghiêng theo bán kính; cogwheel/bamboo chỉnh tỉ lệ.

### 11 asset (assets/3DModel/generated/*.glb)
wood_block, water_block (jelly), cogwheel, chime, grass_tuft, bamboo_stalk, bamboo_pipe, lily_pad (khía+hoa), rock, lantern, bonsai. Palette verify bằng dump Godot: albedo khớp CHÍNH XÁC hex artstyle.

### Ráp vào game
- **Gear** → `generated/cogwheel.glb`; **Bell** → `generated/chime.glb` (repoint `MODEL` const; giữ MeshFit).
- **MeshFit.matte()** (MỚI): glTF import để `metallic_specular=0.5` → bề mặt mượt bị chói (chuông đá #BDBDBD thành trắng). `matte()` duplicate material → ép metallic 0 / spec 0 / roughness 1. Gọi sau fit ở gear/bell/lily/grass.
- **Palette Gỗ/Nước** (giữ isosurface merge): `wood.gdshader` = #D4A373, `water.gdshader` = #48CAE4 (+ sửa override ở `voxel_surface_manager` + `material_ui`). Đồng bộ với model.
- **Cây cỏ + Nước**: `PondDecorManager._add_lily_pad` → instance `lily_pad.glb` (bỏ dựng disc/notch/flower tay); `DecorManager._spawn_moss` → instance `grass_tuft.glb` + vài blob rêu gốc (giữ grow tween). Verify ảnh: lá sen model nổi trên ao, cỏ mọc trên gỗ.
- Verify in-engine: gỗ sand + nước cyan jelly + gear/bell model matte + lá sen — đồng bộ style. Boot + import sạch.

### Còn treo / chưa auto-đặt
- rock, lantern, bonsai, bamboo_stalk, bamboo_pipe: asset đã sinh + đúng style nhưng CHƯA có rule đặt tự động (chưa rõ đặt đâu). Chọn 1: (a) thành loại khối đặt được trong material bar; (b) decor ngẫu nhiên (rock/bonsai/lantern rải trên gỗ, bamboo-pipe ở nguồn nước); (c) trang trí trung tâm.
- Chuông đá #BDBDBD vốn sáng → dưới key light + bloom hơi chói; giảm glow threshold hoặc hạ sáng bell nếu muốn trầm.
- Bevel block Gỗ/Nước model (0.14/0.22) chỉ dùng cho ICON (khối in-game vẫn là isosurface). Nếu sau muốn bỏ isosurface, đã có model per-block sẵn.
- Tất cả model author trong bevel 0.05 seg2 theo spec (block dùng bevel to hơn cho pillow look — lệch có chủ đích, đã ghi).

### Audit animation sau khi swap model (headless, đo số thật)
Lo swap model làm hỏng animation. Verify:
- **Bánh răng quay**: GearManager xoay con "MeshInstance3D" (giờ là pivot chứa cogwheel model) — rot.y đổi qua thời gian khi gear chạm nước ✓.
- **Nước chảy**: `_active_flows` tăng + sóng shader + reveal + waterfall particle ✓.
- **Bèo nổi lềnh bềnh**: `PondDecorManager._pad_data` bob node wrapper (model lá sen bên trong) — y dao động ✓ (tăng biên độ 0.015-0.03 → 0.035-0.06 cho dễ thấy).
- **Cỏ đung đưa** (THÊM): `DecorManager._grass_data` — sway rot.z/x nhẹ theo sin trong `_process` (như cờ). Verify: rot.z đổi qua thời gian ✓.
Các animation khác không đụng: Koi bơi, cờ bay, đom đóm, lá phong rơi, sparkle gear, drop tween đặt khối, bell strike → chime+firefly.

## PHẦN 23: KARAKURI STREAM — NƯỚC CHẢY QUA ỐNG TRE (pivot gameplay) + sửa model + khung cảnh

User: (1) khung cảnh cỏ cây (Blender), (2) gear+chuông vẽ SAI, sửa, (3) THÊM ống tre dẫn nước — **mục tiêu chính**: chọn 1 điểm phun dòng xuống, dùng ống tre điều hướng, rơi trúng gỗ/chuông/bánh răng tạo âm. Không để nước chảy lung tung. Chốt: giữ ao tĩnh + thêm dòng riêng; ống thẳng + cong 90° (aqueduct); va chạm = ô đích dưới điểm rơi.

### Sửa model (phát hiện lỗi TRỤC Blender Z-up vs Godot Y-up)
Gear/chuông "sai" vì author sai hệ trục: Blender Z-up, Godot Y-up, glTF đổi (x,y,z)→(x,z,-y). Bản cũ dựng wheel trong Blender X-Z (đứng) → Godot thành đứng; cột chuông dùng Blender Y làm "cao" → Godot thành NGANG. Sửa: author "cao" theo Blender Z, wheel phẳng trong Blender X-Y. `gen_fix.py`:
- **gear**: đĩa ĐẶC (cyl) + 10 răng trên vành (dính đĩa, không rời) + hub + trục. Verify Godot: nằm ngang trục đứng ✓, xoay 90° = guồng nước trục ngang ✓.
- **bell**: giá torii (2 cột đứng + xà) + chuông đền (skirt cone + vai dome + quai) treo dưới xà + dây chu sa. Verify: đứng đúng ✓.
- Repoint `gear_block.gd`→`gear.glb`, `bell_block.gd`→`bell.glb`. **Bài học: LUÔN verify orientation trong Godot, không chỉ contact sheet Blender (cũng Z-up nên che lỗi).**

### Model mới (Blender): pipe_straight, pipe_elbow, source + scenery (pine_tree, bush, reeds, rock_cluster)

### Gameplay nước-qua-ống
- **Block types mới**: SOURCE, PIPE, PIPE_BEND (`BlockData.Type`, `BlockFactory`, scenes, scripts). Material bar 7 icon (phím 1-7), R xoay ống. `material_ui._build_icon_visual`: mọi loại trừ Gỗ/Nước dùng model thật.
- **Ống có `state["ports"]`** = 2 đầu mở (Vector3i). Straight: `PORT_SETS` X/Z/Y. Elbow: {+Y đỉnh, 1 bên} × 4. `apply_ports()` orient model theo ports. Đặt: cycle bằng R (`_pipe_rot`). Save/load `ports`.
- **`StreamManager`** (autoload MỚI, sau WaterFlowManager): trace mỗi SOURCE — dir=DOWN, qua PIPE thì vào port `-dir` ra port kia, else rơi (ngang ra khỏi ống → gravity DOWN), tới khi trúng khối/ra map. Gom `_segments` (cylinder nước cyan) + `_impacts` (ô đích → âm mỗi 0.55s: gỗ/pipe→wood_hit, bell→chime+firefly, gear→clack) + `_driven_gears`. Rebuild throttled.
- **Gear driven bởi stream**: `GearManager._is_driver` += `StreamManager._driven_gears.has(cell)` (giữ fallback kề nước tĩnh).
- **Flood NGHỈ**: `WaterFlowManager._get_spill_sources()` → `[]`. Khối WATER = ao tĩnh (VoxelSurface render, Pond mọc bèo/koi), không tràn. Đúng "không lung tung".
- **`SceneryManager`** (autoload): rải 9 prop scenery quanh rìa đảo lúc khởi động.
- Verify: test headless routing (source→elbow→pipe→rơi→gear: segments=7, impact gear, gear spin ✓); ảnh: dòng cyan uốn qua ống tre rơi trúng gear/chuông; main scene có vòng scenery + 7 icon.

### Còn treo
- Ống chỉ straight (3 trục) + elbow (đỉnh+4 bên). Chưa có T/cross, chưa elbow ngang-ngang. Đủ cho toy cơ bản.
- Stream visual = cylinder tĩnh (chưa scroll/chảy động); splash + âm theo nhịp cho cảm giác chảy. Có thể thêm droplet particle chảy dọc sau.
- Scenery vị trí cố định, đá hơi sáng (#BDBDBD). SOURCE luôn phun (chưa có on/off).
- Ghost preview chưa hiện orientation ống trước khi đặt (chỉ thấy sau khi đặt + R).

## PHẦN 24: FIX GỖ MERGE XUYÊN + ĐỒNG NHẤT MÀU NƯỚC

Feedback: (1) gỗ merge nhìn xuyên; (2) màu nước trước/sau ống phải giống nhau; (3) thích màu nước tươi của stream → sửa block nước cho tươi.
- **Gỗ xuyên**: thủ phạm là Laplacian smoothing (PHẦN 20) CO mesh → mối nối mỏng/hở, đặc biệt ô kề CHÉO (bậc thang). Fix: đổi sang **Taubin** (`iso_surface._smooth`: co +λ rồi phồng -μ, net không co) + `VoxelSurfaceManager` `ROUND_R` 0.2→0.26, `ISO` 0.5→0.42 (phồng nhẹ bắc cầu ô chéo). Verify ảnh: bậc thang gỗ merge liền đặc, hết hở.
- **Màu nước đồng nhất + tươi**: `StreamManager._stream_mat` và `water.gdshader` cùng dùng #48CAE4. Water shader: base bias về `water_color` (mix factor 0.6 thay 0.3 → head-on vẫn cyan tươi, không tối jade), `deep_color` sáng hơn (0.2,0.66,0.79), thêm self-emission `water_color*0.08` cho tươi như stream. → nước ao, nước trong ống, nước sau ống đều 1 màu cyan tươi.

## PHẦN 25: FIX "1 CỤC GỖ NHÌN XUYÊN" — thực ra là ẢO GIÁC shader, không phải lỗi hình học

User báo đặt 1 cục gỗ đã nhìn xuyên. Điều tra KỸ: mesh **watertight** (holes=0, nonmanifold=0, **flipped_winding=0** — kiểm bằng phân tích cạnh có/vô hướng), render 8+ góc (4 bên/trên/dưới/orbit) + nền trời đều ĐẶC. → hình học KHÔNG hề xuyên.

Thủ phạm THẬT: **ảo giác nhận thức** (hollow-face illusion) do:
1. `wood.gdshader` cũ vẽ `rings = sin(world_pos.y * ...)` → dải zigzag "W" TỐI ngang mặt, trông như rãnh khắc/nếp lõm → mặt đặc đọc thành rỗng. (artstyle.md vốn muốn flat matte, không texture → banding này sai ngay từ đầu.)
2. Cục bo tròn mềm (ROUND_R 0.26 + ISO 0.42 + Taubin) + matte phẳng, nhìn góc-đối-diện thì lồi/lõm nhập nhằng.

Fix:
- Bỏ hẳn sine "rings", grain = noise 3D mềm low-contrast, `grain_strength` 0.5→0.15, `grain_scale` 6→4 (vân rất nhẹ, flat matte đúng artstyle).
- `SMOOTH_PASSES` 2→1 (cạnh rõ hơn chút) + `rim_strength` 0.16→0.26 (rim-light viền silhouette = cue LỒI, khử nhập nhằng).
- Verify: 1 cục + 2 tầng + bậc thang chéo + khối nước — tất cả đọc RÕ là đặc, hết ảo giác xuyên. (Sửa cả 3 chỗ set param: shader default + `voxel_surface_manager` + `material_ui`.)

## PHẦN 26: FIX 6 PHẢN HỒI (xuyên vẫn còn + nước + bèo + ghost + ống tự nối)

1+4. **Vẫn xuyên (gỗ+nước)**: PHẦN 25 chưa đủ — cục bo tròn MỀM + matte phẳng vẫn nhập nhằng lồi/lõm (hollow-face illusion) từ góc nhìn xuống. Fix TRIỆT ĐỂ: (a) geo CRISP hơn — `ROUND_R` 0.26→0.16, `ISO` 0.42→0.48, `SAMPLES_PER_CELL` 3→4 (mặt phẳng + cạnh rõ, mịn không scallop); (b) **fake-sun bake** trong wood+water shader — `albedo *= mix(dark, bright, dot(world_normal, SUN)*0.5+0.5)` phân biệt MỌI mặt → đọc 3D đặc bất kể camera/đèn scene. Verify red-bg + main env: đặc hẳn.
2. **Nước mất tiếng + không lan**: PHẦN 23 tắt flow. Khôi phục `_get_spill_sources` (mọi ô nước hở đỉnh, kể cả y=0 → lan ngang) + caps NHỎ (fall 40, pool 18) → lan lân cận + tiếng nước loop + waterfall rìa, KHÔNG flood cả map.
3. **Bèo chụm**: `PondDecorManager._spawn_pond` mỗi ô ao chỉ `randf()<0.45` → 1 lá (bỏ luôn-2-lá/ô), koi `<0.3` → rải đều, không đống.
5. **Ghost = model thật**: `placement_controller` bỏ boxmesh ghost, dựng `_ghost_root` = model thật của loại đang chọn, TRONG SUỐT (tint), orient đúng (gear theo normal, pipe theo auto-shape). Rebuild chỉ khi type/shape/orient đổi (key). Gỗ/Nước = box mờ.
6. **Ống tự nối (kiểu ray Minecraft)**: gộp còn **1 loại PIPE** (bỏ PIPE_BEND khỏi bar). `PipeRouting.ports_for(cell)` suy 2 đầu mở từ hàng xóm PIPE/SOURCE → `pipe_block` tự chọn model thẳng/cong + orient, nghe grid đổi để `refresh_shape`. `StreamManager` route qua CÙNG `PipeRouting`. Đặt 2 ống vuông góc → tự thành elbow. Phím: 1 Gỗ,2 Nước,3 Nguồn,4 Ống,5 Gear,6 Chuông (bỏ R). Save: pipe chỉ lưu type (shape tự suy lại). Verify ảnh: source→ống tự bẻ→rơi trúng gear quay ✓ (segments=7).

## PHẦN 27: KIỂM TRA TOÀN HỆ + FIX 5 LỖI (ghost là thủ phạm chính)

1+... **Ghost là NGUỒN GỐC của #2/#4/#5**: ghost dựng bằng BlockFactory.instantiate(type) = full block scene CÓ COLLISION → raycast đặt khối đập vào chính GHOST → sai ô đặt + ghost nhảy loạn (gear/chuông/nguồn "lỗi ghost" + "sai vị trí đặt"). Fix: `_disable_collision()` đệ quy tắt mọi CollisionObject3D (layer=0) + CollisionShape3D (disabled) trong ghost. Verify: mọi loại ghost có visual + **0 collision active**.
1+4. **Vẫn xuyên**: (a) gỗ shader thêm `render_mode cull_disabled` (2 mặt → không mặt nào bị cull, hết mọi khả năng hở dù winding); (b) nước đục hơn `alpha 0.9→0.97`. Xác nhận render red-bg: gỗ đặc.
2. **Nước "chảy mọi nơi"**: giảm caps `MAX_FALL 40→18, MAX_POOL 18→6` (lan cục bộ ~6 ô, không tràn) — phần lớn cảm giác "mọi nơi" là do đặt sai vị trí (ghost bug) tạo nhiều nguồn.
3+6. **Ống T/thập/đa hướng**: bỏ model straight/elbow riêng → dựng THỦ TỤC (hub + nhánh tới mỗi hàng xóm) trong `pipe_block.build_visual(dirs)`, dùng chung ghost. `PipeRouting.connections()` trả TẤT CẢ hàng xóm. `StreamManager._trace` viết lại stack-based **RẼ NHÁNH** (nước tách ở T/thập, có `seen` chống lặp). Verify: T-junction → nước tách 2 nhánh → 2 gear quay (segments=11, impacts=2, driven=2).
5. **Chuông sai vị trí**: cùng nguyên nhân ghost-collision, fix theo #ghost.
- Còn treo: warning "material is null" (1 lần, từ surface glb thiếu material — vô hại, khối vẫn render đúng). Source luôn phun (đúng thiết kế fountain). Nước block vẫn lan nhẹ 6 ô + có tiếng.

## PHẦN 28: FIX 5 PHẢN HỒI (chuông/nước/nguồn/gear) + học tutorial public

Tham khảo public (godotshaders.com toon water; blog gear-mesh Blender): water = depth blend + foam giao tuyến (tránh blow-out trắng); gears = quay NGƯỢC chiều cùng tốc + lệch nửa răng, ăn khớp ở PITCH LINE (không chồng sâu).
1. **Chuông**: (a) `FLOOR_Y=-0.5` sát đất; (b) concept — chuông THỤ ĐỘNG, chỉ kêu khi bị **stream rơi trúng** (StreamManager) hoặc **gear kề quay** (GearManager) gõ → đúng "kết hợp nước/bánh răng"; thêm `bell.ring()` = tween lắc nhẹ khi bị gõ (đọc rõ là phản ứng, không tự kêu). GearManager + StreamManager gọi `ring()`.
2. **Nước lộ khối dưới + chảy không tự nhiên**: (a) z-fighting mặt gỗ/nước trùng ở y=1 → **ISO riêng**: gỗ 0.5 (đúng ô), nước 0.4 (phồng xuống che mối nối); (b) `MAX_POOL 6→0` — nước block TĨNH (cube gọn, không lan lộn xộn), vẫn giữ tiếng + `MAX_FALL` cho nước cao rơi. Dòng chảy chủ đích = Source/Pipe.
3. **Nguồn cạnh nước tự quay vòi**: `source_block.face_adjacent_water()` — xoay vòi (+X) về khối WATER kề. Placement/Save set `grid_cell` + gọi.
4. **2 gear quá sát/dính**: `WHEEL_DIAMETER 1.15→0.96` (tip ~0.46, ăn khớp ở pitch, thân KHÔNG chồng thành 1 blob) + `ROTATION_SPEED 3.0→1.6` (quay chậm, mượt). Verify ảnh: 2 gear RÕ riêng, răng lồng ở ngã ba.
5. Đã học tutorial + áp: giảm foam 0.22→0.08, caustic 0.4→0.18, sparkle 0.9→0.35 (hết đốm trắng); gear theo nguyên tắc pitch-line meshing.

## PHẦN 29: ĐẠI TU ÂM THANH (game phụ thuộc âm thanh)

User đã tự "nhặt" file thật (Freesound) vào `assets/sounds/`: wood-block-hit, chimes-5, water-stream-looped, wooden-gear-rattling, waterflow2, jellybounce. Việc = WIRE chuẩn theo hướng dẫn user (humanization, ngũ cung pitch, reverb, bus).
- **Bus** (`default_bus_layout.tres`): 3 bus — Master (AudioEffectReverb wet 0.3, room 0.72) ← Music (-10dB) + SFX. Mọi SFX qua SFX, nhạc nền qua Music, cùng đổ vào Reverb → vang trong trẻo ASMR.
- **AudioManager**: pool 24 trên SFX. `play_wood_hit`/`play_chime` giữ humanization (pitch ±6%, vol ngẫu nhiên) + **ngũ cung** cho chuông (`PENTATONIC_RATIOS`, đánh loạn vẫn êm). Thêm `make_gear_loop_player` (rattle gỗ "kẽo kẹt" loop, WAV `loop_mode=FORWARD`, pitch jitter chống phase), `play_ambient_note` (nốt ngũ cung 2 quãng tám mềm, bus Music).
- **Tiếng suối**: `StreamManager._refresh_source_audio` — loop nước ở MỖI khối SOURCE (quản create/free theo grid). WaterFlowManager vẫn loop ở nước tĩnh đỉnh.
- **Kẽo kẹt bánh răng**: `GearManager._ensure_creak/_remove_creak` — loop rattle theo MỖI gear đang quay (con của mesh, positional, free theo block; như sparkle).
- **Nhạc nền**: `AmbientMusic` autoload (sau AudioManager) — generative, rải nốt ngũ cung mỗi 2.2–5.5s → zen vô tận, không loop nghe được. Đúng "cheat code ngũ cung" của user.
- Verify headless: source_loops=1, gear_creaks=1, bus Music=1/SFX=2, không lỗi audio. (Headless dùng AudioDriverDummy — cần chạy Godot thật để NGHE + tinh chỉnh volume/reverb bằng tai.)
- Còn treo: cân chỉnh mix (volume từng loại, reverb wet) cần TAI THẬT; file `.mp3 waterflow2` + jellybounce chưa wire (dự phòng); có thể thêm drone nền trầm nếu muốn dày hơn.

## PHẦN 30: MODEL BLOCKBENCH + JELLY CUBE (bắt đầu redraw art)

User muốn vẽ lại model đẹp/chi tiết hơn bằng **Blockbench** (đã nối MCP) + thêm object dễ thương. Chốt: khối tương tác trước; jelly = khối đặt được.
- **Pipeline Blockbench→Godot** (xem `assets/3DModel/blockbench/README.md`): gltf export của MCP hỏng (async→rỗng) → dùng **OBJ**. `bb_bridge.py` (Blender): import OBJ (Y-up, KHÔNG xoay trục), gán màu flat matte theo TÊN part (colormap.json keyword→hex, `_default` fallback), bevel theo % kích thước (0.05 thường, 0.08 cho jelly mềm) + smooth, join → GLB. Godot import → MeshFit.fit + matte. Style flat-màu khớp artstyle; chi tiết = geometry nhiều part (mắt/má như vịt).
- **Jelly cube** (Blockbench): body cyan #48CAE4 + 2 mắt sphere đậm + má hồng + miệng. Wire thành **khối đặt được**: `BlockData.Type.JELLY`, `jelly_block.tscn/.gd` (load `generated/jelly.glb`, MeshFit, **wobble** squash-stretch loop trên wrapper để giữ fit scale), factory, material bar (phím 7), placement. Verify ảnh in-game: mặt dễ thương (mắt+má+miệng), bo tròn, nảy nhẹ.
- **Batch 2 (xong)**: vẽ lại **Gear** (disc+hub+trục+8 răng bo), **Bell** (giá torii gỗ + chuông đá skirt+dome + dây chu sa), **Source** (vòi tre post+node+spout nghiêng+dây) bằng Blockbench → bridge → copy đè `generated/{gear,bell,source}.glb` (script trỏ sẵn, khỏi sửa). Verify ảnh in-game: đồng bộ Ghibli chunky. cmaps + preview lưu ở `assets/3DModel/blockbench/`.
- **Còn lại**: Pipe giữ thủ tục (cube bamboo trong `pipe_block`, không cần model). Wood/Water = isosurface (chỉ shader). Thêm object dễ thương khác (slime, mầm cây có mặt, koi mập, đèn lồng mặt cười) thành khối đặt được — batch sau.

## PHẦN 31: HỆ VARIANT (nhiều biến thể mỗi loại khối)

User: click vào 1 loại khối → có nhiều biến thể (ống kín/hở, gỗ/đất, nước nhiều màu, gear/cối xay...).
- **`block_variants.gd`** (`class_name BlockVariants`): registry `V[type] = [{name, color?/model?/open?}]`. WOOD: gỗ/đất/rêu/đá (màu); WATER + JELLY: 4 màu; PIPE: kín/hở; GEAR: bánh răng/cối xay (model). `get_variant`, `count`, `color_of`.
- **Chọn**: `placement.select_material(type)` — chọn LẠI loại đang cầm → **cycle variant** (click icon / bấm phím lại). Lưu `state["variant"]`. Khi đặt: `instance.apply_variant(v)` nếu có.
- **Render theo variant**:
  - Gỗ/Nước (isosurface): `VoxelSurfaceManager` viết lại — nhóm cell theo `(type, variant)`, mỗi nhóm 1 mesh + material màu riêng (material cache theo hex). Dirt merge dirt, không merge gỗ.
  - Model: `gear_block.apply_variant` swap model gear↔mill (`generated/mill.glb` — guồng nước 6 mái chèo, vẽ Blockbench). `jelly_block.apply_variant` → `MeshFit.tint(model, cyan, màu)` chỉ đổi BODY (khớp albedo cyan), giữ mắt/má. `pipe_block.apply_variant` → `_open` → `build_visual(dirs, open)` hạ thấp thành máng (nước stream ở giữa ô nổi trên → thấy chảy).
- **Icon material bar**: `_on_material_changed(type, variant)` rebuild icon loại đó theo variant (thấy màu/model đổi khi cycle). Lazy-build model (`jelly._ensure_model`, `gear._ready` chỉ build nếu pivot rỗng) để apply_variant chạy được TRƯỚC khi vào tree (icon/ghost).
- **Save/load**: `variant` trong JSON; load set state + apply_variant.
- **`.gdignore`** ở `assets/3DModel/blockbench/` để Godot bỏ qua .obj trung gian (chỉ import .glb ở `generated/`).
- Verify ảnh: gỗ 4 màu, nước 4 màu, jelly 4 màu (body đổi, mặt giữ), gear+mill. Boot sạch.
- Còn treo: pipe hở đọc rõ nhất khi CÓ nước chảy qua (source phía trên → ống dưới hứng). Bell/Source hiện 1 variant.

## PHẦN 32: FIX gear orbit + nước trong + audio

1. **Gear xoay lệch (orbit quanh trục vô hình)**: `MeshFit.local_aabb` **BỎ giá trị return** của `_accumulate` (AABB là value type) → luôn trả rỗng → `fit_centered/fit_bottom` KHÔNG căn tâm. Model Blender cũ ở gốc (0) nên không lộ; model Blockbench toạ độ 0..16 → lệch (0.5,0.5,0.5) → gear quay thành orbit. Fix: `box = _accumulate(...)` capture return. → gear căn tâm (center=0,0,0), xoay tại chỗ; đồng thời sửa fit đúng cho MỌI model Blockbench (bell/source/jelly cũng chuẩn hơn).
2. **Nước trong quá**: alpha 0.97→**1.0** (opaque) ở `water.gdshader` + variant materials (`VoxelSurfaceManager`) + stream 0.98. Đặc như style, hết cảm giác xuyên.
3. **Audio**: gear creak mềm hơn (-12→-19dB, pitch 0.85-1.1→0.62-0.82 = tiếng gỗ trầm, không rít sprocket); nhạc nền ấm hơn (`play_ambient_note` thêm hoà âm nhẹ 40%, nốt trầm hơn). CHƯA rõ user muốn gì cụ thể ở audio — cần feedback (to/nhỏ? thiếu giai điệu? chói?).

## PHẦN 33: FIX nước xuyên (thật) + gear khớp

- **Nước vẫn xuyên**: alpha 1.0 chưa đủ vì `water.gdshader` vẫn `blend_mix` (transparent pass, winding hole của isosurface lộ X-ray) + `cull_back`. Fix GIỐNG WOOD: `render_mode cull_disabled` (bỏ blend_mix + depth_draw_always) → **OPAQUE 2 mặt** → không mặt nào bị cull, không thể xuyên. Verify red-bg: nước teal đặc, hết đỏ lọt. (Nước giờ hoàn toàn opaque — không còn trong; pipe-hở thấy nước là nhờ STREAM cyan riêng, không phải khối nước.)
- **Gear khớp khi kề nhau**: (a) `WHEEL_DIAMETER 0.96→1.1` → tip răng ra 0.55 > 0.5 → 2 gear cách 1.0 overlap 0.1 (răng lồng vào khe, thân/hub vẫn tách ~0.64); (b) `GearManager.TOOTH_COUNT 10→8` khớp SỐ RĂNG model Blockbench → `HALF_TOOTH=TAU/16` lệch đúng nửa pitch → gear parity khác nhau lệch pha + quay ngược chiều → răng lồng khe, không đụng đầu-đầu. Verify ảnh: 2 gear kề răng đan xen.

## PHẦN 34: FIX lily chìm + source stream lệch + pipe hub tròn + open pipe thiếu vách

1. **Lily chìm**: fix `local_aabb` (PHẦN 32) làm `fit_centered` giờ căn tâm lily → hạ thấp; + nước opaque/inflate. Nâng `base_pos.y 0.52→0.62` → lily nổi trên mặt nước (dập dình).
2. **Source stream lệch khỏi ống**: stream ở TÂM ô nhưng vòi model cũ offset +X. Rebuild source (Blockbench) = ống tre ĐỨNG CĂN TÂM (x=8,z=8), miệng ở đáy-tâm → stream từ tâm khớp vòi.
3. **Pipe đầu tròn xấu**: `build_visual` hub SphereMesh → **BoxMesh** (cube 0.34) fill ngã ba/góc sạch, không tròn.
4. **Open pipe chỉ có đáy, thiếu vách**: hack `scale.y=0.5` chỉ bẹp ống. Viết lại `_add_trough`: máng U THẬT = 1 tấm đáy + 2 vách bên (BoxMesh), hở trên, dựng dọc +X rồi xoay `_basis_x_to(d)`. Nước stream (tâm ô) chảy trong máng → thấy rõ. Verify ảnh: source thẳng, pipe kín tube + open máng có nước, lily nổi.

## PHẦN 35: FIX source mất vòi + pipe thẳng liền/rẽ tròn + koi mất

1. **Source mất vòi nối nước**: source PHẦN 34 là ống đứng căn tâm nhưng BỎ vòi. Rebuild (Blockbench "source3") = thân tre đứng căn tâm + **vòi bên** (cylinder [10.2,8.2,8] rot z=90) + spout_tip + node_mid + string_accent. Bridge → `generated/source.glb`. `face_adjacent_water()` xoay root cho vòi +X hướng ô WATER kề.
2. **Pipe: đầu tròn xấu khi thẳng, giữ tròn khi rẽ**: `build_visual` phân nhánh — `straight = dirs.size()==2 and dirs[0]==-dirs[1]`. THẲNG → `_add_tube_through` 1 tube liền (KHÔNG hub) / open → `_add_trough` 1 máng dài. RẼ/ngã ba/xuống/lẻ → **SphereMesh** hub tròn (revert box PHẦN 34) + 1 stub/hướng. Verify ảnh `_pipe3`: run ngang = tube liền sạch, elbow xuống = khớp tròn.
3. **Koi biến mất**: nước opaque (PHẦN 33) che koi chìm. Nâng `swim_y 0.56` (mặt nước, lưng nhô trên nước opaque), body radius 0.09/height 0.32, tail (0.18,0.01,0.14), spawn chance 0.3→0.55. Verify ảnh `_koi`: koi cam bơi ở mặt, lá bèo nổi.

Dọn `_dev_f2*`; headless boot sạch.

## PHẦN 36: KOI MODEL THẬT (Blockbench, thay capsule+prism)

User: "cá làm chi tiết hơn, dùng Blockbench làm con cá thực sự". Koi cũ = CapsuleMesh + PrismMesh thô.

- **Thử 1 (fail)**: thân = chuỗi sphere chồng → bb_bridge chỉ join (KHÔNG union), các vỏ sphere cắt nhau thành "accordion" gợn sóng, vây rời. Bỏ.
- **Thử 2 (OK)**: **box-based** (đúng artstyle chunky Blockbench, bevel 0.08 bo mịn). Project "koi2": thân 4 box thon (main/snout/mid/rear, hẹp dần), đốm đỏ Kohaku 3 box nhô trên lưng (patch_head/back1/back2), mắt 2 box đen, vây coral (caudal top/bot xòe ±18°, dorsal, pectoral ±20°). Export OBJ → `bb_bridge.py` + `koi_cmap.json` (eye #242424 / patch #E24E32 / fin #F2A57C / _default #F5EFE6 trắng) → `generated/koi.glb`.
- `pond_decor_manager._add_koi`: instance `KOI.glb`, `MeshFit.fit_centered(0.52-0.7)` (fit theo max(x,z)=chiều dài) + `matte`. `_process`: `swim_y=0.5`; hướng đầu +X theo tiếp tuyến `rotation.y=atan2(-cos a,-sin a)` (verify a=0→-PI/2 khớp vận tốc +Z); thêm lắc thân `rotation.z=sin(...)*0.12`.
- Verify ảnh: close-up = koi trắng+đốm đỏ+vây+mắt rõ; pond = koi nổi mặt nước opaque. Dọn `_dev_koi*`, boot sạch.

## PHẦN 37: FIX source lệch ống + nước ra lệch (căn tâm)

User: "nối ống tre lỗi, ống đầu tới ống nối lệch nhau, nước ra khỏi ống đầu cũng lệch".

- **Root**: source model có vòi bên lệch +X → `MeshFit.fit_bottom` căn theo AABB → AABB bất đối xứng đẩy THÂN lệch -X khỏi tâm ô. Nhưng `StreamManager` phun stream từ **tâm ô** thẳng xuống, `PipeRouting`/ống dưới cũng ở **tâm ô** → thân source (lệch) ≠ nước (tâm) ≠ ống dưới (tâm) = 3 thứ lệch nhau.
- **Fix**: rebuild source (Blockbench "source4") = ống tre ĐỨNG CĂN TÂM (mọi cylinder tại x=8,z=8), miệng `rim_mouth` ở đáy-tâm; lá `leaf_a/b` đối xứng ±Z (giữ AABB center = tâm). → sau fit_bottom thân vẫn ở tâm ô. `source_cmap`: ring/rim #6E8A3C, leaf #A7C957, bamboo #8CB369. → `generated/source.glb`.
- Kết quả: source thẳng hàng ống dọc dưới, nước rơi đúng tâm khớp miệng. Nước trong ống bị che (stream radius 0.09 < ống 0.15 = chảy TRONG tre, đúng), chỉ hiện khi thoát ra.
- Bỏ vòi bên (đổi lại "connect vào pond bên cạnh" thành thuần trang trí — model đối xứng, `face_adjacent_water` giờ vô hại). Verify ảnh `_pipe_align`: source→ống dọc→elbow tròn→ống ngang→wood đều thẳng hàng.

## PHẦN 38: Open pipe hết khớp tròn (hub hộp thay cầu)

User: ống KÍN nối liên tục không có khớp tròn, nhưng ống HỞ chưa áp dụng — thêm vào.

- Đã có: straight open (2 hướng đối) → 1 máng liền (no hub). Vấn đề còn lại: end/bend/T/cross open dùng `_sphere(HUB_R)` = **quả cầu tròn dính trên máng phẳng** → lạc quẻ.
- Fix `build_visual`: nhánh non-straight, `if open` → `_box(0.34,0.30,0.34)` hub PHẲNG lấp mặt cắt máng; `else` → sphere (ống kín tròn thì cầu tròn hợp). → open run: giữa liền, đầu/góc vuông phẳng, không cầu tròn.
- Verify ảnh `_openpipe`: straight run open liền mạch đầu vuông; T-junction hub hộp lấp tâm 3 nhánh liền, góc vuông. Boot sạch, dev dọn.

## PHẦN 39: Dọn file thừa + wire jelly sound

- **Jelly sound chưa dùng**: `463590__mixtos__jellybounce.wav` có nhưng 0 ref. Wire: `AudioManager.play_jelly_bounce(pos)` (pitch jitter 0.88–1.18, SFX bus) — gọi khi ĐẶT jelly (`placement_controller`) + khi STREAM chạm jelly (`stream_manager._play_impact`, thêm case JELLY).
- **Xóa file thừa** (0 ref, verify trước): GLB `bamboo_pipe/bamboo_stalk/pipe_straight/rock/water_block/wood_block` (+.import) — pipe procedural, wood/water isosurface, rock dùng rock_cluster. Giữ `pipe_elbow.glb` (pipe_bend còn wired factory/stream). Xóa `_shot.png(.import)` stray + `blockbench/rubber_duck.obj` (bỏ dở, không GLB). → 15 GLB còn, đều dùng.
- **Chưa xóa** (cần user xác nhận): `845864__bongath_kh__waterflow2.mp3` — sound nước thứ 2 chưa wire (nước đang dùng 249666 ogg).

## PHẦN 40: Audio chill/mưa (CC0) + scenery đầu map (sakura/núi/petals)

**Audio (CC0 OpenGameArt, public domain):**
- Tải: `chill_ambient.ogg` (Ambient-Loop isaiah658) + `chill_loop.mp3` (Relaxing wipics) + `rain_loop.ogg` (Rain loopable Ylmir).
- Wire `ambient_music.gd`: `_start_bed` loop nhạc chill (random 1/2 track, -17dB) + lớp mưa nhẹ (-25dB) trên bus Music, DƯỚI generative pentatonic notes. Set `stream.loop=true` (ogg/mp3).

**Scenery (Blockbench → GLB):**
- `sakura_tree.glb`: thân+cành nâu + tán 6 sphere hồng #F5B7CE (hoa anh đào). Thêm 2 cây vào ring PROPS.
- `mountain.glb`: 4 sphere thân xanh-xám #86A6A8 + đỉnh tuyết #EAF2F2 (lumpy Ghibli peak). Ring MOUNTAINS 8 núi ở radius 32-42, y -10..-13, height 19-30 → backdrop chân trời qua fog.
- `scenery_manager.gd`: `_place_ring_model` chung; `_add_sakura_petals` (billboard hồng #F5B7CE, gravity nhẹ -0.22, bay dịu) — mùa xuân đối ứng lá thu cam (AmbientLeaves).
- Verify ảnh `_scenery_wide/near`: sakura hồng rõ, núi tuyết bao quanh, petals+lá bay. Boot sạch.

## PHẦN 41: Full UI theme + Main menu (Ghibli garden style)

User: thêm toàn bộ UI game — menu bắt đầu, button, khung lựa chọn — vẽ theo tông màu game, đừng để button trơn.

**Theme thống nhất** `ui/karakuri_theme.tres` (gen bằng script 1 lần, set `gui/theme/custom` project-wide → mọi Control tự đẹp):
- Panel = giấy kem #F4EFE2 bo góc 20 + viền #CDB492 + shadow mềm.
- Button = thẻ gỗ #ECD0A0 bo 14 viền nâu; hover sáng+viền salmon; pressed nâu đậm. Text #4A3F35.
- HSlider = track tre xanh #8CB369 + grabber tròn salmon (texture vẽ code).
- Window/dialog = giấy kem.

**Main menu** `scenes/main_menu.tscn` + `scripts/ui/main_menu.gd` (là main_scene mới):
- Backdrop 3D SỐNG: env sky/fog/glow + đảo (2 cylinder) + camera xoay chậm; scenery autoload (núi/sakura/cây) + petals tự trang trí; nhạc chill tự chạy.
- UI: **biển gỗ** khắc title "KARAKURI STREAM / ～Vườn Thủy Cơ～" (Panel nâu #7A5A3A viền sáng) + nút "▶ Chơi / ⚙ Cài đặt / ✕ Thoát" (thẻ gỗ) + hint chân màn.
- Panel Cài đặt: 3 slider volume theo bus (Master/Music/SFX) lưu `user://settings.cfg`.
- Chơi → `change_scene` main.tscn.

**Pause menu**: theme tự áp (giấy kem + nút gỗ + slider) + thêm nút "🏠 Về menu chính" (unpause → về menu).

Verify ảnh `_menu`/`_menu_settings`/`_game_pause`: title gỗ, nút thẻ gỗ, panel giấy, slider tre+salmon, hotbar có khung gỗ quanh icon 3D. Boot sạch từ menu, dev dọn.

## PHẦN 42: System sweep + fix 2 bug (settings wipe, stale grid qua scene)

Full check: boot menu+game sạch; refs GLB/sound đã xóa = 0 dangling; preload toàn bộ tồn tại; flow test tự động (menu→game→build→save→clear→load→variants giữ) = ALL OK.

**Bug 1 — pause volume xoá settings menu**: `pause_menu._save_settings` tạo ConfigFile MỚI chỉ ghi `master_volume` → wipe `music_volume`/`sfx_volume` (panel menu ghi). Fix: `config.load()` trước khi set+save.

**Bug 2 — stale grid ám menu**: `_on_menu_pressed` chỉ đổi scene. Block nodes chết theo main.tscn nhưng GridManager + VoxelSurface/PondDecor/Stream (autoload, vẽ vào chính mình) SỐNG xuyên scene → isosurface gỗ/nước + koi + stream đè lên menu, state bẩn khi chơi lại. Fix: rời game = `SaveManager.save_game()` → `GridManager.clear_all()` (emit `grid_cleared`, mọi manager tự dọn — verify `get_child_count()==0`/`_ponds`/`_segments` rỗng) → đổi scene. Vào game (`pause_menu._ready`): `has_save()` → auto `load_game()` deferred = seamless continue, không mất công trình.

## PHẦN 43: Hệ MAP THEME — 4 bản đồ, mỗi map một theme nhìn phát biết

User: nhiều map, mỗi map theme riêng RÕ RÀNG, gameplay thư giãn giữ nguyên.

**`scripts/data/map_themes.gd`** (class_name MapThemes, static registry + `current` persist `settings.cfg [map] theme`):
| # | Map | Nhận diện |
|---|---|---|
| 0 | Vườn Xuân | trời hồng pastel, sakura, cánh hoa hồng bay (bản gốc) |
| 1 | Rừng Thu | trời hổ phách, lá cây CAM (recolor), đảo vàng nâu, lá phong rơi |
| 2 | Đồi Tuyết | trời xanh băng, đảo TRẮNG, cây phủ sương, tuyết rơi |
| 3 | Đêm Đom Đóm | trời chàm, đảo tối, thông teal ánh trăng, ĐOM ĐÓM vàng phát sáng bay LÊN (emissive→bloom) |

Mỗi theme: sky top/horizon, fog màu+đậm, sun màu/energy, ambient, island top/base, mountain_tint, foliage target, drift {màu, size, gravity, amount, glow}.

- **`MeshFit.recolor_foliage(root, target)`**: surface albedo XANH-trội (g>r,g>b) lerp 0.85 → target; thân/đá/tuyết giữ nguyên → 1 bộ prop phục vụ 4 mùa.
- **`main_scene.gd`** (script MỚI gắn root main.tscn): `_ready` → `MapThemes.apply_environment(env, sun)` + repaint 2 material đảo.
- **`scenery_manager.gd`**: PROPS đổi key string + slot "feature" (sakura/maple=pine cam/pine tuyết/pine teal); `rebuild()` wipe+đặt lại (gọi khi đổi theme); mountain `_tint_all` multiply; **fix lantern nằm đổ**: GLB authored nằm ngang → heuristic AABB (rộng>cao=đổ) xoay đứng qua WRAPPER (local_aabb bỏ transform root nên rotation phải nằm ở con, fit trên wrapper).
- **`ambient_leaves.gd`**: hạt drift THEO THEME (petals/lá/tuyết/đom đóm — đom đóm gravity dương bay lên + emissive 2.2 ăn bloom); `rebuild()`.
- **Menu picker**: hàng 4 CARD màu trời theme (nền = sky_horizon, viền salmon khi chọn, chữ trắng nếu trời tối); bấm → set+save current, repaint backdrop LIVE + SceneryManager/AmbientLeaves rebuild.

Gameplay 0 đổi (block/nước/gear y nguyên). Verify ảnh 4 theme + menu picker: khác biệt rõ. Boot sạch, dev dọn.

## PHẦN 44: Tối ưu hiệu năng (giữ nguyên animation)

Bench thật (vsync off, 1280x720, máy dev): empty 2.47ms / 250 khối+12 gear 3.51ms → sau tối ưu **1.61ms / 2.58ms (−35%/−26%)** — tiết kiệm GPU-side nên web/mobile (gl_compatibility, yếu 10-20×) lợi hơn nhiều.

1. **Hotbar SubViewports** (nặng nhất): 7 viewport `UPDATE_ALWAYS` = 7 world 3D + 14 đèn re-render MỌI frame. → mặc định `UPDATE_ONCE` (đóng băng frame đầu); chỉ icon ĐANG CHỌN hoặc HOVER = `UPDATE_ALWAYS` + quay (`_refresh_viewport_modes`); strip fade mờ → đóng băng cả selected. Animation giữ đúng chỗ mắt nhìn.
2. **GearManager**: BFS drive-train + probe wetness mỗi frame → `_recompute_power()` theo timer `POWER_RECHECK=0.2s`, cache `_powered`/`_gears_cache`; XOAY vẫn per-frame từ cache → spin mượt y cũ. Guard block null (cache stale 0.2s). Clear cache khi grid_cleared.
3. **Shadow map**: directional 4096→2048 (mobile 1024) — blur 2.5 sẵn, không khác biệt nhìn thấy.

Đã kiểm: voxel isosurface có throttle 0.05s ✓, water_flow queue 0.09s ✓, stream chỉ rebuild khi dirty ✓, particles amount nhỏ ✓. Visual verify ảnh: hotbar đủ icon, shadow mềm, gear khớp. Boot sạch.

## PHẦN 45: 5 KHỐI KARAKURI MỚI (chất automata Nhật — nước→cơ→âm)

User: game chưa đủ chất karakuri — thêm object/mechanic thể loại cần; placeholder block đơn giản, polygon sau.

| Khối | Phím | Mechanic |
|---|---|---|
| **Ống gõ đá** (Shishi-odoshi) | 8 | Stream rót vào → `fill()` mỗi tick (0.55s), đầy 2 tick → LẬT: đổ nước TIẾP xuống dưới (`StreamManager.add_temp_source(cell, 0.9s)`) + "cộc…cốc!" (double knock) + bật lại ELASTIC |
| **Trống gỗ** (taiko) | 9 | Stream rơi trúng HOẶC gear kề mỗi vòng quay → `hit()`: "tùm" trầm (wood pitch 0.52) + squash |
| **Phong linh** (chime) | 0 | 5 VARIANT = 5 nốt pentatonic C-D-E-G-A cố định (màu ống theo nốt) → xếp hàng dưới stream = GIAI ĐIỆU người chơi tự soạn |
| **Hộp nhạc** | - | Gear kề POWERED → tay quay xoay + chơi giai điệu pentatonic 8 nốt preset (chime octave cao, nhỏ) |
| **Gầu múc** (scoop) | = | Kề HỒ + kề GEAR powered → guồng quay + TẠO DÒNG MỚI từ ô mình (nước→cơ→nước, vòng năng lượng karakuri) |

Hạ tầng:
- `StreamManager`: `_temp_sources` (expire msec, prune trong `_process`), `add_temp_source()`, `is_scoop_active()` (kề WATER + kề gear `GearManager.is_powered`); `_rebuild` trace thêm temp+scoop; `_play_impact` route SHISHI→fill/CHIME→ring/DRUM→hit.
- `GearManager`: `is_powered`/`is_powered_neighbor` (đọc cache `_powered`); `_recompute_power` đổi kết quả → `StreamManager._on_changed()` (scoop retrace); `_strike_adjacent_bells` thêm DRUM.
- `AudioManager`: `play_wood_pitch` (1 sample gỗ nhiều tốc độ = cả bộ gõ), `play_drum`, `play_shishi_knock` (double), `play_music_box_note` (chime ×2 pitch).
- Hotbar 12 icon (ICON_SIZE 72→54, gap 8); phím 8/9/0/-/=. Save/load generic tự work (type+variant).
- Placeholder visual = primitives matte đúng palette artstyle (tre/gỗ/đá/chu sa) — sculpt Blockbench sau.

Verify tự động `KARAKURI ALL OK`: shishi lật (temp source xuất hiện), scoop active, music box thấy gear. Ảnh: shishi nghiêng đổ + scoop phun dòng mới cạnh gear quay. Boot sạch.

## PHẦN 46: Sculpt Blockbench 7 model karakuri (đúng mechanic)

User: vẽ lại toàn bộ bằng Blockbench hợp mechanic nhất. 10 GLB mới (phần ĐỘNG tách file riêng để script animate = đúng mechanic):

| Model | GLB | Ghi chú |
|---|---|---|
| Chuông | `bell.glb` | Khung 2 cột + xà + mái torii; chuông ĐỒNG ấm #D9B36C (hết "xô trắng") + vành đậm + quả lắc đỏ |
| Cối xay | `mill.glb` | 6 cánh DÀY + đĩa + hub đậm + băng accent (hết cánh gầy) |
| Shishi | `shishi_base.glb` (đá+rêu+cột+chạc) + `shishi_arm.glb` (ống tre+đốt+band đỏ) — arm instance dưới pivot `_arm` → tip animation | 
| Trống | `drum.glb` | Taiko: thùng phình + da kem + đai + đinh đỏ + chân xoạc — squash cả model khi hit |
| Phong linh | `chime_frame.glb` (cột+arm+hook) + `chime_tube.glb` (ống+cap+lắc+giấy gió) — tube dưới pivot `_swing`, TINT theo nốt (`MeshFit.tint` từ base #9BD4CE); fatten ×1.7 ngang (fit uniform quá mảnh) |
| Hộp nhạc | `music_box.glb` | Hộp chạm + nắp inlay đỏ + TRỤC NHẠC lộ pin + trục quay; knob tay quay giữ procedural (xoay) |
| Gầu múc | `scoop_mast.glb` (cột+chân+ổ trục) + `scoop_wheel.glb` (hub+4 arm+4 cup đỏ, mặt XY trục Z) — wheel dưới pivot `_wheel` quay |

Pipeline như cũ (OBJ → bb_bridge + cmap → GLB). 5 script đổi primitives → GLB, MECHANIC GIỮ NGUYÊN (fill/dump/hit/ring/tint/melody/spin). Verify: `KARA2 ALL OK` (shishi tip + scoop active với art mới) + ảnh lineup/close/in-game. Boot sạch.

## PHẦN 47: Audit toàn bộ 3D art

Render lưới MỌI type × variant + decor, 3 góc. Kết quả:
- **1 vấn đề thật**: 5 màu nốt phong linh pastel (#9BD4CE…#F2D3A8) washed TRẮNG dưới nắng game → không phân biệt nốt, mất mechanic "nhìn màu biết nốt". Fix: bảng saturated `block_variants` — Đô #2FA89A / Rê #3E7EC6 / Mi #7C5BBF / Sol #D14E8A / La #E08A2E. Verify: 5 ống phân biệt rõ.
- Pass: bell đồng, drum taiko, shishi (đá+tre band đỏ), musicbox, scoop wheel, jelly ×4 mặt, koi, lily, mill đứng `apply_axis(±X)` = guồng nước cánh dày ✓, sakura/núi/lantern (đã dựng thẳng PHẦN 43).
- Minor chấp nhận: jelly tím pastel hơi nhạt (chủ ý pastel); gear/mill mặc định nằm phẳng (đúng behavior mặt đặt).

## PHẦN 48: 4 nâng cấp "magic per click" (chạm bar Townscaper)

1. **Undo/redo** — autoload `UndoManager` (stack 200): placement record place/remove (type+variant+gear axis); Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z). Undo remove RESTORE đầy đủ (đường recreate giống SaveManager load: variant, axis, refresh pipe/source). `clear()` khi cần.
2. **Auto-decor mặt gỗ trống** — `decor_manager`: MỌI wood có mặt trên trống, sau 5-13s roll 45% mọc 1 trong {hoa (thân+đầu ấm), cặp đá cuội, mầm 2 lá} — grow-in tween BACK; đặt block đè lên → decor xóa ngay (roll null = không re-roll). Con của block node → clear_all tự dọn.
3. **Click feedback** — `_play_place_sound`: MỖI loại 1 giọng khi đặt (gỗ=knock, nước/jelly=plop, bell=chime, phong linh=NỐT CỦA NÓ, trống=tùm, shishi=cộc-cốc, hộp nhạc=nốt đầu, gear=clack cao, tre=knock 1.1); đặt khối CẠNH NƯỚC → ripple splash trên mặt pond (`StreamManager._spawn_splash`).
4. **Photo mode** — `main_scene`: phím **H** ẩn UI+ghost (placement.photo_mode), **U** xoay nắng 30°/lần (golden hour). 

Verify `POLISH ALL OK`: undo place/remove + redo giữ variant, top-decor spawn đúng parent + xóa khi bị che, photo toggle UI. Ảnh: photo mode sạch + sprouts mọc + nắng xoay. Boot sạch.

## PHẦN 49: 2 khối mới + edge fixes + WEB TEST THẬT

**2 khối mới:**
- **Đèn đá** (STONE_LANTERN): lantern.glb dựng thẳng (heuristic AABB chọn trục xoay theo CHIỀU DÀI — model nằm dọc Z nên xoay quanh X; fix cả scenery ring), panel sáng emissive "thở" (sin 1.7Hz) → ăn bloom, map Đêm lung linh.
- **Chong chóng nước** (PINWHEEL, 3 màu variant): stream chạm → `splash()` spin burst +6 (max 14) + flutter giấy nhẹ, ma sát wind-down. StreamManager impact case mới.
- Hotbar 14 icon (ICON_SIZE 44/gap 6).

**Edge fixes:**
- Placement CLAMP bán kính 12 + y 0..24 — trước đó đặt xa trên collider 50×50 → AABB voxel-grid nổ (2 khối cách 40 ô = 4M+ samples, freeze).
- Shishi bị XÓA giữa lúc đổ → temp source mồ côi phun nước từ ô trống 0.9s — prune theo type ngay trong `_process`.

**WEB EXPORT + TEST THẬT (Chrome headless + puppeteer):**
- Steam Godot export lỗi câm "configuration errors:" → nguyên nhân THẬT: `for_mobile=true` đòi ETC2/ASTC chưa import (message bị nuốt). Fix chuẩn: `textures/vram_compression/import_etc2_astc=true` + dùng official Godot 4.7.1 binary + templates 4.7.1.stable (tải tpz, extract web zips). Preset `web_nothreads` (không SharedArrayBuffer → host tĩnh nào cũng chạy, không cần COOP/COEP).
- Build 51MB (wasm 39 + pck 13.6), `build/` gitignore.
- Test end-to-end qua puppeteer-core: boot OK, **menu → Chơi → đặt khối** hoạt động, **144 FPS (vsync cap) cả trên SwiftShader CPU-render** → GPU thật dư sức. 0 JS error (chỉ warning AudioContext autoplay chuẩn browser).
- **Bug web thật tìm ra**: emoji trong nút (▶⚙✕🔊💾…) = ô vuông tofu (web không có font emoji hệ thống) → bỏ toàn bộ emoji UI text (menu + pause), "～" → "-".

## PHẦN 50: Final mile — camera feel, click juice, render polish, tooltips, icon

User: 4 mục cuối, TẬP TRUNG click-feel + render polish.

**Camera feel** (`orbit_camera.gd` viết lại): quán tính xoay (giữ vận tốc sau nhả chuột, damp exp 6.0) + zoom LERP mượt (không step) + touch: 1 ngón xoay, 2 ngón pinch-zoom.

**Click juice** (`placement_controller.gd`):
- Ghost "thở" (scale sin 5Hz ±2%).
- Đặt khối: RING shockwave đất (torus unshaded kem, scale 0.5→1.5 + fade 0.38s) kèm particles/sound sẵn.
- XÓA khối (trước đây im lặng): knock trầm 0.72 + dust puff + ring — không còn "biến mất vô hồn".

**Render polish**:
- `water.gdshader`: **sky sheen** — fresnel mix về màu chân trời hồng (`sky_tint`, mạnh trên mặt phẳng) = phản chiếu trời giả kiểu Townscaper; ROUGHNESS 0.02 khi lặng + SPECULAR 0.65 → glint nắng nhảy trên sóng.
- `main.tscn` env: **tonemap FILMIC** + contrast 1.09 + saturation 1.2 (brightness 1.02 — thử 1.06 bị washed, hạ lại); glow bloom 0.15.
- **FillLight** mới: directional lạnh #B8CCE8 energy 0.22 từ sau-trên (no shadow) → mặt khuất có ánh xanh, khối tách nền.
- Menu backdrop đồng bộ filmic.

**Tooltips onboarding** (`material_ui.gd`): hover icon → card theme (tên + 1 dòng "khối này làm gì") — dict `HINTS` 14 loại, lộ các cặp luật ẩn (gầu cần hồ+gear, hộp nhạc cần gear quay…).

**Icon + splash**: `icon.svg` mới (ống tre nghiêng + giọt nước + bánh răng gỗ + gợn sóng, nền kem bo tròn); boot splash màu kem phẳng (không logo Godot).

Verify ảnh: nước sheen hồng mép + glint, fill light tách khối, jelly drop squash. Fix `expf`→`exp` (GDScript). Boot sạch.

## PHẦN 51: Full regression suite + fix noise + web final PASS

**Test suite chính thức `tests/regression.tscn`** (giữ lâu dài, chạy: `godot --path . tests/regression.tscn`) — 9 section:
1. MỌI type × MỌI variant (31 combo) place + clear sạch
2. Save → clear → load: variant gỗ/nốt chime/trục gear sống sót
3. Undo×10 → redo×10 → over-undo 15/over-redo 20 (không crash, state đúng)
4. Chuỗi karakuri live: shishi lật + scoop múc + hộp nhạc powered + pinwheel/drum/chime
5. Gear 6 trục đặt đủ 6 mặt
6. Pipe cross/T/dọc + open, refresh không crash
7. Xóa GIỮA hoạt động: shishi đang đổ (orphan prune ✓), source đang chảy, nước có koi/lily (pond decor dọn ✓)
8. Đổi 4 theme liên tiếp: scenery node count ổn định (không leak)
9. Photo mode + nắng 360° + pause save GIỮ music_volume

**Kết quả: REGRESS ALL OK — 0 error 0 warning toàn bộ run.**

**Fix trong quá trình:**
- Gear double-build (ready dựng "gear" rồi apply đè "mill"): `_model_name` skip-same + default DEFERRED → không bao giờ dựng-xé thừa.
- Truy vết "Parameter material is null" (28→16→0): noise engine 4.7 khi free node GLB có surface-override CHƯA render lần nào (chỉ tái hiện khi place+undo CÙNG frame — người chơi không thể). Test sửa lại sát thực tế (1 frame giữa place/undo).

**Web final**: re-export (0 lỗi) + puppeteer smoke: menu → Chơi → đặt khối, 144 FPS, 0 JS error, filmic grade hiển thị đúng trên web.

## PHẦN 52: Audio engineering pass (kỹ thuật thanh âm)

Audit lộ 3 lỗi kỹ thuật + thiếu 4 kỹ thuật chuẩn. Làm lại:

**Bus chain mới** (`default_bus_layout.tres`):
- Master: **HardLimiter** (ceiling -0.5dB) — spam đặt khối không bao giờ clip.
- SFX: **Compressor** (thr -14dB, ratio 3:1, attack 30µs — glue các knock chồng nhau) → **Reverb** (chuyển TỪ Master về đây — trước đây reverb đè cả nhạc nền vốn đã có không gian trong recording = double-reverb đục; giờ chỉ SFX có không gian, bed giữ KHÔ).
- Music: **LowPassFilter 900Hz disabled** — bật khi PAUSE = muffle "lặn xuống nước" (`pause_menu._set_music_muffle`; tắt khi resume + khi về menu).

**Humanize** (`stream_manager`): impacts mỗi tick 0.55s trước đây nổ ĐỒNG LOẠT cùng frame (chord phasey) → giờ mỗi impact delay ngẫu nhiên 0–120ms = nhịp tay người chơi thật. Timer nổ sau khi block bị xóa vẫn an toàn (`_node_of` null-safe — verify).

**Anti-machine-gun** (`audio_manager`): `_can_start(kind)` dedupe 35ms cho wood_hit/wood_pitch (nguồn spam chính); CHIME cố ý không dedupe (nốt chồng = hợp âm mong muốn).

**3D tuning**: pool players `panning_strength 1.4` (stereo rõ trái/phải) + `unit_size 8` + inverse-square attenuation.

**Theme ambience mix** (`ambient_music.apply_theme_mix`): mưa tween 1.2s theo map — Thu -18dB (rõ, ấm cúng), Đêm -24, Xuân -28 (thoảng), Tuyết -44 (tuyết "nuốt" âm). Gọi khi đổi card menu + vào game.

Verify runner: bus topology đúng 5 effect, muffle toggle, rain tween, staggered impacts + xóa giữa chừng — **AUDIO ALL OK**; full regression vẫn **REGRESS ALL OK, 0 error**.

## PHẦN 53: Tắt tiếng hệ ống (user feedback)

Tiếng trong ống tre (nguồn + ống dẫn) quá to → tắt TẠM:
- `_refresh_source_audio`: disable — không spawn water-trickle loop per source nữa (dọn player cũ). Bật lại sau với loop nhỏ + filtered nếu muốn.
- `_play_impact`: PIPE/PIPE_BEND/SOURCE → IM LẶNG (nước đi TRONG hệ ống không kêu; chỉ đích cuối cùng kêu — wood/gear/bell/trống/chime...).
Boot + REGRESS ALL OK.
