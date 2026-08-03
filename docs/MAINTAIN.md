# MAINTAIN.md — sổ tay sửa game

Viết cho người **không cần biết lập trình sâu**. Mỗi mục dưới đây trả lời đúng
một câu: *muốn đổi thứ này thì mở file nào, sửa chỗ nào*.

Mọi đường dẫn tính từ thư mục gốc dự án.

---

## 0. Ba lệnh cần thuộc

Mở terminal ngay trong thư mục dự án:

```bash
# 1. Chơi thử
godot --path .

# 2. Kiểm tra không làm hỏng gì  ← LUÔN chạy sau khi sửa
godot --headless --path . tests/regression.tscn
#    → phải in ra: REGRESS ALL OK

# 3. Lỡ sửa hỏng, quay về như cũ (mất mọi thay đổi CHƯA commit)
git checkout -- .
```

**Quy tắc vàng: sửa xong → chạy lệnh 2.** Nếu không ra `REGRESS ALL OK` thì
thứ vừa sửa đã làm hỏng một cơ chế nào đó — đọc dòng `REGRESS FAIL:` để biết
cái gì gãy, hoặc chạy lệnh 3 để quay lại.

---

## 1. Đổi âm thanh

Xem [AUDIO.md](AUDIO.md) — có bảng đầy đủ từng tiếng, đang để bao nhiêu dB,
sửa ở hàm nào. Tóm tắt: hầu hết nằm trong
`scripts/autoload/audio_manager.gd`, mỗi tiếng một hàm, đổi số `volume_db`.

---

## 2. Thêm một loại block mới

Đây là việc hay làm nhất. Có **3 bước**, không hơn.

### Bước 1 — khai tên block

Mở `scripts/data/block_data.gd`, thêm tên mới vào **CUỐI** danh sách:

```gdscript
enum Type { WOOD, WATER, GEAR, ..., HOUSE, LANTERN_MOI }
                                          ^^^^^^^^^^^^ thêm ở đây
```

> ⚠️ **Chỉ được thêm vào cuối, tuyệt đối không đổi thứ tự hay xoá tên cũ.**
> File save của người chơi ghi lại *vị trí* chứ không ghi tên — đảo thứ tự
> là mọi cái chuông trong file save cũ biến thành cái trống.

### Bước 2 — làm scene cho nó

Cách nhanh nhất: trong Godot mở `scenes/blocks/drum_block.tscn` (hoặc block
nào giống nhất), bấm **Scene → Save Scene As…**, lưu thành
`scenes/blocks/lantern_moi_block.tscn`, rồi sửa hình dạng/model bên trong.

### Bước 3 — đăng ký vào danh mục

Mở `scripts/data/block_catalog.gd`, thêm một khối như sau vào danh sách `ALL`:

```gdscript
	{"type": BlockData.Type.LANTERN_MOI, "hotbar": true, "key": KEY_L,
	 "scene": preload("res://scenes/blocks/lantern_moi_block.tscn"),
	 "hint": "Đèn mới — mô tả ngắn hiện khi rê chuột"},
```

Xong. Block tự động có: ô trong thanh công cụ, phím tắt, lưu/tải, hoàn tác.

- `hotbar: false` = vẫn dùng được trong save nhưng **không** hiện trên thanh
  công cụ (dùng cho đồ trang trí thuần).
- `key: KEY_NONE` = không có phím tắt.
- **Vị trí trong danh sách `ALL` chính là thứ tự icon trên thanh công cụ.**

### (Tuỳ chọn) cho nó hành vi

Nếu block cần *làm gì đó* (kêu, quay, nảy…), tạo
`scripts/blocks/lantern_moi_block.gd` và gắn vào scene. Chép từ block gần
giống nhất — ví dụ `drum_block.gd` chỉ có ~25 dòng.

Muốn nước chảy trúng thì nó phản ứng: mở
`scripts/autoload/stream_manager.gd`, tìm hàm `_play_impact`, thêm một
nhánh `BlockData.Type.LANTERN_MOI:` giống các nhánh có sẵn.

---

## 3. Đổi màu / thêm biến thể cho block

Mở `scripts/data/block_variants.gd`. Mỗi block là một danh sách; người chơi
bấm lại icon để đổi qua lại giữa chúng.

```gdscript
	BlockData.Type.WOOD: [
		{"name": "Wood", "color": "#D4A373"},   ← đổi mã màu ở đây
		{"name": "Dirt", "color": "#8B5E3C"},
		{"name": "Màu mới", "color": "#AABBCC"},  ← hoặc thêm dòng mới
	],
```

Mã màu lấy ở bất kỳ trang color-picker nào (dạng `#RRGGBB`). Bảng màu chuẩn
của game nằm trong [artstyle.md](artstyle.md) — bám theo cho đồng bộ.

---

## 4. Đổi bản đồ (mùa / bầu trời / ánh sáng)

Mở `scripts/data/map_themes.gd`. Có 4 map, mỗi map là một khối như thế này:

```gdscript
	{
		"name": "Spring",
		"sky_top": Color(0.42, 0.72, 0.71),      ← màu đỉnh trời
		"sky_horizon": Color(0.92, 0.78, 0.79),  ← màu chân trời
		"fog_color": ..., "fog_density": 0.006,  ← sương
		"sun_energy": 0.9, "ambient_energy": 0.28,  ← độ sáng
		"island_top": Color(...),                 ← màu mặt đảo
		...
	},
```

- **Game sáng quá / bợt màu** → giảm `sun_energy` hoặc `ambient_energy`.
- **Đảo sai màu** → `island_top`.
- **Thêm map thứ 5**: chép nguyên một khối, sửa số, dán vào cuối. Thẻ chọn
  map ở menu tự sinh theo danh sách này.

Màu ở đây viết dạng `Color(r, g, b)` với mỗi số từ 0 đến 1 (không phải 0–255).

---

## 5. Đổi chữ hiển thị trong game

| Chỗ | File |
|---|---|
| Menu chính (Play / Settings / Quit, tên map) | `scripts/ui/main_menu.gd` |
| Menu tạm dừng | `scripts/ui/pause_menu.gd` |
| Dòng gợi ý khi rê chuột lên icon | `scripts/data/block_catalog.gd` (ô `hint`) |
| Tên biến thể ("Wood", "Pink water"…) | `scripts/data/block_variants.gd` (ô `name`) |
| Bảng "How to play" lần đầu chơi | `scripts/main_scene.gd` |

> ⚠️ **Không dùng emoji trong chữ UI.** Bản web không có font emoji, chữ sẽ
> thành ô vuông. Đây là lỗi đã từng gặp thật.

---

## 6. Đổi vườn mẫu (thứ có sẵn khi mở game lần đầu)

`scripts/main_scene.gd`, hàm `_build_starter_garden`. Mỗi dòng là một block
đặt sẵn:

```gdscript
	_starter(Vector3i(-4, 0, -3), BlockData.Type.DRUM)
	             x   y   z          loại block
```

`y = 0` là mặt đất, `y = 1` là tầng trên. Vườn này chỉ dựng **lần đầu** —
người chơi đã có công trình thì không đè lên.

---

## 7. Đổi font chữ

Font pixel do file `tools/font/gen_font.lua` vẽ ra bằng Aseprite. Muốn chữ
mập/gầy khác đi: sửa file đó rồi chạy lại 2 lệnh:

```bash
aseprite -b --script tools/font/gen_font.lua
godot --headless --path . --script tools/apply_pixel_font.gd
```

Muốn quay lại font thường (không pixel): mở `ui/karakuri_theme.tres` trong
Godot, đổi `default_font` sang `assets/fonts/fredoka_chunky.tres`.

---

## 8. Đổi tốc độ / nhịp của máy

| Muốn | File | Chỗ sửa |
|---|---|---|
| Nhịp gõ nhanh/chậm | `scripts/autoload/stream_manager.gd` | `BASE_BEAT` |
| Nước lan nhanh/chậm | `scripts/autoload/water_flow_manager.gd` | `REVEAL_INTERVAL` |
| Bánh răng quay nhanh/chậm | `scripts/autoload/gear_manager.gd` | `ROTATION_SPEED` |
| Nhạc nền dày/thưa | `scripts/autoload/ambient_music.gd` | xem [AUDIO.md](AUDIO.md) |

---

## 9. Game bị chậm / giật

Chạy lệnh đo:

```bash
godot --path . --rendering-driver opengl3 --resolution 1280x720 \
      tools/perf.tscn -- scene=res://scenes/main.tscn lite=0 blocks=24 wood=80
```

Đọc số `worst=` (khung hình chậm nhất) và `over16ms=` (số khung bị rớt).
Bình thường: `worst` dưới ~15ms, `over16ms=0/420`. Nếu tệ hơn nhiều thì thứ
vừa thêm đang tốn — thường là particle hoặc đèn.

Thị trấn đông nhà là ca nặng nhất, đo riêng bằng `houses=48`:

```bash
godot --path . --rendering-driver opengl3 --resolution 1600x900       tools/perf.tscn -- scene=res://scenes/main.tscn lite=0 blocks=24 houses=48
```

Mong đợi `worst` khoảng 12ms, `over16ms=0/420`. Nhà tự giới hạn 3ms dựng hình
mỗi frame (`house_block.REBUILD_BUDGET_US`) nên hình học hội tụ sau vài frame —
**đó là lý do test phải `await _settle_houses()` chứ không chờ số frame cố định**.
Nếu số xấu đi sau khi bạn sửa nhà: xem lại `_digest` trong `house_block.gd`, thêm
một thứ đổi-theo-toà-nhà vào đó là bắt cả thị trấn dựng lại mỗi lần click.

---

## 8b. Sửa chữ / thêm ngôn ngữ

Chữ tiếng Anh trong code CHÍNH LÀ KHOÁ dịch. Muốn sửa bản tiếng Việt: mở
`scripts/autoload/i18n.gd`, sửa vế phải trong `VI`. Muốn sửa chữ tiếng Anh: sửa
tại chỗ trong code **và** sửa khoá tương ứng trong `VI` cho khớp — lệch một ký
tự là chuỗi đó rơi về tiếng Anh.

Thêm ngôn ngữ: thêm một `const XX` giống `VI`, thêm mã vào `LOCALES` và tên vào
`LOCALE_NAMES`, đăng ký thêm một `Translation` trong `_ready()`.

Chuỗi GHÉP lúc chạy (`"Đã lưu vào vườn %d"`) không tự dịch được — phải `tr()`
chuỗi định dạng TRƯỚC rồi mới `%`. Trong game chỉ có ~15 chỗ như vậy, đều đã
đánh dấu bằng `tr(` tại chỗ gọi.

**Chữ có dấu ra ô vuông?** Font pixel và Fredoka chỉ có tới Latin-1. `Nunito.ttf`
nằm CUỐI mảng `fallbacks` trong `ui/karakuri_theme.tres` để vẽ những ký tự hai
font kia không có. Phải để ở mảng đó — Godot không đi tiếp vào fallback của
fallback.

---

## 9b. Thêm một mục vào Sổ khám phá (Journal)

Sổ nằm ở `scripts/autoload/discovery_log.gd`. Thêm 1 mục = 2 chỗ:

1. Thêm vào `ENTRIES`: `id` (chuỗi, đừng đổi sau khi phát hành — nó là khoá lưu
   trong `settings.cfg`), `title`, và `note` giải thích ĐIỀU KIỆN. Note chỉ hiện
   SAU khi người chơi tự tìm ra, nên viết thoải mái.
2. Dạy nó cách nhận ra: thêm một nhánh vào `_house_has()` (nếu là hình dạng nhà,
   hỏi `HouseShape`) hoặc thêm cặp vào vòng lặp trong `_scan_wildlife()`.

Rồi thêm `id` mới vào danh sách `want` ở đầu `_scan_houses()` — thiếu bước này
thì mục mới không bao giờ được quét. Test `_sec_discovery` trong
`tests/regression.gd` sẽ báo lỗi nếu mục thiếu title/note hoặc trùng id.

---

## 10. Khi có lỗi

1. **Đọc dòng lỗi.** Godot in ra `SCRIPT ERROR: ... at: tên_file.gd:123` —
   con số cuối là **số dòng** gây lỗi. Mở đúng dòng đó.
2. **Lỗi hay gặp nhất**: `Identifier "XyzAbc" not declared` sau khi thêm file
   mới → Godot chưa biết file đó. Mở project trong Godot một lần rồi đóng, hoặc:
   ```bash
   godot --headless --path . --editor --quit
   ```
3. **Không hiểu gì cả** → `git checkout -- .` để quay về trạng thái tốt cuối
   cùng, rồi sửa lại từng chút một, mỗi lần sửa chạy test một lần.

---

## 11. Bản đồ dự án — cái gì ở đâu

```
scenes/           màn hình + scene từng block
  main_menu.tscn    menu chính
  main.tscn         màn chơi (ánh sáng, sương, camera ở đây)
  blocks/           mỗi block một scene

scripts/
  data/           ĐỊNH NGHĨA — sửa nhiều nhất
    block_catalog.gd    ★ đăng ký block (thêm block ở đây)
    block_variants.gd   ★ màu và biến thể
    map_themes.gd       ★ 4 bản đồ
    block_data.gd       danh sách tên block
  autoload/       HỆ THỐNG CHẠY NGẦM — cẩn thận
    stream_manager.gd   nước chảy qua ống, gõ trúng cái gì
    gear_manager.gd     bánh răng quay, truyền lực
    audio_manager.gd    ★ mọi âm thanh
    ambient_music.gd    ★ nhạc nền tự sinh
    save_manager.gd     lưu / tải
  blocks/         hành vi từng block (mỗi file rất ngắn)
  ui/             thanh công cụ, menu
  player/         đặt/xoá block, camera

shaders/          chất liệu gỗ / nước / dòng chảy
assets/           âm thanh, font, model 3D
tools/            đồ nghề dev (đo hiệu năng, chụp ảnh, vẽ font)
tests/            bộ kiểm tra tự động
docs/             tài liệu (file bạn đang đọc)
```

★ = an toàn để sửa, chỉ là dữ liệu.

---

## 12. Lưu lại thay đổi

```bash
git add -A
git commit -m "mô tả ngắn việc vừa làm"
git push
```

Làm sau khi test đã xanh. Mỗi lần commit là một điểm quay về an toàn.
