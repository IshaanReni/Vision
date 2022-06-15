#include <stdint.h>
#include <math.h>
#include "kernel_operations.h"
#include "color_operations.h"
#include "platform.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

int main()
{

	for (i32 p = 1; p <= 8; p++)
	{
		i32 x, y, n;
		char buf[100];
		snprintf(buf, 100, "images/test%i.png", p);

		RGB *rgb_data = (RGB *)stbi_load(buf, &x, &y, &n, 0);
		i32 bin_count = 15;
		HSV *hsv_data = rgb_to_hsv((unsigned char *)rgb_data, x, y, n);

		for (i32 i = 0; i < x * y; i++)
		{
			if ((hsv_data[i].hue < 35 && hsv_data[i].hue > 21)) //|| (hsv_data[i].val > 250)) // orangey background
			{
				rgb_data[i] = {0, 0, 0};
			}
			// else if (hsv_data[i].hue < 20)
			// {
			// 	rgb_data[i] = {255, 0, 0};
			// }
			// if ((hsv_data[i].hue < 15 || hsv_data[i].hue > 250) && hsv_data[i].val > 57) // red
			// {
			// 	rgb_data[i] = {255, 0, 0};
			// }
<<<<<<< HEAD
			// else if ((hsv_data[i].hue < 50 && hsv_data[i].hue > 35) && (hsv_data[i].val > 160 && hsv_data[i].val < 210) && (hsv_data[i].sat > 130 && hsv_data[i].sat < 200)) // top half yellow
			// {
			// 	rgb_data[i] = {255, 255, 0};
			// }
=======
			//if ((hsv_data[i].hue < 45 && hsv_data[i].hue > 38) && (hsv_data[i].val > 160 && hsv_data[i].val < 210)) // top half yellow
			//{
			//	rgb_data[i] = {255, 255, 0};
			//}
>>>>>>> eb464311c402b6123c86980ac5854909134b0f32
			// else if (hsv_data[i].hue < 230 && hsv_data[i].hue > 220) // pink
			// {
			// 	rgb_data[i] = {168, 50, 153};
			// }
<<<<<<< HEAD
			// else if ((hsv_data[i].hue < 155 && hsv_data[i].hue > 113) && (hsv_data[i].val > 25 && hsv_data[i].val < 50)) // && hsv_data[i].sat > 100) // Dark blue
			//{
			//	rgb_data[i] = {0, 0, 255};
			//}
			else if (hsv_data[i].hue < 80 && hsv_data[i].hue > 75 && hsv_data[i].val > 130 && hsv_data[i].sat < 200 && hsv_data[i].sat > 120) // light green
			{
				rgb_data[i] = {0, 255, 0};
			}
=======
			  if (hsv_data[i].hue < 130 && hsv_data[i].hue > 100 && hsv_data[i].val > 20 && hsv_data[i].val < 90 && hsv_data[i].sat >100) // Dark blue
			 {
			 	rgb_data[i] = {0, 0, 255};
			 }
			// else if (hsv_data[i].hue < 85 && hsv_data[i].hue > 75 && hsv_data[i].val > 130) // light green
			// {
			// 	rgb_data[i] = {0, 255, 0};
			// }
>>>>>>> eb464311c402b6123c86980ac5854909134b0f32
			// // else if (hsv_data[i].hue < 85 && hsv_data[i].hue > 75 && hsv_data[i].val > 120) // teal
			// {
			// 	rgb_data[i] = {0, 255, 0};
			// }

			// else
			// {
			// rgb_data[i] = {0, 0, 0};
			// }
		}
		snprintf(buf, 100, "images/results/test%i_result.png", p);
		stbi_write_png(buf, x, y, n, rgb_data, x * n * sizeof(u8));
	}
}

/*
u8 hue_counts[bin_count] = {0};
for (i32 i = 0; i < x * y; i++)
{
	hue_counts[hue_pixels[i]] += 1;
}

for (i32 h = 0; h < bin_count; h++)
{
	printf("%i %i\n", h, hue_counts[h]);
	if (hue_counts[h] < 50)
	{
		continue;
	}

	u8 *hue_blob = (u8 *)malloc(x * y * sizeof(u8));
	memset(hue_blob, 0, x * y * sizeof(u8));

	for (i32 p = 0; p < x * y; p++)
	{
		if (hue_pixels[p] == h)
		{
			hue_blob[p] = 120;
			// printf("%i ", p);
		}
	}
	kernel_operation(hue_blob, x, y, 1, GaussianBlur);
	kernel_operation(hue_blob, x, y, 1, Solid);
	// kernel_operation(hue_blob, x, y, 1, Sobel);

	char buf[100];
	snprintf(buf, 100, "images/results/hue_blob%i.png", h);

	stbi_write_png(buf, x, y, 1, hue_blob, x * sizeof(u8));
}
*/