#pragma once

#if defined(__SSE__) || defined(_M_IX86) || defined(_M_X64)
#define HAVE_SSE 1
#define HAVE_SSE2 1
#define HAVE_SSE3 1
#define HAVE_SSE4_1 0
#define HAVE_SSE_INTRINSICS 1
#else
#define HAVE_SSE 0
#define HAVE_SSE2 0
#define HAVE_SSE3 0
#define HAVE_SSE4_1 0
#define HAVE_SSE_INTRINSICS 0
#endif

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#define HAVE_NEON 1
#else
#define HAVE_NEON 0
#endif

