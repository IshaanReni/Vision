#include <stdint.h>
#include <math.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"



void rgb_to_hsv(unsigned char* redpointer, unsigned char* greenpointer, unsigned char* bluepointer)
{
    //casting into int 
    int r,g,b; 
    r = (int) *redpointer;
    g = (int) *greenpointer;
    b = (int) *bluepointer;
    int max = fmax(fmax(r,g), b);
    int min = fmin(fmin(r,g),b);
    int delta = abs(max-min); 
    float h,s,v; 
    //calculating H
    
    if (delta == 0) delta = 1;
    if (max == r){
        h = 60.0*(abs(g-b)/delta); 
        //printf("r max the value of h is %f, %i, %i\n", h, max, delta);
        
    }
    else if (max == g){
        h = 60.0*(abs(b-r)/delta + 2.0);
        printf("g max the value of h is %f, %i, %i\n", h, max, delta);
    }
    else if (max == b){
        h = 60.0*(abs(r-g)/delta + 4.0); 
        printf("b max the value of h is %f, %i, %i\n", h, max, delta);
    }
    else{
        printf("zeroed\n");
        h=0;
    } 
    //calculating staturation
    if (max == 0){
        s = 0; 
    }
    else s = delta/max; 
    // v is just value
    v = max; 
}

void threshold(unsigned char* redpointer, unsigned char* greenpointer, unsigned char* bluepointer)
{
    rgb_to_hsv(redpointer, greenpointer, bluepointer);
    if(*redpointer <= 128){
        *redpointer = 0;
        //printf("max red \n");
    }
    else *redpointer = 0; 
    if(*bluepointer >= 128){
        *bluepointer = 255;
        //printf("max green \n");
    }
    else *bluepointer = 0; 
    if(*greenpointer >= 128){
        *greenpointer = 0;
        //printf("max blue \n ");
    }
    else *greenpointer = 0; 
}
int main(){




    int x,y,n;
    unsigned char *data = stbi_load("alien.png", &x, &y, &n, 0); //pointer to pixel data


    unsigned char* redpointer = data; 
    unsigned char* greenpointer = data+1; 
    unsigned char* bluepointer = data+2; 

    for (int i=0; i< x*y; i++)
    {
        threshold(redpointer, greenpointer, bluepointer);
        redpointer += n; 
        greenpointer += n; 
        bluepointer += n;     

    }


    stbi_write_png("result2.png",x, y, n, data, x*n*sizeof(uint8_t)); 




}