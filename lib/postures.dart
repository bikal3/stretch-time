// Form tips and posture images for the built-in stretches. Pure Dart.
//
// Images live in assets/postures/, named after the exercise:
//   quad-stretch.png        correct posture, shown on the timer
//   quad-stretch-wrong.png  common mistake, shown in the info sheet
// .jpg and .webp work too. A missing image just isn't shown.

/// Every bundled asset path; filled from the asset manifest at startup.
Set<String> assetPaths = {};

/// 'Child's pose' -> 'childs-pose'.
String slug(String exercise) => exercise
    .trim()
    .toLowerCase()
    .replaceAll("'", '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-');

String? postureImage(String exercise, {bool wrong = false}) {
  final base = 'assets/postures/${slug(exercise)}${wrong ? '-wrong' : ''}';
  for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
    if (assetPaths.contains('$base.$ext')) return '$base.$ext';
  }
  return null;
}

List<String>? tipsFor(String exercise) =>
    formTips[exercise.trim().toLowerCase()];

const formTips = {
  'neck stretch': [
    "Let the hand's weight do the work, don't pull",
    'Keep both shoulders down and relaxed',
    'Ease off if you feel tingling',
  ],
  'neck tilt': [
    'Sit tall and keep the body still',
    'Ear toward shoulder, not shoulder to ear',
    'Hold gently, then switch sides',
  ],
  'shoulder rolls': [
    'Big slow circles: up, back, then down',
    'Keep the neck long and chin level',
    "Arms stay loose, don't swing them",
  ],
  'chest opener': [
    'Lift the chest, not the chin',
    'Draw the shoulder blades together and down',
    "Keep the ribs in, don't arch the low back",
  ],
  'side bend': [
    "Bend straight to the side, don't lean forward",
    'Keep the hips level and centred over the feet',
    'Reach long through the fingertips',
  ],
  'forward fold': [
    'Hinge from the hips, not the waist',
    'Soften the knees, never lock them',
    'Let the head hang heavy',
  ],
  'quad stretch': [
    'Knees side by side, pointing down',
    "Stand tall, don't lean forward",
    'Hold a wall or chair for balance',
  ],
  'hip flexor lunge': [
    'Front knee stacked over the ankle',
    'Tuck the pelvis, keep the torso upright',
    'Feel it at the front of the back hip',
  ],
  "child's pose": [
    'Sink the hips back toward the heels',
    'Rest the forehead down, relax the neck',
    'Widen the knees if the belly feels squashed',
  ],
  'shoulder shrugs': [
    'Lift the shoulders straight up, then let them drop',
    'Sit tall with the feet flat',
    'Keep the arms heavy and relaxed',
  ],
  'wrist stretch': [
    'Keep the stretching arm straight',
    'Pull the fingers back gently, never to pain',
    'Shoulders down, sit tall',
  ],
  'seated twist': [
    'Grow tall first, then twist',
    'Turn from the ribs, keep the hips square',
    "Use the chair gently, don't crank",
  ],
  'upper back stretch': [
    'Reach the hands forward and round the upper back',
    'Tuck the chin gently',
    'Spread the shoulder blades apart',
  ],
  'calf raises': [
    'Rise straight up onto the balls of the feet',
    'Keep the knees straight but not locked',
    "Lower slowly, don't drop",
  ],
  'triceps stretch': [
    "Keep the head up, don't let the arm push it forward",
    'Point the elbow straight up',
    'Press the elbow gently, no forcing',
  ],
  'cat-cow': [
    'Hands under shoulders, knees under hips',
    'Round on the exhale, arch on the inhale',
    'Let the head follow the spine',
  ],
  'downward dog': [
    'Push the floor away and lengthen the spine',
    'Hips up and back; bend the knees if needed',
    'Relax the head between the arms',
  ],
  'hamstring stretch': [
    'Hinge from the hips with a long back',
    'Lead with the chest, not the head',
    'A small knee bend is fine; never bounce',
  ],
  'butterfly': [
    'Sit tall, lift through the crown',
    "Let the knees drop on their own, don't force them",
    'Hold the feet, not the knees',
  ],
  'pigeon pose': [
    'Keep the hips square and level',
    'Back leg straight behind you, top of the foot down',
    "Prop the hip on a cushion if it's lifted",
  ],
  'calf stretch': [
    'Press the back heel into the floor',
    'Back leg straight, toes pointing forward',
    'Lean from the ankles, body in one line',
  ],
  'supine twist': [
    'Keep both shoulders on the floor',
    'Let the knees fall only as far as is comfortable',
    'Turn the head away from the knees if it feels good',
  ],
  'happy baby': [
    'Keep the head and tailbone on the floor',
    'Knees toward the armpits, shins vertical',
    'Rock gently side to side if it feels good',
  ],
  'legs up the wall': [
    'Scoot the hips close to the wall',
    'Rest the legs on the wall, no effort',
    'Arms relaxed by your sides, breathe slowly',
  ],
  'reclined butterfly': [
    'Let gravity open the knees, no pushing',
    'Support the knees with cushions if needed',
    'Keep the low back soft on the floor',
  ],
};
