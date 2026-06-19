var
    // control element ranges, these depend on the midi controller
    pad_ranges = [[0, 15], [12, 24]],
    slider_ranges = [[16, 31], [102, 117]],
    note_ranges = [[12, 120]],
    raw_ranges = [[0, 255]],

    pads, sliders,
    notes, note_identities, notes_in_order,

    note_to_midi_id,midi_id_to_note, note_to_is_down,
    pad_to_midi_id, midi_id_to_pad, pad_to_is_down,
    slider_to_midi_id, midi_id_to_slider, slider_to_value,
    raw_to_value,

    assert_is_function,
    assert_is_valid_id,

    note_pressed_handlers, note_pressed_handler_id,
    note_released_handlers, note_released_handler_id,
    bend_handlers, bend_handler_id,
    pad_pressed_handlers, pad_pressed_handler_id,
    pad_released_handlers, pad_released_handler_id,
    slider_handlers, slider_handler_id,
    tick_handlers, tick_handler_id,
    raw_handlers, raw_handler_id,

    note_pressed_midi_func,
    note_released_midi_func,
    bend_midi_func,
    tick_midi_func,
    fallback_midi_func, fallback_midi_func_callback
;

assert_is_function = { arg scope, x;
	if (x.isFunction.not) {
		Error("In %: argument % is not a function".format(scope, x));
	};
};

assert_is_valid_id = { arg scope, id, dict;
	if (dict.includes(id).not) {
		Error("In %: id % is not a valid id".format(scope, id));
	};
};

~midi_connect_note_pressed = { arg f;
	var handler_id = note_pressed_handler_id;
	note_pressed_handler_id = note_pressed_handler_id + 1;
	assert_is_function.value("midi_connect_note_pressed", f);
	note_pressed_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_note_pressed = { arg id;
	assert_is_valid_id("midi_disconnect_note_pressed", id, note_pressed_handlers);
	note_pressed_handlers.removeAt(id);
	nil;
};

~midi_connect_note_released = { arg f;
	var handler_id = note_released_handler_id;
	note_released_handler_id = note_released_handler_id + 1;
	assert_is_function.value("midi_connect_note_released", f);
	note_released_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_note_released = { arg id;
	assert_is_valid_id("midi_disconnect_note_released", id, note_released_handlers);
	note_released_handlers.removeAt(id);
	nil;
};

~midi_connect_pad_pressed = { arg f;
	var handler_id = pad_pressed_handler_id;
	pad_pressed_handler_id = pad_pressed_handler_id + 1;
	assert_is_function.value("midi_connect_pad_pressed", f);
	pad_pressed_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_pad_pressed = { arg id;
	assert_is_valid_id("midi_disconnect_pad_pressed", id, pad_pressed_handlers);
	pad_pressed_handlers.removeAt(id);
	nil;
};

~midi_connect_pad_released = { arg f;
	var handler_id = pad_released_handler_id;
	pad_released_handler_id = pad_released_handler_id + 1;
	assert_is_function.value("midi_connect_pad_released", f);
	pad_released_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_pad_released = { arg id;
	assert_is_valid_id("midi_disconnect_pad_released", id, pad_released_handlers);
	pad_released_handlers.removeAt(id);
	nil;
};

~midi_connect_slider = { arg f;
	var handler_id = slider_handler_id;
	slider_handler_id = slider_handler_id + 1;
	assert_is_function.value("midi_connect_slider", f);
	slider_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_slider = { arg id;
	assert_is_valid_id("midi_disconnect_slider", id, slider_handlers);
	slider_handlers.removeAt(id);
	nil;
};

~midi_connect_bend = { arg f;
	var handler_id = bend_handler_id;
	bend_handler_id = bend_handler_id + 1;
	assert_is_function.value("midi_connect_bend", f);
	bend_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_bend = { arg id;
	assert_is_valid_id("midi_disconnect_bend", id, bend_handlers);
	bend_handlers.removeAt(id);
	nil;
};

~midi_connect_raw = { arg f;
	var handler_id = raw_handler_id;
	raw_handler_id = raw_handler_id + 1;
	assert_is_function.value("midi_connect_raw", f);
	raw_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_raw = { arg id;
	assert_is_valid_id("midi_disconnect_raw", id, raw_handlers);
	raw_handlers.removeAt(id);
	nil;
};

~midi_connect_tick = { arg f;
	var handler_id = tick_handler_id;
	tick_handler_id = tick_handler_id + 1;
	assert_is_function.value("midi_connect_tick", f);
	tick_handlers.put(handler_id, f);
	handler_id;
};

~midi_disconnect_tick = { arg id;
	assert_is_valid_id("midi_disconnect_tick", id, tick_handlers);
	tick_handlers.removeAt(id);
	nil;
};

~midi_note_is_down = { arg note;
	var is_down = note_to_is_down.trueAt(note);
	if (is_down.isNil) {
		Error("In midi_mapping_note_is_down: argument % is note a valid note".format(note));
	} {
		is_down;
	};
};

~midi_is_valid_note = { arg note;
	note.includes(note);
};

~midi_is_midi_id_valid_note = { arg id;
	note_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
};

~midi_note_is_same = { arg a, b;
	var a_flat = note_identities.at(a);
	var b_flat = note_identities.at(b);

	a == b
		|| (a_flat.isNil.not && a_flat == b)
		|| (b_flat.isNil.not && b_flat == a)
	;
};

~midi_note_to_pitch = { arg note;
	if (~midi_is_valid_note.value(note).not) {
		Error("In note_to_pitch: argument % is not a valid note".format(note));
	};

	// TODO
};

~midi_pad_is_down = { arg pad;
	var is_down = pad_to_is_down.trueAt(pad);
	if (is_down.isNil) {
		Error("In midi_mapping_pad_is_down: argument % is pad a valid pad".format(pad));
	} {
		is_down;
	};
};

~midi_is_valid_pad = { arg pad;
	pads.includes(pad);
};

~midi_is_midi_id_valid_pad = { arg id;
	pad_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
};

~midi_slider_get_value = { arg slider_id;
	var value = slider_to_value.at(slider_id);
	if (value.isNil) {
		Error("In slider_get_value: argument % is not a valid slider id".format(slider_id));
	} {
		value;
	}
};

~midi_is_valid_slider = { arg slider;
	sliders.includes(slider);
};

~midi_is_midi_id_valid_slider = { arg id;
	slider_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
};

~midi_raw_get_value = { arg raw;
	var value = raw_to_value.at(raw);
	if (raw.inclusivelyBetween(0, 2**8).not) {
		Error("In raw_get_value: argument % is not a valid midi id".format(raw));
	} {
		value;
	}
};

~midi_is_valid_raw = { arg raw;
	raw_ranges.any({ arg range; raw.inclusivelyBetween(range[0], range[1]) });
};

/* internals */

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

    \C, \Cs, \Db, \D, \Ds, \Eb, \E, \F, \Fs, \Gb, \G, \Gs, \Ab, \A, \As, \Bb, \B,
]);

notes_in_order = Array.newFrom([
	\C1, \Cs1, \D1, \Ds1, \E1, \F1, \Fs1, \G1, \Gs1, \A1, \As1, \B1,
    \C2, \Cs2, \D2, \Ds2, \E2, \F2, \Fs2, \G2, \Gs2, \A2, \As2, \B2,
    \C3, \Cs3, \D3, \Ds3, \E3, \F3, \Fs3, \G3, \Gs3, \A3, \As3, \B3,
    \C4, \Cs4, \D4, \Ds4, \E4, \F4, \Fs4, \G4, \Gs4, \A4, \As4, \B4,
    \C5, \Cs5, \D5, \Ds5, \E5, \F5, \Fs5, \G5, \Gs5, \A5, \As5, \B5,
    \C6, \Cs6, \D6, \Ds6, \E6, \F6, \Fs6, \G6, \Gs6, \A6, \As6, \B6,
    \C7,
]);

note_identities = Dictionary.newFrom([
    \Db2, \Cs2,
	\Eb2, \Ds2,
	\Gb2, \Fs2,
	\Ab2, \Gs2,
	\Bb2, \As2,
    \Db3, \Cs3,
	\Eb3, \Ds3,
	\Gb3, \Fs3,
	\Ab3, \Gs3,
	\Bb3, \As3,
    \Db4, \Cs4,
	\Eb4, \Ds4,
	\Gb4, \Fs4,
	\Ab4, \Gs4,
	\Bb4, \As4,
    \Db5, \Cs5,
	\Eb5, \Ds5,
	\Gb5, \Fs5,
	\Ab5, \Gs5,
	\Bb5, \As5,
    \Db6, \Cs6,
	\Eb6, \Ds6,
	\Gb6, \Fs6,
	\Ab6, \Gs6,
	\Bb6, \As6,

	\C,  \C4,
    \Cs, \Cs4,
    \Db, \Cs4,
    \D,  \D4,
    \Ds, \Ds4,
    \Eb, \Ds4,
    \E,  \E4,
    \F,  \F4,
    \Fs, \Fs4,
    \Gb, \Fs4,
    \G,  \G4,
    \Gs, \Gs4,
    \Ab, \Gs4,
    \A,  \A4,
    \As, \As4,
    \Bb, \As4,
    \B,  \B4
]);

pads = Array.newFrom([
	\Pad01,
	\Pad02,
	\Pad03,
	\Pad04,
	\Pad05,
	\Pad06,
	\Pad07,
	\Pad08,
	\Pad09,
	\Pad10,
	\Pad11,
	\Pad12,
	\Pad13,
	\Pad14,
	\Pad15,
	\Pad16
]);

sliders = Array.newFrom([
	\Slider01,
	\Slider02,
	\Slider03,
	\Slider04,
	\Slider05,
	\Slider06,
	\Slider07,
	\Slider08,
	\Slider09,
	\Slider10,
	\Slider11,
	\Slider12,
	\Slider13,
	\Slider14,
	\Slider15,
	\Slider16
]);

if (true || MIDIClient.initialized.not) {
	MIDIClient.init;
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
				Error("In midi.scd: note range % is larger than the number of notes available, which is %.".format(range, notes_in_order.size));
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
				0, 2 ** 14, // bend is a 14-bit uint as per spec
				0, 1
			));
		});
	});

    tick_midi_func = MIDIFunc.midiClock({ arg tick;
		tick_handlers.do({ arg handler;
			handler.value(tick);
		})
	});

	fallback_midi_func_callback = { arg x, id, channel, source;
		var note, flat, velocity,
		    pad, pad_is_pressed, is_pad,
		    slider, slider_value, is_slider
		;

		"default: % % % %".format(x, id, channel, source).postln;

		if (x.notNil && id.notNil && channel.notNil && source.notNil) {
			if (~midi_is_midi_id_valid_note.value(id)) {
				// handled in noteOn, noteOff
			};

		    if (~midi_is_midi_id_valid_pad.value(id)) {
				pad = midi_id_to_pad.at(id);
				if (pad.notNil) {
					pad_is_pressed = x != 0; // 0 on release, 127 on press
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

			if (~midi_is_midi_id_valid_slider.value(id)) {
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
		\noteOn,    // note pressed
		\noteOff,   // note released
		\control,   // knobs, sliders, mod wheel, pedal
		\touch,     // aftertouch
		\polytouch, // polyphonic aftertouch
		\bend,      // pitch bend
		// \program,   // program change (patch selection)
		\sysrt,     // system real time messages
		\sysex,     // manufacturer-specific system message
		// \mtcQF,     // midi time code quarter frame
		// \smpte,     // midi time code full message
		// \songPosition, // sequencer position in quarter-step
		// \songSelect,   // sequence song
		// \tuneRequest,  // internal oscillator auto tune request
		// \midiClock,    // 24 times per quarter note
		// \tick,      // Sent 96 times per quarter note
		// \start,     // start playback from beginning
		// \continue,  // start playback from last position
		// \stop,      // pause / stop playback
		// \reset,     // request hardware system reset
		// \activeSense,  // midi node "keep alive" ping message
	].do({ arg type;
		fallback_midi_func.add(MIDIFunc(
			fallback_midi_func_callback,
			nil, // all messages
			nil, // all channels
			type,
			nil, // all uids
			nil
		));
	});
};

"midi.scd initialized."
