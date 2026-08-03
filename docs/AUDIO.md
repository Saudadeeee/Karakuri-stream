# AUDIO.md — chỉnh âm thanh từng thành phần

Toàn bộ âm của game đi qua `scripts/autoload/audio_manager.gd`. Mỗi giọng là
một hàm; chỉnh **1 con số** trong hàm đó là đổi giọng ở mọi nơi nó vang lên.
Đơn vị âm lượng là dB: `0` = nguyên bản, mỗi `-6` ≈ nhỏ đi một nửa. Pitch:
`1.0` = nguyên bản, `0.5` = trầm một quãng tám, `2.0` = cao một quãng tám.

## Nguyên tắc mix (rút ra từ thực tế, đừng phá)

1. **Âm lặp-theo-beat (0.55s, mãi mãi) phải nhỏ và trầm.** Mọi độ sáng lặp
   vô hạn đều thành chói tai. Đó là lý do splash nước −16dB pitch 0.7–0.9.
2. **One-shot hiếm được phép nổi** (koi nhảy, shishi lật) — chúng là điểm nhấn.
3. Chuông/chime **luôn** bám thang ngũ cung `PENTATONIC_RATIOS` — đánh loạn
   vẫn êm. Đừng phát pitch tự do ngoài thang cho nhạc cụ có cao độ.

## ĐO THẬT — đừng chỉnh mix bằng cảm giác

`tools/audiotest.gd` gắn `AudioEffectRecord` vào bus **Master**, cho tai nghe
(listener) đứng cách khối 10 đơn vị đúng như camera lúc chơi, rồi gọi **chính
các hàm `AudioManager.play_*`** và thu ra WAV. Số đo vì thế đã tính cả bus
volume, suy giảm theo khoảng cách 3D và pitch — không phải mức file trên đĩa.

```bash
# KHÔNG chạy --headless: driver dummy chỉ thu được im lặng
godot --path . --rendering-driver opengl3 --resolution 320x200 tools/audiotest.tscn
# rồi cắt từng đoạn 1.4s và đo
ffmpeg -ss <0.7 + i*1.4> -t 1.35 -i "<user>/audio_probe.wav" -af volumedetect -f null -
```

**Đo ngày 2026-08-04, sau khi cân lại** (đỉnh, dB, trên bus Master):

| Tiếng | Trước | Sau | So với marimba |
|---|---|---|---|
| Nốt gỗ (marimba) — mốc | −13.2 | **−13.2** | 0 |
| Trống taiko | −13.3 | −13.2 | 0 |
| Shishi (cốc đôi) | −12.8 | −11.7 | +1.5 |
| Chuông gió (chime) | −14.3 | −12.8 | +0.4 |
| Hộp nhạc | −15.8 | −14.6 | −1.4 |
| Thạch nảy | **−11.1** | −15.3 | −2.1 |
| **Nước rơi (plop)** | **−6.5** | **−20.4** | **−7.2** |
| Splash | −14.9 | −16.7 | −3.5 |
| Chim vỗ cánh | −15.8 | −18.9 | −5.7 |
| Vòng lặp dòng nước | −20.0 | −21.1 | −7.9 |
| Vòng lặp bánh răng | −19.0 | −21.7 | −8.5 |
| **UI hover** | **−19.2** | **−32.3** | **−19.1** |
| UI press | −13.2 | −20.4 | −7.2 |

Ba chỗ sai lộ ra khi có số:

1. **Nước rơi TO NHẤT game** — cao hơn nốt nhạc 6.7 dB, mà lại là tiếng vang
   nhiều nhất. Giờ nằm dưới melody 7 dB.
2. **Click UI đúng bằng nốt nhạc** (−13.2 vs −13.2). Giao diện không phải nhạc
   cụ; giờ dưới 7 dB, còn hover dưới 19 dB.
3. **Tiếng hover bị nối DÂY HAI LẦN** — `AudioManager` có hook `node_added` bắt
   mọi `Button`, `CuteButton` lại tự gọi thêm một lần; chỉ nhờ cửa sổ chống
   trùng 35 ms mới không nghe thành hai. Đã bỏ hook, giữ `CuteButton` vì nó là
   nơi duy nhất biết một lưới icon thì phải **hover im lặng** (`quiet_hover` có
   từ đầu mà chưa bao giờ được truyền vào — thanh khối 17 icon vì thế kêu một
   tiếng mỗi lần chuột lướt qua).

Lớp mix, tính theo đỉnh so với nốt marimba:

- **Lớp giai điệu** (gỗ, trống, shishi, chime, hộp nhạc): trong khoảng ±1.5 dB
- **Điểm nhấn** (thạch, splash, chim): dưới 2–6 dB
- **Nền chạy liên tục** (nước rơi, 2 vòng lặp): dưới 7–9 dB
- **Giao diện**: dưới 7 dB (press) và 19 dB (hover) — và hotbar thì im hẳn

## Bảng giọng — sửa ở đâu, số hiện tại

| Thành phần | Hàm trong `audio_manager.gd` | Volume hiện tại | Pitch hiện tại |
|---|---|---|---|
| Gõ gỗ (đặt block, marimba theo độ cao) | `play_wood_hit` / `play_wood_note` → `play_wood_pitch` | −3..0 | theo bậc ngũ cung, kẹp 0.6–2.2 |
| Trống taiko | `play_drum` | **−2..−0.5** | 0.92–1.06 |
| Chuông (bell, theo beat) | `play_chime` | **−4..−1** | ngũ cung × jitter ±1% |
| Hộp nhạc (tine) | `play_music_box_note` | −7 | ngũ cung (sample đã là nốt gốc cao) |
| Shishi-odoshi "cộc… cốc" | `play_shishi_knock` | 0 / **+1** (knock 2) | 1.45 / 0.85 |
| Jelly nảy | `play_jelly_bounce` | −5..−1.5 | 0.88–1.18 |
| Nước đặt block (bloop) | `play_water_plop` | −4..−2 | 0.9–1.12 |
| Splash (chung) | `play_splash(pos, vol, deep)` | mặc định −6 | thường 0.9–1.15; `deep=true` → 0.7–0.9 |
| Chong chóng (giấy) | `play_flutter` | −9..−6 | 0.95–1.2 |
| UI hover / bấm | `play_ui_pop` | **−18.5** hover / −10 bấm | 1.3 / 1.0 |
| Loop nước chảy (pond spill) | `make_water_loop_player` | **−8** | 0.95–1.05 |
| Loop kẽo kẹt bánh răng | `make_gear_loop_player` | −19 | 0.62–0.82 |

### Các CHỖ GỌI có volume riêng (đè mặc định)

| Ngữ cảnh | File : chỗ tìm | Số hiện tại |
|---|---|---|
| Stream chạm ao / bãi cỏ (LẶP mỗi beat) | `stream_manager.gd`, case `WATER` trong `_play_impact` | `play_splash(pos, -16.0, true)` |
| Nước rơi chạm đất khi flow lan | `water_flow_manager.gd` → `_activate_cell` | `play_splash(pos, -15.0, true)` |
| Koi nhảy tái nhập | `pond_decor_manager.gd` | `play_splash(pos, -14.0)` |
| Gõ gỗ theo beat của stream | `stream_manager.gd` `_play_impact` case GEAR/WOOD/... | vol = dye + confluence, **cap +2.0** |
| Nhấc block (knock trầm) | `placement_controller.gd` tìm `play_wood_pitch` | pitch 0.72 |

## Nhạc nền generative — `scripts/autoload/ambient_music.gd`

| Muốn đổi | Sửa hằng số |
|---|---|
| Nhạc dày/thưa hơn | `PHRASE_REST_MIN/MAX` (2.6–6.5s giữa các câu) |
| Nốt trong câu nhanh/chậm | `NOTE_GAP_MIN/MAX` (0.4–1.05s) |
| Đổi "chương" hoà âm nhanh hơn | `CHAPTER_MIN/MAX` (24–44s) |
| Hơi thở dâng-lắng dài/ngắn | `DENSITY_PERIOD` (173s) |
| Nhiều/ít câu-trả-lời | `ANSWER_CHANCE` (0.35) |
| Echo mơ màng | `ECHO_CHANCE` (0.2) |
| Volume pad nền / mưa | `_start_bed(...)` trong `_ready` (−24 / −25) |
| Mưa theo map | `RAIN_DB_BY_THEME` (Spring −28, Autumn −18, Snow −44, Night −24) |

## Bus & hiệu ứng — `default_bus_layout.tres`

```
Master ── HardLimiter (trần −0.5dB, chống clip khi spam)
 ├─ Music (−10dB)  ── LowPass 900Hz (bật khi PAUSE = tiếng "lặn nước")
 └─ SFX  (0dB)     ── Compressor (glue các knock) → Reverb (room 0.72, wet ~0.3)
```

Muốn **bớt vang tổng thể**: mở bus SFX → Reverb, giảm `wet`. Muốn nhạc nền
to/nhỏ toàn cục: `bus/1/volume_db`. Người chơi có 3 slider (Master/Music/SFX)
trong Settings — đừng chỉnh trùng tầng với chúng.

## Đổi hẳn SAMPLE (file .ogg)

File nằm ở `assets/sounds/`. Wav/ogg thả vào là Godot tự import. Đổi tên file
→ sửa dòng `preload` tương ứng đầu `audio_manager.gd`.

6 sample tự synthesize (tham số đầy đủ trong `plan.md` PHẦN 66/71 — tái tạo
được bằng rfxgen/ffmpeg): `taiko_boom`, `music_box_tine`, `splash_soft`,
`water_plop`, `ui_pop`, `paper_flutter`. Ví dụ làm splash mềm hơn nữa: hạ
`lowpass` (hiện 3000Hz) và kéo dài attack (hiện 12ms) rồi encode
`-ar 32000 -ac 1 -c:a libvorbis -q:a 1` đè lên file cũ.

## Quy trình chỉnh an toàn

1. Sửa số → mở game nghe (`godot --path .`).
2. Chạy `godot --headless --path . tests/regression.tscn` → phải ra
   `REGRESS ALL OK`.
3. Nghe cả trên map Snow/Night (mix mưa đổi theo map).
