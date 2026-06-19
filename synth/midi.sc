var notes = [
    \C2, \Cs2, \D2, \Ds2, \E2, \F2, \Fs2, \G2, \Gs2, \A2, \As2, \B2,
    \C3, \Cs3, \D3, \Ds3, \E3, \F3, \Fs3, \G3, \Gs3, \A3, \As3, \B3,
    \C4, \Cs4, \D4, \Ds4, \E4, \F4, \Fs4, \G4, \Gs4, \A4, \As4, \B4,
    \C5, \Cs5, \D5, \Ds5, \E5, \F5, \Fs5, \G5, \Gs5, \A5, \As5, \B5,
    \C6, \Cs6, \D6, \Ds6, \E6, \F6, \Fs6, \G6, \Gs6, \A6, \As6, \B6,
    \C7
];

var note_identities = Dictionary.newFrom([
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
	\Bb6, \As6
]);

/*
 *
 */
MIDIMapping {

    // static
    classvar note_to_midi_id;
    classvar midi_id_to_note;
	classvar note_to_is_down;

	classvar note_on_midi_func;
	classvar note_off_midi_func;

    *initClass {
		if (MIDIClient.initialized.not) {
			MIDIClient.init;
			MIDIIn.connectAll;
		};

        note_to_midi_id = Dictionary.new;
        midi_id_to_note = Dictionary.new;
		note_to_is_down = Dictionary.new;

		notes.size.do({ arg i;
			var midi_num = i + 36; // C3 midi offset
			var note = notes[i];
			note_to_midi_id.put(note, midi_num);
			midi_id_to_note.put(midi_num, note);
			note_to_is_down.put(note, false);
        });

		note_on_midi_func = MIDIFunc.noteOn({ arg velocity, value, channel, source;
			var note = midi_id_to_note.at(value);
			var flat = note_identities.at(value);

			"% % % %".format(velocity, value, channel, source);

			note_to_is_down.put(note, true);

			if (flat.notNil) {
				note_to_is_down.put(flat, true);
			};
		});

		note_off_midi_func = MIDIFunc.noteOff({ arg velocity, value, channel, source;
			var note = midi_id_to_note.at(value);
			var flat = note_identities.at(value);

			"% % % %".format(velocity, value, channel, source);

			note_to_is_down.put(note, false);

			if (flat.notNil) {
				note_to_is_down.put(flat, false);
			};
		});
    }
};
