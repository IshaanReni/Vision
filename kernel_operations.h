#ifndef KERNEL_OPERATIONS_H
#define KERNEL_OPERATIONS_H

#include "platform.h"
#include <stdio.h>
#include <stdlib.h>

#define _USE_MATH_DEFINES // for C
#include <math.h>
#include <cstring>

typedef enum
{
	BoxBlur,
	GaussianBlur,
	Sobel,
	Hough,
} KernelOperation;

void kernel_operation(u8 *data, i32 x, i32 y, i32 n, KernelOperation op);
#endif