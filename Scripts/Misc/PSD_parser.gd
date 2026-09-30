# Special thanks for the Pixelorama Team for the initial PSD import script, this is a modified version of it ( https://github.com/Orama-Interactive/Pixelorama/pull/1308 )
extends RefCounted
class_name PSDParser

const BLOCK_SIG_8BIM := "8BIM"
const BLOCK_SIG_8B64 := "8B64"

# The format caps a document at 300000 px per side (Photoshop's own limit).
# Anything larger is a corrupt header and would throw every layer offset off screen.
const MAX_DOC_SIZE := 300000

# 8192 x 8192 = 64 Mi pixels. Decoding one layer costs ~12 bytes per pixel
# (4 channels + the int32 interleave view + the final image), so this caps the
# peak at ~800 MB instead of the ~2.4 GB the old 200 M limit allowed.
const MAX_LAYER_PIXELS := 67_108_864

const PSB_EIGHT_BYTE_ADDITIONAL_LAYER_KEYS: PackedStringArray = [
	"LMsk", "Lr16", "Lr32", "Layr", "Mt16", "Mt32", "Mtrn",
	"Alph", "FMsk", "lnk2", "FEid", "FXid", "PxSD"
]

# trim_to_content: crop every layer to its painted pixels while decoding. Exporters
# that give each layer a full-canvas rect otherwise pay for millions of transparent
# pixels that never reach the screen.
# keep_position: when cropping, shift the layer offset so the painted content stays
# exactly where it was. Off = the layer stays centred on its full rect.
static func open_photoshop_file(path: String, trim_to_content: bool = false, keep_position: bool = true) -> Array:
	var psd_file := FileAccess.open(path, FileAccess.READ)
	if psd_file == null:
		return []
	psd_file.big_endian = true
	var file_len := psd_file.get_length()

	# Block signatures and keys are 4 raw bytes, not text: decoding them as UTF-8
	# logs one "Unicode parsing error" per bad byte on any non-PSD input.
	if psd_file.get_buffer(4).get_string_from_ascii() != "8BPS":
		return []
	var version := psd_file.get_16()
	if version != 1 and version != 2:
		return []
	var is_psb := version == 2
	psd_file.get_buffer(6) 
	psd_file.get_16() 
	var doc_height := psd_file.get_32()
	var doc_width := psd_file.get_32()
	if doc_width > MAX_DOC_SIZE or doc_height > MAX_DOC_SIZE:
		push_error("PSD canvas %dx%d exceeds the %d limit, clamping" % [doc_width, doc_height, MAX_DOC_SIZE])
		doc_width = mini(doc_width, MAX_DOC_SIZE)
		doc_height = mini(doc_height, MAX_DOC_SIZE)
	var depth := psd_file.get_16()
	psd_file.get_16() # colour mode
	if depth != 8:
		# 16/32-bit documents also keep their records elsewhere (see pitfall #31),
		# so this is a "will not decode as expected" notice rather than an error.
		push_warning("PSD depth %d is not 8-bit; colour channels may decode incorrectly" % depth)

	var color_data_length := psd_file.get_32()
	if color_data_length > 0:
		safe_seek(psd_file, color_data_length)

	var image_resources_length := psd_file.get_32()
	if image_resources_length > 0:
		safe_seek(psd_file, image_resources_length)

	if is_psb:
		psd_file.get_64()
	else:
		psd_file.get_32()

	var _layer_info_length: int
	if is_psb:
		_layer_info_length = psd_file.get_64()
	else:
		_layer_info_length = psd_file.get_32()

	var layer_count := get_signed_16(psd_file)
	if layer_count < 0:
		layer_count = -layer_count
	# A corrupt header can declare an absurd count; a layer record is at least the
	# 34 bytes of rect + channel count + signature + flags + extra length.
	var max_layers := maxi(0, (file_len - psd_file.get_position()) / 34)
	if layer_count > max_layers:
		push_error("PSD layer count %d exceeds file size, clamping to %d" % [layer_count, max_layers])
		layer_count = max_layers

	var psd_layers: Array[Dictionary] = []

	var cons_rand_id = int(randi()/ 2)
	for i in layer_count:
		var layer: Dictionary = {
			"id": 0, # will set from 'lyid'
			"parent_id": 0,
			"name": "Layer %s" % i,
			"type": "layer",
			"visible": true,
			"opacity": 1.0,
			"image": null,
			"channels": []
		}

		layer["top"] = get_signed_32(psd_file)
		layer["left"] = get_signed_32(psd_file)
		layer["bottom"] = get_signed_32(psd_file)
		layer["right"] = get_signed_32(psd_file)
		layer["width"] = layer["right"] - layer["left"]
		layer["height"] = layer["bottom"] - layer["top"]

		var num_channels := psd_file.get_16()
		# A channel record is 6 bytes (psd) or 10 (psb); a corrupt count would
		# otherwise keep reading past EOF and invent thousands of junk channels.
		var max_channels := maxi(0, (file_len - psd_file.get_position()) / (10 if is_psb else 6))
		if num_channels > max_channels:
			push_error("PSD channel count %d exceeds file size, clamping to %d" % [num_channels, max_channels])
			num_channels = max_channels
		for j in range(num_channels):
			var ch := {}
			ch["id"] = get_signed_16(psd_file)
			if is_psb:
				ch["length"] = psd_file.get_64()
			else:
				ch["length"] = psd_file.get_32()
			layer["channels"].append(ch)

		safe_seek(psd_file, 8)

		layer["opacity"] = psd_file.get_8() / 255.0
		psd_file.get_8()
		var flags := psd_file.get_8()
		layer["visible"] = flags & 2 != 2
		psd_file.get_8()

		var extra_data_field_length := psd_file.get_32()
		var extra_start := psd_file.get_position()
		var extra_end := extra_start + extra_data_field_length

		if psd_file.get_position() + 4 <= mini(extra_end, file_len):
			var mask_len := psd_file.get_32()
			if mask_len > 0:
				safe_seek(psd_file, mask_len)

		if psd_file.get_position() + 4 <= mini(extra_end, file_len):
			var blend_len := psd_file.get_32()
			if blend_len > 0:
				safe_seek(psd_file, blend_len)

		if psd_file.get_position() < mini(extra_end, file_len):
			var name_field_start := psd_file.get_position()
			var name_length := psd_file.get_8()
			# Pascal string: [1]length + name_length bytes. Photoshop pads this field
			# to a 4-byte boundary, but files from other exporters omit that padding,
			# so the block chain offset is probed instead of assumed.
			# See find_block_chain_start(): returning the wrong offset silently drops
			# every 'lsct'/'lyid' block, which flattens all layer groups.
			if name_length > 0 and psd_file.get_position() + name_length <= mini(extra_end, file_len):
				layer["name"] = decode_legacy_name(psd_file.get_buffer(name_length))
			else:
				layer["name"] = ""
			psd_file.seek(find_block_chain_start(psd_file, name_field_start, name_length, extra_end))

		# Additional-info block chain. Bounded by BOTH extra_end (the declared end of
		# this layer's extra data) and the file: a corrupt length would otherwise let
		# us walk past EOF, where every read returns nothing and the loop never ends.
		var chain_end := mini(extra_end, file_len)
		while psd_file.get_position() + 12 <= chain_end:
			var _sig := psd_file.get_buffer(4).get_string_from_ascii()
			var key := psd_file.get_buffer(4).get_string_from_ascii()

			var length: int
			if is_psb and key in PSB_EIGHT_BYTE_ADDITIONAL_LAYER_KEYS:
				length = psd_file.get_64()
			else:
				length = psd_file.get_32()

			var block_start := psd_file.get_position()

			if key == "lyid":
				layer["id"] = psd_file.get_32() + cons_rand_id
			if key == "lsct":
				var section_type := psd_file.get_32()
				if section_type == 1 or section_type == 2:
					layer["type"] = "folder"
				elif section_type == 3:
					layer["type"] = "end_folder"
				else:
					layer["type"] = "layer"
			if key == "luni":
				# Authoritative Unicode name (char count + UTF-16BE payload).
				# Overwrites the legacy Pascal name read above, so the layer keeps
				# the correct cross-platform name whenever this block is present.
				var luni_name := read_luni_name(psd_file, length)
				if not luni_name.is_empty():
					layer["name"] = luni_name

			var to_seek := block_start + ((length + 1) & ~1)
			# A zero-length block leaves the cursor where it is. Without this check a
			# corrupt file spins here forever (verified: hung for 20 s).
			if to_seek <= block_start or to_seek > chain_end:
				break
			psd_file.seek(to_seek)

		# Real Photoshop files may leave the last additional block header straddling
		# extra_end (its length field sits exactly on the boundary). Re-align so the
		# next layer record always starts at extra_end, but never seek past EOF.
		var safe_extra_end := mini(extra_end, file_len)
		if psd_file.get_position() != safe_extra_end:
			psd_file.seek(safe_extra_end)

		if layer["id"] == 0:
			layer["id"] = randi()

		psd_layers.append(layer)
	var folder_stack: Array[int] = []
	for idx in range(psd_layers.size() - 1, -1, -1):
		var entry := psd_layers[idx]
		var t = entry["type"]
		if t == "folder":
			if folder_stack.size() > 0:
				entry["parent_id"] = folder_stack[folder_stack.size() - 1]
			else:
				entry["parent_id"] = 0
			folder_stack.append(entry["id"])
		elif t == "end_folder":
			if folder_stack.size() > 0:
				folder_stack.pop_back()
		elif t == "layer":
			if folder_stack.size() > 0:
				entry["parent_id"] = folder_stack[folder_stack.size() - 1]
			else:
				entry["parent_id"] = 0
	for layer in psd_layers:
		for channel in layer["channels"]:
			var offset := psd_file.get_position()
			if typeof(channel["length"]) != TYPE_INT:
				channel["length"] = 0
			if channel["length"] < 0 or channel["length"] > file_len:
				channel["length"] = max(0, file_len - psd_file.get_position())
			# Assign the offset only on a successful skip: when the file ends
			# mid-channel this channel and all later ones keep no data_offset at
			# all, so the decoder skips them instead of re-reading the tail bytes.
			if not safe_seek(psd_file, channel["length"]):
				break
			channel["data_offset"] = offset

	for layer in psd_layers:
		if layer["type"] != "layer":
			continue
		var image := decode_psd_layer(psd_file, layer, is_psb, trim_to_content)
		if image != null and not image.is_empty():
			layer["image"] = image
		else:
			var placeholder = Image.create(32, 32, false, Image.FORMAT_RGBA8)
			placeholder.fill(Color(0, 0, 0, 0))
			layer["crop"] = full_layer_rect(layer)
			layer["image"] = placeholder

	psd_file.close()

	var result := []
	for layer in psd_layers:
		if layer["type"] == "end_folder":
			continue
		var offset = Vector2()
		var crop: Rect2i = layer.get("crop", full_layer_rect(layer))
		if keep_position:
			# Centre of the cropped image, so cropping shifts nothing on screen.
			offset.x = layer["left"] + crop.position.x - doc_width / 2 + crop.size.x / 2.0
			offset.y = layer["top"] + crop.position.y - doc_height / 2 + crop.size.y / 2.0
		else:
			# Centre of the declared rect: matches what an uncropped import would do.
			offset.x = layer["left"] - doc_width / 2 + (layer["right"] - layer["left"]) / 2.0
			offset.y = layer["top"] - doc_height / 2 + (layer["bottom"] - layer["top"]) / 2.0
		
		var entry := {}
		entry["id"] = layer["id"]
		entry["parent_id"] = layer["parent_id"]
		entry["type"] = layer["type"]
		entry["name"] = layer["name"]
		entry["image"] = layer["image"]
		entry["visible"] = layer["visible"]
		entry["opacity"] = layer["opacity"]
		entry["offset"] = offset
		result.append(entry)
	return result

static func safe_seek(file: FileAccess, offset: int) -> bool:
	var pos := file.get_position()
	var end := pos + offset
	if offset < 0 or end > file.get_length():
		return false
	file.seek(end)
	return true

# Photoshop pads the Pascal layer name to a 4-byte boundary, but files written by
# other exporters (and some Photoshop save paths) start the block chain immediately
# after the name bytes. Probe both offsets and return the one holding a block header.
static func find_block_chain_start(file: FileAccess, name_field_start: int, name_length: int, extra_end: int) -> int:
	var unpadded := name_field_start + 1 + name_length
	var padded := unpadded + (-(1 + name_length) & 3)
	var limit := mini(extra_end, file.get_length())
	if padded + 4 <= limit and has_block_signature_at(file, padded):
		return padded
	if unpadded + 4 <= limit and has_block_signature_at(file, unpadded):
		return unpadded
	# Fall back to the Photoshop layout, but never hand back a position past EOF.
	return mini(padded if padded <= limit else unpadded, file.get_length())


# Non-destructive peek: true when an '8BIM'/'8B64' block header starts at pos.
static func has_block_signature_at(file: FileAccess, pos: int) -> bool:
	if pos < 0 or pos + 4 > file.get_length():
		return false
	var here := file.get_position()
	file.seek(pos)
	var sig := file.get_buffer(4).get_string_from_ascii()
	file.seek(here)
	return sig == BLOCK_SIG_8BIM or sig == BLOCK_SIG_8B64


# Reads a 'luni' block payload: [4]char count + UTF-16BE string.
# Returns "" on any malformation so the caller keeps the legacy Pascal name.
static func read_luni_name(file: FileAccess, block_length: int) -> String:
	if block_length < 4:
		return ""
	var block_start := file.get_position()
	var block_end := block_start + block_length
	if block_end > file.get_length():
		return ""
	var char_count := file.get_32()
	var byte_count := char_count * 2
	if char_count <= 0 or file.get_position() + byte_count > block_end:
		return ""
	var raw := file.get_buffer(byte_count)
	# PSD stores luni as UTF-16BE while Godot's from_utf16() assumes little endian,
	# so swap every code unit before decoding.
	var le := PackedByteArray()
	le.resize(byte_count)
	for i in range(0, byte_count - 1, 2):
		le[i] = raw[i + 1]
		le[i + 1] = raw[i]
	return le.get_string_from_utf16()

# Legacy Pascal layer names use the document's code page, not UTF-8.
# get_string_from_utf8() logs a "Unicode parsing error" per bad byte, so validate
# the byte stream first and only fall back to the system code page when it is not UTF-8.
static func decode_legacy_name(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	if is_valid_utf8(bytes):
		return bytes.get_string_from_utf8()
	return bytes.get_string_from_multibyte_char()

# Minimal UTF-8 validator: returns false for the surrogate/overlong/incomplete
# sequences that legacy code pages (GBK, Shift-JIS, ...) produce.
static func is_valid_utf8(bytes: PackedByteArray) -> bool:
	var i := 0
	var n := bytes.size()
	while i < n:
		var b := bytes[i]
		var extra := 0
		if b < 0x80:
			extra = 0
		elif b >= 0xC2 and b <= 0xDF:
			extra = 1
		elif b >= 0xE0 and b <= 0xEF:
			extra = 2
		elif b >= 0xF0 and b <= 0xF4:
			extra = 3
		else:
			return false
		if i + extra >= n:
			return false
		for k in range(1, extra + 1):
			if bytes[i + k] & 0xC0 != 0x80:
				return false
		i += extra + 1
	return true

# A truncated file hands back a short buffer; decoding that indexes out of range.
# Checking the FILE length (as this once did) is wrong -- only the bytes actually
# read matter.
static func get_signed_16(file: FileAccess) -> int:
	var buffer := file.get_buffer(2)
	if buffer.size() < 2:
		return -1
	if file.big_endian:
		buffer.reverse()
	return buffer.decode_s16(0)

static func get_signed_32(file: FileAccess) -> int:
	var buffer := file.get_buffer(4)
	if buffer.size() < 4:
		return -1
	if file.big_endian:
		buffer.reverse()
	return buffer.decode_s32(0)

static func decode_psd_layer(psd_file: FileAccess, layer: Dictionary, is_psb: bool, trim_to_content: bool = false) -> Image:
	var img_channels := {}
	var file_len := psd_file.get_length()

	for channel in layer["channels"]:
		if not channel.has("data_offset") or not channel.has("length"):
			continue
		# Only colour (0/1/2) and transparency (-1) feed the RGBA image. User/real
		# masks (-2/-3) are sized from the mask rect, so decoding them against the
		# layer rect always short-reads and only produces spurious warnings.
		if channel["id"] < -1 or channel["id"] > 2:
			continue
		var data_offset: int = channel["data_offset"]
		var ch_length: int = channel["length"]
		if data_offset < 0 or data_offset >= file_len:
			push_error("Bad data_offset for channel: %s" % str(data_offset))
			continue
		if ch_length <= 0 or ch_length > file_len:
			push_error("Bad channel length: %s" % str(ch_length))
			continue

		psd_file.seek(data_offset)
		if psd_file.get_position() + 2 > file_len:
			push_error("Unexpected EOF reading compression")
			continue
		var compression := psd_file.get_16()

		var width: int = layer["width"]
		var height: int = layer["height"]
		var size: int = width * height
		if size <= 0:
			continue

		if size > MAX_LAYER_PIXELS:
			push_error("Layer '%s' is %dx%d (%d px), over the %d px limit; skipped" % [
					layer["name"], width, height, size, MAX_LAYER_PIXELS])
			continue

		var raw_data := PackedByteArray()

		if compression == 0:
			if psd_file.get_position() + size > data_offset + ch_length:
				push_error("Channel raw data shorter than expected")
				continue
			raw_data = psd_file.get_buffer(size)
		elif compression == 1:
			var scanline_counts := []
			for r in range(height):
				if is_psb:
					if psd_file.get_position() + 4 > data_offset + ch_length:
						push_error("Unexpected EOF reading scanline count (psb)")
						break
					scanline_counts.append(psd_file.get_32())
				else:
					if psd_file.get_position() + 2 > data_offset + ch_length:
						push_error("Unexpected EOF reading scanline count (psd)")
						break
					scanline_counts.append(psd_file.get_16())

			# `for x in array` copies each element, so the clamp has to be written
			# back by index -- assigning to the loop variable silently does nothing.
			# Reported once per channel: a corrupt file can hit this on every row.
			var bad_counts := 0
			for c_i in scanline_counts.size():
				var rcount: int = scanline_counts[c_i]
				if rcount < 0 or rcount > ch_length:
					bad_counts += 1
					scanline_counts[c_i] = clamp(rcount, 0, ch_length)
			if bad_counts > 0:
				push_error("Layer '%s': clamped %d of %d suspicious scanline counts" % [
						layer["name"], bad_counts, scanline_counts.size()])

			# Read the whole RLE payload in one call and walk it by index: one
			# FileAccess.get_8() per control byte dominates the decode otherwise.
			var rle_start := psd_file.get_position()
			var rle := psd_file.get_buffer(maxi(0, data_offset + ch_length - rle_start))
			var rp := 0
			var rle_eof := 0
			for r_i in range(scanline_counts.size()):
				var to_read: int = scanline_counts[r_i]
				var scanline := PackedByteArray()
				var row_start := rp
				var row_end := mini(row_start + to_read, rle.size())
				if to_read > rle.size() - row_start:
					rle_eof += 1
				while scanline.size() < width and rp < row_end:
					var n: int = rle[rp]
					rp += 1
					if n >= 128:
						var count := 257 - n
						if rp >= row_end:
							rle_eof += 1
							break
						var val: int = rle[rp]
						rp += 1
						# A replicate run can overshoot the row; keep the part that
						# fits and let the row-end alignment drop the remainder.
						var to_write := mini(count, width - scanline.size())
						if to_write > 0:
							var run := PackedByteArray()
							run.resize(to_write)
							run.fill(val)
							scanline.append_array(run)
					else:
						# Take the whole literal run at once: the bytes are consumed
						# even past the row width, so the cursor stays correct.
						var count := n + 1
						var take := mini(count, row_end - rp)
						var chunk := rle.slice(rp, rp + take)
						rp += take
						var room := width - scanline.size()
						if chunk.size() > room:
							chunk = chunk.slice(0, room)
						scanline.append_array(chunk)
				# PackBits rows can end with an overshooting run or a trailing
				# sentinel/padding byte. Align to the declared row end so the
				# next row starts at the correct offset.
				rp = row_start + to_read
				raw_data.append_array(scanline)
			if rle_eof > 0:
				push_error("Layer '%s': unexpected EOF while reading RLE data (%d hits)" % [
						layer["name"], rle_eof])
			psd_file.seek(rle_start + rle.size())
		else:
			push_error("Unsupported compression: %d" % compression)
			continue

		if raw_data.size() != size:
			if raw_data.is_empty():
				continue
			push_warning("Channel data size mismatch: layer '%s' channel %s expected %d got %d" % [layer["name"], str(channel["id"]), size, raw_data.size()])
			# resize() truncates when oversized and zero-fills when short, so only
			# the missing tail needs an explicit pass.
			var had := raw_data.size()
			raw_data.resize(size)
			for ii in range(had, size):
				raw_data[ii] = 255
		img_channels[channel["id"]] = raw_data

	if layer["width"] <= 0 or layer["height"] <= 0:
		return null

	var pixel_count: int = layer["width"] * layer["height"]

	# Hoist the channel lookups: a dictionary probe per pixel per channel costs
	# more than the copy itself on multi-megapixel layers.
	var ch_r: PackedByteArray = img_channels.get(0, PackedByteArray())
	var ch_g: PackedByteArray = img_channels.get(1, PackedByteArray())
	var ch_b: PackedByteArray = img_channels.get(2, PackedByteArray())
	var ch_a: PackedByteArray = img_channels.get(-1, PackedByteArray())
	# A missing -1 channel means fully opaque, which also means there is no alpha
	# to derive a crop from.
	var has_a := ch_a.size() == pixel_count

	# if no channel data OR fully transparent, return tiny placeholder
	if img_channels.is_empty() or (has_a and ch_a.count(0) == pixel_count):
		var placeholder := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(0, 0, 0, 0))
		layer["crop"] = full_layer_rect(layer)
		return placeholder

	# Crop to the painted area before interleaving: exporters that write every layer
	# with a full-canvas rect leave ~93% of the pixels transparent, and interleaving
	# them is pure waste. The crop rect travels back to the caller so it can repair
	# the layer offset.
	var crop := full_layer_rect(layer)
	if trim_to_content and has_a:
		crop = opaque_bounds(ch_a, crop.size.x, crop.size.y)
	layer["crop"] = crop

	# Point every missing channel at an all-255 buffer so the interleave loop
	# needs no per-pixel branch. Built lazily: on a 9M-pixel layer that is 9 MB
	# of pure waste when every channel is present.
	var opaque := PackedByteArray()
	var missing := ch_r.size() != pixel_count or ch_g.size() != pixel_count or ch_b.size() != pixel_count or ch_a.size() != pixel_count
	if missing:
		opaque.resize(pixel_count)
		opaque.fill(255)
	if ch_r.size() != pixel_count:
		ch_r = opaque
	if ch_g.size() != pixel_count:
		ch_g = opaque
	if ch_b.size() != pixel_count:
		ch_b = opaque
	if ch_a.size() != pixel_count:
		ch_a = opaque

	# Interleaving byte-by-byte costs four indexed writes per pixel; writing one
	# RGBA word through an int32 view measured ~1.4x faster on 9M-pixel layers
	# (579 ms -> 416 ms). PackedInt32Array is little-endian on every platform Godot
	# targets, so R lands in the low byte as FORMAT_RGBA8 expects.
	var src_w: int = layer["width"]
	var words := PackedInt32Array()
	words.resize(crop.size.x * crop.size.y)
	var w_i := 0
	for y in crop.size.y:
		var s := (crop.position.y + y) * src_w + crop.position.x
		for x in crop.size.x:
			words[w_i] = ch_r[s] | (ch_g[s] << 8) | (ch_b[s] << 16) | (ch_a[s] << 24)
			s += 1
			w_i += 1
	var img_data := words.to_byte_array()
	# Drop the 4-bytes-per-pixel view before create_from_data() copies again, so a
	# huge layer peaks at 12 B/px (channels + view + image) instead of 16.
	words = PackedInt32Array()

	return Image.create_from_data(crop.size.x, crop.size.y, false, Image.FORMAT_RGBA8, img_data)


static func full_layer_rect(layer: Dictionary) -> Rect2i:
	var w: int = maxi(1, layer.get("width", 1))
	var h: int = maxi(1, layer.get("height", 1))
	return Rect2i(0, 0, w, h)


# Bounding box of every non-transparent pixel. Threshold matches ImageTrimmer
# (alpha > 0.01) so a cropped layer is not trimmed a second time downstream.
# Returns the full rect when the layer is empty, i.e. no crop.
#
# Rows are pre-filtered with a native count() instead of a GDScript loop: on a
# full-canvas layer with ~7% content that skips three quarters of the rows and
# measured 4.9x faster overall (171 ms -> 36 ms per 9M-pixel layer).
static func opaque_bounds(alpha: PackedByteArray, w: int, h: int) -> Rect2i:
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		var row := y * w
		if alpha.slice(row, row + w).count(0) == w:
			continue
		var lo := -1
		for x in w:
			if alpha[row + x] > 2:
				lo = x
				break
		# The row filter only proves some byte is non-zero, so a row can still hold
		# nothing above the alpha threshold. Bail out, or the -1 sentinel leaks into
		# min_x and widens the crop past the layer on both sides.
		if lo < 0:
			continue
		var hi := -1
		for x in range(w - 1, -1, -1):
			if alpha[row + x] > 2:
				hi = x
				break
		if lo < min_x:
			min_x = lo
		if hi > max_x:
			max_x = hi
		if y < min_y:
			min_y = y
		if y > max_y:
			max_y = y
	if max_x < 0:
		return Rect2i(0, 0, w, h)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
