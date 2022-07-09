#version 330 core

uniform vec3 u_CamPos;

// PBR material attributes
uniform vec3 u_Albedo;
uniform float u_Metallic;
uniform float u_Roughness;
uniform float u_AmbientOcclusion;
// Texture maps for controlling some of the attribs above, plus normal mapping
uniform sampler2D u_AlbedoMap;
uniform sampler2D u_MetallicMap;
uniform sampler2D u_RoughnessMap;
uniform sampler2D u_AOMap;
uniform sampler2D u_NormalMap;
// If true, use the textures listed above instead of the GUI slider values
uniform bool u_UseAlbedoMap;
uniform bool u_UseMetallicMap;
uniform bool u_UseRoughnessMap;
uniform bool u_UseAOMap;
uniform bool u_UseNormalMap;

// Image-based lighting
uniform samplerCube u_DiffuseIrradianceMap;
uniform samplerCube u_GlossyIrradianceMap;
uniform sampler2D u_BRDFLookupTexture;

// Varyings
in vec3 fs_Pos;
in vec3 fs_Nor; // Surface normal
in vec3 fs_Tan; // Surface tangent
in vec3 fs_Bit; // Surface bitangent
in vec2 fs_UV;
out vec4 out_Col;

const float PI = 3.14159f;

// Set the input material attributes to texture-sampled values
// if the indicated booleans are TRUE
void handleMaterialMaps(inout vec3 albedo, inout float metallic,
                        inout float roughness, inout float ambientOcclusion,
                        inout vec3 normal) {
    if(u_UseAlbedoMap) {
        albedo = texture(u_AlbedoMap, fs_UV).rgb;
    }
    if(u_UseMetallicMap) {
        metallic = texture(u_MetallicMap, fs_UV).r;
    }
    if(u_UseRoughnessMap) {
        roughness = texture(u_RoughnessMap, fs_UV).r;
    }
    if(u_UseAOMap) {
        ambientOcclusion = texture(u_AOMap, fs_UV).r;
    }
    if(u_UseNormalMap) {
        // TODO: Apply normal mapping
        normal = texture(u_NormalMap, fs_UV).rgb;
    }
}
// -------------------------------------------------
float DistributionGGX(vec3 N, vec3 H, float a)
{
    float a2     = a*a*a*a;
    float NdotH  = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom    = a2;
    float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
    denom        = PI * denom * denom;

    return nom / denom;
}

// --------------------------------------------------
float GeometrySchlickGGX(float NdotV, float k)
{
    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float k)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx1 = GeometrySchlickGGX(NdotV, k);
    float ggx2 = GeometrySchlickGGX(NdotL, k);

    return ggx1 * ggx2;
}
// --------------------------------------------------
// we take the roughness into consideration now
// the rougher the surface, less fresnel effects
vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}
void main()
{
    vec3  N                = fs_Nor;
    vec3  albedo           = u_Albedo;
    float metallic         = u_Metallic;
    float roughness        = u_Roughness;
    float ambientOcclusion = u_AmbientOcclusion;

    handleMaterialMaps(albedo, metallic, roughness, ambientOcclusion, N);

    // the ray traveling from the point to camera
    vec3 wo = normalize(u_CamPos - fs_Pos);
    // microfacet surface normal to reflect wo in the direction of wi
    vec3 wh = N;
    // the ray traveling from the point to irradiance source
    vec3 wi = reflect(-wo, wh);

    vec3 baseReflectivty = mix(vec3(0.04), u_Albedo, u_Metallic);

    // reflectance equation
    vec3 Lo = vec3(0.0);

    // ambient light
    // diffusion
    vec3 kS = fresnelSchlickRoughness(max(dot(wh, wo), 0.0), baseReflectivty, roughness);
    vec3 kD = (1.0 - kS) ; // energy conservation
    vec3 irradiance = texture(u_DiffuseIrradianceMap, N).rgb;
    vec3 diffuse = irradiance * albedo ;

    // speculation: sample both the pre-filter map and the BRDF lut and combine them together as per the Split-Sum approximation to get the IBL specular part.
    const float MAX_REFLECTION_LOD = 4.0;
    vec3 prefilteredColor = textureLod(u_GlossyIrradianceMap, wi,  u_Roughness * MAX_REFLECTION_LOD).rgb;
    vec2 brdf  = texture(u_BRDFLookupTexture, vec2(max(dot(wh, wo), 0.0), u_Roughness)).rg;
    vec3 specular = prefilteredColor * (baseReflectivty * brdf.x + brdf.y);

    vec3 ambient  = (kD * diffuse + specular) * u_AmbientOcclusion;

    vec3 color = ambient + Lo;

    // tone mapping: apply the Reinhard operator to your color term
    color = color / (color + vec3(1.0));
    // gamma correction
    color = pow(color, vec3(1.0 / 2.2));

    out_Col = vec4(color, 1.f);}
