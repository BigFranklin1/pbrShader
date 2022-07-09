#version 330 core

uniform vec3 u_CamPos;

// PBR material attributes
uniform vec3  u_Albedo;
uniform float u_Metallic;
uniform float u_Roughness;
uniform float u_AmbientOcclusion;

// Varyings
in vec3 fs_Pos;
in vec3 fs_Nor;
out vec4 out_Col;

// Point lights
const vec3 light_pos[4] = vec3[](vec3(-10, 10, 10),
                                 vec3(10, 10, 10),
                                 vec3(-10, -10, 10),
                                 vec3(10, -10, 10));

const vec3 light_col[4] = vec3[](vec3(300.f, 300.f, 300.f),
                                 vec3(300.f, 300.f, 300.f),
                                 vec3(300.f, 300.f, 300.f),
                                 vec3(300.f, 300.f, 300.f));

const float PI = 3.14159f;
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

vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// --------------------------------------------------
void main()
{

    vec3 N = normalize(fs_Nor);
    vec3 V = normalize(u_CamPos - fs_Pos);

    vec3 baseReflectivty = mix(vec3(0.04), u_Albedo, u_Metallic);


    // reflectance equation
    vec3 Lo = vec3(0.0);

    for(int i = 0; i < 4; ++i)
    {
        // point light intensity falloff
        float distance    = length(light_pos[i] - fs_Pos);
        float attenuation = 1.0 / (distance * distance);
        vec3 radiance     = light_col[i] * attenuation;

        vec3 L = normalize(light_pos[i] - fs_Pos); // light
        vec3 H = normalize(V + L); // half way vector
        // Cook-Torrance BRDF
        // D(ωh): Distribution of facets aligned with half-vector
        float D = DistributionGGX(N, H, u_Roughness);
        // G(ωo,ωi): Geometric attenuation (microfacet self-shadowing)
        float G = GeometrySmith(N, V, L, u_Roughness);
        // Fr(ωo): Fresnel reflectance
        float cosTheta = max(dot(H, V), 0.0);
        vec3 F = fresnelSchlick(cosTheta, baseReflectivty);


        // The specular part of the BRDF
        vec3 numerator = D * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        vec3 specular     = numerator / denominator;


        // Diffuse and Glossy Coefficients with energy conservation
        // kD is for diffusion
        vec3 kD = vec3(1.0) - F;
        // kD only applies to non-metalic materials
        kD *= 1.0 - u_Metallic;

        vec3 f_lambert = u_Albedo / PI;

        Lo += (kD * f_lambert + specular) * radiance * max (dot(N, L), 0.0);
    }

    // ambient light
    vec3 ambient  = vec3(0.03) * u_Albedo * u_AmbientOcclusion;
    vec3 color = ambient + Lo;

    // tone mapping: apply the Reinhard operator to your Lo term
    color = color / (color + vec3(1.0));
    // gamma correction
    color = pow(color, vec3(1.0 / 2.2));

    out_Col = vec4(color, 1.f);
}
