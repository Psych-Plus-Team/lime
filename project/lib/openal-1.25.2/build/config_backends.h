#pragma once

#define HAVE_ALSA 0
#define HAVE_OSS 0
#define HAVE_PIPEWIRE 0
#define HAVE_SOLARIS 0
#define HAVE_SNDIO 0
#define HAVE_WASAPI 0
#define HAVE_DSOUND 0
#define HAVE_WINMM 0
#define HAVE_PORTAUDIO 0
#define HAVE_PULSEAUDIO 0
#define HAVE_JACK 0
#define HAVE_COREAUDIO 0
#define HAVE_OPENSL 0
#define HAVE_OBOE 0
#define HAVE_WAVE 1
#define HAVE_SDL3 0
#define HAVE_SDL2 0

#if defined(__ANDROID__)
#undef HAVE_OPENSL
#define HAVE_OPENSL 1
#elif defined(__APPLE__)
#undef HAVE_COREAUDIO
#define HAVE_COREAUDIO 1
#elif defined(__linux__)
#undef HAVE_ALSA
#define HAVE_ALSA 1
#undef HAVE_OSS
#define HAVE_OSS 1
#undef HAVE_PULSEAUDIO
#define HAVE_PULSEAUDIO 1
#elif defined(_WIN32)
#undef HAVE_WASAPI
#define HAVE_WASAPI 1
#undef HAVE_DSOUND
#define HAVE_DSOUND 1
#undef HAVE_WINMM
#define HAVE_WINMM 1
#endif

