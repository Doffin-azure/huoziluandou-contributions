shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 spark_color : source_color = vec3(.45,.53,.68);
uniform float map_shade = 1.0;
varying float life;
void vertex() {
    life = fract(TIME*.22+INSTANCE_CUSTOM.x);
    VERTEX.y += life*.10;
    VERTEX.x += sin(life*5.0+INSTANCE_CUSTOM.y*6.28)*.009;
}
void fragment() {
    if (life<.20 || life>.78 || map_shade<.9) { discard; }
    float pulse = sin((life-.20)/.58*3.14159);
    ALBEDO = spark_color*pulse*.65;
    EMISSION = spark_color*pulse*.55;
}
