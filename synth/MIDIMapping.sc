MIDIMapping {
    classvar pad_ranges, slider_ranges, note_ranges, raw_ranges;
    classvar pads, sliders, notes, note_identities, notes_in_order;

    classvar note_to_midi_id, midi_id_to_note, note_to_is_down;
    classvar pad_to_midi_id, midi_id_to_pad, pad_to_is_down;
    classvar slider_to_midi_id, midi_id_to_slider, slider_to_value;
    classvar raw_to_value;

    classvar note_pressed_handlers, note_pressed_handler_id;
    classvar note_released_handlers, note_released_handler_id;
    classvar bend_handlers, bend_handler_id;
    classvar pad_pressed_handlers, pad_pressed_handler_id;
    classvar pad_released_handlers, pad_released_handler_id;
    classvar slider_handlers, slider_handler_id;
    classvar tick_handlers, tick_handler_id;
    classvar raw_handlers, raw_handler_id;

    classvar note_pressed_midi_func;
    classvar note_released_midi_func;
    classvar bend_midi_func;
    classvar tick_midi_func;
    classvar fallback_midi_func, fallback_midi_func_callback;

    *initClass {
        // Initialize constants and static data structures
        pad_ranges = [[0, 15], [12, 24]];
        slider_ranges = [[16, 31], [102, 117]];
        note_ranges = [[12, 120]];
        raw_ranges = [[0, 255]];

        note_pressed_handler_id = 0;
        note_pressed_handlers = Dictionary.new;

        note_released_handler_id = 0;
        note_released_handlers = Dictionary.new;

        pad_pressed_handler_id = 0;
        pad_pressed_handlers = Dictionary.new;

        pad_released_handler_id = 0;
        pad_released_handlers = Dictionary.new;

        bend_handler_id = 0;
        bend_handlers = Dictionary.new;

        slider_handler_id = 0;
        slider_handlers = Dictionary.new;

        raw_handler_id = 0;
        raw_handlers = Dictionary.new;

        tick_handler_id = 0;
        tick_handlers = Dictionary.new;

        notes = Array.newFrom([
            \C1, \Cs1, \Db1, \D1, \Ds1, \Eb1, \E1, \F1, \Fs1, \Gb1, \G1, \Gs1, \Ab1, \A1, \As1, \Bb1, \B1,
            \C2, \Cs2, \Db2, \D2, \Ds2, \Eb2, \E2, \F2, \Fs2, \Gb2, \G2, \Gs2, \Ab2, \A2, \As2, \Bb2, \B2,
            \C3, \Cs3, \Db3, \D3, \Ds3, \Eb3, \E3, \F3, \Fs3, \Gb3, \G3, \Gs3, \Ab3, \A3, \As3, \Bb3, \B3,
            \C4, \Cs4, \Db4, \D4, \Ds4, \Eb4, \E4, \F4, \Fs4, \Gb4, \G4, \Gs4, \Ab4, \A4, \As4, \Bb4, \B4,
            \C5, \Cs5, \Db5, \D5, \Ds5, \Eb5, \E5, \F5, \Fs5, \Gb5, \G5, \Gs5, \Ab5, \A5, \As5, \Bb5, \B5,
            \C6, \Cs6, \Db6, \D6, \Ds6, \Eb6, \E6, \F6, \Fs6, \Gb6, \G6, \Gs6, \Ab6, \A6, \As6, \Bb6, \B6,
            \C7,
            \C, \Cs, \Db, \D, \Ds, \Eb, \E, \F, \Fs, \Gb, \G, \Gs, \Ab, \A, \As, \Bb, \B
        ]);

        notes_in_order = Array.newFrom([
            \C1, \Cs1, \D1, \Ds1, \E1, \F1, \Fs1, \G1, \Gs1, \A1, \As1, \B1,
            \C2, \Cs2, \D2, \Ds2, \E2, \F2, \Fs2, \G2, \Gs2, \A2, \As2, \B2,
            \C3, \Cs3, \D3, \Ds3, \E3, \F3, \Fs3, \G3, \Gs3, \A3, \As3, \B3,
            \C4, \Cs4, \D4, \Ds4, \E4, \F4, \Fs4, \G4, \Gs4, \A4, \As4, \B4,
            \C5, \Cs5, \D5, \Ds5, \E5, \F5, \Fs5, \G5, \Gs5, \A5, \As5, \B5,
            \C6, \Cs6, \D6, \Ds6, \E6, \F6, \Fs6, \G6, \Gs6, \A6, \As6, \B6,
            \C7
        ]);

        note_identities = Dictionary.newFrom([
            \Db2, \Cs2, \Eb2, \Ds2, \Gb2, \Fs2, \Ab2, \Gs2, \Bb2, \As2,
            \Db3, \Cs3, \Eb3, \Ds3, \Gb3, \Fs3, \Ab3, \Gs3, \Bb3, \As3,
            \Db4, \Cs4, \Eb4, \Ds4, \Gb4, \Fs4, \Ab4, \Gs4, \Bb4, \As4,
            \Db5, \Cs5, \Eb5, \Ds5, \Gb5, \Fs5, \Ab5, \Gs5, \Bb5, \As5,
            \Db6, \Cs6, \Eb6, \Ds6, \Gb6, \Fs6, \Ab6, \Gs6, \Bb6, \As6,

            \C,  \C4, \Cs, \Cs4, \Db, \Cs4, \D,  \D4, \Ds, \Ds4, \Eb, \Ds4, \E,  \E4,
            \F,  \F4, \Fs, \Fs4, \Gb, \Fs4, \G,  \G4, \Gs, \Gs4, \Ab, \Gs4, \A,  \A4,
            \As, \As4, \Bb, \As4, \B,  \B4
        ]);

        pads = Array.newFrom([
            \Pad01, \Pad02, \Pad03, \Pad04, \Pad05, \Pad06, \Pad07, \Pad08,
            \Pad09, \Pad10, \Pad11, \Pad12, \Pad13, \Pad14, \Pad15, \Pad16
        ]);

        sliders = Array.newFrom([
            \Slider01, \Slider02, \Slider03, \Slider04, \Slider05, \Slider06, \Slider07, \Slider08,
            \Slider09, \Slider10, \Slider11, \Slider12, \Slider13, \Slider14, \Slider15, \Slider16
        ]);
    }

    *init {
        // Run this explicitly (MIDIMapping.init;) to connect MIDI and map handlers.
        if (MIDIClient.initialized.not) {
            MIDIClient.init;
        };
        MIDIIn.disconnectAll;
        MIDIIn.connectAll;

        note_to_midi_id = Dictionary.new;
        midi_id_to_note = Dictionary.new;
        note_to_is_down = Dictionary.new;

        note_ranges.do({ arg range;
            var count = range[1] - range[0] + 1;
            count.do({ arg i;
                var note_id = range[0] + i;
                var note = notes_in_order[i];
                if (note.isNil) {
                    Error("In MIDIMapping: note range % is larger than the number of notes available, which is %.".format(range, notes_in_order.size)).throw;
                } {
                    note_to_midi_id.put(note, note_id);
                    midi_id_to_note.put(note_id, note);
                    note_to_is_down.put(note, false);
                };
            });
        });

        pad_to_midi_id = Dictionary.new;
        midi_id_to_pad = Dictionary.new;
        pad_to_is_down = Dictionary.new;

        pad_ranges.do({ arg range;
            var count = range[1] - range[0] + 1;
            count.do({ arg i;
                var pad_id = range[0] + i;
                var pad = pads[i];
                if (pad.notNil) {
                    pad_to_midi_id.put(pad, pad_id);
                    midi_id_to_pad.put(pad_id, pad);
                    pad_to_is_down.put(pad, false);
                };
            });
        });

        slider_to_midi_id = Dictionary.new;
        midi_id_to_slider = Dictionary.new;
        slider_to_value = Dictionary.new;

        slider_ranges.do({ arg range;
            var count = range[1] - range[0] + 1;
            count.do({ arg i;
                var slider_id = range[0] + i;
                var slider = sliders[i];
                if (slider.notNil) {
                    slider_to_midi_id.put(slider, slider_id);
                    midi_id_to_slider.put(slider_id, slider);
                    slider_to_value.put(slider, 0);
                };
            });
        });

        raw_to_value = Dictionary.new;
        raw_ranges.do({ arg range;
            var count = range[1] - range[0] + 1;
            count.do({ arg i;
                var raw_id = range[0] + i;
                raw_to_value.put(raw_id, 0);
            });
        });

        note_pressed_midi_func = MIDIFunc.noteOn({ arg velocity, value, channel, source;
            var note = midi_id_to_note.at(value);
            var flat = note_identities.at(note);

            "noteOn : % % % %".format(velocity, value, channel, source).postln;

            if (note.notNil) {
                note_to_is_down.put(note, true);

                if (flat.notNil) {
                    note_to_is_down.put(flat, true);
                };

                note_pressed_handlers.do({ arg handler;
                    handler.value(note);
                });
            };
        });

        note_released_midi_func = MIDIFunc.noteOff({ arg velocity, value, channel, source;
            var note = midi_id_to_note.at(value);
            var flat = note_identities.at(note);

            "noteOff: % % % %".format(velocity, value, channel, source).postln;

            if (note.notNil) {
                note_to_is_down.put(note, false);
                if (flat.notNil) {
                    note_to_is_down.put(flat, false);
                };

                note_released_handlers.do({ arg handler;
                    handler.value(note);
                });
            };
        });

        bend_midi_func = MIDIFunc.bend({ arg value, channel, source;
            "bend: % % %".format(value, channel, source).postln;

            bend_handlers.do({ arg handler;
                handler.value(value.linlin(
                    0, 2 ** 14,
                    0, 1
                ));
            });
        });

        tick_midi_func = MIDIFunc.midiClock({ arg tick;
            tick_handlers.do({ arg handler;
                handler.value(tick);
            });
        });

        fallback_midi_func_callback = { arg x, id, channel, source;
            var note, flat, velocity,
                pad, pad_is_pressed, is_pad,
                slider, slider_value, is_slider
            ;

            "default: % % % %".format(x, id, channel, source).postln;

            if (x.notNil && id.notNil && channel.notNil && source.notNil) {
                if (this.is_midi_id_valid_note(id)) {
                    // handled in noteOn, noteOff
                };

                if (this.is_midi_id_valid_pad(id)) {
                    pad = midi_id_to_pad.at(id);
                    if (pad.notNil) {
                        pad_is_pressed = x != 0;
                        pad_to_is_down.put(pad, pad_is_pressed);

                        if (pad_is_pressed) {
                            pad_pressed_handlers.do({ arg handler;
                                handler.value(pad);
                            });
                        } {
                            pad_released_handlers.do({ arg handler;
                                handler.value(pad);
                            });
                        };
                    };
                };

                if (this.is_midi_id_valid_slider(id)) {
                    slider = midi_id_to_slider.at(id);

                    if (slider.notNil) {
                        slider_value = x;
                        slider_to_value.put(slider, slider_value);

                        slider_handlers.do({ arg handler;
                            handler.value(slider, slider_value);
                        });
                    };
                };
            };

            raw_to_value.put(id, x);
            raw_handlers.do({ arg handler;
                handler.value(id, x);
            });
        };

        fallback_midi_func = List.new;

        [
            \noteOn, \noteOff, \control, \touch, \polytouch, \bend,
            \sysrt, \sysex
        ].do({ arg type;
            fallback_midi_func.add(MIDIFunc(
                fallback_midi_func_callback,
                nil, nil, type, nil, nil
            ));
        });

        "MIDIMapping initialized.".postln;
    }

    /* Helpers */

    *assert_is_function { arg scope, x;
        if (x.isFunction.not) {
            Error("In %: argument % is not a function".format(scope, x)).throw;
        };
    }

    *assert_is_valid_id { arg scope, id, dict;
        if (dict.includesKey(id).not) {
            Error("In %: id % is not a valid id".format(scope, id)).throw;
        };
    }

    /* Connection Handlers */

    *connect_note_pressed { arg f;
        var handler_id = note_pressed_handler_id;
        note_pressed_handler_id = note_pressed_handler_id + 1;
        this.assert_is_function("connect_note_pressed", f);
        note_pressed_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_note_pressed { arg id;
        this.assert_is_valid_id("disconnect_note_pressed", id, note_pressed_handlers);
        note_pressed_handlers.removeAt(id);
        ^nil;
    }

    *connect_note_released { arg f;
        var handler_id = note_released_handler_id;
        note_released_handler_id = note_released_handler_id + 1;
        this.assert_is_function("connect_note_released", f);
        note_released_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_note_released { arg id;
        this.assert_is_valid_id("disconnect_note_released", id, note_released_handlers);
        note_released_handlers.removeAt(id);
        ^nil;
    }

    *connect_pad_pressed { arg f;
        var handler_id = pad_pressed_handler_id;
        pad_pressed_handler_id = pad_pressed_handler_id + 1;
        this.assert_is_function("connect_pad_pressed", f);
        pad_pressed_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_pad_pressed { arg id;
        this.assert_is_valid_id("disconnect_pad_pressed", id, pad_pressed_handlers);
        pad_pressed_handlers.removeAt(id);
        ^nil;
    }

    *connect_pad_released { arg f;
        var handler_id = pad_released_handler_id;
        pad_released_handler_id = pad_released_handler_id + 1;
        this.assert_is_function("connect_pad_released", f);
        pad_released_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_pad_released { arg id;
        this.assert_is_valid_id("disconnect_pad_released", id, pad_released_handlers);
        pad_released_handlers.removeAt(id);
        ^nil;
    }

    *connect_slider { arg f;
        var handler_id = slider_handler_id;
        slider_handler_id = slider_handler_id + 1;
        this.assert_is_function("connect_slider", f);
        slider_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_slider { arg id;
        this.assert_is_valid_id("disconnect_slider", id, slider_handlers);
        slider_handlers.removeAt(id);
        ^nil;
    }

    *connect_bend { arg f;
        var handler_id = bend_handler_id;
        bend_handler_id = bend_handler_id + 1;
        this.assert_is_function("connect_bend", f);
        bend_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_bend { arg id;
        this.assert_is_valid_id("disconnect_bend", id, bend_handlers);
        bend_handlers.removeAt(id);
        ^nil;
    }

    *connect_raw { arg f;
        var handler_id = raw_handler_id;
        raw_handler_id = raw_handler_id + 1;
        this.assert_is_function("connect_raw", f);
        raw_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_raw { arg id;
        this.assert_is_valid_id("disconnect_raw", id, raw_handlers);
        raw_handlers.removeAt(id);
        ^nil;
    }

    *connect_tick { arg f;
        var handler_id = tick_handler_id;
        tick_handler_id = tick_handler_id + 1;
        this.assert_is_function("connect_tick", f);
        tick_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_tick { arg id;
        this.assert_is_valid_id("disconnect_tick", id, tick_handlers);
        tick_handlers.removeAt(id);
        ^nil;
    }

    /* Utilities */

    *note_is_down { arg note;
        var is_down = note_to_is_down.trueAt(note);
        if (is_down.isNil) {
            Error("In note_is_down: argument % is not a valid note".format(note)).throw;
        } {
            ^is_down;
        };
    }

    *is_valid_note { arg note;
        ^notes.includes(note);
    }

    *is_midi_id_valid_note { arg id;
        ^note_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *note_is_same { arg a, b;
        var a_flat = note_identities.at(a);
        var b_flat = note_identities.at(b);

        ^(a == b
            || (a_flat.isNil.not && (a_flat == b))
            || (b_flat.isNil.not && (b_flat == a))
        );
    }

    *note_to_pitch { arg note;
        if (this.is_valid_note(note).not) {
            Error("In note_to_pitch: argument % is not a valid note".format(note)).throw;
        };
        // TODO
    }

    *pad_is_down { arg pad;
        var is_down = pad_to_is_down.trueAt(pad);
        if (is_down.isNil) {
            Error("In pad_is_down: argument % is not a valid pad".format(pad)).throw;
        } {
            ^is_down;
        };
    }

    *is_valid_pad { arg pad;
        ^pads.includes(pad);
    }

    *is_midi_id_valid_pad { arg id;
        ^pad_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *slider_get_value { arg slider_id;
        var value = slider_to_value.at(slider_id);
        if (value.isNil) {
            Error("In slider_get_value: argument % is not a valid slider id".format(slider_id)).throw;
        } {
            ^value;
        }
    }

    *is_valid_slider { arg slider;
        ^sliders.includes(slider);
    }

    *is_midi_id_valid_slider { arg id;
        ^slider_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *raw_get_value { arg raw;
        var value = raw_to_value.at(raw);
        if (raw.inclusivelyBetween(0, 2**8).not) {
            Error("In raw_get_value: argument % is not a valid midi id".format(raw)).throw;
        } {
            ^value;
        }
    }

    *is_valid_raw { arg raw;
        ^raw_ranges.any({ arg range; raw.inclusivelyBetween(range[0], range[1]) });
    }
}