#include "platform.h"
#include <cstdio>
#include <cmath>

typedef struct
{
	u8 r, g, b;
} RGB;

typedef struct
{
	u8 hue, sat, val;
} HSV;

HSV *rgb_to_hsv(u8 *data, i32 x, i32 y, i32 n);
