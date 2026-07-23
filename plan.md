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
