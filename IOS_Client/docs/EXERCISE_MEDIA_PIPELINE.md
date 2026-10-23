# Exercise media — Phase3 prototype gate

Decision:REMOVE procedural robot Canvas/Timeline from application presentation. No claim of a higher-quality replacement animation without approved assets.

Candidates(10):Bench Press,Squat,Lat Pulldown,Shoulder Press,Curl,Row,Leg Press,Romanian Deadlift,Lateral Raise,Triceps Pushdown. Exact keys in ClientExerciseMediaPipeline. No inferred key from exercise name;no downloaded/generated assets. Legacy resolver descriptors remain for backwards compatibility,not a rendered demonstration.

Future preferred pipeline:short rights-cleared localMP4 with nativeAVKit controls,no autoplay/loop,offline once bundled. For each candidate collect:asset source/license,exactvariant/equipment/setup,start/end,ROM/eccentric/concentric/posture,technical reviewer approval,loop continuity iffuturelooprequested,dimensions/codec/duration/bytes. Then measure realDevice memory/CPU/FPS,ReduceMotion/VoiceOver/offline at smallest/largest phone. Put approvedfile in bundled ExerciseMedia andexplicitlyallowlist exactkey onlyafter review. Missingfile/unapprovedkey alwaysfallback.

Options:proceduralvector is tiny/offline but currentqualityrejected;SVG/sprites scale poorly acrossmotionvariants/largeassets;Rive/Lottie adddepswithoutverifiedanatomyquality;remotevideo addsnetwork/privacy/offlinerisks. Chosen:staticactualtaxonomy+instructionsnow,smalllocalvideo prototypeslater. All numeric appsize/memory/CPU/FPS comparisons NOT MEASURED,not marketingclaims.

No approvedclipssupplied/created:0. Anatomy isillustrative,broadcatalogrolesonly;unknown/accessory metadata notinvented. ExistingHTTPSexercisevideo isuser-opened Link,not automatically fetched inHome/workout.
