#include <fftw3.h>
#include <math.h>
#include <pulse/error.h>
#include <pulse/simple.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { RATE = 16000, WINDOW = 1024, HOP = 256, BANDS = 12 };

int main(int argc, char **argv) {
    const int from_stdin = argc == 2 && strcmp(argv[1], "--stdin") == 0;
    // Require a named output monitor. Never fall back to the default microphone.
    if (argc != 2 || (!from_stdin &&
        (strlen(argv[1]) <= 8 || strcmp(argv[1] + strlen(argv[1]) - 8, ".monitor")))) {
        fprintf(stderr, "Usage: audio-spectrum SINK.monitor | --stdin (mono s16le, 16000 Hz)\n");
        return 2;
    }

    pa_simple *capture = NULL;
    int error = 0;
    if (!from_stdin) {
        const pa_sample_spec spec = { PA_SAMPLE_S16LE, RATE, 1 };
        const pa_buffer_attr buffering = {
            .maxlength = UINT32_MAX, .tlength = UINT32_MAX,
            .prebuf = UINT32_MAX, .minreq = UINT32_MAX,
            .fragsize = HOP * sizeof(int16_t)
        };
        capture = pa_simple_new(NULL, "Quickshell spectrum", PA_STREAM_RECORD,
            argv[1], "Speaker spectrum", &spec, NULL, &buffering, &error);
        if (!capture) {
            fprintf(stderr, "Output monitor: %s\n", pa_strerror(error));
            return 1;
        }
    }

    double *input = fftw_alloc_real(WINDOW);
    fftw_complex *output = fftw_alloc_complex(WINDOW / 2 + 1);
    if (!input || !output) return 1;
    fftw_plan transform = fftw_plan_dft_r2c_1d(WINDOW, input, output, FFTW_ESTIMATE);
    if (!transform) return 1;
    double samples[WINDOW] = {0}, hann[WINDOW], levels[BANDS] = {0};
    int edges[BANDS + 1];
    for (int i = 0; i < WINDOW; ++i)
        hann[i] = 0.5 - 0.5 * cos(2.0 * M_PI * i / (WINDOW - 1));
    for (int i = 0; i <= BANDS; ++i)
        edges[i] = (int)ceil(40.0 * pow(7600.0 / 40.0, (double)i / BANDS) * WINDOW / RATE);
    // Slow gain recovery preserves differences between soft and loud passages.
    double reference = 0.02;
    uint8_t pcm[HOP * 2];
    setvbuf(stdout, NULL, _IOLBF, 0);
    while (1) {
        if (from_stdin) {
            if (fread(pcm, 1, sizeof(pcm), stdin) != sizeof(pcm)) break;
        } else if (pa_simple_read(capture, pcm, sizeof(pcm), &error) < 0) {
            fprintf(stderr, "Output monitor: %s\n", pa_strerror(error));
            break;
        }
        memmove(samples, samples + HOP, (WINDOW - HOP) * sizeof(double));
        double energy = 0;
        for (int i = 0; i < HOP; ++i) {
            double sample = (int16_t)((unsigned)pcm[2*i] | (unsigned)pcm[2*i+1] << 8) / 32768.0;
            samples[WINDOW - HOP + i] = sample;
            energy += sample * sample;
        }
        for (int i = 0; i < WINDOW; ++i) input[i] = samples[i] * hann[i];
        fftw_execute(transform);
        double magnitudes[BANDS], strongest = 0;
        for (int band = 0; band < BANDS; ++band) {
            double magnitude = 0;
            for (int bin = edges[band]; bin < edges[band+1]; ++bin)
                magnitude = fmax(magnitude, hypot(output[bin][0], output[bin][1]) * 4.0 / WINDOW);
            // A gentle treble lift balances the logarithmic bass-to-treble bands.
            magnitudes[band] = magnitude * pow(sqrt(edges[band] * edges[band+1]) * RATE / WINDOW / 120.0, 0.2);
            strongest = fmax(strongest, magnitudes[band]);
        }
        reference = fmax(0.02, fmax(reference * 0.999, strongest * 1.12));
        const int audible = sqrt(energy / HOP) > 0.0001;
        putchar('[');
        for (int band = 0; band < BANDS; ++band) {
            double ratio = magnitudes[band] / reference;
            double target = audible && ratio > 0.003 ? pow(fmin(1, ratio), 0.7) : 0;
            // Fast attacks follow transients; a short release lets notes fall naturally.
            double blend = target > levels[band] ? 0.85 : 0.18;
            levels[band] += (target - levels[band]) * blend;
            if (levels[band] < 0.001) levels[band] = 0;
            printf("%s%.4f", band ? "," : "", levels[band]);
        }
        puts("]");
        if (ferror(stdout)) break;
    }
    fftw_destroy_plan(transform);
    fftw_free(input);
    fftw_free(output);
    if (capture) pa_simple_free(capture);
    return error ? 1 : 0;
}
