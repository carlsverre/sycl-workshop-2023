//!
//!
//!
const std = @import("std");
const assert = std.debug.assert;

const microzig = @import("microzig");
const cpu = microzig.cpu;
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const irq = rp2040.irq;
const time = rp2040.time;

// code for this workshop
const workshop = @import("workshop");
const Oscillator = workshop.Oscillator;

// configuration
const sample_rate = 96_000;
const Sample = i16;

// hardware blocks
const button = gpio.num(9);
const debug = gpio.num(5);
const I2S = workshop.I2S(Sample, .{ .sample_rate = sample_rate });

pub fn main() !void {
    // see blinky for an explanation here:
    button.set_function(.sio);
    button.set_direction(.in);
    button.set_pull(.down);

    debug.set_function(.sio);
    debug.set_direction(.out);
    debug.put(1);

    const i2s = I2S.init(.pio0, .{
        .clock_config = rp2040.clock_config,
        .clk_pin = gpio.num(2),
        .word_select_pin = gpio.num(3),
        .data_pin = gpio.num(4),
    });

    var osc = Oscillator(sample_rate).init(440);

    // lfg
    while (true) {
        // The highest priority task we have is to generate a sample every sample period. If we fail to do this then the
        if (i2s.is_writable()) {
            debug.put(0);
            defer debug.put(1);
            // assert that this branch never takes longer than a sample period
            const timeout = time.make_timeout_us(10);
            defer assert(!timeout.reached());

            osc.tick();

            // our sample size is 16 bits, and it just so happens that the
            // maximum value of the oscillator corresponds to 2π radians. We
            // get a sawtooth waveform if we use the angle as the magnitude of
            // our generated wave.
            const sample: Sample = if (button.read() == 1)
                osc.to_sawtooth(Sample)
                // alternatively, try:
                // osc.to_sine(Sample)
                // osc.to_squarewave(Sample)
            else
                0;

            // The amplifier takes a left and right input as part of the I2S
            // standard and averages both channels to the single speaker.
            i2s.write_mono(sample);
        }
    }
}
