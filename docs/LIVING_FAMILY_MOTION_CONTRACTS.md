# Living family motion contracts

The Ocean timing authority is `LivingOceanTiming.h`, extracted in 919d99af from the mutually agreeing production model and tests at 15b4266. The values describe current engineering tuning, not owner-specified timing requirements. The external Ocean SHA-256 and event-consumer checks remain mandatory throughout this run.

The remaining family rates have one header each: `LivingRainforestMotion.h`, `LivingArcticMotion.h`, `LivingMountainsMotion.h`, `LivingCanyonMotion.h`, and `LivingDesertMotion.h`. `LivingAtmosphereMotion.h` owns common cloud, fog, precipitation, star and meteor rates. `LivingMotionContracts.h` only imports these authorities for Swift validation; it owns no values. Metal consumes the family headers directly. Artwork geometry, density, lighting and scene seeds are the typed `LivingAtmosphereConfiguration` descriptors consumed by the native renderer and tests.

Rainforest Day retains every byte of the accepted 9494e81 shader. Its literal advection representation is mechanically checked against the family header; its complete accepted program is pinned. No tuning or renderer ownership changes were required to preserve it.

A family header and its descriptors are frozen in the external `FAMILY_MOTION_AUTHORITIES.json` when the first scene in that family earns its passing commit. The common air header is frozen with the first participating scene. Every later validation checks that external ledger. A frozen-value change is a global failure, not a test-adjustment opportunity.

The shared infrastructure commit contains configuration binding, common air helpers and evidence tooling. Pending scene programs are activated and committed individually with focused tests and Simulator motion evidence. A registered implementation and remote engineering PASS do not establish physical acceptance.

Evidence uses an empty UIKit host around the production `LivingEnvironmentSurface`; no alternate renderer or personal data is used. Videos are actual Simulator captures, resized to 540 × 960 for repository storage. The original full-resolution captures, source manifests, timing provenance, restored-draft proof and complete command logs remain in the external checkpoint directory.
