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
	i32 x, y, n;
	RGB *rgb_data = (RGB *)stbi_load("images/test1.png", &x, &y, &n, 0);
	i32 bin_count = 15;
	HSV *hsv_data = rgb_to_hsv((unsigned char *)rgb_data, x, y, n);

	for (i32 i = 0; i < x * y; i++)
	{
		// if (hsv_data[i].hue < 20)
		// {
		// 	rgb_data[i] = {255, 0, 0};
		// } 
		if (hue_pixels[i] < 20 || hue_pixels[i] > 250) //red
		{
			rgb_data[i] = {255, 0, 0};
		} else if (hue_pixels[i] < 60 && hue_pixels[i] > 50) //yellow
		{
			rgb_data[i] = {252, 252, 3};
		} else if (hue_pixels[i] < 230 && hue_pixels[i] > 220) // pink
		{
			rgb_data[i] = {168, 50, 153};
		} else if (hue_pixels[i] < 35 && hue_pixels[i] > 21) // orangey background
		{
			rgb_data[i] = {168, 97, 50};
		}
		// else 
		// {
			// rgb_data[i] = {0, 0, 0};
		// }
	}
	}
	stbi_write_png("images/results/hue_thresholded.png", x, y, n, rgb_data, x * n * sizeof(u8));

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
}