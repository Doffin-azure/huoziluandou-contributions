extends RefCounted
## Raster masks reuse the engine's font cache. No per-letter viewport or RNG.
const RESOLUTION := 256
const FONT_SIZE := 192
static var _cache: Dictionary = {}


static func texture_for(font: Font, text: String) -> Texture2D:
	var key := str(font.get_instance_id())+":"+text
	if _cache.has(key): return _cache[key]
	var result := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	var server := TextServerManager.get_primary_interface()
	var size_key := Vector2i(FONT_SIZE,0)
	# Map inscriptions are single characters, including directional arrows.
	if not text.is_empty():
		for font_rid: RID in font.get_rids():
			var index := server.font_get_glyph_index(font_rid,FONT_SIZE,text.unicode_at(0),0)
			if index==0: continue
			server.font_render_glyph(font_rid,size_key,index)
			var atlas_index := server.font_get_glyph_texture_idx(font_rid,size_key,index)
			var atlas := server.font_get_texture_image(font_rid,size_key,atlas_index)
			if atlas==null: continue
			var rect := Rect2i(server.font_get_glyph_uv_rect(font_rid,size_key,index))
			var bitmap := atlas.get_region(rect)
			bitmap.convert(Image.FORMAT_RGBA8)
			if maxi(bitmap.get_width(),bitmap.get_height())>FONT_SIZE:
				var ratio := float(FONT_SIZE)/maxi(bitmap.get_width(),bitmap.get_height())
				bitmap.resize(maxi(1,roundi(bitmap.get_width()*ratio)),maxi(1,roundi(bitmap.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
			result.blit_rect(bitmap,Rect2i(Vector2i.ZERO,bitmap.get_size()),(Vector2i.ONE*RESOLUTION-bitmap.get_size())/2)
			break
	result.generate_mipmaps()
	var texture := ImageTexture.create_from_image(result)
	_cache[key] = texture
	return texture
