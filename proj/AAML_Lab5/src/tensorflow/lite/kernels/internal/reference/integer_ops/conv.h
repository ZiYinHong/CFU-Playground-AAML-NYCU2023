/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/
#ifndef TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_
#define TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_

#include <algorithm>
#include "playground_util/print_params.h"
#include "tensorflow/lite/kernels/internal/common.h"
#include "tensorflow/lite/kernels/internal/portable_tensor_utils.h"
#include "cfu.h"

#include "perf.h"
#include "models/my_cycles.h"
extern long long unsigned my_cycles;

int flag = 0;
namespace tflite {
namespace reference_integer_ops {


void im2col(const int8_t* input_data,const RuntimeShape& input_shape,const int input_height, const int input_width,const int input_depth,
     const int filter_height, const int filter_width, const int output_depth,const int stride_height, const int stride_width, 
     const int pad_width, const int pad_height, int8_t im2col_output[300][700]) 
{   

    int output_height = (input_height + 2*pad_height - filter_height) / stride_height + 1;
    int output_width = (input_width + 2*pad_width - filter_width) / stride_width + 1;

    int output_row = input_depth * filter_height * filter_width;
    // int output_col = output_height * output_width;

    int col = 0;
    for (int r = 0; r < output_row; r++) {  //channels_col
      for(int h = 0; h < output_height; h++){
        for(int w = 0; w < output_width; w++){
          // im2col_output[r][col] = input_data[(h*output_width+w)+r*(output_col)]; //will have error
          im2col_output[r][col] = input_data[Offset(input_shape, 0, h, w, r)];
          
          col++;  
        } 
      }
      col = 0;
    }
}


void im2col_kernel(const int8_t* kernel_input_data, const RuntimeShape& filter_shape,const int filter_input_depth,
     const int filter_height, const int filter_width, const int filter_output_depth,
     int8_t kernel_im2col_output[300][300]) 
{   
    int output_row = filter_output_depth;
    int output_col = filter_input_depth* filter_height * filter_width;

    for (int row = 0; row < output_row; row++){
        int col = 0;
        while (col < output_col) {
            for (int id = 0; id < filter_input_depth; id++){
                for (int fh = 0; fh < filter_height; fh++) {
                    for (int fw = 0; fw < filter_width; fw++) { 
                        // kernel_im2col_output[row][col] = kernel_input_data[fh*filter_width+fw+id*(filter_width*filter_height)+row*(id*filter_width*filter_height)]; //will have error
                        kernel_im2col_output[row][col] = kernel_input_data[Offset(filter_shape, row, fh, fw, id)];
                        col++;
                    }
                }
            }
        }
    }
}

// Packs 4 bytes into one 32 bit value.
constexpr uint32_t pack_vals(int8_t w, int8_t x, int8_t y, int8_t z) {
  return (w << 24) | (x << 16) | (y << 8) | z;
}

void transpose(int8_t* A, int8_t* B, int K, int M) 
{ 
    int i, j; 
    for (i = 0; i < K; i++) 
        for (j = 0; j < M; j++) 
            B[i*M+j] = *(A+j*K+i); 
} 

// Fixed-point per-channel-quantization convolution reference kernel.
inline void ConvPerChannel(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int8_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_data, const RuntimeShape& bias_shape,
    const int32_t* bias_data, const RuntimeShape& output_shape,
    int8_t* output_data) {
  //show the parameters of every conv layers.
  // printf("in ConvPerChannel first\n");
  // print_conv_params(params, input_shape, filter_shape, output_shape);



  // Get parameters.
  const int32_t input_offset = params.input_offset;  // r = s(q - Z)
  const int stride_width = params.stride_width;
  const int stride_height = params.stride_height;
  const int dilation_width_factor = params.dilation_width_factor;
  const int dilation_height_factor = params.dilation_height_factor;
  const int pad_width = params.padding_values.width;
  const int pad_height = params.padding_values.height;
  const int32_t output_offset = params.output_offset;

  // Set min and max value of the output.
  const int32_t output_activation_min = params.quantized_activation_min;
  const int32_t output_activation_max = params.quantized_activation_max;

  // Consistency check.
  TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
  TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  if (bias_data) {
    TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
  }

  // Check dimensions of the tensors.
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  const int groups = input_depth / filter_input_depth;
  TFLITE_DCHECK_EQ(input_depth % filter_input_depth, 0);
  const int filters_per_group = output_depth / groups;
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);

  flag++;
  if (flag==1){
    //for first conv2d, retain original version
    for (int batch = 0; batch < batches; ++batch) {
      for (int out_y = 0; out_y < output_height; ++out_y) {
        const int in_y_origin = (out_y * stride_height) - pad_height;
        for (int out_x = 0; out_x < output_width; ++out_x) {
          const int in_x_origin = (out_x * stride_width) - pad_width;
          for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
            auto group = out_channel / filters_per_group;
            int32_t acc = 0;
            for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
              const int in_y = in_y_origin + dilation_height_factor * filter_y;  //important to understand
              for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
                const int in_x = in_x_origin + dilation_width_factor * filter_x;   //important to understand

                // Zero padding by omitting the areas outside the image.
                const bool is_point_inside_image =
                    (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                    (in_y < input_height);

                if (!is_point_inside_image) {
                  continue;
                }
                unsigned my_start = perf_get_mcycle();
                for (int in_channel = 0; in_channel < filter_input_depth;in_channel++) {
                  int32_t input_val =
                    input_data[Offset(input_shape, batch, in_y, in_x,
                                      in_channel + group * filter_input_depth)];

                  int32_t filter_val = filter_data[Offset(
                    filter_shape, out_channel, filter_y, filter_x, in_channel)];

                  acc += filter_val * (input_val + input_offset);
                }
                unsigned my_finish = perf_get_mcycle();
                my_cycles += (my_finish - my_start);
              }
            }

            if (bias_data) {
              acc += bias_data[out_channel];
            }
            acc = MultiplyByQuantizedMultiplier(
                acc, output_multiplier[out_channel], output_shift[out_channel]);
            acc += output_offset;
            acc = std::max(acc, output_activation_min);
            acc = std::min(acc, output_activation_max);
            output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] =
                static_cast<int8_t>(acc);
          }
        }
      }
    }
  }else{
    //allocate im2col input data
    // int output_row = input_depth * filter_height * filter_width;
    int output_col = output_height * output_width;
    int8_t im2col_output[300][700] = {0};
    im2col(input_data, input_shape, input_height, input_width, input_depth, filter_height, filter_width, output_depth, stride_height, stride_width, pad_width, pad_height,im2col_output);
    
    //allocate im2col kernel data
    // int kernel_output_row = output_depth;
    //int kernel_output_col = filter_input_depth * filter_height * filter_width;
    int8_t kernel_im2col_output[300][300] = {0};
    im2col_kernel(filter_data, filter_shape,filter_input_depth, filter_height, filter_width, output_depth,kernel_im2col_output);

    //do matrix transpose on filter data
    int8_t kernel_im2col_output_T[300][300] = {0};
    int K = 300;
    transpose(kernel_im2col_output[0], kernel_im2col_output_T[0], K, K); 

    //printf("output_depth = %d,output_col =%d\n", output_depth, output_col);
    int32_t acc = 0;
    cfu_op0(0, 0, 0); //inital
    for(int f_col = 0; f_col < output_depth/4; f_col++){  //300/4 = 75
      for(int in_col = 0; in_col < output_col/4; in_col++){ //ex: output_col = 43x16
        //for each filter: 4*300, input: 300*4 (originally)
        unsigned my_start = perf_get_mcycle();

        //send K, M, N
        cfu_op0(1, K, 4);  

        //send A, B to CFU
        int output_depth_offset = f_col*4;
        int wh_offset = in_col*4;
        for(int i = 0; i < K; i++){
          for (int j = 0; j < 4; j++){
            cfu_op0(2, kernel_im2col_output_T[i][output_depth_offset+j], im2col_output[i][wh_offset+j]);  
          }
        }

        //tell TPU start calculate
        cfu_op0(3, 0, 0);  

        //wait for TPU done calculate (busy 1->0)
        while(cfu_op0(4, 0, 0)==1);

        //get result back from CFU 4*4 values
        for(int i = 0; i < 16; i++){
          acc = cfu_op0(5, 0, 0);

          if (bias_data) {
            acc += bias_data[output_depth_offset+int(i/4)];
          }
          acc = MultiplyByQuantizedMultiplier(
              acc, output_multiplier[output_depth_offset+int(i/4)], output_shift[output_depth_offset+int(i/4)]);
          acc += output_offset;
          acc = std::max(acc, output_activation_min);
          acc = std::min(acc, output_activation_max);
          output_data[Offset(output_shape, 0, int((wh_offset+(i%4))/output_width), int((wh_offset+(i%4))%output_width), output_depth_offset+int(i/4))] = static_cast<int8_t>(acc);
        }

        //reset for next run
        cfu_op0(0, 0, 0);
        
        unsigned my_finish = perf_get_mcycle();
        my_cycles += (my_finish - my_start);
      }
    }
  }
}

inline void ConvPerChannelWithPackedInt4Weights(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int8_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_input, int8_t* unpacked_filter_data,
    const RuntimeShape& bias_shape, const int32_t* bias_data,
    const RuntimeShape& output_shape, int8_t* output_data) {
  TFLITE_DCHECK(unpacked_filter_data != nullptr);
  tflite::tensor_utils::UnpackDenseInt4IntoInt8(
      filter_input, filter_shape.FlatSize(), unpacked_filter_data);
  ConvPerChannel(params, output_multiplier, output_shift, input_shape,
                 input_data, filter_shape, unpacked_filter_data, bias_shape,
                 bias_data, output_shape, output_data);
}

// Fixed-point per-channel-quantization convolution reference kernel.
// 16-bit data and 8-bit filter
template <typename AccumScalar>
inline void ConvPerChannel(
    const ConvParams& params, const int32_t* output_multiplier,
    const int32_t* output_shift, const RuntimeShape& input_shape,
    const int16_t* input_data, const RuntimeShape& filter_shape,
    const int8_t* filter_data, const RuntimeShape& bias_shape,
    const AccumScalar* bias_data, const RuntimeShape& output_shape,
    int16_t* output_data) {
  //show the parameters of every conv layers.
  // printf("in ConvPerChannel second\n");
  // print_conv_params(params, input_shape, filter_shape, output_shape);

  // Get parameters.
  const int stride_width = params.stride_width;
  const int stride_height = params.stride_height;
  const int dilation_width_factor = params.dilation_width_factor;
  const int dilation_height_factor = params.dilation_height_factor;
  const int pad_width = params.padding_values.width;
  const int pad_height = params.padding_values.height;

  // Set min and max value of the output.
  const int32_t output_activation_min = params.quantized_activation_min;
  const int32_t output_activation_max = params.quantized_activation_max;

  // Consistency check.
  TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
  TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
  TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
  const int batches = MatchingDim(input_shape, 0, output_shape, 0);
  const int input_depth = input_shape.Dims(3);
  const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
  if (bias_data) {
    TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
  }

  // Check dimensions of the tensors.
  const int input_height = input_shape.Dims(1);
  const int input_width = input_shape.Dims(2);
  const int filter_height = filter_shape.Dims(1);
  const int filter_width = filter_shape.Dims(2);
  const int filter_input_depth = filter_shape.Dims(3);
  const int groups = input_depth / filter_input_depth;
  TFLITE_DCHECK_EQ(input_depth % filter_input_depth, 0);
  const int filters_per_group = output_depth / groups;
  const int output_height = output_shape.Dims(1);
  const int output_width = output_shape.Dims(2);
  for (int batch = 0; batch < batches; ++batch) {
    for (int out_y = 0; out_y < output_height; ++out_y) {
      const int in_y_origin = (out_y * stride_height) - pad_height;
      for (int out_x = 0; out_x < output_width; ++out_x) {
        const int in_x_origin = (out_x * stride_width) - pad_width;
        for (int out_channel = 0; out_channel < output_depth; ++out_channel) {
          auto group = out_channel / filters_per_group;
          AccumScalar acc = 0;
          for (int filter_y = 0; filter_y < filter_height; ++filter_y) {
            const int in_y = in_y_origin + dilation_height_factor * filter_y;
            for (int filter_x = 0; filter_x < filter_width; ++filter_x) {
              const int in_x = in_x_origin + dilation_width_factor * filter_x;

              // Zero padding by omitting the areas outside the image.
              const bool is_point_inside_image =
                  (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                  (in_y < input_height);

              if (!is_point_inside_image) {
                continue;
              }

              for (int in_channel = 0; in_channel < filter_input_depth;
                   ++in_channel) {
                int32_t input_val =
                    input_data[Offset(input_shape, batch, in_y, in_x,
                                      in_channel + group * filter_input_depth)];
                int32_t filter_val = filter_data[Offset(
                    filter_shape, out_channel, filter_y, filter_x, in_channel)];
                // Accumulate with 64 bits accumulator.
                // int64_t += int8_t * int16_t so the highest value we can
                // get from each accumulation is [-127, 127] * ([-32768,
                // 32767] -
                // [-32768, 32767]), which is [-8322945, 8322945].
                // log2(8322945) = 22.99.
                acc += filter_val * input_val;
              }
            }
          }
          if (bias_data) {
            acc += bias_data[out_channel];
          }
          int32_t scaled_acc = MultiplyByQuantizedMultiplier(
              acc, output_multiplier[out_channel], output_shift[out_channel]);
          scaled_acc = std::max(scaled_acc, output_activation_min);
          scaled_acc = std::min(scaled_acc, output_activation_max);
          output_data[Offset(output_shape, batch, out_y, out_x, out_channel)] =
              static_cast<int16_t>(scaled_acc);
        }
      }
    }
  }
}


}  // namespace reference_integer_ops
}  // namespace tflite

#endif  // TENSORFLOW_LITE_KERNELS_INTERNAL_REFERENCE_INTEGER_OPS_CONV_H_
