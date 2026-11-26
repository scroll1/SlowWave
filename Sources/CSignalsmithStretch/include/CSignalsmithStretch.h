#ifndef CSIGNALSMITH_STRETCH_H
#define CSIGNALSMITH_STRETCH_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SignalsmithStretchHandle SignalsmithStretchHandle;

SignalsmithStretchHandle * _Nullable ss_create(int32_t channels, float sampleRate);
void ss_destroy(SignalsmithStretchHandle * _Nullable handle);
void ss_reset(SignalsmithStretchHandle * _Nonnull handle);
int32_t ss_input_latency(SignalsmithStretchHandle * _Nonnull handle);
int32_t ss_output_latency(SignalsmithStretchHandle * _Nonnull handle);
void ss_set_transpose_factor(SignalsmithStretchHandle * _Nonnull handle, float multiplier);
void ss_seek(
    SignalsmithStretchHandle * _Nonnull handle,
    const float * _Nonnull const * _Nonnull inputs,
    int32_t inputSamples,
    double playbackRate
);
void ss_process(
    SignalsmithStretchHandle * _Nonnull handle,
    const float * _Nonnull const * _Nonnull inputs,
    int32_t inputSamples,
    float * _Nonnull const * _Nonnull outputs,
    int32_t outputSamples
);

#ifdef __cplusplus
}
#endif

#endif // CSIGNALSMITH_STRETCH_H
