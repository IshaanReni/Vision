#include "kernel_operations.h"

// data	: Pointer to raw image data
// x, y : Width in number of pixels
// n	: Number of channels (bytes) per pixels
u8 *kernel_smooth(u8 *data_in, i32 x, i32 y, i32 n, i32 k_halfwidth)
{
	u8 *data_out = (u8 *)malloc(x * y * n * sizeof(u8));

	u8 *p_in = data_in;
	u8 *p_out = data_out;

	// Convert the raw data into an array of pointers, each of which
	// point to the beginning of a row of pixels. This way we can index
	// our raw image data as if it was a multidimensional array.
	u8 **in_img = (u8 **)malloc(y * sizeof(u8 *));
	u8 **out_img = (u8 **)malloc(y * sizeof(u8 *));

	for (u32 r = 0; r < y; r++)
	{
		in_img[r] = p_in;
		p_in += x * n;

		out_img[r] = p_out;
		p_out += x * n;
		// printf("%p ", out_img[r]);
	}
	// printf("\n");

	i32 kernel_size = (2 * k_halfwidth + 1) * (2 * k_halfwidth + 1);
	printf("halfwidth: %u, size: %u \n", k_halfwidth, kernel_size);

	for (i32 r = 0; r < y; r++)
	{
		for (i32 c = 0; c < x; c++)
		{
			// iterate over each channel for a single pixel
			for (i32 l = 0; l < n; l++)
			{
				// make sure that the pixel being processed in not one of the pixels
				// on the edge of the image
				i32 new_pixel = 0;
				if (r > k_halfwidth && c > k_halfwidth && r < y - k_halfwidth && c < x - k_halfwidth)
				{
					i32 w = 0;
					for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
					{
						for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
						{
							new_pixel += in_img[r + i][(c + j) * n + l];
						}
					}
					new_pixel /= kernel_size;
				}

				out_img[r][c * n + l] = (u8)new_pixel;
			}
		}
	}

	free(in_img);
	free(out_img);
	return data_out;
}