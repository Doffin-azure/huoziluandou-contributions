shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
uniform vec4 wear_color : source_color;
uniform vec4 recess_color : source_color;
uniform float metallic_amount = 0.0;
uniform float roughness_amount = 0.65;
uniform int surface_kind = 0; // metal, wood, cloth, stone
varying vec3 local_position;

float hash31(vec3 p) {
 p = fract(p * 0.1031); p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_position = VERTEX; }
void fragment() {
 vec3 p = local_position;
 float broad = noise3(p * 9.0);
 float fine = noise3(p * 145.0);
 float wear = smoothstep(0.64, 0.90, broad) * 0.5;
 float marks = smoothstep(0.65, 0.86, noise3(p * 36.0)) * 0.18;
 if (surface_kind == 1) {
   fine = noise3(p * vec3(65.0, 5.0, 65.0));
   marks += pow(abs(sin(p.y * 95.0 + noise3(p*9.0)*7.0)), 14.0) * 0.14;
 } else if (surface_kind == 2) {
   fine = sin(p.x*900.0)*sin(p.z*900.0)*0.25+0.5;
   marks *= 0.4;
 } else if (surface_kind == 3) {
   wear *= 0.5;
   marks += smoothstep(0.78,0.9,noise3(p*75.0))*0.2;
 }
 vec3 paint = mix(base_color.rgb, wear_color.rgb, wear);
 ALBEDO = mix(paint, recess_color.rgb, marks) * (0.92 + fine * 0.16);
 METALLIC = metallic_amount;
 ROUGHNESS = clamp(roughness_amount + (fine - 0.5) * 0.15, 0.25, 1.0);
 SPECULAR = 0.45;
}
