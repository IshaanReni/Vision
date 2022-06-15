#include "color_operations.h"

HSV *rgb_to_hsv(u8 *data, i32 x, i32 y, i32 n)
{
	if (n != 3)
	{
		printf("Please only provide RBG data\n");
		return NULL;
	}

	HSV *hsv_data = (HSV *)malloc(x * y * sizeof(HSV));

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

		hsv_data[h].hue = H * 255;
		if (max > 0)
		{
			hsv_data[h].sat = (del_max * 255) / max;
		}
		else
		{
			hsv_data[h].sat = 255;
		}
		hsv_data[h].val = max * 255;
		// printf("%f %f %f, %f H: %i, S: %i, V: %i\n", R, G, B, H, hsv_data[h].hue, hsv_data[h].sat, hsv_data[h].val);

		h++;
	}
	return hsv_data;
}