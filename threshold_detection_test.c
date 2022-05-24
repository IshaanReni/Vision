#include <stdint.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_writer.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
void threshold(unsigned char* redpointer, unsigned char* greenpointer, unsigned char* bluepointer)
{
    if(*redpointer <= 170){
        *redpointer = 255;
        printf("max red \n");
    }
    else *redpointer = 0; 
    if(*bluepointer >= 170){
        *bluepointer = 255;
        printf("max green \n");
    }
    else *bluepointer = 0; 
    if(*greenpointer >= 170){
        *greenpointer = 255;
        printf("max blue \n ");
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