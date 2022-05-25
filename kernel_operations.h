#ifndef KERNEL_OPERATIONS_H
#define KERNEL_OPERATIONS_H

#include "platform.h"
#include <stdio.h>
#include <stdlib.h>

u8 *kernel_smooth(u8 *data_in, i32 x, i32 y, i32 n, i32 k_halfwidth);
#endif