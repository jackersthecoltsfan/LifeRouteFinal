#ifndef LIVING_MOUNTAINS_MOTION_H
#define LIVING_MOUNTAINS_MOTION_H

// Mountains engineering motion contract, extracted from the preserved catalogue draft.
// Shared air-system rates live in LivingAtmosphereMotion.h. Scene geometry, seed,
// density and light are the typed LivingAtmosphereConfiguration descriptors.
// Freeze externally after the first passing family scene; do not retune to pass tests.
#define LIVING_MOUNTAINS_CALM_SCALE 0.42f
#define LIVING_MOUNTAINS_NEAR_FOG_SCALE 1.31f
#define LIVING_MOUNTAINS_LAKE_RATE 2.0f
// Independent event starts in a 25-second slot with five seconds of jitter
// produce successive arrivals between 20 and 30 seconds apart.
#define LIVING_MOUNTAINS_METEOR_PERIOD 25.0f
#define LIVING_MOUNTAINS_METEOR_OFFSET 4.0f
#define LIVING_MOUNTAINS_METEOR_JITTER 5.0f
#endif
