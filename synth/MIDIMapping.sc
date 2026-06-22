Notes {
    classvar
        <c0 = \C0, <cs0 = \Cs0, <db0 = \Db0, <d0 = \D0,
        <ds0 = \Ds0, <eb0 = \Eb0, <e0 = \E0, <f0 = \F0,
        <fs0 = \Fs0, <gb0 = \Gb0, <g0 = \G0, <gs0 = \Gs0,
        <ab0 = \Ab0, <a0 = \A0, <as0 = \As0, <bb0 = \Bb0,
        <b0 = \B0, <c1 = \C1, <cs1 = \Cs1, <db1 = \Db1,
        <d1 = \D1, <ds1 = \Ds1, <eb1 = \Eb1, <e1 = \E1,
        <f1 = \F1, <fs1 = \Fs1, <gb1 = \Gb1, <g1 = \G1,
        <gs1 = \Gs1, <ab1 = \Ab1, <a1 = \A1, <as1 = \As1,
        <bb1 = \Bb1, <b1 = \B1, <c2 = \C2, <cs2 = \Cs2,
        <db2 = \Db2, <d2 = \D2, <ds2 = \Ds2, <eb2 = \Eb2,
        <e2 = \E2, <f2 = \F2, <fs2 = \Fs2, <gb2 = \Gb2,
        <g2 = \G2, <gs2 = \Gs2, <ab2 = \Ab2, <a2 = \A2,
        <as2 = \As2, <bb2 = \Bb2, <b2 = \B2, <c3 = \C3,
        <cs3 = \Cs3, <db3 = \Db3, <d3 = \D3, <ds3 = \Ds3,
        <eb3 = \Eb3, <e3 = \E3, <f3 = \F3, <fs3 = \Fs3,
        <gb3 = \Gb3, <g3 = \G3, <gs3 = \Gs3, <ab3 = \Ab3,
        <a3 = \A3, <as3 = \As3, <bb3 = \Bb3, <b3 = \B3,
        <c4 = \C4, <cs4 = \Cs4, <db4 = \Db4, <d4 = \D4,
        <ds4 = \Ds4, <eb4 = \Eb4, <e4 = \E4, <f4 = \F4,
        <fs4 = \Fs4, <gb4 = \Gb4, <g4 = \G4, <gs4 = \Gs4,
        <ab4 = \Ab4, <a4 = \A4, <as4 = \As4, <bb4 = \Bb4,
        <b4 = \B4, <c5 = \C5, <cs5 = \Cs5, <db5 = \Db5,
        <d5 = \D5, <ds5 = \Ds5, <eb5 = \Eb5, <e5 = \E5,
        <f5 = \F5, <fs5 = \Fs5, <gb5 = \Gb5, <g5 = \G5,
        <gs5 = \Gs5, <ab5 = \Ab5, <a5 = \A5, <as5 = \As5,
        <bb5 = \Bb5, <b5 = \B5, <c6 = \C6, <cs6 = \Cs6,
        <db6 = \Db6, <d6 = \D6, <ds6 = \Ds6, <eb6 = \Eb6,
        <e6 = \E6, <f6 = \F6, <fs6 = \Fs6, <gb6 = \Gb6,
        <g6 = \G6, <gs6 = \Gs6, <ab6 = \Ab6, <a6 = \A6,
        <as6 = \As6, <bb6 = \Bb6, <b6 = \B6, <c7 = \C7,
        <cs7 = \Cs7, <db7 = \Db7, <d7 = \D7, <ds7 = \Ds7,
        <eb7 = \Eb7, <e7 = \E7, <f7 = \F7, <fs7 = \Fs7,
        <gb7 = \Gb7, <g7 = \G7, <gs7 = \Gs7, <ab7 = \Ab7,
        <a7 = \A7, <as7 = \As7, <bb7 = \Bb7, <b7 = \B7,
        <c8 = \C8, <cs8 = \Cs8, <db8 = \Db8, <d8 = \D8,
        <ds8 = \Ds8, <eb8 = \Eb8, <e8 = \E8, <f8 = \F8,
        <fs8 = \Fs8, <gb8 = \Gb8, <g8 = \G8, <gs8 = \Gs8,
        <ab8 = \Ab8, <a8 = \A8, <as8 = \As8, <bb8 = \Bb8,
        <b8 = \B8, <c9 = \C9,

        <c = \C, <cs = \Cs, <db = \Db, <d = \D,
        <ds = \Ds, <eb = \Eb, <e = \E, <f = \F,
        <fs = \Fs, <gb = \Gb, <g = \G, <gs = \Gs,
        <ab = \Ab, <a = \A, <as = \As, <bb = \Bb,
        <b = \B
    ;

    classvar <order;
    classvar <identities;
    classvar <all;
	classvar <pitch;

    *initClass {
        order = Array.newFrom([
            \C0, \Cs0, \D0, \Ds0, \E0, \F0, \Fs0, \G0, \Gs0, \A0, \As0, \B0,
            \C1, \Cs1, \D1, \Ds1, \E1, \F1, \Fs1, \G1, \Gs1, \A1, \As1, \B1,
            \C2, \Cs2, \D2, \Ds2, \E2, \F2, \Fs2, \G2, \Gs2, \A2, \As2, \B2,
            \C3, \Cs3, \D3, \Ds3, \E3, \F3, \Fs3, \G3, \Gs3, \A3, \As3, \B3,
            \C4, \Cs4, \D4, \Ds4, \E4, \F4, \Fs4, \G4, \Gs4, \A4, \As4, \B4,
            \C5, \Cs5, \D5, \Ds5, \E5, \F5, \Fs5, \G5, \Gs5, \A5, \As5, \B5,
            \C6, \Cs6, \D6, \Ds6, \E6, \F6, \Fs6, \G6, \Gs6, \A6, \As6, \B6,
            \C7, \Cs7, \D7, \Ds7, \E7, \F7, \Fs7, \G7, \Gs7, \A7, \As7, \B7,
            \C8, \Cs8, \D8, \Ds8, \E8, \F8, \Fs8, \G8, \Gs8, \A8, \As8, \B8,
            \C9
        ]);

        identities = Dictionary.newFrom([
            \Db0, \Cs0,
            \Eb0, \Ds0,
            \Gb0, \Fs0,
            \Ab0, \Gs0,
            \Bb0, \As0,
            \Db1, \Cs1,
            \Eb1, \Ds1,
            \Gb1, \Fs1,
            \Ab1, \Gs1,
            \Bb1, \As1,
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
            \Db7, \Cs7,
            \Eb7, \Ds7,
            \Gb7, \Fs7,
            \Ab7, \Gs7,
            \Bb7, \As7,
            \Db8, \Cs8,
            \Eb8, \Ds8,
            \Gb8, \Fs8,
            \Ab8, \Gs8,
            \Bb8, \As8,
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

        all = Set.newFrom([
            this.c0, this.cs0, this.db0, this.d0, this.ds0, this.eb0,
            this.e0, this.f0, this.fs0, this.gb0, this.g0, this.gs0,
            this.ab0, this.a0, this.as0, this.bb0, this.b0, this.c1,
            this.cs1, this.db1, this.d1, this.ds1, this.eb1, this.e1,
            this.f1, this.fs1, this.gb1, this.g1, this.gs1, this.ab1,
            this.a1, this.as1, this.bb1, this.b1, this.c2, this.cs2,
            this.db2, this.d2, this.ds2, this.eb2, this.e2, this.f2,
            this.fs2, this.gb2, this.g2, this.gs2, this.ab2, this.a2,
            this.as2, this.bb2, this.b2, this.c3, this.cs3, this.db3,
            this.d3, this.ds3, this.eb3, this.e3, this.f3, this.fs3,
            this.gb3, this.g3, this.gs3, this.ab3, this.a3, this.as3,
            this.bb3, this.b3, this.c4, this.cs4, this.db4, this.d4,
            this.ds4, this.eb4, this.e4, this.f4, this.fs4, this.gb4,
            this.g4, this.gs4, this.ab4, this.a4, this.as4, this.bb4,
            this.b4, this.c5, this.cs5, this.db5, this.d5, this.ds5,
            this.eb5, this.e5, this.f5, this.fs5, this.gb5, this.g5,
            this.gs5, this.ab5, this.a5, this.as5, this.bb5, this.b5,
            this.c6, this.cs6, this.db6, this.d6, this.ds6, this.eb6,
            this.e6, this.f6, this.fs6, this.gb6, this.g6, this.gs6,
            this.ab6, this.a6, this.as6, this.bb6, this.b6, this.c7,
            this.cs7, this.db7, this.d7, this.ds7, this.eb7, this.e7,
            this.f7, this.fs7, this.gb7, this.g7, this.gs7, this.ab7,
            this.a7, this.as7, this.bb7, this.b7, this.c8, this.cs8,
            this.db8, this.d8, this.ds8, this.eb8, this.e8, this.f8,
            this.fs8, this.gb8, this.g8, this.gs8, this.ab8, this.a8,
            this.as8, this.bb8, this.b8, this.c9, this.c, this.cs,
            this.db, this.d, this.ds, this.eb, this.e, this.f,
            this.fs, this.gb, this.g, this.gs, this.ab, this.a,
            this.as, this.bb, this.b
		]);

		// cf. https://en.wikipedia.org/wiki/Piano_key_frequencies
		pitch = Dictionary.new();
			\C0, 16.3516, \Cs0, 17.3239, \D0, 18.3540,
			\Ds0, 19.4454, \E0, 20.6017, \F0, 21.8268,
			\Fs0, 23.1247, \G0, 24.4997, \Gs0, 25.9565,
			\A0, 27.5000, \As0, 29.1352, \B0, 30.8677,

			\C1, 32.7032, \Cs1, 34.6478, \D1, 36.7081,
			\Ds1, 38.8909, \E1, 41.2034, \F1, 43.6535,
			\Fs1, 46.2493, \G1, 48.9994, \Gs1, 51.9131,
			\A1,  55.0000, \As1, 58.2705,
			\B1, 61.7354,

			\C2, 65.4064, \Cs2, 69.2957, \D2, 73.4162,
			\Ds2, 77.7817, \E2, 82.4069, \F2, 87.3071,
			\Fs2, 92.4986, \G2, 97.9989, \Gs2, 103.8262,
			\A2, 110.0000, \As2, 116.5409,
			\B2, 123.4708,

			\C3, 130.8128, \Cs3, 138.5913, \D3, 146.8324,
			\Ds3, 155.5635, \E3, 164.8138, \F3, 174.6141,
			\Fs3, 184.9972, \G3, 195.9977, \Gs3, 207.6523,
			\A3, 220.0000, \As3, 233.0819,
			\B3, 246.9417,

			\C4, 261.6256, \Cs4, 277.1826, \D4, 293.6648,
			\Ds4, 311.1270, \E4, 329.6276, \F4, 349.2282,
			\Fs4, 369.9944, \G4, 391.9954, \Gs4, 415.3047,
			\A4, 440.0000, \As4, 466.1638,
			\B4, 493.8833,

			\C5, 523.2511, \Cs5, 554.3653, \D5, 587.3295,
			\Ds5, 622.2540, \E5, 659.2551, \F5, 698.4565,
			\Fs5, 739.9888, \G5, 783.9909, \Gs5, 830.6094,
			\A5, 880.0000, \As5, 932.3275,
			\B5, 987.7666,

			\C6, 1046.5023, \Cs6, 1108.7305, \D6, 1174.6591,
			\Ds6, 1244.5079, \E6, 1318.5102, \F6, 1396.9129,
			\Fs6, 1479.9777, \G6, 1567.9817, \Gs6, 1661.2188,
			\A6, 1760.0000, \As6, 1864.6550,
			\B6, 1975.5332,

			\C7, 2093.0045, \Cs7, 2217.4610, \D7, 2349.3181,
			\Ds7, 2489.0159, \E7, 2637.0205, \F7, 2793.8259,
			\Fs7, 2959.9554, \G7, 3135.9635, \Gs7, 3322.4376,
			\A7, 3520.0000, \As7, 3729.3101,
			\B7, 3951.0664,

			\C8, 4186.0090, \Cs8, 4434.9221, \D8, 4698.6363,
			\Ds8, 4978.0317, \E8, 5274.0409, \F8, 5587.6517,
			\Fs8, 5919.9108, \G8, 6271.9270, \Gs8, 6644.8752,
			\A8, 7040.0000, \As8, 7458.6202,
			\B8, 7902.1328,

			\C9, 8372.0181
		]);

		// insert flats and unnumbered
		identities.keys.do({ arg key;
			this.pitch.put(key, this.pitch.at(this.identities.at(key)));
		});
    }

    *isValid { arg x;
        ^this.all.includes(x)
    }

	*isValidMidi { arg midi_id, note_range = (12 .. 120);
		^midi_id.inclusivelyBetween(
			note_range.at(0),
			note_range.at(note_range.size - 1)
		);
	}

    *isEqual { arg a, b;
        var a_mapped = this.identities.get(a);
        var b_mapped = this.identities.get(b);
        ^(a == b || a == b_mapped || b == a_mapped || a_mapped == b_mapped)
    }

	*midiToNote { arg midi_id, note_range = (12 .. 120);
		if (this.isValidMidi(midi_id, note_range).not) {
			Error("In Notes.midiToNote: midi id % is out of range".format(midi_id)).throw;
		};

		^this.order[midi_id - note_range.at(0)];
	}

	*midiToPitch { arg midi_id, note_range = (12 .. 120);
		if (this.isValidMidi(midi_id, note_range).not) {
			Error("In Notes.midiToNote: midi id % is out of range".format(midi_id)).throw;
		};

		^midi_id.midicps;
	}
}

Pads {
    classvar
        <pad_01 = \PAD_01, <pad_02 = \PAD_02,
        <pad_03 = \PAD_03, <pad_04 = \PAD_04,
        <pad_05 = \PAD_05, <pad_06 = \PAD_06,
        <pad_07 = \PAD_07, <pad_08 = \PAD_08,
        <pad_09 = \PAD_09, <pad_10 = \PAD_10,
        <pad_11 = \PAD_11, <pad_12 = \PAD_12,
        <pad_13 = \PAD_13, <pad_14 = \PAD_14,
        <pad_15 = \PAD_15, <pad_16 = \PAD_16;

    classvar <all;
    classvar <order;

    *initClass {
        all = Set.new();
        order = Array.newFrom([
            \PAD_01, \PAD_02, \PAD_03, \PAD_04, \PAD_05, \PAD_06, \PAD_07, \PAD_08,
            \PAD_09, \PAD_10, \PAD_11, \PAD_12, \PAD_13, \PAD_14, \PAD_15, \PAD_16
        ]);

        [
            this.pad_01, this.pad_02,
			this.pad_03, this.pad_04,
			this.pad_05, this.pad_06,
            this.pad_07, this.pad_08,
			this.pad_09, this.pad_10,
			this.pad_11, this.pad_12,
            this.pad_13, this.pad_14,
			this.pad_15, this.pad_16
        ].do({ arg pad_; all.add(pad_) });
    }

    *isValid { arg x;
        ^this.all.includes(x)
    }

    *isEqual { arg a, b;
        ^(a == b)
    }
}

Faders {
    classvar
        <fader_01 = \FADER_01, <fader_02 = \FADER_02,
        <fader_03 = \FADER_03, <fader_04 = \FADER_04,
        <fader_05 = \FADER_05, <fader_06 = \FADER_06,
        <fader_07 = \FADER_07, <fader_08 = \FADER_08,
        <fader_09 = \FADER_09, <fader_10 = \FADER_10,
        <fader_11 = \FADER_11, <fader_12 = \FADER_12,
        <fader_13 = \FADER_13, <fader_14 = \FADER_14,
        <fader_15 = \FADER_15, <fader_16 = \FADER_16;

    classvar <all;
    classvar <order;

    *initClass {
        all = Set.new();
        order = Array.newFrom([
            \FADER_01, \FADER_02, \FADER_03, \FADER_04, \FADER_05, \FADER_06,
            \FADER_07, \FADER_08, \FADER_09, \FADER_10, \FADER_11, \FADER_12,
            \FADER_13, \FADER_14, \FADER_15, \FADER_16
        ]);

        [
            this.fader_01,
			this.fader_02,
			this.fader_03,
			this.fader_04,
			this.fader_05,
			this.fader_06,
            this.fader_07,
			this.fader_08,
			this.fader_09,
			this.fader_10,
			this.fader_11,
			this.fader_12,
            this.fader_13,
			this.fader_14,
			this.fader_15,
			this.fader_16
        ].do({ arg fader; all.add(fader) });
    }

    *isValid { arg x;
        ^this.all.includes(x)
    }

    *isEqual { arg a, b;
        ^(a == b)
    }
}

/*
MIDIMapping {
    classvar <>pad_ranges, <>fader_ranges, <>note_ranges, <>raw_ranges;

    classvar note_to_midi_id, midi_id_to_note, note_to_is_down;
    classvar pad_to_midi_id, midi_id_to_pad, pad_to_is_down;
    classvar fader_to_midi_id, midi_id_to_fader, fader_to_value;
    classvar raw_to_value;

    classvar note_pressed_handlers, note_pressed_handler_id;
    classvar note_released_handlers, note_released_handler_id;
    classvar bend_handlers, bend_handler_id;
    classvar pad_pressed_handlers, pad_pressed_handler_id;
    classvar pad_released_handlers, pad_released_handler_id;
    classvar fader_handlers, fader_handler_id;
	classvar aftertouch_handlers, aftertouch_handler_id;
    classvar tick_handlers, tick_handler_id;
    classvar raw_handlers, raw_handler_id;

    classvar note_pressed_midi_func;
    classvar note_released_midi_func;
    classvar bend_midi_func;
    classvar tick_midi_func;
	classvar aftertouch_midi_func;
    classvar fallback_midi_func, fallback_midi_func_callback;

	classvar <>is_initialized = false;

    *initClass {
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

        fader_handler_id = 0;
        fader_handlers = Dictionary.new;

		aftertouch_handler_id = 0;
		aftertouch_handlers = Dictionary.new;

        raw_handler_id = 0;
        raw_handlers = Dictionary.new;

        tick_handler_id = 0;
        tick_handlers = Dictionary.new;
    }

    * init { arg note_ranges = #[[12, 120]], // C1 to C7
		         pad_ranges = #[[0, 15]], // 16 pads
		         fader_ranges = #[[16, 31], ]; // 16 faders

		note_ranges.do({ arg range;
			var n = range[1] - range[0] + 1;
			if (n != Notes.order.size) {
				Error("In MIDIMapping.init: note range % declares % notes, but should be of size %".format(range, n, Notes.order.size)).throw;
			};
		});
		this.note_ranges = note_ranges;

		pad_ranges.do({ arg range;
			var n = range[1] - range[0] + 1;
			if (n != Pads.order.size) {
				Error("In MIDIMapping.init: pad range % specifies % pads, but it should specify %".format(range, n, Pads.order.size)).throw;
			};
		});
		this.pad_ranges = pad_ranges;

		fader_ranges.do({ arg range;
			var n = range[1] - range[0] + 1;
			if (n != Faders.order.size) {
				Error("In MIDIMapping.init: fader range % specifies % notes, but it should specify %".format(range, n, Faders.order.size)).throw;
			};
		});
		this.fader_ranges = fader_ranges;

		// raw is always all messages
		this.raw_ranges = [[0, 255]];

		if (this.is_initialized) {
			^this;
		};

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
                var note = Notes.order[i];
                if (note.notNil) {
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
                var pad = Pads.order[i];
                if (pad.notNil) {
                    pad_to_midi_id.put(pad, pad_id);
                    midi_id_to_pad.put(pad_id, pad);
                    pad_to_is_down.put(pad, false);
                };
            });
        });

        fader_to_midi_id = Dictionary.new;
        midi_id_to_fader = Dictionary.new;
        fader_to_value = Dictionary.new;

        fader_ranges.do({ arg range;
            var count = range[1] - range[0] + 1;
            count.do({ arg i;
                var fader_id = range[0] + i;
                var fader = Faders.order[i];
                if (fader.notNil) {
                    fader_to_midi_id.put(fader, fader_id);
                    midi_id_to_fader.put(fader_id, fader);
                    fader_to_value.put(fader, 0);
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

		if (this.is_initialized.not) {
			note_pressed_midi_func = MIDIFunc.noteOn({ arg velocity, value, channel, source;
				var note = midi_id_to_note.at(value);
				var flat = Notes.identities.at(note);

				// "noteOn : % % % %".format(velocity, value, channel, source).postln;

				if (note.notNil) {
					note_to_is_down.put(note, true);

					if (flat.notNil) {
						note_to_is_down.put(flat, true);
					};

					note_pressed_handlers.do({ arg handler;
						handler.value(note, Notes.pitch.at(note));
					});
				};
			});

			note_released_midi_func = MIDIFunc.noteOff({ arg velocity, value, channel, source;
				var note = midi_id_to_note.at(value);
				var flat = Notes.identities.at(note);

				// "noteOff: % % % %".format(velocity, value, channel, source).postln;

				if (note.notNil) {
					note_to_is_down.put(note, false);
					if (flat.notNil) {
						note_to_is_down.put(flat, false);
					};

					note_released_handlers.do({ arg handler;
						handler.value(note, Notes.pitch.at(note));
					});
				};
			});

			bend_midi_func = MIDIFunc.bend({ arg value, channel, source;
				// "bend: % % %".format(value, channel, source).postln;
				if (value.notNil) {
				    bend_handlers.do({ arg handler;
						handler.value(value.linlin(
							0, 2 ** 14,
							-1, 1
						));
					});
				};
			});

			aftertouch_midi_func = MIDIFunc.polytouch({ arg value, channel, source;
				// "aftertouch: % % %".format(value, channel, source).postln;

				aftertouch_handlers.do({ arg handler;
					handler.value(value.linlin(
						0, 2 ** 14,
						0, 1
					));
				});
			});

			tick_midi_func = MIDIFunc.midiClock({ arg tick;
				// "tick %".format(tick).postln

				tick_handlers.do({ arg handler;
					handler.value(tick);
				});
			});

			fallback_midi_func_callback = { arg x, id, channel, source;
				var note, flat, velocity,
				pad, pad_is_pressed, is_pad,
				fader, fader_value, is_fader
				;

				// "default: % % % %".format(x, id, channel, source).postln;

				if (x.notNil && id.notNil && channel.notNil && source.notNil) {
					if (this.note_midi_id_is_valid(id)) {
						// handled in noteOn, noteOff
					};

					if (this.pad_midi_id_is_valid(id)) {
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

					if (this.fader_midi_id_is_valid(id)) {
						fader = midi_id_to_fader.at(id);
                        fader.postln;
						if (fader.notNil) {
							fader_value = x;
							fader_to_value.put(fader, fader_value);

							fader_handlers.do({ arg handler;
								handler.value(fader, fader_value);
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
				\noteOn,
				\noteOff,
				\bend,
				\control,
				\touch,
				\aftertouch,
				\bend,
				\sysrt,
				\sysex
			].do({ arg type;
				fallback_midi_func.add(MIDIFunc(
					fallback_midi_func_callback,
					nil, nil, type, nil, nil
				));
			});
		};

		this.is_initialized = true;
        "MIDIMapping initialized.".postln;
    }

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

    *connect_fader { arg f;
        var handler_id = fader_handler_id;
        fader_handler_id = fader_handler_id + 1;
        this.assert_is_function("connect_fader", f);
        fader_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_fader { arg id;
        this.assert_is_valid_id("disconnect_fader", id, fader_handlers);
        fader_handlers.removeAt(id);
        ^nil;
    }

	*connect_aftertouch { arg f;
        var handler_id = aftertouch_handler_id;
        aftertouch_handler_id = aftertouch_handler_id + 1;
        this.assert_is_function("connect_aftertouch", f);
        aftertouch_handlers.put(handler_id, f);
        ^handler_id;
    }

    *disconnect_aftertouch { arg id;
        this.assert_is_valid_id("disconnect_aftertouch", id, aftertouch_handlers);
        aftertouch_handlers.removeAt(id);
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

    *note_is_down { arg note;
        var is_down = note_to_is_down.trueAt(note);
        if (is_down.isNil) {
            Error("In note_is_down: argument % is not a valid note".format(note)).throw;
        } {
            ^is_down;
        };
    }

    *note_is_valid { arg note;
        ^Notes.isValid(note);
    }

    *note_midi_id_is_valid { arg id;
        ^note_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *note_is_same { arg a, b;
        ^Notes.isEqual(a, b);
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

    *pad_is_valid { arg pad;
        ^Pads.isValid(pad);
    }

    *pad_midi_id_is_valid { arg id;
        ^pad_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *fader_get_value { arg fader_id;
        var value = fader_to_value.at(fader_id);
        if (value.isNil) {
            Error("In fader_get_value: argument % is not a valid fader id".format(fader_id)).throw;
        } {
            ^value;
        }
    }

    *fader_is_valid { arg fader;
        ^Faders.isValid(fader);
    }

    *fader_midi_id_is_valid { arg id;
        ^fader_ranges.any({ arg range; id.inclusivelyBetween(range[0], range[1]) });
    }

    *raw_get_value { arg raw;
        var value = raw_to_value.at(raw);
        if (raw.inclusivelyBetween(0, 2**8).not) {
            Error("In raw_get_value: argument % is not a valid midi id".format(raw)).throw;
        } {
            ^value;
        }
    }

    *raw_is_valid { arg raw;
        ^raw_ranges.any({ arg range; raw.inclusivelyBetween(range[0], range[1]) });
    }
}
*/