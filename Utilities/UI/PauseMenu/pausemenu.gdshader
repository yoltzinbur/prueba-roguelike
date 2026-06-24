shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 5.0) = 2.0; // Ajusta el nivel de borrosidad

void fragment() {
    // 1. Tomamos el fondo del juego y lo difuminamos
    vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV, lod);
    
    // 2. Lo oscurecemos un poco (multiplicando por 0.5) para que actúe como una capa de sombra
    color.rgb *= 0.5;
    
    COLOR = color;
}
