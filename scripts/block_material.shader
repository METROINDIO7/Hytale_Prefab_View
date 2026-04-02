// block_material.shader
// Custom shader for block texturing - each face uses full texture (0-1 UVs)
// Texture filter: NEAREST (pixelated style)

shader_type spatial;

uniform sampler2D albedo_texture : hint_default_white, filter_nearest;
uniform vec3 albedo_color : hint_color = vec3(1.0);

void fragment() {
	// Sample texture directly
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Use texture color, fallback to albedo_color if texture is transparent
	vec3 final_color = tex_color.rgb;
	if (tex_color.a < 0.1) {
		final_color = albedo_color;
	}
	
	ALBEDO = final_color;
	ALPHA = tex_color.a;
}

