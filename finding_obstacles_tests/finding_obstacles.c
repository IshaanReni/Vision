#include <stdio.h>

#define SIZEOFLINE 17
struct stripe {
  int start_coord;
  int end_coord;
}; 

void get_stripes(struct stripe* found_stripes, int* sobel_line, int* counter) //takes one-hot array and 
{
  *counter = 0; 
  for (int i=0; i<SIZEOFLINE; i++){
    if (sobel_line[i]==1){
      struct stripe new_elem;  

      int j = i +1; 
      for(; (j<SIZEOFLINE-1 && sobel_line[j] != 1); j++){
        //do nothing
      }
      if(j != SIZEOFLINE-1){
        new_elem.start_coord = i;
        new_elem.end_coord = j;
        *(found_stripes + (*counter)*sizeof(stripe))  = new_elem; 
        *counter += 1; 
      }     
    } 
    //return 1;
  }

  // -1 is the end of the array
  (found_stripes + *counter*sizeof(stripe))->start_coord = -1; 
  (found_stripes + *counter*sizeof(stripe))->end_coord = -1; 
}

void print_stripes(struct stripe* found_stripes){
  for(int i = 0; (i < SIZEOFLINE) && ((found_stripes + i*sizeof(stripe))->start_coord != -1); i++){
    printf("start : %d end : %d  \n", (found_stripes + i*sizeof(stripe))->start_coord, (found_stripes + i*sizeof(stripe))->end_coord);
  }
}

void get_width(struct stripe* found_stripes, int* fs_size, int* obs_start, int* obs_end){
  int current_min_coord = 0;
  int current_second_to_min_coord = 1;
  int tmp_distance = 0;
  int curr_min_width = SIZEOFLINE;
  int curr_second_to_min_width = SIZEOFLINE;
  printf("*fs_size = %d \n", *fs_size);
  for (int i=0; i < *fs_size; i++)
  {
    //currently just the minimum (narrowest stripe) is considered to be extremity (only works for one object)
    tmp_distance = (found_stripes+ i*sizeof(stripe))->end_coord - (found_stripes + i*sizeof(stripe))->start_coord;
    curr_min_width = (found_stripes+ current_min_coord*sizeof(stripe))->end_coord - (found_stripes + current_min_coord*sizeof(stripe))->start_coord;
    int curr_second_to_min_width = (found_stripes+ current_second_to_min_coord*sizeof(stripe))->end_coord - (found_stripes + current_second_to_min_coord*sizeof(stripe))->start_coord;
    printf("tmp_distance = %d, curr_min_width = %d \n", tmp_distance, curr_min_width);
    if(tmp_distance < curr_min_width){
      printf("entered if \n "); 
      current_min_coord = i; 
    }
    else if(tmp_distance <= curr_second_to_min_width){
      printf("entered second if with i = %d \n", i);
      printf("start coord %d, %d \n", (found_stripes + current_second_to_min_coord*sizeof(stripe))->start_coord, (found_stripes + current_second_to_min_coord*sizeof(stripe))->end_coord);
      
      current_second_to_min_coord = i;
    }
  }
  *obs_start = (found_stripes + current_min_coord*sizeof(stripe))->start_coord;
  *obs_end = (found_stripes + current_second_to_min_coord*sizeof(stripe))->end_coord;
}


int main(void) {
  struct stripe found_stripes[SIZEOFLINE];
  int sobel_line [SIZEOFLINE] = {0,1,0,1,0,0,1,0,0,0,1,0,0,1,0,1,0};
  int num_stripes = 0;
  get_stripes(found_stripes, sobel_line, &num_stripes);
  print_stripes(found_stripes);
  int obj_start, obj_end = 0; 
  get_width(found_stripes,&num_stripes,&obj_start, &obj_end);
  printf("obj_start %d, obj_end %d \n", obj_start, obj_end);
  return 0;
}