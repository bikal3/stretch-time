// Stick-figure postures for the built-in stretches. Pure Dart, like workout.dart.
//
// A pose is 11 joints in a 100×100 box (y down, floor at 92), in this order:
// head, neck, hip, left elbow, left hand, right elbow, right hand,
// left knee, left foot, right knee, right foot.
// Side views face right; "left" limbs are the near ones.

enum Limb { head, spine, lArm, rArm, lLeg, rLeg }

/// Joint indexes each limb is drawn through.
const limbJoints = {
  Limb.head: [1, 0],
  Limb.spine: [1, 2],
  Limb.lArm: [1, 3, 4],
  Limb.rArm: [1, 5, 6],
  Limb.lLeg: [2, 7, 8],
  Limb.rLeg: [2, 9, 10],
};

typedef Pt = (double, double);

List<Pt> _points(String s) => [
  for (final p in s.trim().split(RegExp(r'\s+')))
    (double.parse(p.split(',')[0]), double.parse(p.split(',')[1])),
];

class Pose {
  final String _joints;
  final List<String> _props; // floor, furniture: polylines, drawn thin

  const Pose(this._joints, [this._props = const [_floor]]);

  List<Pt> get joints => _points(_joints);
  List<List<Pt>> get props => [for (final p in _props) _points(p)];
}

class Posture {
  final Pose correct, wrong;
  final Set<Limb> wrongLimbs; // drawn red on the wrong pose
  final List<String> tips;
  const Posture(this.correct, this.wrong, this.wrongLimbs, this.tips);
}

Posture? postureFor(String exercise) => postures[exercise.trim().toLowerCase()];

const _floor = '4,92 96,92';
const _chairSide = '36,28 36,62 62,62';
const _chairSideLegs = ['38,62 38,92', '60,62 60,92'];
// Outline of a mat, for poses seen from above.
const _mat = '14,4 86,4 86,96 14,96 14,4';
const _chairFront = ['36,60 64,60', '37,60 37,92', '63,60 63,92'];

// Shared lower bodies.
const _standFront = '46,72 45,92 54,72 55,92';
const _standSide = '51,72 53,92 49,72 47,92';
const _sitSide = '64,58 66,92 63,59 65,92';
const _sitFront = '44,60 44,92 56,60 56,92';

const postures = {
  'neck stretch': Posture(
    Pose('57,14 50,22 50,52 41,36 39,50 64,20 54,7 $_standFront'),
    Pose('62,19 50,22 50,52 41,36 39,50 67,20 59,10 $_standFront'),
    {Limb.head, Limb.rArm},
    [
      "Let the hand's weight do the work, don't pull",
      'Keep both shoulders down and relaxed',
      'Ease off if you feel tingling',
    ],
  ),
  'neck tilt': Posture(
    Pose('57,17 50,26 50,56 42,42 44,58 58,42 56,58 $_sitFront', [
      _floor,
      ..._chairFront,
    ]),
    Pose('63,19 55,27 50,56 42,42 44,58 62,34 60,48 $_sitFront', [
      _floor,
      ..._chairFront,
    ]),
    {Limb.head, Limb.spine, Limb.rArm},
    [
      'Sit tall and keep the body still',
      'Ear toward shoulder, not shoulder to ear',
      'Hold gently, then switch sides',
    ],
  ),
  'shoulder rolls': Posture(
    Pose('50,12 50,22 50,52 54,37 55,51 53,37 54,51 $_standSide'),
    Pose('60,17 55,26 50,52 55,40 57,53 55,40 57,53 $_standSide'),
    {Limb.head, Limb.spine},
    [
      'Big slow circles: up, back, then down',
      'Keep the neck long and chin level',
      "Arms stay loose, don't swing them",
    ],
  ),
  'chest opener': Posture(
    Pose('51,12 50,22 50,52 42,38 36,52 43,39 37,53 $_standSide'),
    Pose('44,14 48,23 55,52 40,32 32,42 41,33 33,43 55,72 50,92 55,72 50,92'),
    {Limb.head, Limb.spine},
    [
      'Lift the chest, not the chin',
      'Draw the shoulder blades together and down',
      "Keep the ribs in, don't arch the low back",
    ],
  ),
  'side bend': Posture(
    Pose('37,17 42,25 50,52 38,38 40,51 42,11 32,5 45,72 43,92 55,72 57,92'),
    Pose('36,20 44,27 60,52 38,40 40,53 43,13 32,9 52,72 45,92 60,72 57,92'),
    {Limb.spine},
    [
      "Bend straight to the side, don't lean forward",
      'Keep the hips level and centred over the feet',
      'Reach long through the fingertips',
    ],
  ),
  'forward fold': Posture(
    Pose('62,83 62,74 46,50 62,82 63,91 61,83 62,91 50,71 47,92 50,71 47,92'),
    Pose('57,80 64,70 50,50 64,80 61,90 63,80 60,90 50,71 50,92 50,71 50,92'),
    {Limb.spine, Limb.head, Limb.lLeg, Limb.rLeg},
    [
      'Hinge from the hips, not the waist',
      'Soften the knees, never lock them',
      'Let the head hang heavy',
    ],
  ),
  'quad stretch': Posture(
    Pose('50,12 50,22 50,52 58,34 66,38 44,38 39,55 50,72 50,92 51,72 38,56'),
    Pose('62,14 58,24 50,52 66,36 72,42 52,40 45,57 50,72 50,92 62,66 45,58'),
    {Limb.spine, Limb.rLeg},
    [
      'Knees side by side, pointing down',
      "Stand tall, don't lean forward",
      'Hold a wall or chair for balance',
    ],
  ),
  'hip flexor lunge': Posture(
    Pose('46,30 45,40 44,70 52,52 60,66 51,53 59,67 62,70 64,92 32,89 14,91'),
    Pose('64,36 58,44 46,72 66,56 72,70 65,57 71,71 76,74 62,92 34,90 16,91'),
    {Limb.spine, Limb.lLeg},
    [
      'Front knee stacked over the ankle',
      'Tuck the pelvis, keep the torso upright',
      'Feel it at the front of the back hip',
    ],
  ),
  "child's pose": Posture(
    Pose('70,85 62,84 34,80 76,89 90,90 76,89 90,90 56,90 30,92 56,90 30,92'),
    Pose('72,74 66,82 40,68 72,88 80,90 72,88 80,90 56,90 32,92 56,90 32,92'),
    {Limb.spine, Limb.head},
    [
      'Sink the hips back toward the heels',
      'Rest the forehead down, relax the neck',
      'Widen the knees if the belly feels squashed',
    ],
  ),
  'shoulder shrugs': Posture(
    Pose('44,20 43,30 42,60 47,44 49,58 47,44 49,58 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    Pose('60,26 52,33 46,60 54,46 58,58 54,46 58,58 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    {Limb.head, Limb.spine},
    [
      'Lift the shoulders straight up, then let them drop',
      'Sit tall with the feet flat',
      'Keep the arms heavy and relaxed',
    ],
  ),
  'wrist stretch': Posture(
    Pose('44,20 43,30 42,60 56,31 70,31 56,38 70,27 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
      '70,31 71,23',
    ]),
    Pose('54,24 48,32 44,60 54,40 64,32 56,42 64,28 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
      '64,32 65,24',
    ]),
    {Limb.lArm, Limb.spine},
    [
      'Keep the stretching arm straight',
      'Pull the fingers back gently, never to pain',
      'Shoulders down, sit tall',
    ],
  ),
  'seated twist': Posture(
    Pose('41,20 43,30 42,60 36,38 36,30 54,44 62,56 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    Pose('58,27 52,34 46,60 42,42 37,34 58,48 64,58 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    {Limb.spine, Limb.head},
    [
      'Grow tall first, then twist',
      'Turn from the ribs, keep the hips square',
      "Use the chair gently, don't crank",
    ],
  ),
  'upper back stretch': Posture(
    Pose('54,27 48,32 42,60 60,36 72,38 59,37 71,39 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    Pose('54,16 46,28 42,60 56,46 66,54 55,47 65,55 $_sitSide', [
      _floor,
      _chairSide,
      ..._chairSideLegs,
    ]),
    {Limb.head, Limb.lArm, Limb.rArm},
    [
      'Reach the hands forward and round the upper back',
      'Tuck the chin gently',
      'Spread the shoulder blades apart',
    ],
  ),
  'calf raises': Posture(
    Pose('50,9 50,19 50,49 58,28 64,32 58,28 64,32 50,69 50,88 50,69 50,88', [
      _floor,
      '64,32 64,62 88,62',
      '66,62 66,92',
      '86,62 86,92',
      '47,88 56,92',
    ]),
    Pose('60,14 57,23 45,52 61,30 64,34 61,30 64,34 54,71 50,92 54,71 50,92', [
      _floor,
      '64,32 64,62 88,62',
      '66,62 66,92',
      '86,62 86,92',
    ]),
    {Limb.spine, Limb.lLeg, Limb.rLeg},
    [
      'Rise straight up onto the balls of the feet',
      'Keep the knees straight but not locked',
      "Lower slowly, don't drop",
    ],
  ),
  'triceps stretch': Posture(
    Pose('50,13 50,22 50,52 38,14 51,6 53,7 45,20 $_standFront'),
    Pose('44,17 47,25 52,52 36,18 47,9 50,10 42,23 $_standFront'),
    {Limb.head, Limb.spine},
    [
      "Keep the head up, don't let the arm push it forward",
      'Point the elbow straight up',
      'Press the elbow gently, no forcing',
    ],
  ),
  'cat-cow': Posture(
    Pose('71,59 64,64 34,66 64,78 64,91 63,78 63,91 34,90 14,91 34,90 14,91'),
    Pose('70,73 66,64 40,66 70,78 78,91 69,78 77,91 32,90 12,91 32,90 12,91'),
    {Limb.head, Limb.lArm, Limb.rArm},
    [
      'Hands under shoulders, knees under hips',
      'Round on the exhale, arch on the inhale',
      'Let the head follow the spine',
    ],
  ),
  'downward dog': Posture(
    Pose('65,79 70,70 50,46 75,80 80,91 74,80 79,91 37,69 24,92 37,69 24,92'),
    Pose('72,62 66,70 52,44 68,80 70,91 67,80 69,91 44,68 36,92 44,68 36,92'),
    {Limb.head, Limb.spine},
    [
      'Push the floor away and lengthen the spine',
      'Hips up and back; bend the knees if needed',
      'Relax the head between the arms',
    ],
  ),
  'hamstring stretch': Posture(
    Pose('61,63 54,68 30,86 62,76 70,86 61,77 69,87 52,89 74,89 52,89 74,89'),
    Pose('56,76 50,70 30,86 58,78 64,86 57,79 63,87 50,80 70,90 50,80 70,90'),
    {Limb.spine, Limb.head, Limb.lLeg, Limb.rLeg},
    [
      'Hinge from the hips with a long back',
      'Lead with the chest, not the head',
      'A small knee bend is fine; never bounce',
    ],
  ),
  'butterfly': Posture(
    Pose('50,42 50,52 50,82 42,66 48,86 58,66 52,86 32,80 48,88 68,80 52,88'),
    Pose('50,54 50,62 50,84 38,72 32,78 62,72 68,78 34,84 48,88 66,84 52,88'),
    {Limb.head, Limb.spine, Limb.lArm, Limb.rArm},
    [
      'Sit tall, lift through the crown',
      "Let the knees drop on their own, don't force them",
      'Hold the feet, not the knees',
    ],
  ),
  'pigeon pose': Posture(
    Pose('49,40 48,50 46,80 54,64 58,88 53,65 57,89 62,86 50,89 24,88 6,90'),
    Pose('30,46 36,54 46,78 40,68 38,88 39,69 37,89 62,86 50,89 26,86 18,74'),
    {Limb.spine, Limb.rLeg},
    [
      'Keep the hips square and level',
      'Back leg straight behind you, top of the foot down',
      "Prop the hip on a cushion if it's lifted",
    ],
  ),
  'calf stretch': Posture(
    Pose('72,22 66,30 52,56 76,30 86,28 75,31 86,29 66,72 64,92 42,74 32,92', [
      _floor,
      '86,4 86,92',
    ]),
    Pose('72,22 66,30 52,56 76,30 86,28 75,31 86,29 66,72 64,92 40,78 28,86', [
      _floor,
      '86,4 86,92',
    ]),
    {Limb.rLeg},
    [
      'Press the back heel into the floor',
      'Back leg straight, toes pointing forward',
      'Lean from the ankles, body in one line',
    ],
  ),
  // Seen from above.
  'supine twist': Posture(
    Pose('50,14 50,24 50,54 36,24 22,24 64,24 78,24 68,62 60,78 70,68 62,82', [
      _mat,
    ]),
    Pose('50,14 50,24 50,54 36,24 22,24 58,34 66,44 68,62 60,78 70,68 62,82', [
      _mat,
    ]),
    {Limb.rArm},
    [
      'Keep both shoulders on the floor',
      'Let the knees fall only as far as is comfortable',
      'Turn the head away from the knees if it feels good',
    ],
  ),
  'happy baby': Posture(
    Pose('18,86 28,88 56,88 34,70 42,58 35,71 43,59 44,74 42,56 45,75 43,57'),
    Pose('22,76 32,84 56,82 36,68 42,58 37,69 43,59 44,70 42,54 45,71 43,55'),
    {Limb.head, Limb.spine},
    [
      'Keep the head and tailbone on the floor',
      'Knees toward the armpits, shins vertical',
      'Rock gently side to side if it feels good',
    ],
  ),
  'legs up the wall': Posture(
    Pose('26,86 36,88 66,88 42,80 52,84 43,81 53,85 67,66 67,44 66,66 66,44', [
      _floor,
      '70,4 70,92',
    ]),
    Pose('10,86 20,88 46,88 26,80 36,84 27,81 37,85 54,68 62,48 53,68 61,48', [
      _floor,
      '70,4 70,92',
    ]),
    {Limb.lLeg, Limb.rLeg},
    [
      'Scoot the hips close to the wall',
      'Rest the legs on the wall, no effort',
      'Arms relaxed by your sides, breathe slowly',
    ],
  ),
  // Seen from above.
  'reclined butterfly': Posture(
    Pose('50,14 50,24 50,54 38,36 30,48 62,36 70,48 32,70 48,80 68,70 52,80', [
      _mat,
    ]),
    Pose('50,14 50,24 50,54 40,42 34,66 60,42 66,66 32,70 48,80 68,70 52,80', [
      _mat,
    ]),
    {Limb.lArm, Limb.rArm},
    [
      'Let gravity open the knees, no pushing',
      'Support the knees with cushions if needed',
      'Keep the low back soft on the floor',
    ],
  ),
};
