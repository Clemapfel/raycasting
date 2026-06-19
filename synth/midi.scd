var notes,
    note_identities,
    min_note_midi_id,
    max_note_midi_id,
    pads,
    note_to_midi_id,
    midi_id_to_note,

    note_to_is_down,

    assert_is_function,
    assert_is_valid_id,

    note_on_handlers,
    note_on_handler_id,
    note_off_handlers,
    note_off_handler_id,
    bend_handlers,
    bend_handler_id,

    note_on_midi_func,
    note_off_midi_func,
    bend_midi_func
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

~midi_connect_note_on = { arg f;
	var id = note_on_handler_id;
	note_on_handler_id = note_on_handler_id + 1;
	assert_is_function.value("midi_connect_note_one", f);
	note_on_handlers.put(id, f);
	id;
};

~midi_disconnect_note_on = { arg id;
	assert_is_valid_id("midi_disconnect_note_on", id, note_on_handlers);
	note_on_handlers.removeAt(id);
	nil;
};

~midi_connect_note_off = { arg f;
	var id = note_off_handler_id;
	note_off_handler_id = note_off_handler_id + 1;
	assert_is_function.value("midi_connect_note_off", f);
	note_off_handlers.put(id, f);
	id;
};

~midi_disconnect_note_off = { arg id;
	assert_is_valid_id("midi_disconnect_note_off", id, note_off_handlers);
	note_off_handlers.removeAt(id);
	nil;
};

~midi_connect_bend = { arg f;
	var id = bend_handler_id;
	bend_handler_id = bend_handler_id + 1;
	assert_is_function.value("midi_connect_bend", f);
	bend_handlers.put(id, f);
	id;
};

~midi_disconnect_bend = { arg id;
	assert_is_valid_id("midi_disconnect_bend", id, bend_handlers);
	bend_handlers.removeAt(id);
	nil;
};

~note_is_down = { arg note;
	var is_down = note_to_is_down.trueAt(note);
	if (is_down.isNil) {
		Error("In midi_mapping_note_is_down: argument % is note a valid note".format(note));
	} {
		is_down;
	};
};

~note_to_midi_id = { arg note;
	var key = note_to_midi_id.at(note);
	if (key.isNil) {
		Error("In midi_mapping_note_to_midi_mapping_key: argument % is note a valid note".format(note));
	} {
		key;
	};
};

~midi_id_to_note = { arg id;
	var note = midi_id_to_note.at(id);
	if (note.isNil) {
		Error("In midi_mapping_midi_mapping_key_to_note: argument % is note a valid midi_mapping key".format(id));
	} {
		note;
	};
};

~note_is_valid = { arg note;
	note_to_is_down.includes(note);
};

~note_is_same = { arg a, b;
	var a_flat = note_identities.at(a);
	var b_flat = note_identities.at(b);

	a == b
		|| (a_flat.isNil.not && a_flat == b)
		|| (b_flat.isNil.not && b_flat == a)
	;
};

/* internals */

note_on_handler_id = 0;
note_on_handlers = Dictionary.new;

note_off_handler_id = 0;
note_off_handlers = Dictionary.new;

bend_handler_id = 0;
bend_handlers = Dictionary.new;

notes = Array.newFrom([
    \C2, \Cs2, \D2, \Ds2, \E2, \F2, \Fs2, \G2, \Gs2, \A2, \As2, \B2,
    \C3, \Cs3, \D3, \Ds3, \E3, \F3, \Fs3, \G3, \Gs3, \A3, \As3, \B3,
    \C4, \Cs4, \D4, \Ds4, \E4, \F4, \Fs4, \G4, \Gs4, \A4, \As4, \B4,
    \C5, \Cs5, \D5, \Ds5, \E5, \F5, \Fs5, \G5, \Gs5, \A5, \As5, \B5,
    \C6, \Cs6, \D6, \Ds6, \E6, \F6, \Fs6, \G6, \Gs6, \A6, \As6, \B6,
    \C7,

	\C, \Cs, \D, \Ds, \E, \F, \Fs, \G, \Gs, \A, \As, \B,
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

min_note_midi_id = 36;
max_note_midi_id = 96;

if (MIDIClient.initialized.not) {
	MIDIClient.init;
	MIDIIn.connectAll;

	note_to_midi_id = Dictionary.new;
	midi_id_to_note = Dictionary.new;
	note_to_is_down = Dictionary.new;

	notes.size.do({ arg i;
		var midi_mapping_num = i + min_note_midi_id; // C3 midi_mapping offset
		var note = notes[i];
		note_to_midi_id.put(note, midi_mapping_num);
		midi_id_to_note.put(midi_mapping_num, note);
		note_to_is_down.put(note, false);
	});



	note_on_midi_func = MIDIFunc.noteOn({ arg velocity, value, channel, source;
		var note = midi_id_to_note.at(value);
		var flat = note_identities.at(note);

		// "noteOn : % % % %".format(velocity, value, channel, source).postln;

		note_to_is_down.put(note, true);

		if (flat.notNil) {
			note_to_is_down.put(flat, true);
		};

		note_on_handlers.do({ arg handler;
			handler.value(note);
		});
	});

	note_off_midi_func = MIDIFunc.noteOff({ arg velocity, value, channel, source;
		var note = midi_id_to_note.at(value);
		var flat = note_identities.at(note);

		// "noteOff: % % % %".format(velocity, value, channel, source).postln;

		note_to_is_down.put(note, false);
		if (flat.notNil) {
			note_to_is_down.put(flat, false);
		};

		note_off_handlers.do({ arg handler;
			handler.value(note);
		});
	});

	bend_midi_func = MIDIFunc.bend({ arg value, channel, source;

		// "bend: % % %".format(value, channel, source).postln;

		bend_handlers.postln;
		bend_handlers.do({ arg handler;
			handler.value(value.linlin(
				0, 2 ** 14, // bend is a 14-bit unsigned int
				0, 1
			));
		});
	});
};

"midi_mapping initialized."
