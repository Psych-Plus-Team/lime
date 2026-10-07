#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <system/CFFI.h>
#include <system/CFFIPointer.h>
#include <utils/Bytes.h>
#include <signalsmith-stretch.h>
#include <algorithm>
#include <cstdint>
#include <vector>

namespace lime {

	class AudioStretch {
	public:
		AudioStretch (int channels, int sampleRate)
			: channels (std::max (1, channels)) {
			stretch.presetCheaper (this->channels, std::max (8000, sampleRate));
		}

		void Reset () { stretch.reset (); }

		bool Process (Bytes& input, Bytes& output, int inputFrames, int outputFrames) {
			if (inputFrames < 0 || outputFrames < 0) return false;
			if (input.length < inputFrames * channels * 2 || output.length < outputFrames * channels * 2) return false;

			inputPlanar.assign (channels, std::vector<float> (inputFrames));
			outputPlanar.assign (channels, std::vector<float> (outputFrames));
			inputPointers.resize (channels);
			outputPointers.resize (channels);

			const int16_t* source = reinterpret_cast<const int16_t*> (input.b);
			for (int channel = 0; channel < channels; ++channel) {
				inputPointers[channel] = inputPlanar[channel].data ();
				outputPointers[channel] = outputPlanar[channel].data ();
				for (int frame = 0; frame < inputFrames; ++frame) {
					inputPlanar[channel][frame] = source[frame * channels + channel] / 32768.0f;
				}
			}

			stretch.process (inputPointers.data (), inputFrames, outputPointers.data (), outputFrames);

			int16_t* destination = reinterpret_cast<int16_t*> (output.b);
			for (int frame = 0; frame < outputFrames; ++frame) {
				for (int channel = 0; channel < channels; ++channel) {
					float sample = std::max (-1.0f, std::min (1.0f, outputPlanar[channel][frame]));
					destination[frame * channels + channel] = static_cast<int16_t> (sample * 32767.0f);
				}
			}
			return true;
		}

	private:
		int channels;
		signalsmith::stretch::SignalsmithStretch<float> stretch;
		std::vector<std::vector<float> > inputPlanar;
		std::vector<std::vector<float> > outputPlanar;
		std::vector<float*> inputPointers;
		std::vector<float*> outputPointers;
	};

	void gc_audio_stretch (value handle) {
		delete reinterpret_cast<AudioStretch*> (val_data (handle));
	}

	value lime_audio_stretch_create (int channels, int sampleRate) {
		return CFFIPointer (new AudioStretch (channels, sampleRate), gc_audio_stretch);
	}

	bool lime_audio_stretch_process (value handle, value inputValue, value outputValue, int inputFrames, int outputFrames) {
		if (val_is_null (handle)) return false;
		Bytes input (inputValue);
		Bytes output (outputValue);
		return reinterpret_cast<AudioStretch*> (val_data (handle))->Process (
			input, output, inputFrames, outputFrames);
	}

	void lime_audio_stretch_reset (value handle) {
		if (!val_is_null (handle)) reinterpret_cast<AudioStretch*> (val_data (handle))->Reset ();
	}

	DEFINE_PRIME2 (lime_audio_stretch_create);
	DEFINE_PRIME5 (lime_audio_stretch_process);
	DEFINE_PRIME1v (lime_audio_stretch_reset);

}

extern "C" int lime_audio_stretch_register_prims () {
	return 0;
}
