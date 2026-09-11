#ifndef LIVING_ARCTIC_MOTION_H
#define LIVING_ARCTIC_MOTION_H

// Arctic engineering motion contract, extracted from the preserved catalogue draft.
// Shared air-system rates live in LivingAtmosphereMotion.h. Scene geometry, seed,
// density and light are the typed LivingAtmosphereConfiguration descriptors.
// Freeze externally after the first passing family scene; do not retune to pass tests.
#define LIVING_ARCTIC_DAY_CALM_SCALE 0.42f
#define LIVING_ARCTIC_SNOW_BANK_RATE 0.16f
#define LIVING_ARCTIC_SNOW_ROLL_RATE 0.012f
#define LIVING_ARCTIC_CHANNEL_RATE 2.4f
#define LIVING_ARCTIC_NIGHT_CALM_SCALE 0.35f
#define LIVING_ARCTIC_AURORA_FOLD_RATE 0.19f
#define LIVING_ARCTIC_AURORA_REFORM_RATE 0.13f
#define LIVING_ARCTIC_AURORA_CURTAIN_RATE 0.37f
#define LIVING_ARCTIC_AURORA_VERTICAL_RATE 0.17f
#define LIVING_ARCTIC_LAKE_RATE 2.1f
#endif
