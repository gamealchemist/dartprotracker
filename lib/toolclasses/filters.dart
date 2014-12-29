library audiofilters;

import "dart:typed_data";


/* Digital filter designed by mkfilter/mkshape/gencode   A.J. Fisher
   Command line: /www/usr/fisher/helpers/mkfilter -Bu -Lp -o 5 -a 4.5248868778e-01 0.0000000000e+00 -l */

void filterloop__11Ksamples_5200cutoff(Float32List fbuffer) {
  //return;
  final int NZEROS = 5;
  final int NPOLES = 5;
  final double GAIN = 1.624585301e+00;
  int bufLen = fbuffer.length;
  Float32List xv = new Float32List(NZEROS + 1);
  Float32List yv = new Float32List(NPOLES + 1);

  {
    for (int i = 0; i < bufLen; i++) {
      xv[0] = xv[1];
      xv[1] = xv[2];
      xv[2] = xv[3];
      xv[3] = xv[4];
      xv[4] = xv[5];
      xv[5] = fbuffer[i] / GAIN;
      yv[0] = yv[1];
      yv[1] = yv[2];
      yv[2] = yv[3];
      yv[3] = yv[4];
      yv[4] = yv[5];
      yv[5] = (xv[0] + xv[5]) +
          5 * (xv[1] + xv[4]) +
          10 * (xv[2] + xv[3]) +
          (-0.3788915839 * yv[0]) +
          (-2.2600959439 * yv[1]) +
          (-5.4340383051 * yv[2]) +
          (-6.5893286726 * yv[3]) +
          (-4.0349799380 * yv[4]);
      fbuffer[i] = yv[5];
    }
  }
}

/* Digital filter designed by mkfilter/mkshape/gencode   A.J. Fisher
   Command line: /www/usr/fisher/helpers/mkfilter -Bu -Bp -o 5 -a 7.2562358277e-03 3.6281179138e-01 -l */

// band pass
void filterloop(Float32List fbuffer) {
  int NZEROS = 10;
  int NPOLES = 10;
  double GAIN = 4.642132758e+00;
  Float32List xv = new Float32List(NZEROS + 1);
  Float32List yv = new Float32List(NPOLES + 1);

  for (int i = 0; i < fbuffer.length; i++) {
    xv[0] = xv[1];
    xv[1] = xv[2];
    xv[2] = xv[3];
    xv[3] = xv[4];
    xv[4] = xv[5];
    xv[5] = xv[6];
    xv[6] = xv[7];
    xv[7] = xv[8];
    xv[8] = xv[9];
    xv[9] = xv[10];
    xv[10] = fbuffer[i] / GAIN;
    yv[0] = yv[1];
    yv[1] = yv[2];
    yv[2] = yv[3];
    yv[3] = yv[4];
    yv[4] = yv[5];
    yv[5] = yv[6];
    yv[6] = yv[7];
    yv[7] = yv[8];
    yv[8] = yv[9];
    yv[9] = yv[10];
    yv[10] = (xv[10] - xv[0]) +
        5 * (xv[2] - xv[8]) +
        10 * (xv[6] - xv[4]) +
        (0.0463695660 * yv[0]) +
        (0.1229743058 * yv[1]) +
        (-0.1939898762 * yv[2]) +
        (-0.6822396154 * yv[3]) +
        (0.1621236810 * yv[4]) +
        (1.8629851017 * yv[5]) +
        (-0.3518260385 * yv[6]) +
        (-1.5520993792 * yv[7]) +
        (-1.0525407768 * yv[8]) +
        (2.6382415989 * yv[9]);
    fbuffer[i] = yv[10];

  }
}

// http://yehar.com/blog/wp-content/uploads/2009/08/deip.pdf
void interpolateHermite_2X(Float32List input, Float32List output, int index) {
  Float32List y = new Float32List.view(
      input.buffer,
      (index - 2) * Float32List.BYTES_PER_ELEMENT,
      6);
  int offset = 2;
  // 6-point, 5th-order Hermite (x-form)
  double eighthym2 = 1 / 8.0 * y[offset - 2];
  double eleventwentyfourthy2 = 11 / 24.0 * y[offset + 2];
  double twelfthy3 = 1 / 12.0 * y[offset + 3];
  double c0 = y[offset + 0];
  double c1 =
      1 / 12.0 * (y[offset - 2] - y[offset + 2]) +
      2 / 3.0 * (y[offset + 1] - y[offset - 1]);
  double c2 =
      13 / 12.0 * y[offset - 1] - 25 / 12.0 * y[offset + 0] +
          3 / 2.0 * y[offset + 1] -
          eleventwentyfourthy2 +
          twelfthy3 -
      eighthym2;
  double c3 =
      5 / 12.0 * y[offset + 0] - 7 / 12.0 * y[offset + 1] + 7 / 24.0 * y[offset + 2] -
      1 / 24.0 * (y[offset - 2] + y[offset - 1] + y[offset + 3]);
  double c4 =
      eighthym2 - 7 / 12.0 * y[offset - 1] + 13 / 12.0 * y[offset + 0] -
          y[offset + 1] +
          eleventwentyfourthy2 -
      twelfthy3;
  double c5 =
      1 / 24.0 * (y[offset + 3] - y[offset - 2]) +
      5 / 24.0 * (y[offset - 1] - y[offset + 2]) +
      5 / 12.0 * (y[offset + 1] - y[offset + 0]);
  var fn = (x) => ((((c5 * x + c4) * x + c3) * x + c2) * x + c1) * x + c0;
  int intIndex = 2 * index;
  output[intIndex + 0] = fn(0);
  output[intIndex + 1] = fn(0.5);
}

// http://yehar.com/blog/wp-content/uploads/2009/08/deip.pdf
void interpolate6p5oo4x(Float32List input, Float32List output, int index) {
  Float32List y = new Float32List.view(
      input.buffer,
      (index - 2) * Float32List.BYTES_PER_ELEMENT,
      6);
  // Optimal 4x (6-point, 4th-order) (z-form)
  //double z = x - 1/2.0;
  int offset = 2;
  double even1 = y[offset + 1] + y[offset + 0],
      odd1 = y[offset + 1] - y[offset + 0];
  double even2 = y[offset + 2] + y[offset - 1],
      odd2 = y[offset + 2] - y[offset - 1];
  double even3 = y[offset + 3] + y[offset - 2],
      odd3 = y[offset + 3] - y[offset - 2];
  double c0 =
      even1 * 0.26148143200222657 +
      even2 * 0.22484494681472966 +
      even3 * 0.01367360612950508;
  double c1 =
      odd1 * -0.20245593827436142 +
      odd2 * 0.29354348112881601 +
      odd3 * 0.06436924057941607;
  double c2 =
      even1 * -0.022982104451679701 +
      even2 * -0.09068617668887535 +
      even3 * 0.11366875749521399;
  double c3 =
      odd1 * 0.36296419678970931 +
      odd2 * -0.26421064520663945 +
      odd3 * 0.08591542869416055;
  double c4 =
      even1 * 0.02881527997393852 +
      even2 * -0.04250898918476453 +
      even3 * 0.01369173779618459;
  var fn = (z) => (((c4 * z + c3) * z + c2) * z + c1) * z + c0;
  //now fill -1 0 1 2  in -1 1
  int intIndex = 4 * index;
  output[intIndex + 0] = fn(1 / 8 - 1 / 2 + 1 / 4);
  output[intIndex + 1] = fn(1 / 8 - 1 / 2 + 2 / 4);
  output[intIndex + 2] = fn(1 / 8 - 1 / 2 + 3 / 4);
  output[intIndex + 3] = fn(1 / 8 - 1 / 2 + 4 / 4);

}
