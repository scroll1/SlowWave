#include "CSignalsmithStretch.h"
#include "signalsmith-stretch.h"

struct SignalsmithStretchHandle {
    signalsmith::stretch::SignalsmithStretch<float> stretch;
};

SignalsmithStretchHandle *ss_create(int32_t channels, float sampleRate) {
    if (channels <= 0 || sampleRate <= 0.0f) {
        return nullptr;
    }
    auto *handle = new SignalsmithStretchHandle();
    handle->stretch.presetDefault(channels, sampleRate, false);
    handle->stretch.setTransposeFactor(1.0f);
    return handle;
}

void ss_destroy(SignalsmithStretchHandle *handle) {
    delete handle;
}

void ss_reset(SignalsmithStretchHandle *handle) {
    handle->stretch.reset();
}

int32_t ss_input_latency(SignalsmithStretchHandle *handle) {
    return static_cast<int32_t>(handle->stretch.inputLatency());
}

int32_t ss_output_latency(SignalsmithStretchHandle *handle) {
    return static_cast<int32_t>(handle->stretch.outputLatency());
}

void ss_set_transpose_factor(SignalsmithStretchHandle *handle, float multiplier) {
    handle->stretch.setTransposeFactor(multiplier);
}

void ss_seek(
    SignalsmithStretchHandle *handle,
    const float *const *inputs,
    int32_t inputSamples,
    double playbackRate
) {
    handle->stretch.seek(inputs, inputSamples, playbackRate);
}

void ss_process(
    SignalsmithStretchHandle *handle,
    const float *const *inputs,
    int32_t inputSamples,
    float *const *outputs,
    int32_t outputSamples
) {
    handle->stretch.process(inputs, inputSamples, outputs, outputSamples);
}
