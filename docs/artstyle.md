1. Phân tích Phong cách chung (The Art Style)Hình khối (Geometry): "Chunky & Beveled" (Dày dặn và Vát góc). Không bao giờ có góc nhọn hoắt 90 độ. Mọi cạnh đều phải được vát (bevel) nhẹ để bắt sáng mượt mà. Số lượng đa giác (polygon) cực thấp (Low-poly) nhưng nhìn không bị gồ ghề (phải bật Smooth Shading).Chất liệu (Material): "Clay & Matte" (Đất sét và Nhám mờ). Không bóng loáng, không phản chiếu kim loại phức tạp. Vật liệu giống như những món đồ chơi bằng gỗ được sơn màu nhám, tạo cảm giác an toàn và dễ chịu.Màu sắc (Color Palette): Pastel / Wabi-Sabi. Bảng màu tĩnh, độ bão hòa (saturation) thấp.Gỗ mộc (Nâu cát ấm): #D4A373Trúc tươi (Xanh lá pastel): #8CB369Nước thạch (Xanh lục lam): #48CAE4Đá/Chuông xỉn màu (Xám ấm): #BDBDBDDây lạt/Điểm nhấn (Đỏ chu sa): #E07A5FTỉ lệ (Scale): Dạng lưới (Grid-based). Mọi vật thể đều phải nằm vừa vặn trong một khối lập phương $2 \times 2 \times 2$ mét để hệ thống tự động bắt dính (snap) chuẩn xác.2. MASTER PROMPT (Dành cho Claude / Blender Agent)Hãy copy toàn bộ khung dưới đây và dán vào phần Custom Instructions (hoặc gửi làm tin nhắn đầu tiên) cho Claude mỗi khi bạn muốn nhờ viết code sinh file .glb.[BẮT ĐẦU MASTER PROMPT]"You are an Expert 3D Technical Artist Agent. Your task is to write Python scripts for Blender (bpy) to generate 3D assets for a web-based Godot game named 'Karakuri Stream'.CRITICAL STYLE CONSTRAINTS (DO NOT DEVIATE):Aesthetic: 'Townscaper' meets Japanese miniature diorama. Cozy, digital toy vibe.Geometry: Ultra low-poly but soft. You MUST apply a Bevel modifier to every sharp edge (Width: 0.05m, Segments: 2). Apply 'Shade Auto Smooth' so the faces look flat but edges catch light smoothly like clay/painted wood.Proportions: Chunky, stylized, and slightly thick (not realistically thin). All base objects must fit perfectly within a $2 \times 2 \times 2$ meter grid logic.Materials: Use ONLY unlit/diffuse flat colors (no complex textures, no metallic, roughness = 1.0). Assign materials using these strict Hex colors depending on the material requested:Wood: #D4A373Bamboo: #8CB369Jelly Water: #48CAE4Stone/Iron: #BDBDBDAccent String: #E07A5FExport: The script must automatically clear the default scene, generate the requested object, apply all modifiers, and export it as a binary .glb file optimized for Godot 4.Acknowledge these rules. I will now give you the name of the object to create."[KẾT THÚC MASTER PROMPT]

## Chống cảm giác "nhựa" (2026-08-04)

Ba thứ cộng lại làm cả game đọc thành đồ nhựa, và không cái nào là màu sắc:

1. **Không có bóng tiếp đất.** Renderer `gl_compatibility` KHÔNG có SSAO — không
   có screen-space gì cả — nên chỗ vật chạm đất chẳng có gì: không tối lại,
   không khe, chỉ hai mảng màu phẳng gặp nhau. Bóng đổ của mặt trời không thay
   được: nó lệch sang một bên, biến mất khi vật đứng trong bóng khác, và không
   nói gì về việc CHẠM. → `scripts/autoload/contact_shadow.gd`: một mesh duy
   nhất cho cả đảo, dựng lại theo throttle như các manager khác, mỗi vệt là một
   quạt 8 cạnh viền trong suốt. Cả vườn = **1 draw call trong suốt**.
   *Bẫy đã dính*: `cell_to_world()` trả về TÂM ô ở `y + 0.5`; lấy `cell.y - 0.5`
   là chôn mọi vệt xuống dưới đảo nửa đơn vị, chỉ vài vệt ở chỗ đất trũng mới ló ra.
2. **Mặt đất là MỘT màu phẳng.** Đảo là bề mặt lớn nhất màn hình — hơn nửa khung
   hình — và chỉ có đúng một giá trị RGB. Một mảng màu đồng nhất to như thế mới
   là thứ đọc thành nhựa, trước cả thiết lập vật liệu. → `shaders/ground.gdshader`:
   nhiễu value 2 quãng trong không gian thế giới, chu kỳ tính bằng ĐƠN VỊ Ô
   (2.4 và 0.45) chứ không phải một hệ số chia mơ hồ, lệch về phía tối vì đất thì
   bẩn chứ không bóng. Hash cố tình KHÔNG dùng `fract(sin(dot()))` — 8 lần `sin`
   mỗi pixel trên bề mặt lớn nhất là thứ target compatibility chịu không nổi.
3. **Không có chút bóng sáng nào.** `roughness 1.0` + specular 0 là bề mặt
   khuếch tán hoàn hảo: định nghĩa vật lý của phấn, định nghĩa thị giác của
   vinyl — và nó nằm trên MỌI prop. `MeshFit.SHEEN_ROUGHNESS 0.88` /
   `SHEEN_SPECULAR 0.16` là ranh giới: không có đốm sáng, chỉ có cạnh bắt nắng.

Cộng thêm: bóng đổ mặt trời từ `opacity 0.55 / blur 3.2` (nhạt và nhoè đến mức
không vật nào có mặt tối) sang **0.72 / 2.2** — một khối không có mặt tối thì đọc
thành hình dán.

**Chi phí đo được** (A/B có kiểm soát, `git stash` rồi đo 3 lần mỗi bên, 800 khối):
không thay đổi trong sai số — 15.1/14.8/15.4 ms có art pass so với 15.4/17.4/16.0 ms
khi stash đi. Lần đo đầu tưởng tụt 87→66 fps là do **máy trôi** giữa các phiên,
không phải do code; đó là lý do phải A/B chứ đừng so với số đo cách đó vài giờ.


## Giãn dải sáng-tối (2026-08-04, đợt 2)

Đo histogram độ sáng một khung hình chơi thật (bỏ thanh hotbar):

| | trước | sau |
|---|---|---|
| Trung vị | 181 | **160** |
| Bách phân vị 25 → 75 | 170 → 186 | 149 → 168 |
| **IQR (độ giãn nửa giữa)** | **16** | **19** |
| Tỷ lệ tối (<90) | 6.3 % | 7.6 % |

Nửa khung hình từng nằm gọn trong **16 mức sáng** — đó chính là định nghĩa của
một bức phẳng. Bãi cỏ là thủ phạm: nó chiếm quá nửa màn hình ở đúng một giá trị.
Ba việc:

1. **Ambient −28 % mọi map.** Ánh sáng môi trường lấp đầy mọi bóng; bớt nó đi là
   cách duy nhất để một khối có mặt tối.
2. **Nền đảo sâu màu hơn ~12 %** — nó là cái cao nguyên trong histogram.
3. **Tối dần ra vành đảo** (`edge_darken` trong `ground.gdshader`). Chỉ thêm
   nhiễu KHÔNG giãn được dải: đo lại thấy IQR vẫn 13, chỉ dịch xuống. Phải có
   một biến thiên diện rộng mới giãn được — và nó cũng đóng khung chỗ người chơi
   đang xây.

Ống tre: mỗi ô và mỗi nhánh lấy một sắc xanh riêng (hash theo ô nên reload không
đổi). Trước đó mọi ống trong vườn đúng một màu phẳng suốt chiều dài — mà ống là
thứ nhiều nhất trên một hòn đảo hoàn chỉnh. Chi phí bằng 0: `MeshFit.bake` gộp
mọi màu phẳng vào một surface màu-theo-vertex.

Nước: `wave_height` 0.025 → 0.042 và `foam_amount` 0.08 → 0.14. Ao tĩnh nhìn từ
camera chơi chủ yếu là MẶT TRÊN, mà ở 0.025 mặt đó gần như không động — đọc
thành một tấm thạch xanh.

**Chi phí đo được** (A/B `git stash`, máy đã dọn sạch process sót):
LITE 24 khối 4.66/4.74 ms → **5.07 ms** (+0.35 ms). 800 khối: không khác biệt
ngoài nhiễu. *Bài học đo đạc*: hai lần trước tôi suýt kết luận sai vì so với số
đo cũ vài tiếng — máy trôi, và có 2 process Godot của chính tôi còn sót chiếm
GPU khiến suite báo lỗi giả "rebuild is town-wide again" (4.7 s cho 3 frame).
Dọn process xong là REGRESS ALL OK. **Luôn A/B trong cùng một phiên.**


## Thử cỏ — và bỏ (2026-08-04)

Đã thử rải ~520 túm cỏ batched (1 draw call) lên đảo để mặt đất có HÌNH KHỐI chứ
không chỉ có màu. **Bỏ sau 5 vòng lặp**, vì ở khoảng cách camera chơi mỗi túm
chỉ vài pixel và luôn đọc thành **rác vụn** chứ không thành cỏ:

- lá phẳng dựng đứng → pháp tuyến NẰM NGANG → không ăn nắng → sợi đen
- đổi sang chóp 3 mặt → vẫn tối
- chóp thấp và bè ra (tỷ lệ ~1:1) → vẫn tối
- đảo chiều cuốn đỉnh (pháp tuyến đang chúc xuống) → vẫn tối
- hạ tương phản xuống gần đúng màu cỏ → vẫn thành đốm

Kết luận giữ lại cho lần sau: **vật thể vài pixel trên nền sáng thì mọi sắc độ
tối hơn nền đều đọc thành bẩn**. Muốn có cỏ thì phải là cụm to hơn (như
`DecorManager` đang làm quanh nước), hoặc dùng shader ghi đè normal cho hướng
lên, chứ không phải hình học nhỏ dựng đứng.

Neo tối thì giữ: mặt dưới đảo sâu màu hẳn (4 map). Nó chỉ hiện khi camera hạ
thấp gần đường chân trời — không đổi histogram ở góc nhìn thường, nhưng đó là
chỗ DUY NHẤT bức tranh pastel này được phép có màu tối thật.


## Sáng lại (2026-08-04, sửa sau phản hồi)

Người chơi thử bản trước và nói: **tối hơn hẳn, không còn tươi sáng**. Đúng. Mỗi
quyết định "tối thêm một chút" đều hợp lý riêng lẻ, nhưng chúng CỘNG DỒN:

| | trước loạt art | sau (quá tối) | giờ |
|---|---|---|---|
| Trung vị | 181 | 160 | **184** |
| IQR | 16 | 19 | **19** |
| Tối (<90) | 6.3 % | 7.5 % | 5.9 % |

Trả lại: ambient 72 % → **92 %** giá trị gốc, màu mặt đảo về nguyên bản, bóng đổ
0.72 → 0.62, `edge_darken` 0.26 → 0.15, `slope_shade` 0.22 → 0.16, và **bỏ hẳn
độ lệch tối** trong nhiễu nền (giờ dao động hai chiều quanh màu gốc).

Giữ lại: bóng tiếp đất, nhiễu nền, ống tre nhiều sắc, sóng nước. Kết quả là độ
sáng bằng — hơi hơn — bản gốc mà **vẫn giữ được dải giãn**. Bài học: đo trung vị
CÙNG với IQR. Chỉ nhìn IQR thì "tối đi" cũng được tính là "khá hơn".

## `tools/uitest.gd` — bấm thử mọi nút

UI dựng hoàn toàn bằng code nên không soi được file scene để tìm dây nối hỏng, và
một nút gạt lỗi chỉ lộ ra khi có người bấm. Script này bấm mọi `Button` trong
menu (hai lần, để thấy nút gạt có thật sự đổi trạng thái không) rồi in ra nhãn
trước/sau:

```
godot --path . --rendering-driver opengl3 --resolution 1280x720 tools/uitest.tscn
```

Nó tìm ra đúng hai lỗi thật:
- `MeshFit.flat()` gán `m.specular` — **StandardMaterial3D ở Godot 4 KHÔNG có
  thuộc tính đó**. Nó rơi vào lớp tương thích Godot 3.x, in cảnh báo kèm
  backtrace cho MỖI material game tạo ra, và không set gì cả. Tên đúng là
  `metallic_specular`. Nghĩa là "sheen" thêm hôm trước chưa từng tồn tại.
- `_retranslate()` ghi chữ ĐÃ DỊCH vào thẻ bản đồ. Godot tự dịch `text` của
  Control mỗi lần đổi ngôn ngữ, nhưng chỉ khi đó vẫn là chuỗi GỐC. Ghi đè bản
  tiếng Việt vào rồi chuyển sang English là nửa menu mỗi thứ tiếng — đúng cái
  "nút trong setting bị lỗi" mà người chơi thấy.
