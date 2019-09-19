/*
  ===============================================================================

 Copyright (c) 2019, CryptoExperts and PQShield Ltd.

 All rights reserved. A copyright license for redistribution and use in
 source and binary forms, with or without modification, is hereby granted for
 non-commercial, experimental, research, public review and evaluation
 purposes, provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

  Authors: Dahmun Goudarzi, Matthieu Rivain

  ===============================================================================
*/

#include <stdint.h>
#include <stdio.h>
#include "api.h"


//==============================================================================
//=== Definitions
//==============================================================================

#define STATE_SIZE_96        3
#define STATE_SIZE_128       4

#define NB_ROUNDS_96        14
#define NB_ROUNDS_128       14
#define NB_ROUNDS_KS        14

#define WITH_CONST_ADD       0
#define WOUT_CONST_ADD       1

//==============================================================================
//=== Macros
//==============================================================================

#define right_rotate(row)			\
  row = (row >> 1) | (row << 31);

#define left_rotate(row,n)			\
  row = (row >> n) | (row << (32-n));

//==============================================================================
//=== Constants
//==============================================================================

#define COL_M0        0xa3861085
#define COL_M1        0x63417021
#define COL_M2        0x692cf280
#define COL_M3        0x48a54813
#define COL_MK        0xb881b9ca

#define COL_INV_M0    0x2037a121
#define COL_INV_M1    0x108ff2a0
#define COL_INV_M2    0x9054d8c0
#define COL_INV_M3    0x3354b117

#define KS_CONSTANT_0   0x00000080
#define KS_CONSTANT_1   0x00006a00
#define KS_CONSTANT_2   0x003f0000
#define KS_CONSTANT_3   0x24000000

#define KS_ROT_GAP1            8
#define KS_ROT_GAP2           15
#define KS_ROT_GAP3           18

//==============================================================================
//=== Declarations (assembly functions)
//==============================================================================

uint32_t mat_mult(uint32_t mat_col, uint32_t vec);

void isw_mult_96 (uint32_t state[MASKING_ORDER][STATE_SIZE_96],  int acc, int op1, int op2);
void isw_mult_128(uint32_t state[MASKING_ORDER][STATE_SIZE_128], int acc, int op1, int op2);

void isw_macc_96_201(uint32_t state[MASKING_ORDER][STATE_SIZE_96]);
void isw_macc_96_012(uint32_t state[MASKING_ORDER][STATE_SIZE_96]);
void isw_macc_96_102(uint32_t state[MASKING_ORDER][STATE_SIZE_96]);

void isw_macc_128_301(uint32_t state[MASKING_ORDER][STATE_SIZE_128]);
void isw_macc_128_012(uint32_t state[MASKING_ORDER][STATE_SIZE_128]);
void isw_macc_128_123(uint32_t state[MASKING_ORDER][STATE_SIZE_128]);
void isw_macc_128_203(uint32_t state[MASKING_ORDER][STATE_SIZE_128]);

//==============================================================================
//=== Common functions
//==============================================================================

void load_state(const uint8_t *plaintext, uint32_t *state, int state_size)
{
    int i;

    for (i=0; i<state_size; i++)
    {
        state[i] =                   plaintext[4*i+0];
        state[i] = (state[i] << 8) | plaintext[4*i+1];
        state[i] = (state[i] << 8) | plaintext[4*i+2];
        state[i] = (state[i] << 8) | plaintext[4*i+3];
    }
}

void unload_state(uint8_t *ciphertext, const uint32_t *state, int state_size)
{
    int i;

    for (i=0; i<state_size; i++)
    {
        ciphertext [4*i+0] = (uint8_t) (state[i] >> 24);
        ciphertext [4*i+1] = (uint8_t) (state[i] >> 16);
        ciphertext [4*i+2] = (uint8_t) (state[i] >>  8);
        ciphertext [4*i+3] = (uint8_t) (state[i] >>  0);
    }
}


//==============================================================================
//=== Pyjamask-128 (encryption)
//==============================================================================

void mix_rows_128(uint32_t *state)
{
    state[0] = mat_mult(COL_M0, state[0]);
    state[1] = mat_mult(COL_M1, state[1]);
    state[2] = mat_mult(COL_M2, state[2]);
    state[3] = mat_mult(COL_M3, state[3]);
}

void add_round_key_128(uint32_t *state, const uint32_t *round_key, int r)
{
    state[0] ^= round_key[4*r+0];
    state[1] ^= round_key[4*r+1];
    state[2] ^= round_key[4*r+2];
    state[3] ^= round_key[4*r+3];
}

void masked_sub_bytes_128(uint32_t state[MASKING_ORDER][STATE_SIZE_128])
{
    int i;

    for (i=0; i<MASKING_ORDER; i++)
    {
        state[i][0] ^= state[i][3];
    }

    //printf("Gonna mult\n");

    isw_macc_128_301(state);
    // printf("After 1st mult\n");
    isw_macc_128_012(state);
    isw_macc_128_123(state);
    isw_macc_128_203(state);

    // printf("Mult over\n");

    for (i=0; i<MASKING_ORDER; i++)
    {
        state[i][2] ^= state[i][1];
        state[i][1] ^= state[i][0];

        // swap state[i][2] <-> state[i][3]
        state[i][2] ^= state[i][3];
        state[i][3] ^= state[i][2];
        state[i][2] ^= state[i][3];
    }

    state[0][2] = ~state[0][2];
}

void masked_pyjamask_128_enc(uint32_t state[MASKING_ORDER][STATE_SIZE_128], uint32_t round_keys[MASKING_ORDER][4*(NB_ROUNDS_KS+1)], uint32_t cipher[MASKING_ORDER][STATE_SIZE_128])
{
    int i, r;

    // Initial AddRoundKey

    for (i=0; i<MASKING_ORDER; i++)
    {
        add_round_key_128(state[i], round_keys[i], 0);
    }

    // Main loop

    for (r=1; r<=NB_ROUNDS_128; r++)
    {
      // printf("round %d\n", r);
      masked_sub_bytes_128(state);
      // printf("Subbytes OK\n");
      
        for (i=0; i<MASKING_ORDER; i++)
        {
	  // printf("mixrows / addkey: %d\n",i);
            mix_rows_128(state[i]);
            add_round_key_128(state[i], round_keys[i], r);
        }
    }

    // Unmask and unload state
    for (i = 0; i < MASKING_ORDER; i++)
      for (r = 0; r < STATE_SIZE_128; r++)
        cipher[i][r] = state[i][r];
}

uint32_t bench_speed() {
  /* inputs */
  uint32_t plaintext[4][MASKING_ORDER] = { 0 };
  uint32_t key[15][4][MASKING_ORDER] = { 0 };
  /* outputs */
  uint32_t ciphertext[4][MASKING_ORDER] = { 0 };
  /* fun call */
  masked_pyjamask_128_enc(plaintext, key,ciphertext);

  /* Returning the number of encrypted bytes */
  return 16;
}
