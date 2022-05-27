#include "kernel_operations.h"

void circle_hough_transform(u8 **in_img, u8 **out_img, i32 x, i32 y)
{
	u8 *t_img = (u8 *)malloc(sizeof(u8) * x * y);
	u8 **t_img_arr = (u8 **)malloc(y * sizeof(u8 *));
	u8 *p = t_img;

	for (u32 r = 0; r < y; r++)
	{
		t_img_arr[r] = p;
		p += x;
	}

	for (i32 radius = 40; radius < 100; radius++)
	{
		memset(t_img, 0, sizeof(u8) * x * y);
		for (i32 r = 0; r < y; r++)
		{
			for (i32 c = 0; c < x; c++)
			{
				if (in_img[r][c] > 10 && r > radius && c > radius && r < y - radius && c < x - radius)
				{
					i32 a, b;
					for (i32 t = 0; t < 360; t++)
					{
						a = c - radius * cos(t * M_PI / 180);
						b = r - radius * sin(t * M_PI / 180);
						t_img_arr[b][a] += 1;
						// out_img[b][a] += 1;
					}

					// printf("a: %u, b: %u, val %u \n", a, b, out_img[a][b]);
				}
			}
		}
		i32 max_pixel_val = 0;
		i32 max_r = 0, max_c = 0;
		for (i32 r = 0; r < y; r++)
		{
			for (i32 c = 0; c < x; c++)
			{

				if (t_img_arr[r][c] > max_pixel_val)
				{
					max_pixel_val = t_img_arr[r][c];
					max_r = r;
					max_c = c;
				}
			}
		}
		printf("max: %i, r: %i, c: %i \n", max_pixel_val, max_r, max_c);
		out_img[max_r][max_c] += 100;
	}
	free(t_img);
	free(t_img_arr);
}

// Only operates on gray scale data
void solid_kernel(u8 **in_img, u8 **out_img, i32 x, i32 y)
{
	// https://en.wikipedia.org/wiki/Sobel_operator
	/*
	i32 kernel[9][9] = {
		{1, 1, 1},
		{1, 1, 1},
		{1, 1, 1},
	};
	*/

	i32 k_halfwidth = 15;
	i32 k_tot_size = (2 * k_halfwidth + 1) * (2 * k_halfwidth + 1);

	for (i32 r = 0; r < y; r++)
	{
		for (i32 c = 0; c < x; c++)
		{

			i32 p = 0;
			// make sure that the pixel being processed in not one of the pixels
			// on the edge of the image
			if (r > k_halfwidth && c > k_halfwidth && r < y - k_halfwidth && c < x - k_halfwidth)
			{
				for (i32 i = -k_halfwidth; i <= k_halfwidth; i++)
				{
					for (i32 j = -k_halfwidth; j <= k_halfwidth; j++)
					{
						p += (in_img[r + i][c + j] > 0);
					}
				}

				p /= k_tot_size - 10;
				p = (p > 0) * 100;
			}

			out_img[r][c] = p;
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

void gaussian_blur_kernel(u8 **in_img, u8 **out_img, i32 x, i32 y, i32 n, u32 k)
{
	// Generalised formula at https://en.wikipedia.org/wiki/Canny_edge_detector
	i32 k_width = 2 * k + 1;

	i32 *bin_coeff = (i32 *)malloc(k_width * sizeof(i32));
	bin_coeff[0] = 1;
	printf("Gaussian Filter Applied: \n");
	for (i32 j = 1; j < k_width; j++)
	{
		bin_coeff[j] = bin_coeff[j - 1] * (k_width - j) / j;
	}

	i32 gaus_coef = (1 << (k_width - 1)) * (1 << (k_width - 1));
	printf("%i \n", gaus_coef);
	i32 *gaus_kernel = (i32 *)malloc(k_width * k_width * sizeof(i32));

	for (i32 i = 0; i < k_width; i++)
	{
		for (i32 j = 0; j < k_width; j++)
		{
			gaus_kernel[i * k_width + j] = bin_coeff[i] * bin_coeff[j];
			printf("%i \t", gaus_kernel[i * k_width + j]);
		}
		printf("\n");
	}

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
				if (r > k && c > k && r < y - k && c < x - k)
				{
					for (u32 i = 0; i < k_width; i++)
					{
						for (u32 j = 0; j < k_width; j++)
						{
							new_pixel += gaus_kernel[i * k_width + j] * in_img[r - k + i][(c - k + j) * n + l];
						}
					}
					new_pixel /= gaus_coef;
				}
				out_img[r][c * n + l] = (u8)new_pixel;
			}
		}
	}

	free(bin_coeff);
	free(gaus_kernel);
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
		gaussian_blur_kernel(in_img, out_img, x, y, n, 1);
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
		circle_hough_transform(in_img, out_img, x, y);
	}
	break;
	case Solid:
	{
		solid_kernel(in_img, out_img, x, y);
	}
	}

	memcpy(data, data_out, x * y * n * sizeof(u8));

	free(in_img);
	free(out_img);
	free(data_out);
}