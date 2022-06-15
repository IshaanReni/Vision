#include "platform.h"
#include <cstdio>
#include <cmath>

typedef struct
{
	u8 r, g, b;
} RGB;

u8 *rgb_to_hue(u8 *data, i32 x, i32 y, i32 n);
