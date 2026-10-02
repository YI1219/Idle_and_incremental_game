# CMU captured turning motions

Retrieved 2026-09-20 directly from the CMU Graphics Lab Motion Capture Database. Only the subject index, terms page, one calibrated skeleton and five specifically relevant trials were downloaded. There was no database crawl, account operation, or purchase.

- Official index: <http://mocap.cs.cmu.edu/search.php?subjectnumber=69>
- Official terms: <http://mocap.cs.cmu.edu/>
- Calibrated subject skeleton: <http://mocap.cs.cmu.edu/subjects/69/69.asf>
- Trial 07: walk and turn, repeated. Evaluated as a candidate; not used in runtime clips.
- Trial 13: walk, turn in place, repeated. Runtime half-turn source.
- Trial 16: turn in place. Evaluated; successive quarter turns are slower than the selected moving-turn clips.
- Trial 20: walk forward, 90 degree right turn. Runtime right quarter-turn source.
- Trial 24: walk forward, 90 degree left turn. Runtime left quarter-turn source.

All trials are 120 Hz. Each motion URL follows the exact recorded index link, for example <http://mocap.cs.cmu.edu/subjects/69/69_13.amc>. The original ASF/AMC files are retained without editing. SHA-256 hashes are recorded in `assets/characters/qinglan/turn_motion.json`.

## Terms

The official terms permit research use and inclusion in commercially sold products. Direct resale of the motion data is forbidden, including converted forms. This is not a CC0 declaration. The saved `terms_home.html` retains the retrieved wording, and `subject69.html` retains trial descriptions and frame rates.

Requested acknowledgment: The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

The official page warns that hand/toe channels may be noisy and finger/thumb channels are not captured measurements. No finger/thumb animation is used. Qinglan has no independent toe bone; the existing foot bone receives captured foot orientation.

ASF interpretation reference: <https://research.cs.wisc.edu/graphics/Courses/cs-838-1999/Jeff/ASF-AMC.html>. The reader implements column-vector equivalents of its rotation composition rules.
