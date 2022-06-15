#include "color_operations.h"

u8 *rgb_to_hue(u8 *data, i32 x, i32 y, i32 n, i32 bin_count)
{
	if (n != 3)
	{
		printf("Please only provide RBG data\n");
		return NULL;
	}
	u8 *hue = (u8 *)malloc(x * y * sizeof(u8));
	i32 h = 0;
	for (u8 *p = data; p < (data + x * y * n); p += n)
	{
		// printf("(%i, %i, %i) ", p[0], p[1], p[2]);
		f32 R = p[0] / 255.0;
		f32 G = p[1] / 255.0;
		f32 B = p[2] / 255.0;

		f32 min = fmin(fmin(R, B), G);

		f32 max = 0;
		u8 maxIsR = 0;
		u8 maxIsG = 0;

		if (R >= G && R >= B)
		{
			max = R;
			maxIsR = true;
		}
		else if (G > B)
		{
			max = G;
			maxIsG = true;
		}
		else
		{
			max = B;
		}

		f32 del_max = max - min;

		f32 H;

		if (del_max == 0)
		{
			H = 0;
		}
		else
		{
			f32 del_R = (((max - R) / 6.0) + (del_max / 2.0)) / del_max;
			f32 del_G = (((max - G) / 6.0) + (del_max / 2.0)) / del_max;
			f32 del_B = (((max - B) / 6.0) + (del_max / 2.0)) / del_max;

			if (maxIsR)
			{
				H = del_B - del_G;
			}
			else if (maxIsG)
			{
				H = (1.0 / 3.0) + del_R - del_B;
			}
			else
			{
				H = (2.0 / 3.0) + del_G - del_R;
			}

			if (H < 0)
			{
				H += 1;
			}
			if (H > 1)
			{
				H -= 1;
			}
		}

		hue[h] = H * bin_count;
		// printf("%f %f %f, %f %i\n", R, G, B, H, hue[h]);

		h++;
	}

	return hue;
}