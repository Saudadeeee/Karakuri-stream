
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
