shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://src/shaders/expedition_stone_surface.gdshaderinc"
uniform sampler2D glyph_mask : filter_linear_mipmap, repeat_disable;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 fog_color : source_color = vec3(.022,.026,.033);
uniform float worn : hint_range(0.0,1.0) = 0.0;
uniform float map_shade = 1.0;
varying vec3 world_position;

void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }

float cut_mask(vec2 uv) {
    // Broad chips break the mechanically perfect font edge without adding
    // a second high-contrast texture or erasing thin recognisable strokes.
    float chip = smoothstep(.69,.85,stone_noise(world_position.xz*81.0));
    return texture(glyph_mask,uv).a*(1.0-chip*.34);
}

void fragment() {
    vec2 p = world_position.xz;
    vec2 texel = 1.0/vec2(textureSize(glyph_mask,0));
    float cut = cut_mask(UV);
    float left = cut_mask(UV-vec2(texel.x*1.6,0));
    float right = cut_mask(UV+vec2(texel.x*1.6,0));
    float front = cut_mask(UV-vec2(0,texel.y*1.6));
    float back = cut_mask(UV+vec2(0,texel.y*1.6));
    float rim = max(max(left,right),max(front,back));
    float depth = mix(.65,.38,worn);
    vec3 col = stone_surface(p);
    // The groove is darker stone, with one narrow chipped lip catching light.
    col *= 1.0-cut*depth;
    col *= 1.0+max(0.0,rim-cut)*.22;
    float grain = stone_noise(p*170.0);
    col *= 1.0+cut*(grain-.5)*.12;
    vec3 slope = vec3((right-left)*1.4,0.0,(back-front)*1.4);
    NORMAL = normalize(NORMAL+(VIEW_MATRIX*vec4(slope,0.0)).xyz);
    vec2 fog = map_vision_at(p);
    float explored = smoothstep(.08,.70,fog.r);
    col *= mix(.42,1.0,smoothstep(.08,.9,fog.g));
    ALBEDO = col*explored;
    EMISSION = fog_color*(1.0-explored);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
