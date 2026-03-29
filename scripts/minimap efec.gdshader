shader_type canvas_item;

uniform float border_width : hint_range(0.0, 10.0) = 4.0; // Ancho del borde
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color del borde

void fragment() {
    // Coordenadas del centro y el radio del círculo
    vec2 center = vec2(0.5);
    float radius = 0.5;

    // Distancia del pixel actual al centro
    float dist = distance(UV, center);

    // Aplicar la máscara circular y el borde
    if (dist > radius) {
        discard; // Descarta cualquier pixel fuera del círculo
    } else if (dist > radius - (border_width / 100.0)) {
        COLOR = border_color; // Dibuja el borde
    } else {
        COLOR = texture(TEXTURE, UV); // Muestra el contenido del minimapa
    }
}
