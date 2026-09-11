#ifndef LIVING_CANYON_MOTION_H
#define LIVING_CANYON_MOTION_H

// Canyon engineering motion contract, extracted from the preserved catalogue draft.
// Shared air-system rates live in LivingAtmosphereMotion.h. Scene geometry, seed,
// density and light are the typed LivingAtmosphereConfiguration descriptors.
// Freeze externally after the first passing family scene; do not retune to pass tests.
#define LIVING_CANYON_CALM_SCALE 0.42f
#define LIVING_CANYON_RIVER_RATE 0.29f
#define LIVING_CANYON_SURFACE_RATE 1.7f
#endif
