#include "kernel_operations.h"

void circle_hough_transform(u8 **in_img, u8 **out_img, i32 x, i32 y, i32 radius_pixels)
{
	for (i32 radius = 50; radius < 51; radius++)
	{
		for (i32 r = 0; r < y; r++)
		{
			for (i32 c = 0; c < x; c++)
			{
				if (in_img[r][c] > 10 && r > radius_pixels && c > radius_pixels && r < y - radius_pixels && c < x - radius_pixels)
				{
					i32 a, b;
					for (i32 t = 0; t < 360; t++)
					{
						a = c - radius_pixels * cos(t * M_PI / 180);
						b = r - radius_pixels * sin(t * M_PI / 180);
						out_img[a][b] += 1;
					}

					// printf("a: %u, b: %u, val %u \n", a, b, out_img[a][b]);
				}
			}
		}
	}
}

// Only operates on gray scale data
void sobel_kernel(u8 **in_img, u8 **out_img, i32 x, i32 y)
{
	// https://en.wikipedia.org/wiki/Sobel_operator
	i32 k_x[3][3] = {
		{1, 0, -1},
		{2, 0, -2},
		{1, 0, -1},
	};

	i32 k_y[3][3] = {
		{1, 2, 1},
		{0, 0, 0},
		{-1, -2, -1},
	};
	i32 k_halfwidth = 1;

	for (i32 r = 0; r < y; r++)
	{
		for (i32 c = 0; c < x; c++)
		{

			// make sure that the pixel being processed in not one of the pixels
			// on the edge of the image
			i32 g_x = 0;
			if (r > k_halfwidth && c > k_halfwidth && r < y - k_halfwidth && c < x - k_halfwidth)
			{
				for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
				{
					for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
					{
						g_x += k_x[i + k_halfwidth][j + k_halfwidth] * in_img[r + i][c + j];
					}
				}
			}

			i32 g_y = 0;
			if (r > k_halfwidth && c > k_halfwidth && r < y - k_halfwidth && c < x - k_halfwidth)
			{
				for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
				{
					for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
					{
						g_y += k_y[i + k_halfwidth][j + k_halfwidth] * in_img[r + i][c + j];
					}
				}
			}

			out_img[r][c] = sqrt(g_x * g_x + g_y * g_y);

			if (out_img[r][c] < 150)
			{
				out_img[r][c] = 0;
			}
		}
	}
}

void gaussian_blur_kernel(u8 **in_img, u8 **out_img, i32 x, i32 y, i32 n)
{
	// Generalised formula at https://en.wikipedia.org/wiki/Canny_edge_detector
	i32 gaus_kernel[3][3] = {
		{1, 2, 1},
		{2, 4, 2},
		{1, 2, 1},
	};
	i32 k_halfwidth = 1;

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
					for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
					{
						for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
						{
							new_pixel += gaus_kernel[i + k_halfwidth][j + k_halfwidth] * in_img[r + i][(c + j) * n + l];
						}
					}
					new_pixel /= 16;
				}
				out_img[r][c * n + l] = (u8)new_pixel;
			}
		}
	}
}

void box_blur_kernel(u8 **in_img, u8 **out_img, i32 x, i32 y, i32 n, i32 k_halfwidth)
{
	i32 k_size = (2 * k_halfwidth + 1) * (2 * k_halfwidth + 1);
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
					for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
					{
						for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
						{
							new_pixel += in_img[r + i][(c + j) * n + l];
						}
					}
					new_pixel /= k_size;
				}
				out_img[r][c * n + l] = (u8)new_pixel;
			}
		}
	}
}

// data	: Pointer to raw image data
// x, y : Width in number of pixels
// n	: Number of channels (bytes) per pixels
// k_halfwidth : Half the width of the kernel minus the center
void kernel_operation(u8 *data, i32 x, i32 y, i32 n, KernelOperation op)
{
	u8 *data_in = (u8 *)malloc(x * y * n * sizeof(u8));
	memcpy(data_in, data, x * y * n * sizeof(u8));
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
	switch (op)
	{
	case BoxBlur:
	{
		box_blur_kernel(in_img, out_img, x, y, n, 2);
	}
	break;
	case GaussianBlur:
	{
		gaussian_blur_kernel(in_img, out_img, x, y, n);
	}
	break;
	case Sobel:
	{
		if (n == 1)
		{
			sobel_kernel(in_img, out_img, x, y);
		}
		else
		{
			printf("A Sobel Operation can only be performed on a grayscale image. Returning input image.\n");
		}
	}
	break;
	case Hough:
	{
		memset(data_out, 0, x * y);
		circle_hough_transform(in_img, out_img, x, y, 40);
	}
	break;
	}

	memcpy(data, data_out, x * y * n * sizeof(u8));

	free(in_img);
	free(out_img);
	free(data_out);
}