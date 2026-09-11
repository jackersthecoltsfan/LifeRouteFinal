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

#include "LivingOceanTiming.h"
#include "LivingRainforestMotion.h"
#include "LivingArcticMotion.h"
#include "LivingMountainsMotion.h"
#include "LivingCanyonMotion.h"
#include "LivingDesertMotion.h"
#include "LivingAtmosphereMotion.h"

struct LivingAtmosphereConfiguration {
    float4 skyA, skyB, light, air;
};
static float3 livingClouds(texture2d<float>, sampler, float2, float3, float, float, float, LivingAtmosphereConfiguration);
static float3 livingNightSky(float3, float2, float, float, float, LivingAtmosphereConfiguration);

// Ocean is a train of finite, independently shaped wave events. A wave enters,
// grows a face, crests, spills, leaves an expanding foam wake, then dissipates.
// Events overlap but never translate the camera, horizon, or exposed seabed.
struct LivingOceanConfiguration {
    float horizon, crestIntercept, crestSlope, shallow;
    float reflectionX, night, swellAmplitude, padding;
};

struct LivingWaveEvent {
    float age, lifetime, progress, front, width, strength;
    float swell, crest, breaking, foam, envelope;
};

static LivingWaveEvent livingOceanEvent(float time, float eventID) {
    float seed = livingHash(float2(eventID, LIVING_OCEAN_START_SEED));
    float start = eventID * LIVING_OCEAN_ARRIVAL_SPACING + seed * LIVING_OCEAN_START_JITTER;
    // Bounded to 18 seconds; arrival spacing, not a longer lifetime, supplies overlap.
    float life = LIVING_OCEAN_LIFETIME_MIN + livingHash(float2(eventID, LIVING_OCEAN_LIFETIME_SEED)) * LIVING_OCEAN_LIFETIME_VARIATION;
    float age = time - start;
    float p = saturate(age / life);
    float envelope = smoothstep(LIVING_OCEAN_ENVELOPE_START, LIVING_OCEAN_ENVELOPE_FULL, p) * (1.0 - smoothstep(LIVING_OCEAN_DISSIPATION_START, LIVING_OCEAN_DISSIPATION_END, p));
    float swell = smoothstep(LIVING_OCEAN_SWELL_START, LIVING_OCEAN_SWELL_FULL, p) * (1.0 - smoothstep(LIVING_OCEAN_SWELL_DECAY, LIVING_OCEAN_SWELL_END, p));
    float crest = smoothstep(LIVING_OCEAN_CREST_START, LIVING_OCEAN_CREST_FULL, p) * (1.0 - smoothstep(LIVING_OCEAN_CREST_DECAY, LIVING_OCEAN_CREST_END, p));
    float breaking = smoothstep(LIVING_OCEAN_BREAK_START, LIVING_OCEAN_BREAK_FULL, p) * (1.0 - smoothstep(LIVING_OCEAN_BREAK_DECAY, LIVING_OCEAN_BREAK_END, p));
    float foam = smoothstep(LIVING_OCEAN_FOAM_START, LIVING_OCEAN_FOAM_FULL, p) * (1.0 - smoothstep(LIVING_OCEAN_FOAM_DECAY, LIVING_OCEAN_FOAM_END, p));
    return {age, life, p, 0.035 + 0.94 * pow(p, LIVING_OCEAN_TRAVEL_EXPONENT),
        0.012 + 0.038 * p, 0.76 + 0.48 * seed,
        swell * envelope, crest * envelope, breaking * envelope, foam * envelope, envelope};
}

// Independent GPU tests read the actual temporal model used by the fragment.
// This kernel is never dispatched by the application.
kernel void livingOceanWaveProbe(device const float2 *requests [[buffer(0)]],
                                 device float4 *values [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    LivingWaveEvent e = livingOceanEvent(requests[id].x, requests[id].y);
    values[id * 3] = float4(e.age, e.lifetime, e.progress, e.front);
    values[id * 3 + 1] = float4(e.swell, e.crest, e.breaking, e.foam);
    values[id * 3 + 2] = float4(e.envelope, e.width, e.strength, 0);
}

fragment float4 livingOceanFragment(LivingSceneVertex in [[stage_in]],
                                    texture2d<float> artwork [[texture(0)]],
                                    constant LivingSceneUniforms &u [[buffer(0)]],
                                    constant LivingOceanConfiguration &o [[buffer(1)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling, uv).rgb;
    if (u.motion <= 0.0) return float4(original, 1);
    if (uv.y <= o.horizon) {
        LivingAtmosphereConfiguration air = {float4(o.horizon),float4(o.horizon),
            float4(o.night, mix(17.0,31.0,o.night), o.reflectionX, 0.145),float4(0.012,0.42,0,0)};
        float sky = 1.0 - smoothstep(o.horizon - 0.06,o.horizon - 0.012,uv.y);
        if (o.night > 0.5) sky *= smoothstep(0.035,0.070,length((uv - float2(o.reflectionX,0.145)) * float2(0.563,1)));
        float t = u.time * mix(LIVING_OCEAN_CALM_TIME_SCALE,LIVING_OCEAN_FULL_TIME_SCALE,u.motion);
        float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,air);
        color = livingNightSky(color,uv,t,sky,u.atmosphere,air);
        return float4(color,1);
    }
    float depth = saturate((uv.y - o.horizon) / (1.0 - o.horizon));
    float wet = smoothstep(0.0, 0.032, depth);
    // Calm slows the physical sequence as well as reducing amplitude. It never
    // removes the primary break/foam stages; those are part of the water itself.
    float t = u.time * mix(LIVING_OCEAN_CALM_TIME_SCALE, LIVING_OCEAN_FULL_TIME_SCALE, u.motion);
    float face = 0, normal = 0, crest = 0, breakWater = 0, wake = 0;
    float newest = floor(t / LIVING_OCEAN_ARRIVAL_SPACING);
    for (int i = 0; i < LIVING_OCEAN_EVENT_SLOTS; ++i) {
        float eventID = newest - float(i);
        LivingWaveEvent e = livingOceanEvent(t, eventID);
        if (e.envelope <= 0.0001) continue;
        float seed = livingHash(float2(eventID, LIVING_OCEAN_START_SEED));
        // Oblique arrivals follow the photographed wave direction. Curvature,
        // crest fragmentation and lifetime vary independently for each arrival.
        float bend = (uv.x - 0.5) * o.crestSlope * 0.64
            + sin(uv.x * (5.0 + seed * 4.0) + seed * 20.0) * 0.018 * e.progress;
        float distance = depth - e.front - bend;
        float ridge = exp(-pow(distance / e.width, 2.0));
        float lip = exp(-pow((distance + e.width * 0.24) / (e.width * 0.21), 2.0));
        float curl = livingNoise(float2(uv.x * 32.0 + seed * 47.0, distance * 65.0 - e.age * LIVING_OCEAN_CURL_RATE));
        float fragments = smoothstep(0.24, 0.69, curl);
        face += ridge * e.swell * e.strength;
        normal += (-distance / e.width) * ridge * e.swell * e.strength;
        // Fine aerated cells fragment the spilling lip. Broad low-frequency
        // noise alone produced pale bars in the Simulator motion capture.
        float aeration = livingNoise(float2(uv.x * 247.0 + seed * 101.0,
            depth * 620.0 - e.age * LIVING_OCEAN_FOAM_ADVECTION_RATE));
        float froth = smoothstep(0.38, 0.74, aeration);
        crest += lip * e.crest * e.strength * smoothstep(0.32, 0.72, curl) * (0.2 + 0.8 * froth);
        breakWater += lip * e.breaking * fragments * e.strength * froth;
        // Foam remains behind the travelling front and spreads across its wake.
        // Two advecting scales erode and reform it; there is no repeating texture.
        float wakeWidth = 0.025 + 0.11 * smoothstep(LIVING_OCEAN_WAKE_SPREAD_START, LIVING_OCEAN_WAKE_SPREAD_END, e.progress);
        float wakeRegion = smoothstep(-wakeWidth, -wakeWidth * 0.2, distance)
            * (1.0 - smoothstep(-0.004, 0.012, distance));
        float lace = livingNoise(float2(uv.x * 113.0 + seed * 101.0, depth * 245.0 - e.age * LIVING_OCEAN_FOAM_ADVECTION_RATE));
        lace = 0.62 * lace + 0.38 * livingNoise(float2(uv.x * 247.0 - e.age * LIVING_OCEAN_FOAM_CROSS_RATE, depth * 397.0 + seed * 13.0));
        wake += wakeRegion * e.foam * smoothstep(0.43, 0.73, lace) * (0.55 + 0.45 * fragments);
    }
    float amplitude = wet * u.motion * o.swellAmplitude;
    float shallows = o.shallow * smoothstep(0.42, 0.82, depth);
    float ripple = sin(log(1.0 + depth * 6.0) * 101.0 + uv.x * 33.0 - t * LIVING_OCEAN_RIPPLE_RATE
        + livingNoise(uv * 29.0 + t * LIVING_OCEAN_RIPPLE_EVOLUTION_RATE));
    float2 offset = float2(-o.crestSlope * normal, normal) * mix(7.0, 0.5, shallows);
    offset += float2(ripple * 0.20, ripple * 0.34);
    float2 sampleUV = uv + offset * amplitude / u.textureSize;
    sampleUV.y = max(o.horizon, sampleUV.y);
    float3 water = artwork.sample(sampling, sampleUV).rgb;
    // A travelling shaded wave face and narrowing illuminated lip supply shape,
    // rather than uniform oscillation or shimmer. Existing water remains visible.
    water *= 1.0 + amplitude * (normal * 0.13 - face * 0.12 + ripple * 0.013);
    float reflectionWidth = 0.035 + depth * 0.19;
    float reflection = exp(-pow((uv.x - o.reflectionX) / reflectionWidth, 2.0)) * o.night;
    water += float3(0.10, 0.14, 0.17) * crest * amplitude * mix(0.6, 0.20 + reflection * 0.9, o.night);
    // Night's unbroken open-water swells spill sparsely; no shore is fabricated.
    float foam = saturate(breakWater * 0.60 + wake * 0.26) * amplitude * mix(1.0, 0.44, o.night);
    float3 foamColor = mix(float3(0.68, 0.84, 0.84), float3(0.14, 0.25, 0.33) + reflection * 0.25, o.night);
    water = mix(water, foamColor, foam);
    water += float3(0.05, 0.075, 0.10) * reflection * amplitude * (normal * 0.18 + crest * 0.23);
    if (u.atmosphere > 0.0) {
        float spray = smoothstep(0.70, 0.93, livingNoise(uv * float2(390, 460) + float2(-t * LIVING_OCEAN_SPRAY_CROSS_RATE, t * LIVING_OCEAN_SPRAY_RISE_RATE)));
        water += foamColor * spray * breakWater * amplitude * u.atmosphere * 0.06;
    }
    return float4(mix(original, water, wet), 1);
}

// Supplemental configuration is only bound for the new family programs. The
// accepted Rainforest Day prefix and its primary uniform layout stay unchanged.

static float livingSky(float2 uv, LivingAtmosphereConfiguration c) {
    float x = clamp(uv.x, 0.0, 0.9999) * 7.0;
    int i = int(floor(x));
    float a = i < 4 ? c.skyA[i] : c.skyB[i - 4];
    int j = i + 1;
    float b = j < 4 ? c.skyA[j] : c.skyB[j - 4];
    float edge = mix(a, b, fract(x));
    return 1.0 - smoothstep(edge - 0.045, edge - 0.012, uv.y);
}

static float livingMoonExclusion(float2 uv, LivingAtmosphereConfiguration c) {
    return smoothstep(0.045, 0.080, length((uv - c.light.zw) * float2(0.563, 1.0)));
}

static float livingFractal(float2 p, float t) {
    float2 warp = float2(livingNoise(p * 0.43 + float2(t * LIVING_AIR_WARP_X, 4.7)),
                        livingNoise(p * 0.51 + float2(9.2, -t * LIVING_AIR_WARP_Y))) - 0.5;
    return livingNoise(p + warp * 1.3) * 0.57
        + livingNoise(p * 2.07 - warp + float2(3.1, t * LIVING_AIR_FINE_DRIFT)) * 0.29
        + livingNoise(p * 4.13 + float2(-t * LIVING_AIR_FINE_REFORM, 7.8)) * 0.14;
}

// Different velocities and independently evolving domain warps create depth.
// Existing cloud material is advected locally; the sky mask excludes terrain.
static float3 livingClouds(texture2d<float> art, sampler sampling, float2 uv,
                          float3 original, float sky, float t, float amount,
                          LivingAtmosphereConfiguration c) {
    if (sky < 0.001 || amount <= 0.0 || c.air.y <= 0.0) return original;
    float night = c.light.x;
    float material = mix(smoothstep(0.05, 0.28, min(original.r, original.g)),
                         smoothstep(0.012, 0.075, dot(original, float3(0.21,0.72,0.07))), night);
    float2 flow = float2(c.air.x * 1.8, c.air.x * 0.25);
    float3 advected = livingAdvect(art, sampling, uv, flow, t, LIVING_AIR_CLOUD_ADVECTION);
    float farLayer = livingFractal(uv * float2(7.5, 15.0) + float2(-t * c.air.x, c.light.y), t);
    float nearLayer = livingFractal(uv * float2(12.5, 24.0) + float2(t * c.air.x * 1.7, -t * LIVING_AIR_CLOUD_VERTICAL), t + c.light.y);
    float structure = smoothstep(0.36, 0.74, farLayer * 0.62 + nearLayer * 0.38);
    float coverage = sky * amount * c.air.y;
    float3 cloud = mix(original, advected, material * coverage * 0.85);
    float3 tint = mix(float3(0.80, 0.86, 0.91), float3(0.08, 0.13, 0.20), night);
    return mix(cloud, tint, structure * coverage * mix(0.19, 0.27, night));
}

// Mist moves through a bounded depth region, not through a translating image.
static float3 livingFog(float3 color, float2 uv, float t, float mask,
                       float amount, float seed, float3 tint) {
    if (mask <= 0.001 || amount <= 0.0) return color;
    float back = livingFractal(uv * float2(9.0, 26.0) + float2(-t * LIVING_AIR_FOG_FAR, seed), t);
    float front = livingFractal(uv * float2(15.0, 39.0) + float2(t * LIVING_AIR_FOG_NEAR, -t * LIVING_AIR_FINE_DRIFT), t + seed);
    float billow = smoothstep(0.22, 0.79, back * 0.6 + front * 0.4);
    return mix(color, tint, mask * amount * (0.025 + 0.26 * billow));
}

// Sparse deterministic depth layers; no emitters, allocations or extra clocks.
static float livingPrecipitation(float2 uv, float t, float seed, bool snow) {
    float sum = 0;
    for (int layer = 0; layer < 3; ++layer) {
        float d = float(layer);
        float2 p = uv * float2(72.0 - d * 15.0, 68.0 - d * 12.0);
        p -= float2(t * (snow ? LIVING_AIR_SNOW_DRIFT_BASE + d * LIVING_AIR_SNOW_DRIFT_DEPTH : LIVING_AIR_RAIN_DRIFT), t * (snow ? LIVING_AIR_SNOW_FALL_BASE + d * LIVING_AIR_SNOW_FALL_DEPTH : LIVING_AIR_RAIN_FALL_BASE + d * LIVING_AIR_RAIN_FALL_DEPTH));
        float2 cell = floor(p), local = fract(p) - 0.5;
        float random = livingHash(cell + seed + d * 37.0);
        if (random < (snow ? 0.965 : 0.981)) continue;
        local.x += snow ? sin(t * (LIVING_AIR_SNOW_SWAY_BASE + d * LIVING_AIR_SNOW_SWAY_DEPTH) + random * 80.0) * 0.14 : local.y * 0.10;
        float2 radius = snow ? float2(0.027 + d * 0.012) : float2(0.019, 0.20);
        float dotSize = dot(local / radius, local / radius);
        sum += exp(-dotSize) * (0.24 + d * 0.13);
    }
    return sum;
}

static float3 livingNightSky(float3 color, float2 uv, float t, float sky,
                            float amount, LivingAtmosphereConfiguration c) {
    if (sky < 0.001 || amount <= 0.0 || c.light.x < 0.5) return color;
    float seed = c.light.y;
    // Existing photographed stars vary faintly; no global brightness oscillation.
    float starMaterial = smoothstep(0.12, 0.45, max(color.r, max(color.g, color.b)));
    color += color * starMaterial * sin(t * LIVING_AIR_STAR_RATE + livingHash(floor(uv * 800.0)) * 30.0) * 0.08 * sky * amount;
    // One 0.75-second meteor in a scene-seeded 71-second slot, with varied
    // start, origin and slope each time. Separate scenes never synchronize.
    float slot = floor((t + seed * LIVING_AIR_METEOR_SEED_SCALE) / LIVING_AIR_METEOR_SLOT);
    float random = livingHash(float2(slot, seed));
    float age = t + seed * LIVING_AIR_METEOR_SEED_SCALE - slot * LIVING_AIR_METEOR_SLOT - (LIVING_AIR_METEOR_START_MIN + random * LIVING_AIR_METEOR_START_RANGE);
    if (age > 0.0 && age < LIVING_AIR_METEOR_DURATION) {
        float2 origin = float2(0.28 + random * 0.37, 0.10 + livingHash(float2(seed, slot)) * 0.16);
        float2 direction = normalize(float2(1.0, 0.36 + random * 0.28));
        float2 head = origin + direction * age * LIVING_AIR_METEOR_TRAVEL_RATE;
        float2 delta = uv - head;
        float along = dot(delta, direction), across = abs(delta.x * direction.y - delta.y * direction.x);
        float streak = (1.0 - smoothstep(0.0004, 0.0017, across))
            * smoothstep(-0.08, -0.003, along) * (1.0 - smoothstep(0.0, 0.003, along));
        float envelope = sin(age / LIVING_AIR_METEOR_DURATION * M_PI_F);
        color += float3(0.20, 0.26, 0.34) * streak * envelope * sky * amount;
    }
    return color;
}

fragment float4 livingRainforestNightFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling, uv).rgb;
    if (u.motion <= 0.0) return float4(original, 1);
    float t = u.time * mix(LIVING_RF_CALM_SCALE, 1.0, u.motion), colorAmount = u.motion;
    // This photograph has a stream and pool, not a distinct waterfall.
    float y = saturate((uv.y - 0.51) / 0.29);
    float center = 0.49 - 0.055 * sin(y * 4.1);
    float stream = (1.0 - smoothstep(0.12, 0.24, abs(uv.x - center)))
        * smoothstep(0.50, 0.55, uv.y) * (1.0 - smoothstep(0.75, 0.82, uv.y));
    float material = smoothstep(0.003, 0.025, original.b - original.r)
        * (1.0 - smoothstep(0.01, 0.04, original.g - original.b));
    float ripple = sin(uv.y * 560.0 - t * LIVING_RF_STREAM_RIPPLE_RATE + sin(uv.x * 77.0 + t * LIVING_RF_STREAM_VARIATION_RATE));
    float2 flow = float2(0.007 + y * 0.012, 0.004 + y * 0.015) * u.motion;
    float3 moving = livingAdvect(artwork, sampling, uv + float2(ripple * 0.5, ripple * 0.18) / u.textureSize * u.motion, flow, t, LIVING_RF_STREAM_ADVECTION_RATE);
    moving *= 1.0 + ripple * 0.04 * u.motion;
    float3 color = mix(original, moving, stream * material * 0.94);
    float leaf = max(livingOval(uv, float2(0.22,0.82),float2(0.17,0.06)),
                     livingOval(uv, float2(0.87,0.56),float2(0.11,0.07)));
    if (leaf > 0.001 && u.atmosphere > 0.0) {
        float2 offset = float2(sin(t * LIVING_RF_LEAF_SWAY_RATE + uv.y * 11.0), sin(t * LIVING_RF_LEAF_CROSS_RATE + uv.x * 19.0) * 0.5);
        color = mix(color, artwork.sample(sampling, uv + offset / u.textureSize * colorAmount).rgb, leaf * u.atmosphere);
    }
    float mist = livingOval(uv, float2(0.49,0.545),float2(0.28,0.045));
    color = livingFog(color, uv, t, mist, c.air.z * u.atmosphere, c.light.y, float3(0.055,0.15,0.18));
    float air = livingOval(uv, float2(0.49,0.39),float2(0.14,0.12));
    if (u.atmosphere > 0.0) color += float3(0.10,0.18,0.21) * livingPrecipitation(uv,t,c.light.y,false) * air * c.air.w;
    return float4(color, 1);
}

fragment float4 livingArcticDayFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling, uv).rgb;
    if (u.motion <= 0.0) return float4(original, 1);
    float t = u.time * mix(LIVING_ARCTIC_DAY_CALM_SCALE,1.0,u.motion);
    float sky = livingSky(uv,c);
    float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,c);
    // Spindrift travels over the channel and along existing ice-shelf planes.
    // The foreground ice face and mountain skyline receive no displacement.
    float bank = max(livingOval(uv,float2(0.48,0.405),float2(0.55,0.065)),
                     livingOval(uv,float2(0.35,0.55),float2(0.35,0.10)));
    float drift = livingFractal(uv * float2(9,48) + float2(-t * LIVING_ARCTIC_SNOW_BANK_RATE, t * LIVING_ARCTIC_SNOW_ROLL_RATE), t + 23.0);
    float rolling = smoothstep(0.30,0.73,drift);
    color = mix(color,float3(0.74,0.83,0.90), bank * rolling * 0.34 * u.motion);
    color = livingFog(color,uv,t,bank,c.air.z * u.atmosphere,c.light.y,float3(0.66,0.76,0.84));
    float water = livingOval(uv,float2(0.37,0.69),float2(0.13,0.11));
    if (water > 0.001) {
        float wave = sin(uv.y * 700.0 + uv.x * 19.0 - t * LIVING_ARCTIC_CHANNEL_RATE);
        float3 flow = artwork.sample(sampling,uv + float2(wave * 0.4,wave * 0.3) / u.textureSize * u.motion).rgb;
        color = mix(color,flow,water * 0.7 * u.atmosphere);
    }
    if (u.atmosphere > 0.0) color += float3(0.56,0.63,0.70) * livingPrecipitation(uv,t,c.light.y,true) * max(bank,sky * 0.3) * c.air.w;
    return float4(color,1);
}

fragment float4 livingArcticNightFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling,uv).rgb;
    if (u.motion <= 0.0) return float4(original,1);
    float t = u.time * mix(LIVING_ARCTIC_NIGHT_CALM_SCALE,1.0,u.motion);
    float sky = livingSky(uv,c) * livingMoonExclusion(uv,c);
    // Animate the visible aurora itself. Its green/cyan material gate excludes
    // stars, baked clouds, moon, glacier and mountain silhouettes.
    float aurora = sky * smoothstep(0.004,0.035,original.g - original.r)
        * (1.0 - smoothstep(0.02,0.08,original.r));
    float fold = sin(uv.x * 10.0 - t * LIVING_ARCTIC_AURORA_FOLD_RATE + sin(uv.x * 17.0 + t * LIVING_ARCTIC_AURORA_REFORM_RATE));
    float curtain = sin(uv.x * 86.0 + fold * 2.4 - t * LIVING_ARCTIC_AURORA_CURTAIN_RATE);
    float2 offset = float2(fold * 2.5, sin(uv.x * 7.0 + t * LIVING_ARCTIC_AURORA_VERTICAL_RATE) * 7.0 + curtain * 1.2) / u.textureSize * u.motion;
    float3 ribbon = artwork.sample(sampling,uv + offset).rgb;
    ribbon *= 1.0 + u.motion * (fold * 0.12 + curtain * 0.10);
    float3 color = mix(original,ribbon,aurora);
    float haze = livingOval(uv,float2(0.48,0.51),float2(0.27,0.04));
    color = livingFog(color,uv,t,haze,c.air.z * u.atmosphere,c.light.y,float3(0.06,0.14,0.20));
    float lake = livingOval(uv,float2(0.48,0.72),float2(0.24,0.12));
    if (lake > 0.001 && u.atmosphere > 0.0) {
        float wave = sin(uv.y * 630.0 - t * LIVING_ARCTIC_LAKE_RATE + sin(uv.x * 41.0));
        float3 reflection = artwork.sample(sampling,uv + float2(wave * 0.8,wave * 0.24) / u.textureSize * u.motion).rgb;
        color = mix(color,reflection,lake * u.atmosphere);
    }
    color = livingNightSky(color,uv,t,sky,u.atmosphere,c);
    if (u.atmosphere > 0.0) color += float3(0.20,0.29,0.36) * livingPrecipitation(uv,t,c.light.y,true) * haze * c.air.w;
    return float4(color,1);
}
