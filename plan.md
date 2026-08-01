
## PHẦN 70 (main): TÌM LẠI NHỮNG CĂN NHÀ — merge nhánh chore về main + 2 fix audio

User: "sao mở Godot không có nhà? Tưởng chỉ bỏ khỏi bản web?" — điều tra ra sự thật khó chịu: **main chưa bao giờ có nhà**. Hệ nhà Townscaper + wildlife + cleanup 60k dòng chết phát triển trên `chore/cleanup-dead-code-and-assets` (tip 55e91c6); `web` fork TỪ NHÁNH ĐÓ rồi cắt nhà. Main đứng im ở b7f0671 (merge-base) — mọi cải tiến gần đây đắp lên một main cũ.

### Merge 55e91c6 → main (12 conflict, nguyên tắc resolve):
- Perf/audio/font mới của main THẮNG: voxel manager (bản async là superset của occ-index chore tự làm), iso_surface, harness perf/shoot (đã branch-safe).
- Thời-đại-nhà THẮNG: map_themes (chore fix cháy sáng bằng HẠ AMBIENT 0.45→0.28 thay vì hạ albedo đảo — lấy cách của họ), theme.tres (re-apply pixel font đè lên sau), lawn-landing (bản chore clip segment tại mặt cỏ + voice WATER, sớm hơn và gọn hơn — bỏ bản LAWN của mình thành dead code), font Fredoka (chore đã đổi từ Baloo2; pixel fallback trỏ lại fredoka_chunky).
- Union: regression chạy CẢ 2 bộ section (22 section), hotbar giữ 2 cột + thêm HOUSE (14 icon), version giữ 0.0.0, gear rattle theo chore đã convert wav→ogg.

### 3 lỗi hậu-merge tóm được:
1. **AudioManager có 2 `play_ui_pop`** (chore một bản wood-knock, mình một bản sample) → PARSE ERROR → autoload Nil → 21 lỗi dây chuyền "Nonexistent function in base Nil". Xóa bản chore.
2. House colour-audit fail vì `settings.cfg theme=3` — section theme_switch của lần chạy TRƯỚC lưu Night; tint Night ép 2 màu decor sát nhau còn 0.038 < ngưỡng 0.12. Suite giờ PIN theme=0 ở đầu — hết phụ thuộc lần chạy trước.
3. Teardown: AudioManager freed trước WaterFlow/GearManager lúc quit → guard `is_instance_valid`.

### Audio fix (commit riêng trước merge):
- Splash "chát": sample lowpass 5.2k→3k, attack 12ms, chirp nhẹ hơn; koi -14dB.
- Hover hotbar to: -13→-18.5dB.

REGRESS ALL OK (22 section, 0 script error). Ảnh: nhà 2 tầng chữ L merge đúng cạnh máy karakuri, chim+mèo+vịt về, hotbar 14 icon.

## PHẦN 71 (main): MIX PASS TOÀN CỤC — thư giãn là mặc định

Feedback: tiếng nước từ vòi rơi xuống chát và to. Audit TOÀN BỘ đường phát âm — nguyên tắc mới: **âm lặp-theo-beat vô hạn phải nằm xa dưới nhạc cụ và trầm** (mọi độ sáng lặp mãi đều thành chói); one-shot hiếm mới được nổi.

| Đường âm | Trước | Sau |
|---|---|---|
| Splash nước chạm ao/cỏ (LẶP mỗi beat 0.55s) | -9dB, pitch 0.9-1.15 | **-16dB, pitch 0.7-0.9** (cờ `deep` mới) |
| Splash nước rơi trong flow reveal | -12 | -15, deep |
| Taiko (lặp theo beat khi stream gõ) | +1..+2.5 | **-2..-0.5** |
| Chuông bell (lặp theo beat) | -2..+1 | -4..-1 |
| Shishi knock đôi | 0.5 / **+2.0** | 0.0 / +1.0 |
| Loop nước chảy (pond spill) | -4 | -8 |
| Confluence accent | không cap (+2.5/dòng) | **cap +2.0 tổng** |
| Koi leap splash (one-shot hiếm) | -14 | giữ (được phép nổi) |
| Marimba knock beat / đặt block / tine / jelly / creak -19 / UI -18.5 | | giữ — đã cân

REGRESS ALL OK. Chưa thể nghe hộ — cần tai thật chấm lần cuối; mọi số ở audio_manager/stream_manager, đổi 1 dòng/giọng.

## PHẦN 72 (main): NHÀ DƯỚI CỘT + AUDIO.md

1. **Bug nhà-cột** (user: "xây nhà có cột, xây thêm nhà ở dưới cột là bị lỗi"):
   - Repro đầu SAI: quên set `grid_cell` → nhà build bằng `lone_context` không bao giờ rebuild → tưởng mất cột. Đường thật của game có set — repro lại đúng đường.
   - Bug THẬT: nhà trên rebuild đúng (chân drop=1 chạm mặt phẳng y=1) nhưng **mái DỐC nhà dưới nhô ~0.6 lên ô trên** → chân + đế chôn trong mái, ống khói nhà dưới đâm xuyên sàn nhà trên.
   - Fix đúng ngôn ngữ hệ thống: patch mái **bears_stilts** (có nhà cách ≥2 ô thẳng trên, không khí thông suốt, chân đáp đúng nóc) → cả patch thành TERRACE phẳng (hệ terrace có sẵn) + triệt ống khói dưới sàn nhà khác. `bears_stilts` vào digest chống stale. Ảnh verify: sân thượng phẳng + chậu cây, chân đứng gọn, chim đậu nóc — đọc như kiến trúc cố ý.
   - Regression mới `_sec_house_under_stilts`: bears/terrace đúng, geometry không vượt y=1.05, GỠ nhà trên → mái revert dốc.
2. **AUDIO.md** (root): doc chỉnh âm hoàn chỉnh — bảng mọi giọng (hàm, volume, pitch hiện tại), các call-site đè volume, hằng số composer, sơ đồ bus, cách thay sample, quy trình chỉnh an toàn. Nguyên tắc mix ghi thành luật: lặp-theo-beat = nhỏ+trầm, one-shot hiếm được nổi.

REGRESS ALL OK (24 section).
