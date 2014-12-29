library Tables;

import "dart:math";

/// provides the (integer) sample period for this full note.
int getSamplePeriod(int fullNote) =>
    ((fullNote & 0x0F) << 8 | ((fullNote & 0xFF00) >> 8));

/// provides the sample number for this full note.
int getSampleNumber(int fullNote) =>
    ((fullNote & 0xF0) | ((fullNote & 0x00F00000) >> 20));

/// all mod commands.
class ModCommand {
  static const int positionJump = 0x0B;
  static const int patternBreak = 0x0D;
  static const int setSpeed = 0x0F;
  static const int loopPattern = 0xE6;
  static const int patternDelay = 0xEE;
}

/// all mod effects.
final Set<int> modEffect = new Set<int>.from(
    [
        0X00,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0C,
        0xE,
        0xE0,
        0xE1,
        0xE2,
        0xE3,
        0xE4,
        0xE5,
        0xE6,
        0xE7,
        0xE8,
        0xEA,
        0xEB,
        0xEC,
        0xED,
        0xEF]);

const num palClockFreq = 7093789.2;
const num ntscClockFreq = 7159090.5;

/// supported period values.
final List<int> periodTable = [
    1712,
    1616,
    1525,
    1440,
    1357,
    1281,
    1209,
    1141,
    1077,
    1017,
    961,
    907,
    856,
    808,
    762,
    720,
    678,
    640,
    604,
    570,
    538,
    508,
    480,
    453,
    428,
    404,
    381,
    360,
    339,
    320,
    302,
    285,
    269,
    254,
    240,
    226,
    214,
    202,
    190,
    180,
    170,
    160,
    151,
    143,
    135,
    127,
    120,
    113,
    107,
    101,
    95,
    90,
    85,
    80,
    76,
    71,
    67,
    64,
    60,
    57];

/// accurate period values.
final List<double> accurateBasePeriodTable =
    new List<double>(periodTable.length);

/// provides a note (from 1 to 5*12) from a period.
final Map<int, int> periodToNoteTable = new Map<int, int>();

/// provide an accurate frequency for a supported one.
final Map<int, double> acurateFrequencyMap = new Map<int, double>();

/// finetune multipliers
final List<double> finetuneTable = new List<double>(16);

/// tables giving the channel count for the mod format.
/// any other format is not supported.
final Map<String, int> formatTable = {
  "M.K.": 4,
  "M!K!": 4,
  "4CHN": 4,
  "FLT4": 4,
  "6CHN": 6,
  "8CHN": 8,
  "FLT8": 8,
  "28CH": 28
};

/// table provide a non-linear volume for a channel volume.
final List<int> _baseVolumeTable = [
    0,
    1750,
    2503,
    2701,
    2741,
    2781,
    2944,
    2964,
    2981,
    3000,
    3017,
    3034,
    3052,
    3070,
    3207,
    3215,
    3224,
    3232,
    3240,
    3248,
    3256,
    3263,
    3271,
    3279,
    3287,
    3294,
    3303,
    3310,
    3317,
    3325,
    3458,
    3462,
    3466,
    3469,
    3473,
    3478,
    3481,
    3484,
    3489,
    3492,
    3495,
    3499,
    3502,
    3506,
    3509,
    3513,
    3517,
    3520,
    3524,
    3528,
    3532,
    3534,
    3538,
    3543,
    3545,
    3549,
    3552,
    3556,
    3558,
    3563,
    3565,
    3570,
    3573,
    3577,
    3580,
    3580];

///
double acurate320 = 0.0;

/// max volume
const int maxVolume = 3580;

/// provides a normalized (0.0-1.0) webaudio volume for a channel volume.
final List<double> normalizedVolume = new List<double>(_baseVolumeTable.length);

double A4Frequency = 453.0; // should be 440.0 ...

/// oversampling compared to the original (11025Hz) sample.
const int overSampleRatio = 2;


// ---------------- Initializer  -----------------

bool _tables_initialized = false;

void init_tables() {
  if (_tables_initialized) return;
  _init_fineTune();
  _init_acurateMap();
  init_normalizedVolume();
  init_periodToNotTable();
  _tables_initialized = true;
}


void init_normalizedVolume() {
  for (int i = 0; i < _baseVolumeTable.length; i++) {
    num vol = _baseVolumeTable[i];
    normalizedVolume[i] = vol / maxVolume;
  }
}

void _init_fineTune() {
  for (int t =
      0; t < 16; t++) finetuneTable[t] = 1.0 * pow(2, (t - 8) / 12 / 8);
}


void init_periodToNotTable() {
  for (int i = 0; i < periodTable.length; i++) {
    periodToNoteTable[periodTable[i]] = i;
  }
}

void _init_accurateBasePeriodTable() {
  // seek A4 index
  int A4Index = 0;
  while (periodTable[A4Index] != 453) A4Index++;
  double currentFrequency = A4Frequency;
  double magicNumber = pow(2, 1 / 12);
  double magicNumberInverse = 1 / magicNumber;
  // fill table downward
  int ind = A4Index;
  while (ind >= 0) {
    int period = periodTable[ind];
    accurateBasePeriodTable[ind] =
        acurateFrequencyMap[period] = currentFrequency;
    currentFrequency *= magicNumber;
    ind--;
  }
  // fill table upward
  currentFrequency = A4Frequency;
  ind = A4Index;
  while (ind < periodTable.length) {
    int period = periodTable[ind];
    accurateBasePeriodTable[ind] =
        acurateFrequencyMap[period] = currentFrequency;
    currentFrequency *= magicNumberInverse;
    ind++;
  }

  acurate320 = acurateFrequencyMap[320];
  // print
  // for (ind=0; ind<basePeriodTable.length; ind++) {



      //      print ('original is ${basePeriodTable[ind]} and other ${accurateBasePeriodTable[ind]}');
  //}
}

void _init_acurateMap() {
  _init_accurateBasePeriodTable();
  for (int i = 0; i < periodTable.length; i++) {
    int unac_freq = periodTable[i];
    acurateFrequencyMap[unac_freq] = accurateBasePeriodTable[i];
  }
}

final _rng = new Random();
