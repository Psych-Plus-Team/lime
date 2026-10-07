#pragma once

#define FORCE_ALIGN
#define HAVE_CXXMODULES 0
#define HAVE_RTKIT 0
#define ALSOFT_UWP 0
#define ALSOFT_EAX 0

#if defined(_WIN32)
#define HAVE_DYNLOAD 1
#define HAVE_GUIDDEF_H 1
#define HAVE_INTRIN_H 1
#define HAVE_CPUID_INTRINSIC 1
#else
#define HAVE_DYNLOAD 1
#define HAVE_DLFCN_H 1
#define HAVE_PTHREAD_SETSCHEDPARAM 1
#define HAVE_PTHREAD_SETNAME_NP 1
#endif

