#ifndef LIVING_DESERT_MOTION_H
#define LIVING_DESERT_MOTION_H

// Desert engineering motion contract, extracted from the preserved catalogue draft.
// Shared air-system rates live in LivingAtmosphereMotion.h. Scene geometry, seed,
// density and light are the typed LivingAtmosphereConfiguration descriptors.
// Freeze externally after the first passing family scene; do not retune to pass tests.
#define LIVING_DESERT_CALM_SCALE 0.38f
#define LIVING_DESERT_AIR_DRIFT_RATE 0.09f
#define LIVING_DESERT_HEAT_RISE_RATE 0.65f
#define LIVING_DESERT_HEAT_REFRACTION_RATE 2.2f
#define LIVING_DESERT_GUST_PERIOD 13.0f
#define LIVING_DESERT_STAR_DRIFT_RATE 0.006f
#define LIVING_DESERT_METEOR_PERIOD 11.5f
#define LIVING_DESERT_METEOR_OFFSET 1.5f
#define LIVING_DESERT_METEOR_JITTER 3.5f
#endif
