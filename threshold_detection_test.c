#include <stdint.h>
#include <math.h>
#include "kernel_operations.h"
#include "color_operations.h"
#include "platform.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

typedef struct section
{
	int hue;
	int start_coord;
	int end_coord;
	int y;
};

float wrapparound(float f)
{
	while (f < 0)
	{
		f += 360;
		printf("wrapping around \n");
	}
	return f;
}

int rgb_to_hsv(unsigned char *redpointer, unsigned char *greenpointer, unsigned char *bluepointer)
{
	// casting into int
	float r, g, b;
	r = ((float)*redpointer) / 255;
	g = ((float)*greenpointer) / 255;
	b = ((float)*bluepointer) / 255;

	float max = fmax(fmax(r, g), b);
	float min = fmin(fmin(r, g), b);
	float delta = abs(max - min);
	float h, s, v, c;
	// calculating H

	if (delta != 0)
	{
		if ((r >= g) && (r >= b))
		{
			if (g >= b)
			{ // orange
				h = 60.0 * (g - b) / (r - b);
			}
			else
			{ // rose
				h = 60.0 * (6.0 - (b - g) / (r - g));
			}
		}
		else if ((g >= r) && (g >= b))
		{
			if (r >= b)
			{ // chartreuse
				h = 60.0 * (2.0 - (r - b) / (g - b));
			}
			else
			{ // spring green
				h = 60.0 * (2.0 + (b - r) / (g - r));
			}
			// printf("%f \n", h);
			// printf("g max the value of h is %f, %i, %i\n", h, max, delta);
		}
		else if ((b >= r) && (b >= g))
		{
			if (g > r)
			{ // azure
				h = 60.0 * (4.0 - (g - r) / (b - r));
			}
			else
			{ // violet
				h = 60.0 * (4.0 + (r - g) / r - g);
			}

			// h = 1.0*(abs(r-g)/delta + 4.0);
			// printf("b max the value of h is %f, %i, %i\n", h, max, delta);
		}
		else
		{
			printf("zeroed\n");
			h = 0;
		}
		if (h < 0)
		{
			printf("h = %f \n", h);
		}
	}

	// calculating staturation
	if (max == 0)
	{
		s = 0;
	}
	else
		s = delta / max;
	// v is just value
	v = max;
	return (int)h; // hue between 0 and 360°
}

int threshold(unsigned char *redpointer, unsigned char *greenpointer, unsigned char *bluepointer)
{
	uint8_t hue = rgb_to_hsv(redpointer, greenpointer, bluepointer);
	// printf("printing h %f", h);
	if ((0 <= hue) && (hue < 30))
	{
		*redpointer = 255;
		*greenpointer = 85;
		*bluepointer = 0;
	}
	else if ((30 <= hue) && (hue < 60))
	{
		*redpointer = 255;
		*greenpointer = 255;
		*bluepointer = 255;
	}
	else if ((60 <= hue) && (hue < 90))
	{
		// apple green
		*redpointer = 128;
		*greenpointer = 255;
		*bluepointer = 0;
	}
	else if ((120 <= hue) && (hue < 150))
	{
		// pale green
		*redpointer = 0;
		*greenpointer = 255;
		*bluepointer = 128;
	}
	else if ((150 <= hue) && (hue < 195))
	{
		printf("option 1 \n");
		// background atm
		*redpointer = 0;
		*greenpointer = 128;
		*bluepointer = 255;
	}
	else if ((195 <= hue) && (hue < 240))
	{
		// printf("option 2 \n");
		*redpointer = 128;
		*greenpointer = 0;
		*bluepointer = 255;
	}
	else if ((240 <= hue) && (hue < 300))
	{
		*redpointer = 255;
		*greenpointer = 0;
		*bluepointer = 128;
		// printf("here \n");
	}
	else
	{
		*redpointer = 25;
		*greenpointer = 212;
		*bluepointer = 128;
		// printf("here \n");
	}

	return hue;
}

int *find_candidates_in_array(int *hue_array, int length, int bottom_hue, int top_hue, int y)
{
	struct section candidates[length]; // end symbol will be an X (don't have dynamic arrays)

	void find_candidates_in_array(struct section * foundcandidates, int hue_array[], int length, int bottom_hue, int top_hue, int y)
	{
		int min_bound = 3;
		int max_bound = 5;
		// struct section candidates[length]; //end symbol will be a NULL (don't have dynamic arrays)
		struct section new_section; // instantiate
		int candidate_index = 0;

		int counter = 1; // keeps track of how many of the same element we have found

		for (int i = 0; i < length - 1; i++)
		{ // length -1 to prevent us from accessing too far in hue_array[i+1]
			if (counter == min_bound)
			{ // object is large enough to be considered - add to array (first time we go over)
				printf("if 4  with i = %d \n", i);
				struct section new_section;
				new_section.hue = hue_array[i];
				new_section.start_coord = (i - min_bound + 1); //+1 to correct starting from 0 earlier

				*(foundcandidates + candidate_index) = new_section; // found relevant section - add it to the list
			}

			if (counter >= max_bound)
			{
				printf("if 1 \n");
				counter = 1; // if the object is too wide we ignore it
			}
			else if (hue_array[i] == hue_array[i + 1])
			{ // if we have found consecutive identical hues on pixels
				printf("if 2 with hue_array[%d] = %d and hue_array %d +1 = %d \n", i, hue_array[i], i, hue_array[i + 1]);
				counter += 1;
				if ((i == length - 2) && (counter >= min_bound) && (counter < max_bound))
				{ // we are on second to last pixel
					candidate_index += 1;
					counter = 1;
				}
			}
			else if (counter >= min_bound)
			{ // min bound of recognition

				printf("if 3 \n");
				(foundcandidates + candidate_index)->end_coord = i;

				// if (counter < max_bound){
				candidate_index += 1; // if we are above the maximum bound we don't want to increment the candidate index as we want that location to be overwritten
				//}
				counter = 1;

				// if object is large enough to be considered and we encounter a new hue; we add it to the list (increment candidate index)
			}
			else
			{
				counter = 1;
				printf("resetting counter \n ");
			}
		}
		struct section end_candidates_marker; // just something to mark end of candidates array (we are using array of maximal size but won't necessaraly fill it up)
		end_candidates_marker.end_coord = -1; // we use -1 (impossible coordiante and hue to mark end)
		end_candidates_marker.start_coord = -1;
		end_candidates_marker.hue = -1;
		end_candidates_marker.y = -1;

		*(foundcandidates + candidate_index) = end_candidates_marker; // adding final element to array

		candidate_found_at[candidate_found_index] = i;
	}
}
}
int main()
{
	// code to test find candidates
	int line_size = 36;

	int line[36] = {1, 1, 2, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 5, 5, 6, 6, 6, 6, 7, 8, 8, 123, 123, 3, 4, 5, 2, 1, 2, 3, 4, 44, 44, 44, 44};

	struct section *found_candidates;

	found_candidates = (struct section *)malloc((line_size) * sizeof(struct section));
	find_candidates_in_array(found_candidates, line, line_size, 0, 0, 0);
	int i = 0;
	while ((i < line_size && (found_candidates + i)->hue != -1))
	{

		printf("hue = %d \n", (found_candidates + i)->hue);
		printf("start_coord = %d \n", (found_candidates + i)->start_coord);
		printf("end_coord = %d \n", (found_candidates + i)->end_coord);
		printf("y = %d \n", (found_candidates + i)->y);
		printf("\n");

		// printhue = f("he = %d, start = %d, e->d = %d", found_candidates[i].hue, found_candidates[i].start_coord, found_candidates[i].end_coord);
		//	printf("\n");
		i++;
	}

	/*
	int x, y, n;
	unsigned char *data = stbi_load("images/alien3.png", &x, &y, &n, 0); // pointer to pixel data
	i32 bin_count = 15;
	u8 *hue_pixels = rgb_to_hue(data, x, y, n, bin_count);

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

	/*
	unsigned char *data = stbi_load("images/red_downscaled.png", &x, &y, &n, 1); // pointer to pixel data
	n = 1;
	kernel_operation(data, x, y, n, GaussianBlur);
	stbi_write_png("images/results/gaus.png", x, y, n, data, x * n * sizeof(uint8_t));
	kernel_operation(data, x, y, n, Sobel);
	stbi_write_png("images/results/sobel.png", x, y, n, data, x * n * sizeof(uint8_t));
	kernel_operation(data, x, y, n, Hough);
	stbi_write_png("images/results/hough.png", x, y, n, data, x * n * sizeof(uint8_t));

	*/
	//   kernel_operation(data, x, y, n, GaussianBlur);

	/*
	int Hue_Matrix[x][y];

	u8 *new_data = kernel_smooth(data, x, y, n, 4);

	unsigned char *redpointer = new_data;
	unsigned char *greenpointer = new_data + 1;
	unsigned char *bluepointer = new_data + 2;

	for (int i = 0; i < x; i++)
	{
		for (int j = 0; j < y; j++)
		{
			Hue_Matrix[i][j] = threshold(redpointer, greenpointer, bluepointer);
			redpointer += n;
			greenpointer += n;
			bluepointer += n;
		}

		// printf("r = %d, g = %d, b = %d \n", *redpointer,*greenpointer,*bluepointer);
		// printf("\n ");
	}
	//expected result
	 1, 0, 1
	 -1, -1, -1
	 Unallocated
	 ...





	stbi_write_png("result2.png", x, y, n, new_data, x * n * sizeof(uint8_t));
	*/

	// int[]
}