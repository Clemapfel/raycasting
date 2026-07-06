MIDIInterface {
    var <server;
	var <bends;
    var <cc_spec;
	var <bend_spec;
    var <id_to_bus, <id_to_spec, <id_to_midi_def;

	var <>sliders, <>knobs, <>enable_logging = true;

    *new { arg server;
        ^super.new.init(server);
    }

    init { arg server;
		server = server ?? { Server.default };

        sliders = Pseq((110 .. 117), inf).asStream;
        knobs = Pseq((102 .. 109), inf).asStream;
        bends = Pseq((0 .. 15), inf).asStream;

        cc_spec = ControlSpec(0, 2**7, \lin);
		bend_spec = ControlSpec(0, 2**14, \lin);

        id_to_bus = IdentityDictionary.new;
        id_to_spec = IdentityDictionary.new;
        id_to_midi_def = IdentityDictionary.new;

		MIDIClient.init;
		MIDIIn.connectAll;
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

				if (this.enable_logging) { "[MIDI] % = %".format(id, mapped).postln; };
                bus.set(unmapped);
            }, slider)
        );
    }

    get_cc { arg id;
        ^id_to_spec.at(id).map(In.kr(id_to_bus.at(id)));
    }

    get_cc_raw { arg id;
        ^id_to_spec.at(id).map(id_to_bus.at(id).getSynchronous);
    }


    set_cc { arg id, value;
        id_to_bus.at(id).setSynchronous(id_to_spec.at(id).unmap(value));
	    if (this.enable_logging) { "[MIDI] % = %".format(id, value).postln; };
    }

    register_bend { arg id, lower = 0, upper = 1, easing = \lin;
        var bend, bus;

        bend = bends.next;
        bus = Bus.control(server, 1);

        id_to_bus.put(id, bus);
        id_to_spec.put(id, ControlSpec(lower, upper, easing));

        id_to_midi_def.put(
            id,
            MIDIdef.bend(id, { arg value, channel, source;
                var unmapped, mapped;

                unmapped = bend_spec.unmap(value);
                mapped = id_to_spec.at(id).map(unmapped);

                "% : %".format(id, mapped).postln;
                bus.set(unmapped);
            }, bend)
        );
    }

    get_bend { arg id;
        ^id_to_spec.at(id).map(In.kr(id_to_bus.at(id)));
    }

    get_bend_raw { arg id;
        ^id_to_spec.at(id).map(id_to_bus.at(id).getSynchronous);
    }

    set_bend { arg id, value;
        id_to_bus.at(id).setSynchronous(id_to_spec.at(id).unmap(value));
        "% : %".format(id, value).postln;
    }

    free {
        id_to_bus.do({ arg bus; bus.free });
        id_to_midi_def.do({ arg mdef; mdef.free });

        id_to_bus.clear;
        id_to_spec.clear;
        id_to_midi_def.clear;
    }
}