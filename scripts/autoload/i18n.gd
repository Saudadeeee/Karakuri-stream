extends Node

## Tiếng Việt, without a build step.
##
## The keys ARE the English strings. Godot's Control nodes auto-translate their
## own `text` through TranslationServer, so every label and button in the game
## picks up a translation the moment one is registered under its English text —
## no `tr()` sprinkled through the UI code, no CSV to re-import when a string
## changes, and an untranslated string falls back to English instead of showing a
## key like UI_MENU_PLAY.
##
## Strings the game BUILDS at runtime ("Saved to garden %d") cannot work that way
## — by the time the number is in it, it matches no key — so those few call sites
## translate the format string first and interpolate after. They are marked with
## tr() at the call site.
##
## Adding a language: add its dictionary below and its code to LOCALES. The
## setting lives in settings.cfg so the menu can offer it.

const SETTINGS_PATH: String = "user://settings.cfg"
const LOCALES: Array[String] = ["en", "vi"]
const LOCALE_NAMES: Dictionary = {"en": "English", "vi": "Tiếng Việt"}

func _ready() -> void:
	var t := Translation.new()
	t.locale = "vi"
	for key in VI:
		t.add_message(key, VI[key])
	TranslationServer.add_translation(t)
	TranslationServer.set_locale(saved_locale())

func saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return _system_default()
	var code: String = str(cfg.get_value("ui", "locale", ""))
	return code if code in LOCALES else _system_default()

## A Vietnamese system opens the game in Vietnamese. Guessing right once is worth
## more than a language menu nobody finds.
func _system_default() -> String:
	return "vi" if OS.get_locale().begins_with("vi") else "en"

func set_locale(code: String) -> void:
	if not (code in LOCALES):
		return
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ui", "locale", code)
	cfg.save(SETTINGS_PATH)

func current_locale() -> String:
	var code: String = TranslationServer.get_locale().substr(0, 2)
	return code if code in LOCALES else "en"

func next_locale() -> String:
	var i: int = LOCALES.find(current_locale())
	return LOCALES[(i + 1) % LOCALES.size()]

func locale_name(code: String) -> String:
	return str(LOCALE_NAMES.get(code, code))

## en -> vi. Em dashes and the middle dot are kept as authored: they are part of
## how this game's text looks, not English punctuation.
const VI: Dictionary = {
	# ---------------------------------------------------------------- menu
	"Play": "Chơi",
	"Settings": "Cài đặt",
	"Credits": "Ghi công",
	"Quit": "Thoát",
	"Close": "Đóng",
	"Map": "Bản đồ",
	"Sound": "Âm thanh",
	"Screen": "Màn hình",
	"Master": "Tổng",
	"Music": "Nhạc",
	"Effects": "Hiệu ứng",
	"Mute away": "Tắt khi rời",
	"Language": "Ngôn ngữ",
	"Window": "Cửa sổ",
	"V-Sync": "Đồng bộ dọc",
	"Fullscreen": "Toàn màn hình",
	"On": "Bật",
	"Off": "Tắt",
	"F11 toggles fullscreen anywhere": "F11 bật/tắt toàn màn hình ở mọi lúc",
	"drop blocks · hear the stream · relax": "thả khối · nghe dòng nước · thư giãn",
	"Spring": "Xuân",
	"Autumn": "Thu",
	"Snow": "Tuyết",
	"Night": "Đêm",

	# ---------------------------------------------------------------- pause
	"Paused": "Tạm dừng",
	"Volume": "Âm lượng",
	"Resume": "Chơi tiếp",
	"Journal": "Sổ khám phá",
	"Gardens": "Vườn",
	"Save build": "Lưu công trình",
	"Clear all": "Xoá sạch",
	"Main menu": "Về menu chính",
	"Build saved": "Đã lưu công trình",
	"Could not save — storage unavailable": "Không lưu được — không truy cập được bộ nhớ",
	"Clear the whole build?": "Xoá toàn bộ công trình?",
	"Clear": "Xoá",
	"Cancel": "Huỷ",
	"Delete this garden? This cannot be undone.":
		"Xoá vườn này? Không hoàn tác được.",
	"Delete": "Xoá",
	"Keep": "Giữ lại",
	"Save": "Lưu",
	"Open": "Mở",
	"- empty": "- trống",
	"%d blocks": "%d khối",
	"just now": "vừa xong",
	"%d min ago": "%d phút trước",
	"%d h ago": "%d giờ trước",
	"%d days ago": "%d ngày trước",
	"saved": "đã lưu",
	"Saved to garden %d": "Đã lưu vào vườn %d",
	"Opened garden %d": "Đã mở vườn %d",
	"Garden %d could not be read": "Không đọc được vườn %d",
	"Garden %d deleted": "Đã xoá vườn %d",
	"Garden %d": "Vườn %d",
	"Could not save - storage unavailable": "Không lưu được - không truy cập được bộ nhớ",

	# ------------------------------------------------------------- controls
	"How to play": "Cách chơi",
	"Got it": "Đã hiểu",
	"Left click — place a block        Right click — remove":
		"Chuột trái — đặt khối        Chuột phải — gỡ",
	"Middle drag — orbit camera      Scroll — zoom":
		"Giữ chuột giữa kéo — xoay góc nhìn      Cuộn — phóng to/nhỏ",
	"Click a hotbar icon again — change its style / tempo":
		"Bấm lại biểu tượng khối — đổi kiểu / nhịp",
	"Tap — place a block        Erase button — delete mode":
		"Chạm — đặt khối        Nút Xoá — chế độ gỡ",
	"One finger — orbit camera      Two fingers — pinch zoom":
		"Một ngón — xoay góc nhìn      Hai ngón — chụm để phóng",
	"Tap a hotbar icon again — change its style / tempo":
		"Chạm lại biểu tượng khối — đổi kiểu / nhịp",
	"Q — houses. Line them up and they become one building.":
		"Q — nhà. Xếp thẳng hàng thì chúng gộp thành một toà.",
	"Build a village and animals move in. Birds play your bells.":
		"Xây thành xóm thì thú về ở. Chim sẽ gõ chuông của bạn.",
	"Undo button — take back the last block":
		"Nút Hoàn tác — lấy lại khối vừa đặt",
	"Ctrl+Z undo · H hide UI · U move the sun · P screenshot · F11 fullscreen":
		"Ctrl+Z hoàn tác · H ẩn giao diện · U dời mặt trời · P chụp ảnh · F11 toàn màn hình",
	"Screenshot saved": "Đã lưu ảnh chụp",
	"Erase": "Xoá",
	"Erase\nON": "Xoá\nBẬT",
	"Undo": "Hoàn tác",

	# -------------------------------------------------------------- journal
	"Journal  %d / %d": "Sổ khám phá  %d / %d",
	"The town made %s": "Thị trấn vừa tạo ra %s",
	"A spire": "một chóp tháp",
	"Four storeys on one cell and the tower grows a spire.":
		"Bốn tầng trên cùng một ô thì tháp mọc chóp nhọn.",
	"A roof terrace": "một sân thượng",
	"A roof in the shadow of a taller part flattens into a railed deck.":
		"Mái nằm dưới bóng phần cao hơn sẽ phẳng lại thành sân có lan can.",
	"A courtyard": "một cái sân trong",
	"Ring an empty cell with houses and the gap becomes a planted court.":
		"Vây kín một ô trống bằng nhà, chỗ trống đó thành sân có cây.",
	"Bunting": "dây cờ",
	"Leave one cell of air between two rooftops of equal height.":
		"Chừa đúng một ô trống giữa hai mái nhà cao bằng nhau.",
	"An arch": "một vòm cầu",
	"A house cell bridging open ground grows an arch instead of legs.":
		"Ô nhà bắc ngang khoảng trống sẽ mọc vòm thay vì cột chống.",
	"A dormer window": "một cửa sổ mái",
	"A long roof opens a dormer to light the attic under it.":
		"Mái dài sẽ mở một cửa sổ để lấy sáng cho gác xép bên dưới.",
	"A roof garden": "một vườn trên mái",
	"A big building's flat roof earns pots and greenery.":
		"Mái bằng của toà nhà lớn được thưởng chậu cây.",
	"Stilts": "cột nhà sàn",
	"A house built over open air walks down to whatever is beneath it.":
		"Nhà xây trên không sẽ tự mọc chân xuống chỗ bên dưới.",
	"Birds": "chim",
	"Houses bring birds — and a bird landing on a bell, chime or drum plays it.":
		"Có nhà thì chim về — và chim đậu trúng chuông, ống hay trống là nó gõ thật.",
	"A cat": "một con mèo",
	"Two houses are enough for a cat to move in and walk the rooftops.":
		"Hai căn nhà là đủ để mèo dọn tới và đi dạo trên mái.",
	"Ducks": "vịt",
	"Three open water cells make a pond a duck will paddle.":
		"Ba ô nước hở là thành cái ao cho vịt bơi.",
	"A deer": "một con nai",
	"A deer only comes out when the machine is quiet. Switch the garden off.":
		"Nai chỉ ra khi cỗ máy im lặng. Tắt vườn đi rồi chờ.",
	"? ? ?": "? ? ?",

	# ----------------------------------------------------------- block hints
	"Building block — click again for Wood/Dirt/Moss/Stone":
		"Khối xây dựng — bấm lại để đổi Gỗ/Đất/Rêu/Đá",
	"House — stack and line them up, they merge into one building":
		"Nhà — xếp chồng và xếp hàng, chúng gộp thành một toà",
	"Still pond — powers any gear touching it":
		"Ao nước tĩnh — làm quay mọi bánh răng chạm vào",
	"Spout — pours a stream straight down":
		"Vòi — rót một dòng nước thẳng xuống",
	"Self-connecting pipe — click again for closed/open":
		"Ống tự nối — bấm lại để đổi kín/hở",
	"Spins when touching water — chain them to transfer power":
		"Quay khi chạm nước — nối chuỗi để truyền lực",
	"Rings when a stream hits it or a gear strikes it":
		"Kêu khi dòng nước rơi trúng hoặc bánh răng gõ vào",
	"Bouncy jelly — boings when water lands on it":
		"Thạch nảy — bùng khi nước rơi lên",
	"Fills with water, then TIPS: pours onward + knock!":
		"Đầy nước rồi ĐỔ: rót tiếp + cốc!",
	"Drum — beaten by streams or a gear next to it":
		"Trống — dòng nước hoặc bánh răng bên cạnh gõ vào",
	"Each colour is a note, shorter tube = higher — line them up = a melody":
		"Mỗi màu là một nốt, ống ngắn = cao hơn — xếp thành hàng = một giai điệu",
	"Put beside a SPINNING gear → plays a tune":
		"Đặt cạnh bánh răng ĐANG QUAY → chơi một khúc nhạc",
	"Beside a POND + spinning gear → ladles a new stream":
		"Cạnh AO + bánh răng quay → múc ra một dòng mới",
	"Sluice gate — CLICK it in the world to open/close the flow":
		"Cửa cống — BẤM vào nó trong vườn để mở/đóng dòng chảy",
	"Glowing lantern — prettiest on the Night map":
		"Đèn đá phát sáng — đẹp nhất trên bản đồ Đêm",
	"Pinwheel — spins when a stream hits it":
		"Chong chóng — quay khi dòng nước thổi vào",
	"Legacy elbow pipe — the plain pipe bends itself now":
		"Ống khuỷu cũ — ống thường giờ tự bẻ góc được rồi",

	# --------------------------------------------------------- variant names
	"Wood": "Gỗ", "Dirt": "Đất", "Moss": "Rêu", "Stone": "Đá",
	"Teal water": "Nước xanh mòng két", "Pink water": "Nước hồng",
	"Lilac water": "Nước tím nhạt", "Mint water": "Nước bạc hà",
	"Cyan jelly": "Thạch xanh lơ", "Pink jelly": "Thạch hồng",
	"Sunny jelly": "Thạch vàng nắng", "Lilac jelly": "Thạch tím nhạt",
	"Closed pipe": "Ống kín", "Open pipe": "Ống hở", "Alternator pipe": "Ống chia luân phiên",
	"Gear": "Bánh răng", "Water mill": "Guồng nước", "Bell": "Chuông",
	"Spout — steady": "Vòi — đều", "Spout — slow": "Vòi — chậm", "Spout — quick": "Vòi — nhanh",
	"Bend pipe": "Ống khuỷu",
	"Chime C": "Ống C", "Chime D": "Ống D", "Chime E": "Ống E",
	"Chime G": "Ống G", "Chime A": "Ống A",
	"Shishi-odoshi": "Shishi-odoshi", "Shishi — quick": "Shishi — nhanh",
	"Shishi — patient": "Shishi — chậm rãi",
	"Stone lantern": "Đèn đá",
	"Pink pinwheel": "Chong chóng hồng", "Orange pinwheel": "Chong chóng cam",
	"Blue pinwheel": "Chong chóng xanh",
	"Wooden drum": "Trống gỗ", "Music box": "Hộp nhạc", "Sluice gate": "Cửa cống",
	"Cream house": "Nhà kem", "Tomato house": "Nhà đỏ cà chua",
	"Sea-blue house": "Nhà xanh biển", "Saffron house": "Nhà vàng nghệ",
	"Leaf house": "Nhà xanh lá", "Whitewash house": "Nhà quét vôi",
	"Rose house": "Nhà hồng phấn", "Violet house": "Nhà tím",
	"Water scoop": "Gàu múc nước",
}
