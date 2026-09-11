#ifndef LIVING_RAINFOREST_MOTION_H
#define LIVING_RAINFOREST_MOTION_H

// Rainforest engineering motion contract, extracted from the preserved catalogue draft.
// Shared air-system rates live in LivingAtmosphereMotion.h. Scene geometry, seed,
// density and light are the typed LivingAtmosphereConfiguration descriptors.
// Freeze externally after the first passing family scene; do not retune to pass tests.
// Day retains its accepted shader bytes; the guard pins that implementation.
#define LIVING_RF_DAY_FALL_RATE 0.63f
#define LIVING_RF_DAY_STREAM_RATE 0.48f
#define LIVING_RF_CALM_SCALE 0.5f
#define LIVING_RF_STREAM_RIPPLE_RATE 3.6f
#define LIVING_RF_STREAM_VARIATION_RATE 0.42f
#define LIVING_RF_STREAM_ADVECTION_RATE 0.37f
#define LIVING_RF_LEAF_SWAY_RATE 0.65f
#define LIVING_RF_LEAF_CROSS_RATE 0.91f
#endif
