# Frozen Ocean timing authority

`LifeRoute/LivingOceanTiming.h` is the sole timing authority for Living Ocean Day/Night. This header was extracted without retuning from `15b42662210652599f9d85c35b6907ed284d451a`. Metal includes it and the offline Swift GPU tests import the same C header. No runtime configuration, additional allocation or per-frame bridge was introduced.

The authority records the original lifetime range and maximum, nominal arrival spacing and start jitter, event slots, phase boundaries, travel exponent, calm playback scaling, foam/ripple/spray rates and the meaningful overlap sample already used by validation. Maximum adjacent-start gap derives from spacing plus jitter. The guaranteed developed-swell overlap derives from that gap, the later maximum lifetime and the earlier minimum lifetime/dissipation bound.

After this authority commit the header is read-only for the rest of Living Themes expansion. A timing-value change requires `STOP_OCEAN_TIMING_AUTHORITY_CHANGE_REQUIRED`; do not update the pin to manufacture a pass.

`python3 scripts/check_ocean_timing_authority.py` checks the header/event-consumer pins, remaining timing consumers and test import, and requires rejection of independently mutated authority, event timing and arrival selector. The pins are guards, not a second source of timing values. GPU tests inspect the actual production event function, stage ordering, advancing fronts, substantial simultaneous waves, differing event generations, still/calm behavior and rendered fixed/moving regions.

Authority-establishment pixel preservation and native build logs live in the full-expansion external checkpoint's `authority-validation/` directory. Host/Simulator evidence is not physical acceptance.

## Provenance

At the extraction source, production uses `14.2 + hash * 3.8`, and tests require a lifetime no greater than 18 seconds: those values agree. Both identify 6.3 seconds as nominal arrival spacing; production adds up to 1.7 seconds of seeded jitter. Tests query real starts, lifetimes and simultaneous phases at a developed later swell.

The preceding `a88aea6 -> 15b4266` change replaced a conflicting historical `life > 18.9` proxy with actual overlap tests and bounded lifetimes. That historical mismatch is not present at the extraction source. The values extracted here are current engineering authority for this run; the product requirement is semantic motion and overlapping waves, not a permanent aesthetic timing law. Exact provenance is recorded in the external `OCEAN_TIMING_PROVENANCE.json`.
