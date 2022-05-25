#include <stdint.h>
#include <math.h>
#include "kernel_operations.h"
#include "platform.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

typedef struct section{
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
		if ((r>=g) && (r>=b))
		{
            if (g >= b){ //orange
                h = 60.0*(g-b)/(r-b);
            }
            else { //rose
                h = 60.0*(6.0-(b-g)/(r-g));
            }
		}
		else if ((g>=r) && (g>=b))
		{
            if (r >= b){  //chartreuse
                h = 60.0*(2.0-(r-b)/(g-b));
            }
            else { //spring green
                h = 60.0*(2.0+(b-r)/(g-r));
            }
			// printf("%f \n", h);
			// printf("g max the value of h is %f, %i, %i\n", h, max, delta);
		}
		else if ((b>=r) && (b>=g))
		{
            if(g>r){ //azure
                h = 60.0*(4.0-(g-r)/(b-r));
            }
            else {//violet
                h = 60.0*(4.0+(r-g)/r-g);
            }

			// h = 1.0*(abs(r-g)/delta + 4.0);
			// printf("b max the value of h is %f, %i, %i\n", h, max, delta);
		}
		else
		{
			printf("zeroed\n");
			h = 0;
		}
        if (h < 0){
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
        //apple green
		*redpointer = 128;
		*greenpointer = 255;
		*bluepointer = 0;
	}
	else if ((120 <= hue) && (hue < 150))
	{
        //pale green
		*redpointer = 0;
		*greenpointer = 255;
		*bluepointer = 128;
	}
	else if ((150 <= hue) && (hue < 195))
	{
        printf("option 1 \n");
        //background atm
		*redpointer = 0;
		*greenpointer = 128;
		*bluepointer = 255;
	}
	else if ((195 <= hue) && (hue < 240))
	{
        //printf("option 2 \n");
		*redpointer = 128;
		*greenpointer = 0;
		*bluepointer = 255;
	}
	else if ((240 <= hue) && (hue < 300))
	{
		*redpointer = 255;
		*greenpointer = 0;
		*bluepointer = 128;
		//printf("here \n");
	}
    else
	{
		*redpointer = 25;
		*greenpointer = 212;
		*bluepointer = 128;
		//printf("here \n");
	}

    return hue;
}


int* find_candidates_in_array( int* hue_array, int length, int bottom_hue, int top_hue, int y){
    struct section candidates[length]; //end symbol will be an X (don't have dynamic arrays)
    
    int candidate_index = 0;

    int counter = 0; //keeps track of how many of the same element we have found

    for (int i=0; i < length; i++){
        if (counter == 100){ 
            counter = 0; //if the object is too wide we ignore it
        }

        if(hue_array[i] == hue_array[i+1]){ //if we have found consecutive identical hues on pixels
            counter += 1;
        }
        else if(counter >= 30){
            //if object is large enough to be considered and we encounter a new hue; we add it to the list (incrmeentne candidate index)

        }
        if (counter == 30){ //object is large enough to be considered
            struct section new_section;
            new_section.hue = hue_array[i];
            new_section.start_coord = i;

            candidate_found_at[candidate_found_index] = i;
        }

        
    }
    

}

int main()
{

	int x, y, n;
	unsigned char *data = stbi_load("p.png", &x, &y, &n, 0); // pointer to pixel data

    int Hue_Matrix [x][y];

	u8 *new_data = kernel_smooth(data, x, y, n, 4);

	
	unsigned char *redpointer = new_data;
	unsigned char *greenpointer = new_data + 1;
	unsigned char *bluepointer = new_data + 2;

	for (int i = 0; i < x; i++)
	{
        for (int j = 0; j<y; j++){
            Hue_Matrix[i][j] = threshold(redpointer, greenpointer, bluepointer);
		    redpointer += n;
		    greenpointer += n;
		    bluepointer += n;
        }


		//printf("r = %d, g = %d, b = %d \n", *redpointer,*greenpointer,*bluepointer);
        //printf("\n ");
        
	}
	

	stbi_write_png("result2.png", x, y, n, new_data, x * n * sizeof(uint8_t));
}