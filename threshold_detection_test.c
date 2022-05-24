#include <stdint.h>
#include <math.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"


float wrapparound(float f){
    while (f < 0){
        f += 360;
    }
    return f; 
}

uint8_t rgb_to_hsv(unsigned char* redpointer, unsigned char* greenpointer, unsigned char* bluepointer)
{
    //casting into int 
    float r,g,b; 
    r = ((float) *redpointer)/255;
    g = ((float) *greenpointer)/255;
    b = ((float) *bluepointer)/255;

    float max = fmax(fmax(r,g), b);
    float min = fmin(fmin(r,g),b);
    float delta = abs(max-min); 
    float h,s,v,c; 
    //calculating H
    
    if (delta != 0){
        if (max == r){   
            h = wrapparound(360.0*((float)(g-b))/delta); 
        }
        else if (max == g){
            h = wrapparound(360.0*((float)(b-r))/delta); 
            // h = abs(60*((b-r)/delta + 2.0));
            //printf("%f \n", h);
            // printf("g max the value of h is %f, %i, %i\n", h, max, delta);
        }
        else if (max == b){
            h = wrapparound(360.0*((float)(r-g))/delta); 
            // h = 1.0*(abs(r-g)/delta + 4.0); 
            // printf("b max the value of h is %f, %i, %i\n", h, max, delta);
        }
        else{
            printf("zeroed\n");
            h=0;
        } 


        printf("h = %f \n", h);

         
    }
    
    //calculating staturation
    if (max == 0){
        s = 0; 
    }
    else s = delta/max; 
    // v is just value
    v = max; 
    return (uint8_t) h; //hue between 0 and 360°
}

void threshold(unsigned char* redpointer, unsigned char* greenpointer, unsigned char* bluepointer)
{
    uint8_t hue = rgb_to_hsv(redpointer, greenpointer, bluepointer);
    //printf("printing h %f", h);
    if ((0 <= hue) && (hue < 60)){
        *redpointer= 255;
        *greenpointer = 85; 
        *bluepointer= 0;
    }
    else if ((60 <= hue) && (hue < 120)){
        *redpointer= 128;
        *greenpointer = 255; 
        *bluepointer= 0;
        printf("green \n");
    }
    else if ((120 <= hue) && (hue < 180)){
        *redpointer= 0;
        *greenpointer = 255; 
        *bluepointer= 128;
    }
    else if ((180 <= hue) && (hue < 240)){
        *redpointer= 0;
        *greenpointer = 128; 
        *bluepointer= 255;
    }
    else if ((240 <= hue) && (hue < 300)){
        *redpointer= 128;
        *greenpointer = 0; 
        *bluepointer= 255;
    }
    else if ((300 <= hue) && (hue < 360)){
        *redpointer= 255;
        *greenpointer = 0; 
        *bluepointer= 128;
        printf("here \n");
    }
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