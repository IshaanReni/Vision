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
    int other_axis_coord;
};

typedef struct pair{
	int x; 
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

int find_candidates_in_array(struct section* foundcandidates, int hue_array[], int length, int bottom_hue, int top_hue, int other_axis_coord){
	int min_bound = 3;
	int max_bound = 5;
    //struct section candidates[length]; //end symbol will be a NULL (don't have dynamic arrays)
    struct section new_section; //instantiate
    int candidate_index = 0;

    int counter = 1; //keeps track of how many of the same element we have found

    for (int i=0; i < length-1; i++){ //length -1 to prevent us from accessing too far in hue_array[i+1]
        if (counter == min_bound){ //object is large enough to be considered - add to array (first time we go over)
			printf("if 4  with i = %d \n", i);
            struct section new_section;
            new_section.hue = hue_array[i];
            new_section.start_coord = (i-min_bound+1);//+1 to correct starting from 0 earlier
			new_section.other_axis_coord = other_axis_coord;

            *(foundcandidates+candidate_index) = new_section; //found relevant section - add it to the list
        } 

		if (counter >= max_bound){
			printf("if 1 \n"); 
            counter = 1; //if the object is too wide we ignore it
        }
        else if(hue_array[i] == hue_array[i+1]){ //if we have found consecutive identical hues on pixels
            printf("if 2 with hue_array[%d] = %d and hue_array %d +1 = %d \n", i, hue_array[i], i, hue_array[i+1]);
			counter += 1;
			if ((i == length-2) && (counter >= min_bound) && (counter < max_bound)){// we are on second to last pixel
				candidate_index += 1; 
				counter  = 1;

			}
        }
        else if(counter >= min_bound){ //min bound of recognition
			
			printf("if 3 \n");
			(foundcandidates+candidate_index)->end_coord = i;
		
			//if (counter < max_bound){
				candidate_index += 1; //if we are above the maximum bound we don't want to increment the candidate index as we want that location to be overwritten
			//}
			counter = 1; 
	 		
            //if object is large enough to be considered and we encounter a new hue; we add it to the list (increment candidate index)
        }		
		else {
			counter = 1; 
			printf("resetting counter \n ");
		}
    }  
	struct section end_candidates_marker; //just something to mark end of candidates array (we are using array of maximal size but won't necessaraly fill it up)
	end_candidates_marker.end_coord = -1; //we use -1 (impossible coordiante and hue to mark end)
	end_candidates_marker.start_coord = -1;
	end_candidates_marker.hue = -1;
	end_candidates_marker.other_axis_coord = -1;

	*(foundcandidates+candidate_index) = end_candidates_marker; //adding final element to array
	return candidate_index; //return number of candidtates found
}

void gridify(int width, int height, int* hue_array,  struct section* found_candidates_x, struct section* found_candidates_y ){
	/*
	input = image width, image height, input array(from jox) 
	output = output all candidates in a single array, 
	split input array into rows or scan row by row and run the find candidates function on them. 
	then store the candidates as you go row by row.
	do the same for the y coords
	send 2 arrays back to scott
	*/
	
	int x_line[width];
	found_candidates_x = (struct section*) malloc ( (width) * sizeof(struct section));

	int old_numb_cand_found = 0;
	for (int row = 0; row < height; row++){ //iterating by row
		for (int column=0; column < width; column++){ //iterating through each element one by one and adding each element to x_line
			x_line[column] = *(hue_array+row*width+column);
		}
		//we now have a complete row to operate on
		struct section *candidatesforx; //internal array of candidates for this y (row)
		candidatesforx = (struct section*) malloc ( (width) * sizeof(struct section));
		int numb_new_cand_found = find_candidates_in_array(candidatesforx, x_line, width, 0, 0, row);

		int i = 0;
		while(i<width && (candidatesforx + i)->hue!=-1 && (i < numb_new_cand_found) ){ //checks that we are not counting the end_candidate as an actual candidate
			*(found_candidates_x + old_numb_cand_found + i) = *(candidatesforx + i); //add a found x candidate from found_candidates to the array found_candidates_x as long as it isn't the end_candidate
			i++;
		}
		old_numb_cand_found += numb_new_cand_found;
	}
	

	int y_line[height];
	found_candidates_y = (struct section*) malloc ( (height) * sizeof(struct section));

	old_numb_cand_found = 0;
	for (int column = 0; column < width; column++){ //iterating by row
		for (int row=0; row < height; row++){ //iterating through each element one by one and adding each element to x_line
			y_line[row] = *(hue_array+row*width+column);
		}
		//we now have a complete row to operate on
		struct section *candidatesfory; //internal array of candidates for this y (row)
		candidatesfory = (struct section*) malloc ( (height) * sizeof(struct section));
		int numb_new_cand_found = find_candidates_in_array(candidatesfory, x_line, width, 0, 0, height);

		int i = 0;
		while(i<width && (candidatesfory + i)->hue!=-1 && (i < numb_new_cand_found) ){ //checks that we are not counting the end_candidate as an actual candidate
			*(found_candidates_y + old_numb_cand_found + i) = *(candidatesfory + i); //add a found x candidate from found_candidates to the array found_candidates_x as long as it isn't the end_candidate
			i++;
		}
		old_numb_cand_found += numb_new_cand_found;
	}
	

}

void find_intersecting_sections(struct pair* matches, int* matches_index_ptr, struct section* all_x_candidates, int all_x_candidates_size, struct section* all_y_candidates, int all_y_candidates_size)
{
	*matches_index_ptr = 0; //NB : this also acts as a size marker for matches at the end

	matches = (struct pair*) malloc ( (fmax(all_x_candidates_size, all_y_candidates_size)) * sizeof(struct pair));
	printf(" DEBUG ----- GOT HERE \n \n");
	for(int i=0; i<all_x_candidates_size; i++){
		while ((all_x_candidates+i)->hue != -1){
			for(int j=0; j<all_y_candidates_size; j++){
				if(((all_x_candidates+i)->other_axis_coord >= (all_y_candidates+j)->start_coord) && ((all_x_candidates+i)->other_axis_coord <= (all_y_candidates+j)->end_coord)){
					if(((all_y_candidates+j)->other_axis_coord >= (all_x_candidates+i)->start_coord) && ((all_y_candidates+j)->other_axis_coord <= (all_x_candidates+i)->end_coord)){
						if( ((all_x_candidates+i)->hue == (all_y_candidates+j)->hue)){
							//if sections line up and are not end markers- we have a point that we want to add to the return array
							struct pair new_match;
							new_match.x = all_y_candidates->other_axis_coord;
							new_match.y = all_x_candidates->other_axis_coord;
							*(matches + *matches_index_ptr) = new_match; 
							*matches_index_ptr += 1;
							if(new_match.x != 0){
								printf("DEBUG new_match->x = %d new_match->y = %d \n \n", new_match.x, new_match.y);

							}
							
						} 
					}
				}
			}
		}
	}
	//add an end marker 
	struct pair end_marker; 
	end_marker.x = -1; 
	end_marker.y = -1;
	*(matches + *matches_index_ptr) = end_marker; 
}



int main()
{
	//x axis work
	 int x_line_size = 4;
	// int x_line[15] = {1,1,1,3,3,3,4,4,4,4,4,4,4,5,5};
	struct section *found_candidates_x;
	found_candidates_x = (struct section*) malloc ( (x_line_size) * sizeof(struct section));
	// find_candidates_in_array(found_candidates_x, x_line, x_line_size, 0, 0, 0);

	

	int y_line_size = 4;
	// int y_line[12] = {1,1,1,0,1,2,2,2,3,2,1,1};
	struct section *found_candidates_y;
	found_candidates_y = (struct section*) malloc ( (y_line_size) * sizeof(struct section));
	// find_candidates_in_array(found_candidates_y, y_line, y_line_size, 0, 0, 0);

	
	
	int arrayy[16] = {1,1,2,3,4,5,6,6,6,7,8,9,10,10,10,10}; 

	gridify(4, 4, arrayy, found_candidates_x, found_candidates_y);

	printf(" done with finding candidates \n \n");

	
	struct pair* matches; 
	int* result_size_ptr;
	printf("break1 \n");
	result_size_ptr = (int*) malloc(sizeof(int));

	printf("break2 \n");

	printf("DEBUG : found_candidates_x->hue = %d \n", found_candidates_x->hue);
	
	find_intersecting_sections(matches,result_size_ptr,found_candidates_x, 4, found_candidates_y, 4);
	
	printf("break3 \n");
	  





	//test codes for thresholding

	/*
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
	//expected result
	 1, 0, 1
	 -1, -1, -1
	 Unallocated
	 ...



	

	stbi_write_png("result2.png", x, y, n, new_data, x * n * sizeof(uint8_t));
	*/

	//int[]
}