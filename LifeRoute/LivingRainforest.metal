#include <metal_stdlib>
using namespace metal;

struct LivingSceneUniforms {
    float2 uvScale;
    float2 textureSize;
    float time;
    float motion;
    float atmosphere;
    float padding;
};

struct LivingSceneVertex { float4 position [[position]]; float2 uv; };

vertex LivingSceneVertex livingSceneVertex(uint id [[vertex_id]]) {
    const float2 positions[] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
    float2 p = positions[id];
    return {float4(p, 0, 1), float2(p.x * 0.5 + 0.5, 0.5 - p.y * 0.5)};
}

static float livingHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float livingNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(livingHash(i), livingHash(i + float2(1, 0)), f.x),
               mix(livingHash(i + float2(0, 1)), livingHash(i + 1), f.x), f.y);
}

static float livingOval(float2 uv, float2 center, float2 radius) {
    float2 p = (uv - center) / radius;
    return 1.0 - smoothstep(0.42, 1.0, dot(p, p));
}

// Two advected samples hand over at zero weight before either phase wraps.
// Texture details travel downstream continuously rather than rocking backwards.
static float3 livingAdvect(texture2d<float> artwork, sampler sampling,
                           float2 uv, float2 flow, float time, float rate) {
    float a = fract(time * rate), b = fract(a + 0.5);
    float weight = 1.0 - abs(a * 2.0 - 1.0);
    float3 first = artwork.sample(sampling, uv - flow * (a - 0.5)).rgb;
    float3 second = artwork.sample(sampling, uv - flow * (b - 0.5)).rgb;
    return first * weight + second * (1.0 - weight);
}

fragment float4 livingRainforestFragment(LivingSceneVertex in [[stage_in]],
                                         texture2d<float> artwork [[texture(0)]],
                                         constant LivingSceneUniforms &u [[buffer(0)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    // Fixed framing. Time never enters the camera or the aspect-fill transform.
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling, uv).rgb;
    if (u.motion <= 0.0) return float4(original, 1);
    float t = u.time;
    float3 color = original;

    // Soft masks are calibrated to the existing 941 x 1672 photograph. Trunks,
    // rock banks, distant scenery and framing remain fixed. Only leaf clusters flex.
    float leaf = max(livingOval(uv, float2(0.73, 0.195), float2(0.15, 0.071)),
                     livingOval(uv, float2(0.86, 0.408), float2(0.19, 0.070)));
    leaf = max(leaf, livingOval(uv, float2(0.73, 0.822), float2(0.25, 0.075)));
    leaf = max(leaf, livingOval(uv, float2(0.23, 0.837), float2(0.21, 0.089)));
    if (leaf > 0.001) {
        float sway = sin(t * 0.91 + uv.y * 13.0) + 0.34 * sin(t * 1.47 + uv.x * 17.0);
        float2 flex = float2(sway * 1.65, sin(t * 0.73 + uv.x * 8.0) * 0.8);
        color = artwork.sample(sampling, uv + flex / u.textureSize * leaf * u.motion).rgb;
    }

    // Falling water accelerates and spreads from the lip into the spray basin.
    float fallProgress = saturate((uv.y - 0.402) / 0.158);
    float fallCenter = mix(0.547, 0.569, fallProgress);
    float fallWidth = mix(0.014, 0.033, fallProgress);
    float fall = (1.0 - smoothstep(fallWidth * 0.55, fallWidth, abs(uv.x - fallCenter)))
        * smoothstep(0.398, 0.414, uv.y) * (1.0 - smoothstep(0.548, 0.568, uv.y));

    // Curved stream coordinates follow the actual water course between the rocks.
    float riverY = clamp(uv.y, 0.559, 0.748);
    float center, slope, width;
    if (riverY < 0.613) {
        center = mix(0.582, 0.647, (riverY - 0.559) / 0.054); slope = 1.20; width = 0.033;
    } else if (riverY < 0.658) {
        center = mix(0.647, 0.587, (riverY - 0.613) / 0.045); slope = -1.33; width = 0.037;
    } else if (riverY < 0.700) {
        center = mix(0.587, 0.550, (riverY - 0.658) / 0.042); slope = -0.88; width = 0.033;
    } else {
        center = mix(0.550, 0.611, (riverY - 0.700) / 0.048); slope = 1.27; width = 0.040;
    }
    float river = (1.0 - smoothstep(width * 0.5, width, abs(uv.x - center)))
        * smoothstep(0.554, 0.572, uv.y) * (1.0 - smoothstep(0.735, 0.756, uv.y));
    // Exclude green occluding foliage and dark rocks from the water matte.
    float waterMaterial = (1.0 - smoothstep(0.035, 0.15, original.g - original.r))
        * smoothstep(0.025, 0.16, dot(original, float3(0.2126, 0.7152, 0.0722)));
    fall *= waterMaterial;
    river *= waterMaterial;
    if (fall > 0.001) {
        float2 flow = float2(0.0018 * sin(uv.y * 43.0), 0.032 + 0.025 * fallProgress) * u.motion;
        float3 water = livingAdvect(artwork, sampling, uv, flow, t, 0.63);
        // Advected narrow filaments resolve the falling sheet itself, with
        // different local speeds. This is confined to actual falling water.
        float streak = livingNoise(float2(uv.x * 680.0, uv.y * 185.0 - t * 10.0));
        float turbulence = livingNoise(float2(uv.x * 205.0 + t * 0.7, uv.y * 280.0 - t * 18.0));
        water *= 0.78 + 0.42 * streak;
        water += float3(0.13, 0.15, 0.15) * smoothstep(0.47, 0.90, turbulence) * u.motion;
        color = mix(color, water, fall * 0.96);
    }
    if (river > 0.001) {
        float speed = mix(0.010, 0.032, saturate((uv.y - 0.559) / 0.189));
        float2 flow = float2(slope * speed * 0.65, speed) * u.motion;
        float ripple = sin(uv.y * 580.0 - t * 6.0 + sin(uv.x * 140.0 + t));
        float2 surface = uv + float2(ripple * 0.65, ripple * 0.28) / u.textureSize * u.motion;
        float3 water = livingAdvect(artwork, sampling, surface, flow, t, 0.48);
        color = mix(color, water, river * 0.94);
    }

    // Spray rises out of the waterfall's impact, dissipating into the existing
    // sunlit air. No rain, screen-wide particles, moving light, or new weather.
    float mist = livingOval(uv, float2(0.584, 0.538), float2(0.072, 0.065));
    if (mist > 0.001 && u.atmosphere > 0.0) {
        float billow = livingNoise(uv * float2(38, 49) + float2(-t * 0.16, t * 0.33));
        billow = billow * 0.65 + livingNoise(uv * 87.0 + float2(t * 0.20, t * 0.51)) * 0.35;
        float opacity = mist * (0.02 + 0.11 * billow) * u.atmosphere;
        color = mix(color, float3(0.72, 0.78, 0.70), opacity);
    }
    return float4(color, 1);
}
