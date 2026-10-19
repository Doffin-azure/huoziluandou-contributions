// Shared by the actual ground and its incisions, so an inscription never
// introduces a differently painted square on top of the stone.
uniform sampler2D land_mask : filter_linear, repeat_disable;
uniform vec4 theme_tint : source_color = vec4(1.0);
uniform vec3 stone_color : source_color = vec3(.245,.250,.245);
uniform vec3 stone_cool : source_color = vec3(.205,.229,.251);
uniform vec3 stone_warm : source_color = vec3(.275,.260,.235);
uniform vec2 stone_grid_offset = vec2(0.0);
// Authored court edging is part of the same stone, not another coplanar mesh.
uniform vec2 court_origin = vec2(0.0);
uniform vec2 court_x = vec2(1.0,0.0);
uniform vec2 court_z = vec2(0.0,1.0);
uniform vec2 court_size = vec2(0.0);
uniform float court_style = 0.0;
float stone_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float stone_noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(stone_hash(i),stone_hash(i+vec2(1,0)),f.x),mix(stone_hash(i+vec2(0,1)),stone_hash(i+vec2(1)),f.x),f.y);
}
vec3 stone_surface(vec2 p) {
    float patch = stone_noise(p*.63+vec2(4,9));
    vec3 col = mix(stone_cool,stone_warm,smoothstep(.22,.79,patch));
    float tile = stone_hash(floor(p+stone_grid_offset)+vec2(7,13));
    col = mix(col,stone_color,.35)*mix(.78,1.16,floor(tile*4.0)/3.0);
    vec2 seam = min(fract(p+stone_grid_offset),1.0-fract(p+stone_grid_offset));
    float joint = 1.0-smoothstep(.009,.020,min(seam.x,seam.y));
    col *= (1.0-joint*.43)*mix(.98,1.02,stone_noise(p*1.6));
    if (court_style > .5) {
        vec2 q = vec2(dot(p-court_origin,court_x),dot(p-court_origin,court_z));
        float edge = min(min(q.x,court_size.x-q.x),min(q.y,court_size.y-q.y));
        float band = 1.0-smoothstep(.035,.055,abs(edge-.38));
        float inner = 1.0-smoothstep(.010,.019,abs(edge-.50));
        col = mix(col,col*vec3(.78,.82,.86),band*.65);
        col *= 1.0-inner*.30;
        if (court_style > 2.5) {
            float axis_band = 1.0-smoothstep(.014,.024,abs(abs(q.x-court_size.x*.5)-1.10));
            col *= 1.0-axis_band*.25*smoothstep(.7,1.0,edge);
        }
    }
    float shore = 1.0-smoothstep(.5,.94,texture(land_mask,(p+vec2(3))/vec2(18,14)).r);
    return col*mix(vec3(1),vec3(.78,.80,.82),shore*.50)*theme_tint.rgb;
}
