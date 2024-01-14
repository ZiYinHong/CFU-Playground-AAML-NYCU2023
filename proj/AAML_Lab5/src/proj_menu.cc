/*
 * Copyright 2021 The CFU-Playground Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "proj_menu.h"

#include <stdio.h>

#include "cfu.h"
#include "menu.h"

namespace {

// Template Fn

void do_hello_world(void) { puts("Hello, World!!!\n"); }

// Test template instruction
void do_grid_cfu_op0(void) {
  puts("\nExercise CFU Op0\n");
  printf("a   b-->");
  for (int b = 0; b < 6; b++) {
    printf("%8d", b);
  }
  puts("\n-------------------------------------------------------");
  for (int a = 0; a < 6; a++) {
    printf("%-8d", a);
    for (int b = 0; b < 6; b++) {
      int cfu = cfu_op0(0, a, b);  //R type add
      printf("%8d", cfu);
    }
    puts("");
  }
}

// send for element of matrix to cfu
// void do_simple_matrix_multi(void) {
//   puts("\nExercise CFU Op0\n");
//   int a = 1, b = 2;
//   printf("a = %d, b = %d");

//   int cfu = cfu_op0(0, a, b);  //R type add
  
//   printf("cfu = %d", cfu);
// }

// Packs 4 bytes into one 32 bit value.
constexpr uint32_t pack_vals(int8_t w, int8_t x, int8_t y, int8_t z) {
  return ((unsigned int8_t)w << 24) | ((unsigned int8_t)x << 16) | ((unsigned int8_t)y << 8) | z;
}

void transpose(int8_t* A, int8_t* B, int K, int M) 
{ 
    int i, j; 
    for (i = 0; i < K; i++) 
        for (j = 0; j < M; j++) 
            B[i*M+j] = *(A+j*K+i); 
} 

void do_simple_matrix_multi(void) {
  // int8_t input_data_pre[8][300] = {{1, 1, 1, 1, 1}, {2, 2, 2, 2, 2},{3, 3, 3, 3, 3}, {4, 4, 4, 4, 4}, {5, 5, 5, 5, 5}, {6,6,6,6,6},{7,7,7,7,7},{8,8,8,8,8}};

  int8_t input_data_pre[8][300] = {{-1, -1, -1, -1, -1}, {-2, -2, -2, -2, -2},{-3, -3, -3, -3, -3}, {-4, -4, -4, -4, -4}, {-5, -5, -5, -5, -5}, {-6,-6,-6,-6,-6},{-7,-7,-7,-7,-7},{-8,-8,-8,-8,-8}};
  int8_t filter_data[300][8] = {{-1,-1,-1,-1,-1,-1,-1,-1}, {-1,-1,-1,-1,-1,-1,-1,-1},{-1,-1,-1,-1,-1,-1,-1,-1}, {-1,-1,-1,-1,-1,-1,-1,-1},{-1,-1,-1,-1,-1,-1,-1,-1}};
  // int8_t filter_data[300][8] = {{1,1,1,1,1,1,1,1}, {1,1,1,1,1,1,1,1},{1,1,1,1,1,1,1,1}, {1,1,1,1,1,1,1,1},{1,1,1,1,1,1,1,1}};


  //start doing matrix mul
  int8_t input_data[300][8]= {0};//; 
  int M = 8, K = 300;
  transpose(input_data_pre[0], input_data[0], K, M); 

  //===============================================
  //start matrix cal 4*K
  printf("===========start matrix cal 4*K first time=======\n");
  //send K, M, N
  cfu_op0(0, 0, 0);  
  int32_t cfu;
  cfu_op0(1, K, 4);  


  //send A, B
  for(int i = 0; i < K; i++){
    for (int j = 0; j < 4; j++){
      cfu_op0(2, input_data[i][j], filter_data[i][j]);  
      // printf("%d, %d\n", input_data[i][j], filter_data[i][j]);
    }
  }
  printf("after send A, B\n");

  printf("set in_valid = 1\n");
  cfu_op0(3, 0, 0);  

  while(cfu_op0(4, 0, 0)==1);


  for(int i = 0; i < 16; i++){
    cfu = cfu_op0(5, 0, 0);  
    printf("after send A, B, C i = %d, cfu = %ld\n", i, cfu);
  }


  cfu_op0(0, 0, 0);  
  printf("after matrix 1st\n");
  //===============================================
  //start matrix cal 4*K
  printf("===========start matrix cal 4*K second time========\n");
  //send K, M, N
  cfu_op0(1, K, 4);  


  //send A, B, C 
  for(int i = 0; i < K; i++){
    for (int j = 4; j < 8; j++){
      cfu_op0(2, input_data[i][j], filter_data[i][j]);  
      // printf("%d, %d\n", input_data[i][j], filter_data[i][j]);
    }
  }
  printf("after send A, B\n");


  printf("set in_valid = 1\n");
  cfu_op0(3, 0, 0);  

  while(cfu_op0(4, 0, 0)==1);


  for(int i = 0; i < 16; i++){
    cfu = cfu_op0(5, 0, 0);  
    printf("after send A, B, C i = %d, cfu = %ld\n", i, cfu);
  }

  return;
}



// Test template instruction
void do_exercise_cfu_op0(void) {
  puts("\nExercise CFU Op0\n");
  int count = 0;
  for (int a = -0x71234567; a < 0x68000000; a += 0x10012345) {
    for (int b = -0x7edcba98; b < 0x68000000; b += 0x10770077) {
      int cfu = cfu_op0(0, a, b);
      printf("a: %08x b:%08x cfu=%08x\n", a, b, cfu);
      if (cfu != a) {
        printf("\n***FAIL\n");
        return;
      }
      count++;
    }
  }
  printf("Performed %d comparisons", count);
}

struct Menu MENU = {
    "Project Menu",
    "project",
    {
        MENU_ITEM('0', "exercise cfu op0", do_exercise_cfu_op0),
        MENU_ITEM('g', "grid cfu op0", do_grid_cfu_op0),
        MENU_ITEM('h', "say Hello", do_hello_world),
        MENU_ITEM('s', "do_simple_matrix_multi", do_simple_matrix_multi),
        MENU_END,
    },
};

};  // anonymous namespace

extern "C" void do_proj_menu() { menu_run(&MENU); }
