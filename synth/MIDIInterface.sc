MIDIInterface {
	var <server;
	var <pads;
	var <cc_spec;
	var <bend_spec;
	var <velocity_spec;
	var <id_to_bus, <id_to_spec, <id_to_midi_def;
	var <>sliders, <>knobs, <>enable_logging = true;
	var <note_to_is_down;
	var <bend_bus;
	var <state_midi_defs;
	*new { arg server;
		^super.new.init(server);
	}
	init { arg server;
		server = server ?? { Server.default };
		sliders = Pseq((110 .. 117), inf).asStream;
		knobs = Pseq((102 .. 109), inf).asStream;
		pads = Pseq([3, 4, 5, 6]).asStream;

		cc_spec = ControlSpec(0, 2**7, \lin);
		bend_spec = ControlSpec(0, 2**14, \lin);
		velocity_spec = ControlSpec(0, 127, \lin);

		id_to_bus = IdentityDictionary.new;
		id_to_spec = IdentityDictionary.new;
		id_to_midi_def = IdentityDictionary.new;
		note_to_is_down = IdentityDictionary.new;

		MIDIClient.init;
		MIDIIn.connectAll;

		bend_bus = Bus.control(server, 1);
		bend_bus.set(0);

		state_midi_defs = [
			MIDIdef.bend(\midi_interface_bend_state, { arg value;
				bend_bus.set(value);
			}),
			MIDIdef.noteOn(\midi_interface_note_on_state, { arg veloc, num, channel, source;
				note_to_is_down.put(num, true);
			}),
			MIDIdef.noteOff(\midi_interface_note_off_state, { arg veloc, num, channel, source;
				note_to_is_down.put(num, false);
			}),
		];
		/*
		MIDIFunc.cc({ arg value, num, channel, source;
			num.postln;
		});
		*/
	}

	register_cc { arg id, lower = 0, upper = 1, easing = \lin, slider;
		var bus;
		slider = slider ?? { sliders.next };
		bus = Bus.control(server, 1);
		id_to_bus.put(id, bus);
		id_to_spec.put(id, ControlSpec(lower, upper, easing));
		id_to_midi_def.put(
			id,
			MIDIdef.cc(id, { arg value, num, channel, source;
				var unmapped, mapped;
				unmapped = cc_spec.unmap(value);
				mapped = id_to_spec.at(id).map(unmapped);
				if (this.enable_logging) { "[MIDI] % = %".format(id, unmapped).postln; };
				bus.set(unmapped);
			}, slider)
		);
	}

	unregister_cc { arg id;
		id_to_bus.removeAt(id) !? (_.free);
		id_to_spec.removeAt(id);
		id_to_midi_def.removeAt(id) !? (_.free);
	}

	get_cc { arg id;
		^id_to_spec.at(id).map(In.kr(id_to_bus.at(id)));
	}

	get_cc_raw { arg id;
		^id_to_spec.at(id).map(id_to_bus.at(id).getSynchronous);
	}

	get_bend {
		^bend_spec.map(bend_bus.getSynchronous);
	}

	get_note_on { arg id;
		^note_to_is_down.at(id) ? false;
	}

	get_note_off { arg id;
		^(note_to_is_down.at(id) ? false).not;
	}

	connect_bend { arg id, callback;
		id_to_midi_def.put(
			id,
			MIDIdef.bend(id, { arg value;
				var mapped = this.bend_spec.map(value);
				if (this.enable_logging) { "[MIDI] % : %".format(id, value).postln; };
				callback.(mapped);
			});
		);
	}

	disconnect_bend { arg id;
		id_to_midi_def.removeAt(id) !? (_.free);
	}

	connect_note_on { arg id, callback;
		id_to_midi_def.put(
			id,
			MIDIdef.noteOn(id, { arg value, unused, velocity;
				if (this.enable_logging) { "[MIDI] % : % %".format(id, value, velocity).postln; };
				callback.(value, this.velocity_spec.map(velocity));
			});
		);
	}

	connect_note_off { arg id, callback;
		id_to_midi_def.put(
			id,
			MIDIdef.noteOff(id, { arg value;
				if (this.enable_logging) { "[MIDI] % : %".format(id, value).postln; };
				callback.(value);
			});
		);
	}
	disconnect_note_on { arg id;
		id_to_midi_def.removeAt(id) !? (_.free);
	}
	disconnect_note_off { arg id;
		id_to_midi_def.removeAt(id) !? (_.free);
	}
	free {
		id_to_bus.do({ arg bus; bus.free });
		id_to_midi_def.do({ arg mdef; mdef.free });
		state_midi_defs.do({ arg mdef; mdef.free });
		bend_bus.free;
		id_to_bus.clear;
		id_to_spec.clear;
		id_to_midi_def.clear;
	}
}