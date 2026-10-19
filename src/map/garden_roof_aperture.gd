extends RefCounted
## Keep the roof silhouette; reveal only a small screen-space window around
## the walker. Shared shader variants use per-instance aperture parameters.
static var _shaders := {}
static var _wall_shaders := {}


static func material(original: ShaderMaterial) -> ShaderMaterial:
	var source: Shader = original.shader
	var key := source.get_instance_id()
	if not _shaders.has(key):
		var code := source.code
		var marker := "void fragment() {"
		if not code.contains(marker): return original
		code = code.replace("void vertex() {","varying vec3 garden_roof_world;\nvoid vertex() {\n garden_roof_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n")
		code = code.replace(marker,"""instance uniform vec4 garden_roof_aperture = vec4(0.0);
instance uniform vec4 garden_roof_cut_plane = vec4(0.0);
instance uniform vec4 garden_roof_window = vec4(0.0);
void fragment() {
    if (garden_roof_cut_plane.w > 0.5 && dot(garden_roof_world.xz, garden_roof_cut_plane.xy) > garden_roof_cut_plane.z) discard;
    if (garden_roof_aperture.w > 1.5) {
        if (garden_roof_world.x >= garden_roof_window.x && garden_roof_world.z >= garden_roof_window.y && garden_roof_world.x <= garden_roof_window.z && garden_roof_world.z <= garden_roof_window.w) discard;
    } else {
        vec2 offset = (SCREEN_UV - garden_roof_aperture.xy) * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
        float distance_to_walker = length(offset);
        float coverage = smoothstep(garden_roof_aperture.z * 0.85, garden_roof_aperture.z, distance_to_walker);
        float stipple = fract(dot(floor(FRAGCOORD.xy), vec2(0.75487766, 0.56984029)));
        if (garden_roof_aperture.w > 0.5 && coverage <= stipple) discard;
    }
""")
		var shader := Shader.new(); shader.code = code; _shaders[key] = shader
	var paint: ShaderMaterial = original.duplicate()
	paint.shader = _shaders[key]
	return paint


static func wall_material(original: ShaderMaterial) -> ShaderMaterial:
	var source: Shader = original.shader; var key := source.get_instance_id()
	if not _wall_shaders.has(key):
		var code := source.code
		if not code.contains("void fragment() {"): return original
		code = code.replace("void vertex() {","varying vec3 garden_wall_world;\nvoid vertex() {\n garden_wall_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n")
		code = code.replace("void fragment() {","""instance uniform vec4 garden_wall_clip = vec4(0.0);
instance uniform vec4 garden_wall_plane = vec4(0.0);
void fragment() {
    bool in_room = garden_wall_world.x >= garden_wall_clip.x && garden_wall_world.z >= garden_wall_clip.y && garden_wall_world.x <= garden_wall_clip.z && garden_wall_world.z <= garden_wall_clip.w;
    if (garden_wall_plane.w > 0.5 && in_room && garden_wall_world.y > 0.78 && dot(garden_wall_world.xz, garden_wall_plane.xy) > garden_wall_plane.z) discard;
""")
		var shader := Shader.new(); shader.code = code; _wall_shaders[key] = shader
	var paint: ShaderMaterial = original.duplicate(); paint.shader = _wall_shaders[key]
	return paint
