# Third-party notices

Original Dictate Unlimited application code is MIT, copyright 2026 DOO MADE.
Third-party components and model weights retain their own licenses.

- Bark 3.0, Plus and Pro: Conway Research / Underdog; derived from NVIDIA
  Parakeet TDT v3 and Moondream. CC BY 4.0. See Resources/Notices/Bark-NOTICE.txt
  and Bark-CC-BY-4.0.txt. Exact model revisions/files/hashes are in
  Sources/DictateCore/Resources/models.json.
- Sources/BarkSmall adapts the published Bark NumPy/Core ML reference algorithm
  into Swift/Accelerate. It is separately attributed under CC BY 4.0; see its
  ATTRIBUTION.md. Changes: native Swift array/archive handling, FFT, LSTM/TDT,
  persistent Core ML cache and bounded local segmentation. No Resonant code used.
- FluidAudio: Apache-2.0. Pinned revision `a00964e1aa8eff99c4bce80bc9c8ff2d4dd1568d` in scripts/prepare-dependencies.sh; full notice in
  Resources/Notices/FluidAudio-LICENSE.txt. Pro adapter uses its public ASR API
  following the Conway Research reference runner.
- ZIPFoundation: MIT. Exact version 0.9.19; retain its package LICENSE when
  distributing. See Package.resolved for resolved package identity.

Model cards advertise original MLX/BF16 sizes. This app downloads separate Core ML
exports, labels the actual bytes, and does not claim BF16 inference for Pro's FP16
Core ML export. It makes no benchmark-equivalence claim.

FluidAudio includes third-party implementations. Its pinned third-party notices
are retained in Resources/Notices/FluidAudio-ThirdParty/, including fastcluster
(BSD-2-Clause), VBx (Apache-2.0), and G2P provenance. Keeping these notices does
not imply that this app exposes those features or bundles their model/data files.
NeMo text processing is disabled through `traits: []` with Swift 6.2. LuxTTS
lexicon/auxiliary data is deliberately excluded from the packaged application.
No third-party model weights are included in the source preview or app bundle.

The BarkSmall adaptation notice is also copied into the app's Notices directory.
See docs/LICENSING.md for file scope and the offline audit boundary.
