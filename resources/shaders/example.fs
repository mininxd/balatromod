#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
	#define MY_HIGHP_OR_MEDIUMP highp
#else
	#define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern MY_HIGHP_OR_MEDIUMP float time;
extern MY_HIGHP_OR_MEDIUMP vec4 texture_details;
extern MY_HIGHP_OR_MEDIUMP vec2 image_details;
extern MY_HIGHP_OR_MEDIUMP vec4 colour_1;
extern MY_HIGHP_OR_MEDIUMP vec4 colour_2;

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    // Get original texture color and Alpha mask
    MY_HIGHP_OR_MEDIUMP vec4 tex = Texel(texture, texture_coords);
    
    // Correct UV coordinates based on Balatro's atlas system
    MY_HIGHP_OR_MEDIUMP vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;
    
    // Center UVs for rotation/scaling
    MY_HIGHP_OR_MEDIUMP vec2 uv_c = uv - 0.5;
    
    // Complex Noise Field (similar to Balatro's style)
    MY_HIGHP_OR_MEDIUMP float t = time * 0.5;
    MY_HIGHP_OR_MEDIUMP vec2 uv_noise = uv_c * 4.0;
    
    MY_HIGHP_OR_MEDIUMP float noise = 0.0;
    noise += sin(uv_noise.x + t) * cos(uv_noise.y + t);
    noise += sin(uv_noise.y * 1.5 - t) * cos(uv_noise.x * 1.5 + t);
    noise += sin(length(uv_noise) * 2.0 - t);
    
    noise = (noise + 3.0) / 6.0; // Normalize to 0-1
    
    // Stars / Sparkle effect
    MY_HIGHP_OR_MEDIUMP float sparkle = fract(sin(dot(uv_c + floor(time*20.0)*0.01, vec2(12.9898, 78.233))) * 43758.5453);
    sparkle = smoothstep(0.99, 1.0, sparkle);
    
    // Color mixing
    MY_HIGHP_OR_MEDIUMP vec3 final_rgb = mix(colour_1.rgb, colour_2.rgb, noise);
    final_rgb += sparkle * 0.5;
    
    // Important: Use the original texture alpha so it stays within the UI box
    // Also use the provided color (modulates alpha/brightness)
    return vec4(final_rgb, tex.a * colour.a);
}
