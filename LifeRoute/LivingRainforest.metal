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

#include "LivingSceneEvents.h"

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
static float livingWaterInterior(float2, thread const float2 *, int, float = 0.0007, float = 0.0035);
static float3 livingNightSky(float3, float2, float, float, float, LivingAtmosphereConfiguration,
    float = LIVING_AIR_METEOR_SLOT, float = LIVING_AIR_METEOR_START_MIN, float = LIVING_AIR_METEOR_START_RANGE);

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
    bool broadWater = true;
    if (uv.y <= o.horizon) {
        LivingAtmosphereConfiguration air = {float4(o.horizon),float4(o.horizon),
            float4(o.night, mix(17.0,31.0,o.night), o.reflectionX, 0.145),float4(0.012,0.42,0,0)};
        if (broadWater) air.air = o.night > 0.5 ? float4(0.042,0.80,0,0) : float4(0.046,0.82,0,0);
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
        if (broadWater) bend += sin(uv.x*(19.0+seed*8.0)+seed*31.0)*0.025*e.progress;
        float distance = depth - e.front - bend;
        float width = broadWater ? e.width*(2.8+seed*0.7) : e.width;
        float ridge = exp(-pow(distance / width, 2.0));
        float lip = exp(-pow((distance + width * 0.24) / (width * (broadWater ? 0.34 : 0.21)), 2.0));
        float curl = livingNoise(float2(uv.x * 32.0 + seed * 47.0, distance * 65.0 - e.age * LIVING_OCEAN_CURL_RATE));
        float fragments = smoothstep(0.24, 0.69, curl);
        face += ridge * e.swell * e.strength;
        normal += (-distance / width) * ridge * e.swell * e.strength;
        // Fine aerated cells fragment the spilling lip. Broad low-frequency
        // noise alone produced pale bars in the Simulator motion capture.
        float aeration = livingNoise(float2(uv.x * 247.0 + seed * 101.0,
            depth * 620.0 - e.age * LIVING_OCEAN_FOAM_ADVECTION_RATE));
        float froth = smoothstep(0.38, 0.74, aeration);
        // At the breaking phase the old threshold filled entire noise cells,
        // exposing a stippled grid when the wave face widened. Thin continuous
        // contours form irregular foam filaments instead of filled cell patches.
        if (broadWater) froth = exp(-abs(aeration-0.54)*38.0);
        crest += lip * e.crest * e.strength * smoothstep(0.32, 0.72, curl) * (0.2 + 0.8 * froth);
        breakWater += lip * e.breaking * fragments * e.strength * froth;
        // Foam remains behind the travelling front and spreads across its wake.
        // Two advecting scales erode and reform it; there is no repeating texture.
        float wakeWidth = 0.025 + 0.11 * smoothstep(LIVING_OCEAN_WAKE_SPREAD_START, LIVING_OCEAN_WAKE_SPREAD_END, e.progress);
        if (broadWater) wakeWidth *= 1.6;
        float wakeRegion = smoothstep(-wakeWidth, -wakeWidth * 0.2, distance)
            * (1.0 - smoothstep(-0.004, 0.012, distance));
        float lace = livingNoise(float2(uv.x * (broadWater ? 401.0 : 113.0) + seed * 101.0, depth * (broadWater ? 751.0 : 245.0) - e.age * LIVING_OCEAN_FOAM_ADVECTION_RATE));
        lace = 0.62 * lace + 0.38 * livingNoise(float2(uv.x * (broadWater ? 653.0 : 247.0) - e.age * LIVING_OCEAN_FOAM_CROSS_RATE, depth * (broadWater ? 953.0 : 397.0) + seed * 13.0));
        float foamLace = broadWater ? exp(-abs(lace-0.53)*34.0) : smoothstep(0.43,0.73,lace);
        wake += wakeRegion * e.foam * foamLace * (0.55 + 0.45 * fragments);
    }
    float amplitude = wet * u.motion * o.swellAmplitude;
    float shallows = o.shallow * smoothstep(0.42, 0.82, depth);
    float ripple = sin(log(1.0 + depth * 6.0) * 101.0 + uv.x * 33.0 - t * LIVING_OCEAN_RIPPLE_RATE
        + livingNoise(uv * 29.0 + t * LIVING_OCEAN_RIPPLE_EVOLUTION_RATE));
    float2 offset = float2(-o.crestSlope * normal, normal) * mix(7.0, 0.5, shallows);
    offset += float2(ripple * 0.20, ripple * 0.34);
    float broadSlope=0, crossSlope=0;
    if (broadWater) {
        // Irregular perspective-scaled surface waves remain active between
        // arriving event fronts. This bends local water geometry, never camera
        // or horizon, and keeps translucent shallows gently refractive.
        float perspective=log(1.0+depth*7.0);
        float wind=livingNoise(float2(uv.x*8.0-t*LIVING_OCEAN_RIPPLE_EVOLUTION_RATE,depth*13.0));
        float phase=perspective*35.0+uv.x*13.0-t*LIVING_OCEAN_RIPPLE_RATE+wind*3.0;
        float crossing=perspective*51.0-uv.x*21.0-t*LIVING_OCEAN_CURL_RATE+wind*2.0;
        broadSlope=sin(phase)*0.65+sin(crossing)*0.35;
        crossSlope=cos(phase+uv.x*5.0)*0.55+sin(crossing+depth*17.0)*0.45;
        offset += float2(crossSlope*4.5,broadSlope*7.5)*mix(0.55,1.0,sqrt(depth))*mix(1.0,0.24,shallows);
    }
    float2 sampleUV = uv + offset * amplitude / u.textureSize;
    sampleUV.y = max(o.horizon, sampleUV.y);
    float3 water = artwork.sample(sampling, sampleUV).rgb;
    // A travelling shaded wave face and narrowing illuminated lip supply shape,
    // rather than uniform oscillation or shimmer. Existing water remains visible.
    water *= 1.0 + amplitude * (normal * 0.13 - face * 0.12 + ripple * 0.013);
    if (broadWater) water *= 1.0+amplitude*(broadSlope*0.075+crossSlope*0.035);
    float reflectionWidth = 0.035 + depth * 0.19;
    float reflectionCenter = o.reflectionX;
    if (o.night > 0.5) reflectionCenter += crossSlope*depth*0.028;
    float reflection = exp(-pow((uv.x - reflectionCenter) / reflectionWidth, 2.0)) * o.night;
    if (o.night > 0.5) {
        // The photographed moon trail bends with the same current as dark water.
        // Crossing slopes break and reform its light across broad moving faces.
        float fragments=0.5+0.5*sin(log(1.0+depth*7.0)*77.0+uv.x*29.0
            -t*LIVING_OCEAN_RIPPLE_RATE+crossSlope*2.4);
        water *= 1.0 + reflection*amplitude*(fragments-0.5)*0.20;
        water += float3(0.035,0.052,0.072)*reflection*amplitude
            *max(0.0,broadSlope)*(0.25+0.75*fragments);
    }
    if (broadWater) crest *= 0.48;
    water += float3(0.10, 0.14, 0.17) * crest * amplitude * mix(0.6, 0.20 + reflection * 0.9, o.night);
    // Night's unbroken open-water swells spill sparsely; no shore is fabricated.
    float foam = saturate(breakWater * 0.60 + wake * 0.26) * amplitude * mix(1.0, 0.44, o.night);
    if (broadWater) foam *= 0.45;
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
static float livingPrecipitation(float2 uv, float t, float seed, bool snow, float density = 1.0) {
    float sum = 0;
    for (int layer = 0; layer < 3; ++layer) {
        float d = float(layer);
        float2 p = uv * float2(72.0 - d * 15.0, 68.0 - d * 12.0);
        p -= float2(t * (snow ? LIVING_AIR_SNOW_DRIFT_BASE + d * LIVING_AIR_SNOW_DRIFT_DEPTH : LIVING_AIR_RAIN_DRIFT), t * (snow ? LIVING_AIR_SNOW_FALL_BASE + d * LIVING_AIR_SNOW_FALL_DEPTH : LIVING_AIR_RAIN_FALL_BASE + d * LIVING_AIR_RAIN_FALL_DEPTH));
        float2 cell = floor(p), local = fract(p) - 0.5;
        float random = livingHash(cell + seed + d * 37.0);
        // Keep every existing caller bit-equivalent at the default density.
        // Arctic Day uses ten times the eligible snow cells, retaining the same
        // direction, depth planes and falling/swaying particle shape.
        float threshold = snow ? (density == 1.0 ? 0.965 : 1.0 - 0.035*density) : (density == 1.0 ? 0.981 : 1.0 - 0.019*density);
        if (random < threshold) continue;
        local.x += snow ? sin(t * (LIVING_AIR_SNOW_SWAY_BASE + d * LIVING_AIR_SNOW_SWAY_DEPTH) + random * 80.0) * 0.14 : local.y * 0.10;
        float2 radius = snow ? float2(0.027 + d * 0.012) : float2(0.019, 0.20);
        float dotSize = dot(local / radius, local / radius);
        sum += exp(-dotSize) * (0.24 + d * 0.13);
    }
    return sum;
}

static float livingSnowfallWithGust(float2 uv,float t,float seed) {
    LivingGustEvent gust=livingGustEvent(t);
    return livingPrecipitation(uv-float2(gust.travel,0),t,seed,true,17.5)
        * (1.0+0.15*gust.strength);
}

// Owner-requested physical refinements only. Existing callers retain their
// original air system. Travel is in artwork widths, independent of camera UV.
static float3 livingPhysicalClouds(float3 color, float2 uv, float sky, float t,
                                  float crossing, float amount, float night, float seed) {
    float2 travel = float2(uv.x - t / crossing, uv.y);
    float broad = livingFractal(travel * float2(7.5,15.0) + float2(seed,0), t * 0.35);
    float detail = livingFractal(travel * float2(15.0,27.0) + float2(0,seed), t * 0.53);
    float mass = smoothstep(0.35,0.69,broad*0.72+detail*0.28);
    float3 tint = mix(float3(0.83,0.87,0.90),float3(0.028,0.047,0.078),night);
    return mix(color,tint,mass*sky*amount*mix(0.30,0.55,night));
}

static float livingMeteorOffset(float slot, float seed, float minimum, float jitter) {
    return minimum + livingHash(float2(slot,seed)) * jitter;
}

// The test probes the same event offsets used below; application rendering never
// dispatches this kernel. Arrival bounds belong to the family timing contract.
kernel void livingMountainsMeteorProbe(device const float2 *requests [[buffer(0)]],
    device float2 *events [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    float slot = requests[id].x, seed = requests[id].y;
    events[id] = float2(slot * LIVING_MOUNTAINS_METEOR_PERIOD
        + livingMeteorOffset(slot,seed,LIVING_MOUNTAINS_METEOR_OFFSET,LIVING_MOUNTAINS_METEOR_JITTER)
        - seed * LIVING_AIR_METEOR_SEED_SCALE, livingHash(float2(slot,seed)));
}

kernel void livingDesertMeteorProbe(device const float2 *requests [[buffer(0)]],
    device float2 *events [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    float slot = requests[id].x, seed = requests[id].y;
    events[id] = float2(slot * LIVING_DESERT_METEOR_PERIOD
        + livingMeteorOffset(slot,seed,LIVING_DESERT_METEOR_OFFSET,LIVING_DESERT_METEOR_JITTER)
        - seed * LIVING_AIR_METEOR_SEED_SCALE, livingHash(float2(slot,seed)));
}

static float3 livingNightSky(float3 color, float2 uv, float t, float sky,
                            float amount, LivingAtmosphereConfiguration c,
                            float meteorPeriod, float meteorMinimum, float meteorJitter) {
    if (sky < 0.001 || amount <= 0.0 || c.light.x < 0.5) return color;
    float seed = c.light.y;
    // Existing photographed stars vary faintly; no global brightness oscillation.
    float starMaterial = smoothstep(0.12, 0.45, max(color.r, max(color.g, color.b)));
    color += color * starMaterial * sin(t * LIVING_AIR_STAR_RATE + livingHash(floor(uv * 800.0)) * 30.0) * 0.08 * sky * amount;
    // Family-selected arrival cadence; legacy callers retain their original
    // defaults. Start, origin and slope vary independently for each event.
    float slot = floor((t + seed * LIVING_AIR_METEOR_SEED_SCALE) / meteorPeriod);
    float random = livingHash(float2(slot, seed));
    float age = t + seed * LIVING_AIR_METEOR_SEED_SCALE - slot * meteorPeriod
        - livingMeteorOffset(slot,seed,meteorMinimum,meteorJitter);
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
    // Clouds travel only through the blue opening between fixed tree limbs.
    // Material and moon exclusions keep the photographed trunks/moon stationary.
    float opening = livingOval(uv,float2(0.53,0.23),float2(0.12,0.115))
        * livingMoonExclusion(uv,c) * smoothstep(0.01,0.04,original.b-original.g);
    if (u.atmosphere > 0.0) {
        color += livingClouds(artwork,sampling,uv,original,opening,t,u.motion,c)-original;
        color = livingPhysicalClouds(color,uv,opening,t,60.0,u.atmosphere,1.0,c.light.y);
    }
    float leaf = max(max(livingOval(uv,float2(0.16,0.74),float2(0.15,0.07)),
                         livingOval(uv,float2(0.34,0.86),float2(0.13,0.07))),
                    max(livingOval(uv,float2(0.44,0.29),float2(0.07,0.035)),
                         livingOval(uv,float2(0.73,0.33),float2(0.09,0.045))));
    leaf = max(leaf,max(livingOval(uv,float2(0.24,0.30),float2(0.20,0.16)),
                        livingOval(uv,float2(0.79,0.23),float2(0.15,0.17))));
    // The foreground left trunk and diagonal right limb occlude rain and
    // canopy travel. Leaf colour alone also occurs on wet bark.
    float trunkClear = mix(smoothstep(0.20,0.235,uv.x)
        * smoothstep(0.070,0.105,abs(uv.x-(0.52+uv.y))),1.0,smoothstep(0.58,0.66,uv.y));
    leaf *= trunkClear;
    float foliage = smoothstep(0.002,0.017,original.g-original.r)
        * (1.0-smoothstep(0.002,0.012,original.b-original.g));
    if (leaf * foliage > 0.001 && u.atmosphere > 0.0) {
        float gust = smoothstep(0.1,0.9,sin(t*LIVING_RF_LEAF_SWAY_RATE*0.47+uv.x*4.0));
        float2 offset = float2(sin(t*1.8+uv.y*17.0+uv.x*29.0),
            sin(t*2.3+uv.x*19.0)*0.45);
        offset *= colorAmount*(5.0+gust*5.0)*leaf*foliage;
        color += (artwork.sample(sampling,uv+offset/u.textureSize).rgb-original)*leaf*foliage*u.atmosphere;
    }
    float mist = livingOval(uv, float2(0.49,0.545),float2(0.28,0.045));
    color = livingFog(color, uv, t*4.0, mist, c.air.z * u.atmosphere, c.light.y, float3(0.055,0.15,0.18));
    // Rain spans the environment at three depths. Small short streaks are
    // composited over it; the physically accepted water computation is intact.
    float air = smoothstep(0.04,0.16,uv.y) * (1.0-smoothstep(0.91,1.0,uv.y));
    if (u.atmosphere > 0.0) color += float3(0.20,0.31,0.38)
        * livingPrecipitation(uv,t,c.light.y,false,8.0) * air * trunkClear * livingMoonExclusion(uv,c) * u.atmosphere;
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
    if (uv.y > 0.389 && uv.y < 0.917) {
        const float2 shore[] = {float2(0.44,0.389),float2(0.53,0.395),float2(0.542,0.421),
            float2(0.588,0.452),float2(1,0.480),float2(1,0.489),float2(0.80,0.490),
            float2(0.60,0.490),float2(0.448,0.506),float2(0.442,0.525),float2(0.475,0.572),
            float2(0.553,0.619),float2(0.540,0.724),float2(0.550,0.762),float2(0.50,0.780),
            float2(0.46,0.790),float2(0.40,0.803),float2(0.37,0.811),float2(0.33,0.824),
            float2(0.25,0.847),float2(0.20,0.864),float2(0.15,0.881),float2(0.10,0.891),
            float2(0,0.917),float2(0,0.568),
            float2(0.14,0.522),float2(0.34,0.464),float2(0.427,0.438)};
        float water = livingWaterInterior(uv,shore,28);
        float phase = t * LIVING_ARCTIC_CHANNEL_RATE;
        float depth = saturate((uv.y-0.40)/0.47);
        float folds = livingFractal(uv*float2(13,34)+float2(-phase*0.02,0),t);
        float wave = sin(uv.y*330.0+uv.x*19.0-phase+folds*7.0);
        float cross = sin(uv.y*497.0-uv.x*37.0-phase*0.71+folds*11.0);
        float2 displacement = float2(wave*1.2+cross*0.45,wave*0.70+cross*0.32)
            * mix(0.30,1.0,depth)*water*u.motion;
        float3 flow = livingAdvect(artwork,sampling,uv+displacement/u.textureSize,
            float2(-0.012,0.005)*u.motion,t,0.12);
        flow *= 1.0+u.motion*(wave*0.07+cross*0.035);
        // Keep spindrift already composited above while water/floating fragments
        // respond slowly underneath it. Foreground shelf faces remain fixed.
        color += (flow-original)*water;
    }
    if (u.atmosphere > 0.0) color += float3(0.56,0.63,0.70) * livingSnowfallWithGust(uv,t,c.light.y) * max(bank,sky * 0.65) * c.air.w;
    return float4(color,1);
}

struct LivingAuroraSample {
    float2 offset;
    float3 light;
    float modulation;
};

// Three curtains share the family clock but have independent phase, fold,
// vertical deformation, striation and color evolution. Reflection below samples
// this same field, never a second animation authority.
static LivingAuroraSample livingAuroraCurtains(float2 uv, float t) {
    LivingAuroraSample result = {float2(0),float3(0),0};
    for (int layer = 0; layer < 3; ++layer) {
        float d = float(layer), seed = d*2.31;
        float fold = sin(uv.x*(9.0+d*3.0)-t*LIVING_ARCTIC_AURORA_FOLD_RATE*(1.0+d*0.37)+seed
            + sin(uv.x*(15.0+d*2.0)+t*LIVING_ARCTIC_AURORA_REFORM_RATE+seed)*0.85);
        float center = 0.408-uv.x*0.245+(d-1.0)*0.028
            + sin(uv.x*(6.0+d*1.7)+t*LIVING_ARCTIC_AURORA_VERTICAL_RATE*(1.0+d*0.29)+seed)*0.018;
        float band = exp(-pow((uv.y-center)/(0.035+d*0.003),2.0));
        float striation = pow(0.5+0.5*sin(uv.x*(139.0+d*37.0)+fold*(6.0+d*1.5)
            - t*LIVING_ARCTIC_AURORA_CURTAIN_RATE*(1.0+d*0.23)),2.0);
        float life = 0.55+0.45*sin(uv.x*(3.0+d)+t*LIVING_ARCTIC_AURORA_REFORM_RATE*(1.0+d*0.31)+seed);
        float hue = 0.5+0.5*sin(t*LIVING_ARCTIC_AURORA_REFORM_RATE+uv.x*2.5+seed);
        float3 tint = mix(float3(0.015,0.33,0.19),float3(0.035,0.18,0.35),hue);
        result.offset += float2(fold*(5.25+d*2.625),fold*(14.0+d*5.25)+striation*3.5)*band;
        result.light += tint*band*(0.05775+striation*0.1815)*life;
        result.modulation += fold*band*(0.12+striation*0.15);
    }
    return result;
}

fragment float4 livingArcticNightFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], texture2d<float> objectMask [[texture(3)]], constant LivingSceneUniforms &u [[buffer(0)]],
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
    LivingAuroraSample curtains = livingAuroraCurtains(uv,t*1.6);
    float3 ribbon = artwork.sample(sampling,uv+curtains.offset/u.textureSize*u.motion).rgb;
    ribbon *= 1.0+curtains.modulation*u.motion;
    float3 color = livingClouds(artwork,sampling,uv,original,sky*(1.0-aurora),t,u.motion,c);
    color += (ribbon-original+curtains.light*u.motion)*aurora;
    float haze = livingOval(uv,float2(0.48,0.51),float2(0.27,0.04));
    color = livingFog(color,uv,t,haze,c.air.z * u.atmosphere,c.light.y,float3(0.06,0.14,0.20));
    // The foreground photograph is frozen, cracked ice. Its geometry never
    // ripples: only light from the evolving curtains changes on the icy surface.
    float ice = livingOval(uv,float2(0.48,0.665),float2(0.36,0.115))
        * smoothstep(0.012,0.07,original.b-original.r);
    if (ice > 0.001 && u.atmosphere > 0.0) {
        LivingAuroraSample reflected = livingAuroraCurtains(float2(uv.x,0.408-uv.x*0.245),t*1.6);
        color += reflected.light*ice*u.atmosphere*0.32;
    }
    color = livingNightSky(color,uv,t,sky,u.atmosphere,c);
    // Each photographed connected star core shares one fixed phase/period.
    // Nearest sampling preserves object identity; alpha is zero on sky/aurora.
    constexpr sampler objectSampling(coord::normalized,address::clamp_to_edge,filter::nearest);
    float4 star=objectMask.sample(objectSampling,uv);
    float starPhase=fract(t/(1.5+star.g*2.5)+star.r);
    float twinkle=smoothstep(0.0,0.10,starPhase)*(1.0-smoothstep(0.20,0.30,starPhase));
    color-=float3(star.b*star.b)*twinkle*0.65*star.a*u.atmosphere;
    if (u.atmosphere > 0.0) color += float3(0.20,0.29,0.36) * livingPrecipitation(uv,t,c.light.y,true) * haze * c.air.w;
    return float4(color,1);
}

// Artwork-space water boundary. Feather only inside the photographed shoreline;
// no displacement or animated opacity reaches the surrounding fixed geometry.
static float livingWaterInterior(float2 uv, thread const float2 *points, int count, float edgeStart, float edgeEnd) {
    bool inside = false;
    float distanceSquared = 1.0;
    for (int i = 0, j = count - 1; i < count; j = i++) {
        float2 a = points[j], b = points[i], edge = b - a;
        float along = clamp(dot(uv - a, edge) / max(dot(edge, edge), 0.0000001), 0.0, 1.0);
        float2 separation = uv - a - edge * along;
        distanceSquared = min(distanceSquared, dot(separation, separation));
        if ((a.y > uv.y) != (b.y > uv.y)) {
            if (uv.x < (b.x - a.x) * (uv.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
        }
    }
    return inside ? smoothstep(edgeStart, edgeEnd, sqrt(distanceSquared)) : 0.0;
}

fragment float4 livingMountainsFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling,uv).rgb;
    if (u.motion <= 0.0) return float4(original,1);
    float t = u.time * mix(LIVING_MOUNTAINS_CALM_SCALE,1.0,u.motion), night = c.light.x;
    float sky = livingSky(uv,c) * livingMoonExclusion(uv,c);
    float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,c);
    if (night < 0.5) color = livingPhysicalClouds(color,uv,sky,t,35.0,u.motion,0.0,c.light.y);
    // Separate valley and lake depth planes, calibrated to each photograph.
    float valley = mix(livingOval(uv,float2(0.66,0.465),float2(0.20,0.055)),
                       livingOval(uv,float2(0.56,0.475),float2(0.36,0.065)),night);
    float near = mix(livingOval(uv,float2(0.63,0.56),float2(0.19,0.06)),
                     livingOval(uv,float2(0.45,0.59),float2(0.25,0.045)),night);
    color = livingFog(color,uv,t,valley,c.air.z * u.motion,c.light.y,mix(float3(0.43,0.57,0.65),float3(0.065,0.12,0.19),night));
    color = livingFog(color,uv,t * LIVING_MOUNTAINS_NEAR_FOG_SCALE,near,c.air.z * u.atmosphere * 0.55,c.light.y + 13.0,mix(float3(0.40,0.53,0.59),float3(0.055,0.10,0.16),night));
    if (night > 0.5) {
        // Full lake from the distant shore to the foreground rock silhouette.
        // This matte follows visible water, rather than a central oval. Water is
        // primary environment motion and remains when secondary air is removed.
        if (uv.y > 0.57 && uv.y < 0.881) {
            const float2 shore[] = {float2(0,0.578),float2(0.28,0.579),float2(0.48,0.575),
                float2(0.79,0.570),float2(1,0.574),float2(1,0.742),float2(0.9,0.766),
                float2(0.78,0.781),float2(0.75,0.850),float2(0.58,0.881),float2(0.40,0.852),
                float2(0.32,0.873),float2(0.20,0.850),float2(0,0.804)};
            float lake = livingWaterInterior(uv, shore, 14);
            float depth = saturate((uv.y - 0.575) / 0.29);
            float travel = t * LIVING_MOUNTAINS_LAKE_RATE;
            float wave = sin(uv.y * 425.0 + uv.x * 29.0 - travel
                + sin(uv.x * 13.0 + travel * 0.31) * 1.7);
            float cross = sin(uv.y * 713.0 - uv.x * 43.0 - travel * 1.23);
            float2 displacement = float2(wave * 2.4 + cross * 0.75, wave * 0.75 + cross * 0.42)
                * mix(0.45,1.0,depth) * lake * u.motion;
            float3 water = artwork.sample(sampling,uv + displacement / u.textureSize).rgb;
            water *= 1.0 + u.motion * (wave * 0.065 + cross * 0.035);
            // Preserve already-composited valley mist while the underlying
            // reflection and water surface evolve. Camera/shore never move.
            color += (water - original) * lake;
        }
        float wisps = livingOval(uv,float2(0.49,0.625),float2(0.47,0.072));
        color = livingFog(color,uv,t * LIVING_MOUNTAINS_NEAR_FOG_SCALE * 2.4,wisps,
            c.air.z * u.atmosphere * 0.65,c.light.y + 29.0,float3(0.075,0.14,0.20));
        float nearWisps = livingOval(uv,float2(0.55,0.73),float2(0.34,0.056));
        color = livingFog(color,uv,t * LIVING_MOUNTAINS_NEAR_FOG_SCALE * 3.1,nearWisps,
            c.air.z * u.atmosphere * 0.32,c.light.y + 47.0,float3(0.065,0.12,0.17));
        // Wind lifts sparse snow from the distant snowy ridge. Transposed air
        // coordinates make this travel laterally with the wisps, not fall as a
        // full-screen snow storm. The ridge texture itself remains stationary.
        float snowEdge = livingOval(uv,float2(0.63,0.455),float2(0.24,0.035))
            * smoothstep(0.035,0.12,dot(original,float3(0.21,0.72,0.07)));
        float snowDrift = livingPrecipitation(float2(uv.y * 1.8,-uv.x),
            t * LIVING_MOUNTAINS_NEAR_FOG_SCALE,c.light.y,true);
        color += float3(0.30,0.40,0.48) * snowDrift * snowEdge * u.atmosphere * 0.35;
    } else {
        // Distant lake follows both banks and the right-hand inlet. Several
        // fine wind-driven fronts cross its whole visible surface; shore and
        // mountain silhouettes stay fixed and secondary air is optional.
        if (uv.y > 0.463 && uv.y < 0.546) {
            const float2 shore[] = {float2(0.542,0.480),float2(0.598,0.468),float2(0.66,0.463),
                float2(0.72,0.465),float2(0.754,0.471),float2(0.786,0.476),float2(0.778,0.484),
                float2(0.787,0.489),float2(0.82,0.497),float2(0.865,0.509),float2(0.90,0.517),
                float2(0.917,0.525),float2(0.917,0.533),float2(0.898,0.537),float2(0.835,0.540),
                float2(0.775,0.543),float2(0.742,0.546),float2(0.707,0.540),float2(0.67,0.535),
                float2(0.646,0.532),float2(0.650,0.528),float2(0.641,0.522),float2(0.618,0.517),
                float2(0.603,0.520),float2(0.597,0.515),float2(0.587,0.512),float2(0.60,0.508),
                float2(0.584,0.501),float2(0.564,0.493)};
            float lake = livingWaterInterior(uv,shore,29);
            float travel = t * 3.0;
            float bend = livingFractal(uv * float2(26,73) + float2(-travel * 0.02,0),t);
            float windPatch = livingFractal(uv * float2(53,141) + float2(travel * 0.035,3.7),t);
            float wave = sin(uv.y * 1850.0 + uv.x * 65.0 - travel
                + bend * 12.0 + sin(uv.x * 19.0 + travel * 0.31));
            float cross = sin(uv.y * 2810.0 - uv.x * 43.0 - travel * 1.23 + bend * 19.0);
            float rippleStrength = 0.35 + windPatch * 0.65;
            float2 displacement = float2(wave * 2.3 + cross * 0.84,wave * 0.76 + cross * 0.42)
                * lake * rippleStrength * u.motion;
            float3 water = artwork.sample(sampling,uv + displacement / u.textureSize).rgb;
            water *= 1.0 + u.motion * rippleStrength * (wave * 0.13 + cross * 0.065);
            color += (water - original) * lake;
        }
        // Restrict wind to photographed grass clumps, with stems anchored at
        // their bases. Grey rock material and the major foreground slabs remain
        // stationary while blade tips respond to different phases and gusts.
        float grass = max(max(livingOval(uv,float2(0.065,0.875),float2(0.06,0.06)),
                              livingOval(uv,float2(0.27,0.946),float2(0.18,0.045))),
                          max(livingOval(uv,float2(0.60,0.975),float2(0.22,0.03)),
                              livingOval(uv,float2(0.90,0.865),float2(0.10,0.06))));
        float vegetation = smoothstep(0.018,0.10,original.g - original.b)
            * (1.0 - smoothstep(0.09,0.18,original.r - original.g));
        float gust = smoothstep(0.05,0.85,sin(t * LIVING_MOUNTAINS_NEAR_FOG_SCALE * 0.47 + uv.x * 3.0));
        float blades = sin(t * LIVING_MOUNTAINS_LAKE_RATE + uv.x * 73.0 + uv.y * 29.0);
        // 3.14s dominant period; 8-12.8 artwork-pixel tip travel across
        // 120-350px clumps (~4-8% for the dominant foreground clusters).
        float sway = grass * vegetation * u.motion * (8.0 + gust * 4.8) * blades;
        color += (artwork.sample(sampling,uv + float2(sway,sway * 0.12) / u.textureSize).rgb - original)
            * grass * vegetation;
    }
    if (night > 0.5) {
        color = livingNightSky(color,uv,t,sky,u.atmosphere,c,LIVING_MOUNTAINS_METEOR_PERIOD,
            LIVING_MOUNTAINS_METEOR_OFFSET,LIVING_MOUNTAINS_METEOR_JITTER);
    } else {
        color = livingNightSky(color,uv,t,sky,u.atmosphere,c);
    }
    return float4(color,1);
}

// Distance along the actual winding channel, lateral offset and local tangent.
// Flow changes direction at bends instead of translating water on a global UV axis.
static float4 livingRiverCoordinates(float2 uv, thread const float2 *path, int count, float aspect) {
    float best = 100.0, distanceAlong = 0.0, traversed = 0.0, across = 0.0;
    float2 tangent = float2(0,1), metric = float2(aspect,1);
    for (int i = 1; i < count; ++i) {
        float2 a = path[i-1] * metric, edge = (path[i]-path[i-1]) * metric;
        float lengthAlong = length(edge), unitScale = max(lengthAlong,0.00001);
        float u = clamp(dot(uv * metric-a,edge) / (unitScale * unitScale),0.0,1.0);
        float2 separation = uv * metric-a-edge*u;
        float d = dot(separation,separation);
        if (d < best) {
            best = d; distanceAlong = traversed + lengthAlong*u;
            across = dot(separation,float2(-edge.y,edge.x)/unitScale);
            tangent = normalize(path[i]-path[i-1]);
        }
        traversed += lengthAlong;
    }
    return float4(distanceAlong,across,tangent);
}

fragment float4 livingCanyonFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], texture2d<float> objectMask [[texture(3)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling,uv).rgb;
    if (u.motion <= 0.0) return float4(original,1);
    float t = u.time * mix(LIVING_CANYON_CALM_SCALE,1.0,u.motion), night = c.light.x;
    float sky = livingSky(uv,c) * livingMoonExclusion(uv,c);
    float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,c);
    if (night < 0.5) color = livingPhysicalClouds(color,uv,sky,t,42.0,u.motion,0.0,c.light.y);
    float distanceHaze = mix(livingOval(uv,float2(0.57,0.412),float2(0.22,0.052)),
                            livingOval(uv,float2(0.50,0.408),float2(0.18,0.055)),night);
    color = livingFog(color,uv,t,distanceHaze,c.air.z * u.motion,c.light.y,mix(float3(0.56,0.33,0.24),float3(0.08,0.14,0.21),night));
    if (night > 0.5) {
        // A cloud bank crosses the actual moon every32scene seconds. Its
        // bounded track is already visibly travelling before the crossing.
        float cloudX = -0.30 + fract((t+8.0)/32.0)*1.60;
        float cloudY = c.light.w + sin(t*0.09)*0.012;
        float bank = exp(-pow((uv.x-cloudX)/0.18,2.0))
            * exp(-pow((uv.y-cloudY)/0.047,2.0));
        float moonBank = exp(-pow((c.light.z-cloudX)/0.18,2.0))
            * exp(-pow((c.light.w-cloudY)/0.047,2.0));
        color = livingPhysicalClouds(color,uv,sky,t,40.0,u.atmosphere,1.0,c.light.y);
        color = mix(color,float3(0.025,0.041,0.069),bank*livingSky(uv,c)*0.70*u.atmosphere);
        // Moonlit and dark water share the full actual channel, not a diagonal
        // strip through the canyon wall. Its two banks stay at fixed pixels.
        float moonTransmission = 1.0 - moonBank*0.70;
        if (uv.y > 0.45) {
            const float2 shore[] = {float2(0.375,0.451),float2(0.42,0.465),float2(0.45,0.472),float2(0.51,0.483),
                float2(0.508,0.489),float2(0.54,0.495),float2(0.573,0.502),float2(0.58,0.509),
                float2(0.568,0.524),float2(0.553,0.537),float2(0.517,0.549),float2(0.491,0.559),
                float2(0.466,0.569),float2(0.462,0.577),float2(0.434,0.582),float2(0.405,0.588),
                float2(0.39,0.593),float2(0.407,0.602),float2(0.391,0.608),float2(0.365,0.614),
                float2(0.36,0.624),float2(0.375,0.633),float2(0.398,0.643),float2(0.412,0.657),
                float2(0.416,0.676),float2(0.413,0.693),float2(0.398,0.709),float2(0.369,0.735),
                float2(0.345,0.754),float2(0.306,0.78),float2(0.255,0.817),float2(0.199,0.852),
                float2(0.128,0.901),float2(0.072,0.944),float2(0.017,0.989),float2(0,1),
                float2(0,0.918),float2(0.04,0.875),float2(0.111,0.83),float2(0.173,0.796),
                float2(0.219,0.76),float2(0.246,0.725),float2(0.263,0.689),float2(0.263,0.66),
                float2(0.259,0.636),float2(0.262,0.615),float2(0.27,0.598),float2(0.301,0.586),
                float2(0.341,0.576),float2(0.373,0.568),float2(0.401,0.556),float2(0.405,0.55),
                float2(0.404,0.543),float2(0.428,0.535),float2(0.44,0.522),float2(0.458,0.517),
                float2(0.475,0.514),float2(0.497,0.51),float2(0.485,0.506),float2(0.462,0.503),
                float2(0.427,0.495),float2(0.43,0.491),float2(0.47,0.492),float2(0.452,0.487),
                float2(0.417,0.48),float2(0.423,0.473),float2(0.399,0.468),float2(0.377,0.463),
                float2(0.372,0.457)};
            float river = livingWaterInterior(uv,shore,69);
            if (river > 0.001) {
                const float2 channel[] = {float2(0.38,0.455),float2(0.432,0.471),float2(0.477,0.482),
                    float2(0.475,0.491),float2(0.538,0.507),float2(0.51,0.531),float2(0.463,0.55),
                    float2(0.422,0.571),float2(0.345,0.597),float2(0.307,0.623),float2(0.339,0.65),
                    float2(0.34,0.69),float2(0.304,0.733),float2(0.26,0.777),float2(0.198,0.822),
                    float2(0.116,0.868),float2(0.049,0.92),float2(0.01,0.964)};
                float4 flow = livingRiverCoordinates(uv,channel,18,u.textureSize.x/u.textureSize.y);
                float waterTime = t * 1.6;
                float phase = waterTime * LIVING_CANYON_SURFACE_RATE;
                float eddies = livingFractal(float2(flow.x*49.0-phase*0.06,flow.y*110.0+c.light.y),waterTime);
                float riffle = sin(flow.x*540.0-phase+eddies*11.0+flow.y*77.0);
                float cross = sin(flow.x*830.0-phase*1.31+eddies*17.0-flow.y*103.0);
                float2 drift = flow.zw*(0.004+saturate((uv.y-0.48)/0.36)*0.003)*u.motion;
                float3 water = livingAdvect(artwork,sampling,uv,drift,waterTime,LIVING_CANYON_RIVER_RATE);
                water *= 1.0 + u.motion*(riffle*0.11+cross*0.055)*(0.4+eddies*0.6);
                // The cloud field modulates photographed reflection locally;
                // optional atmosphere never gates the underlying river flow.
                float reflectedLight = smoothstep(0.025,0.12,dot(original,float3(0.21,0.72,0.07)));
                water *= 1.0 - reflectedLight*(1.0-moonTransmission)*u.atmosphere*0.35;
                color += (water-original)*river;
            }
        }
        float moonHalo = exp(-pow(length((uv-c.light.zw)*float2(0.563,1.0))/0.10,2.0))*sky;
        color += float3(0.045,0.070,0.10)*moonHalo*(moonTransmission-0.825)*u.atmosphere;
        float riverMist = livingOval(uv,float2(0.39,0.555),float2(0.17,0.032));
        color = livingFog(color,uv,t,riverMist,c.air.z*u.atmosphere*0.45,c.light.y+19.0,float3(0.065,0.12,0.19));
    } else if (uv.y > 0.422 && uv.y < 0.647) {
        // Both photographed banks, including the broad left bend, are traced
        // independently of the old approximate QA/renderer centerline.
        const float2 shore[] = {float2(0.548,0.424),float2(0.577,0.43),float2(0.573,0.433),float2(0.606,0.438),
                float2(0.635,0.443),float2(0.618,0.448),float2(0.576,0.454),float2(0.547,0.461),
                float2(0.551,0.466),float2(0.545,0.47),float2(0.557,0.474),float2(0.6,0.48),
                float2(0.648,0.489),float2(0.66,0.499),float2(0.658,0.509),float2(0.643,0.515),
                float2(0.606,0.524),float2(0.562,0.534),float2(0.531,0.543),float2(0.522,0.55),
                float2(0.524,0.556),float2(0.557,0.571),float2(0.605,0.585),float2(0.647,0.599),
                float2(0.678,0.612),float2(0.715,0.628),float2(0.725,0.633),float2(0.703,0.635),
                float2(0.672,0.636),float2(0.622,0.638),float2(0.608,0.645),float2(0.595,0.645),
                float2(0.58,0.634),float2(0.565,0.629),float2(0.552,0.616),float2(0.538,0.607),
                float2(0.535,0.6),float2(0.52,0.59),float2(0.51,0.584),float2(0.505,0.576),
                float2(0.487,0.57),float2(0.46,0.561),float2(0.433,0.555),float2(0.422,0.549),
                float2(0.423,0.542),float2(0.438,0.534),float2(0.477,0.522),float2(0.518,0.512),
                float2(0.55,0.503),float2(0.56,0.498),float2(0.555,0.493),float2(0.536,0.486),
                float2(0.499,0.481),float2(0.47,0.477),float2(0.451,0.471),float2(0.475,0.464),
                float2(0.502,0.458),float2(0.54,0.453),float2(0.575,0.449),float2(0.604,0.444),
                float2(0.592,0.44),float2(0.559,0.433),float2(0.569,0.43),float2(0.548,0.426)};
        float river = livingWaterInterior(uv,shore,64);
        if (river > 0.001) {
            const float2 channel[] = {float2(0.551,0.425),float2(0.57,0.433),float2(0.619,0.443),
                float2(0.57,0.452),float2(0.506,0.467),float2(0.549,0.48),float2(0.613,0.501),
                float2(0.558,0.520),float2(0.472,0.544),float2(0.493,0.56),float2(0.544,0.58),
                float2(0.587,0.603),float2(0.641,0.625),float2(0.62,0.64)};
            float4 flow = livingRiverCoordinates(uv,channel,14,u.textureSize.x/u.textureSize.y);
            float phase = t * LIVING_CANYON_SURFACE_RATE;
            float eddies = livingFractal(float2(flow.x*72.0-phase*0.08,flow.y*160.0+c.light.y),t);
            float riffle = sin(flow.x*710.0-phase+eddies*11.0+flow.y*93.0);
            float cross = sin(flow.x*1070.0-phase*1.31+eddies*17.0-flow.y*125.0);
            float2 drift = flow.zw * (0.006 + saturate((uv.y-0.43)/0.20)*0.007) * u.motion;
            float3 water = livingAdvect(artwork,sampling,uv,drift,t,LIVING_CANYON_RIVER_RATE);
            water *= 1.0 + u.motion*(riffle*0.075+cross*0.035)*(0.4+eddies*0.6);
            color += (water-original)*river;
        }
    }
    if (night < 0.5 && u.atmosphere > 0.0) {
        // Data mask traces actual photographed crowns and stays6pixels
        // inside their boundaries. No warm-rock colour classifier is used.
        float foliage = objectMask.sample(sampling,uv).r;
        if (foliage>0.001) {
            float sway=sin(t*1.8+uv.x*9.0+uv.y*5.0)*(4.0+sin(t*0.63));
            float2 offset=float2(sway,sway*0.12)*foliage*u.motion/u.textureSize;
            color+=(artwork.sample(sampling,uv+offset).rgb-original)*foliage*u.atmosphere;
        }
        // Anchored sunset shafts breathe with the same drifting cloud field.
        // Only air over the distant gorge is lit; no global exposure pulse.
        float beamArea = livingOval(uv,float2(0.58,0.43),float2(0.22,0.053));
        float beamCoordinate = uv.x + (uv.y-0.30)*1.65;
        float shafts = exp(-pow((beamCoordinate-0.81)/0.035,2.0))
            + exp(-pow((beamCoordinate-0.90)/0.025,2.0))*0.65;
        float cloudShade = livingFractal(float2(uv.x*7.5-t*c.air.x,uv.y*15.0+c.light.y),t);
        color += float3(0.11,0.055,0.018)*shafts*beamArea*(0.25+cloudShade*0.75)*u.atmosphere;
    }
    color = livingNightSky(color,uv,t,sky,u.atmosphere,c);
    if (night > 0.5) color=livingBat(color,uv,u.textureSize,t,u.atmosphere>0.0 && u.motion>0.5);
    return float4(color,1);
}

fragment float4 livingDesertFragment(LivingSceneVertex in [[stage_in]],
    texture2d<float> artwork [[texture(0)]], constant LivingSceneUniforms &u [[buffer(0)]],
    constant LivingAtmosphereConfiguration &c [[buffer(2)]]) {
    constexpr sampler sampling(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 uv = (in.uv - 0.5) * u.uvScale + 0.5;
    float3 original = artwork.sample(sampling,uv).rgb;
    if (u.motion <= 0.0) return float4(original,1);
    float t = u.time * mix(LIVING_DESERT_CALM_SCALE,1.0,u.motion), night = c.light.x;
    float sky = livingSky(uv,c) * livingMoonExclusion(uv,c);
    if (night > 0.5) {
        // Sky is an opening under an arch. A conservative interior matte avoids
        // moving any part of the arch, foreground sand or distant silhouettes.
        sky *= livingOval(uv,float2(0.60,0.29),float2(0.30,0.19));
        float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,c);
        // Move only the fine photographed star signal; retain the broad sky
        // gradient, moon and arch in their original coordinates.
        float2 drift = float2(sin(t*LIVING_DESERT_STAR_DRIFT_RATE)*18.0,
            (cos(t*LIVING_DESERT_STAR_DRIFT_RATE*0.73)-1.0)*9.0) / u.textureSize;
        float3 points[2];
        for (int sampleIndex=0;sampleIndex<2;++sampleIndex) {
            float2 location = uv + drift*float(sampleIndex);
            float2 dx=float2(2.0,0.0)/u.textureSize, dy=float2(0.0,2.0)/u.textureSize;
            float3 center=artwork.sample(sampling,location).rgb;
            float3 surround=(artwork.sample(sampling,location+dx).rgb+artwork.sample(sampling,location-dx).rgb
                +artwork.sample(sampling,location+dy).rgb+artwork.sample(sampling,location-dy).rgb)*0.25;
            points[sampleIndex]=max(float3(0),center-surround)*smoothstep(0.015,0.07,max(center.r,max(center.g,center.b)));
        }
        color += (points[1]-points[0])*sky*u.atmosphere;
        color = livingFog(color,uv,t,sky,c.air.z * u.motion,c.light.y,float3(0.035,0.055,0.105));
        // Layered low dust occupies the distant basin, clear of the near arch
        // and the fixed foreground dune. It remains primary motion when optional
        // celestial atmosphere is removed. Each gust lifts, travels and settles.
        const float2 basin[8]={float2(0.35,0.495),float2(0.82,0.495),float2(0.79,0.54),float2(0.73,0.57),
            float2(0.63,0.60),float2(0.55,0.626),float2(0.40,0.626),float2(0.40,0.594)};
        float basinMask=livingWaterInterior(uv,basin,8,0.004,0.035);
        float dust=0;
        for (int layer=0;layer<3;++layer) {
            float d=float(layer), phase=t/LIVING_DESERT_GUST_PERIOD+d*0.31;
            float gust=0.25+0.75*pow(0.5+0.5*sin(phase*2.0*M_PI_F),2.0);
            float height=0.515+d*0.034-gust*0.008;
            float depth=exp(-pow((uv.y-height)/(0.020+d*0.008),2.0));
            float cells=livingFractal(uv*float2(15.0+d*4.0,74.0-d*12.0)
                +float2(-t*LIVING_DESERT_AIR_DRIFT_RATE*(1.0+d*0.6),d*7.9),t+d*3.0);
            dust += depth*(0.10+0.90*smoothstep(0.2,0.8,cells))*gust;
        }
        color=mix(color,float3(0.13,0.16,0.25),basinMask*min(dust*0.38,0.52)*u.motion);
        color = livingNightSky(color,uv,t,sky,u.atmosphere,c,LIVING_DESERT_METEOR_PERIOD,
            LIVING_DESERT_METEOR_OFFSET,LIVING_DESERT_METEOR_JITTER);
        return float4(color,1);
    }
    float3 color = livingClouds(artwork,sampling,uv,original,sky,t,u.motion,c);
    // Preserve the original far-basin heat character, with independently phased
    // zones at progressively nearer depths. Foreground dunes never move.
    const float4 zones[4]={float4(0.52,0.265,0.30,0.055),float4(0.28,0.294,0.14,0.022),
        float4(0.58,0.334,0.20,0.032),float4(0.79,0.393,0.13,0.040)};
    float2 refraction=0;
    for (int layer=0;layer<4;++layer) {
        float d=float(layer),heat=livingOval(uv,zones[layer].xy,zones[layer].zw);
        float cells=livingFractal(uv*float2(45.0+d*7.0,105.0-d*12.0)
            +float2(t*LIVING_DESERT_AIR_DRIFT_RATE,-t*LIVING_DESERT_HEAT_RISE_RATE*(1.0+d*0.23)),t+d*4.3);
        float fine=sin(uv.y*(390.0-d*39.0)-t*LIVING_DESERT_HEAT_REFRACTION_RATE*(1.0+d*0.17)+cells*5.0+d*7.0);
        refraction+=float2((cells-0.5)*(4.3+d*1.3),fine*(1.2+d*0.3))*heat;
    }
    float3 refracted=artwork.sample(sampling,uv+refraction*u.motion/u.textureSize).rgb;
    color += refracted-original;
    float haze=livingOval(uv,float2(0.56,0.29),float2(0.29,0.05));
    color=livingFog(color,uv,t,haze,c.air.z*u.motion,c.light.y,float3(0.62,0.39,0.21));
    // Separate drifting dust sheets lift from the basin and settle between
    // gusts. Soft volumes retain the photographed ridges and dune crests.
    const float4 gustZones[3]={float4(0.44,0.29,0.29,0.027),float4(0.60,0.338,0.20,0.034),float4(0.79,0.393,0.13,0.037)};
    float dust=0;
    for (int layer=0;layer<3;++layer) {
        float d=float(layer),phase=t/LIVING_DESERT_GUST_PERIOD+d*0.29;
        float gust=pow(max(0.0,sin(phase*2.0*M_PI_F)),2.0);
        float2 center=gustZones[layer].xy+float2(0,-gust*0.009);
        float area=livingOval(uv,center,gustZones[layer].zw);
        float cells=livingFractal(uv*float2(19.0+d*6.0,82.0-d*13.0)
            +float2(-t*LIVING_DESERT_AIR_DRIFT_RATE*(1.5+d*0.7),d*7.1),t+d*5.0);
        dust+=area*gust*smoothstep(0.22,0.82,cells);
    }
    color=mix(color,float3(0.68,0.44,0.23),min(dust*0.48,0.48)*c.air.w*u.motion);
    return float4(color,1);
}

// Tests query the same production state used by the scene fragment.
kernel void livingBatEventProbe(device const float2 *requests [[buffer(0)]],
    device float4 *results [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    LivingFlightEvent e=livingBatEvent(requests[id].x,requests[id].y>0.5);
    results[id*2]=float4(e.position,e.state,e.eventStart);
    results[id*2+1]=float4(e.tangent,e.wingPhase,e.cycle);
}

kernel void livingGustEventProbe(device const float2 *requests [[buffer(0)]],
    device float4 *results [[buffer(1)]], uint id [[thread_position_in_grid]]) {
    LivingGustEvent e=livingGustEvent(requests[id].x);
    if (requests[id].y<0.5) e={0,0,0,0};
    results[id*2]=float4(e.strength,e.travel,e.state,e.eventStart);
    results[id*2+1]=float4(0);
}
