LuaExport {
	classvar indent = "    ";
    var <>data;

    *new { arg server;
        ^super.new.init(server);
    }

    init {
        data = Dictionary.new;
        ^this;
    }

    pr_assertLuaType { arg scope, value;
        if (value.isKindOf(Array)) {
            value.do { |item| this.pr_assertLuaType(scope, item) };
            ^true;
        } {
            if (value.isKindOf(Dictionary)) {
                value.keysValuesDo { |key, val|
                    this.pr_assertLuaType(scope, key);
                    this.pr_assertLuaType(scope, val);
                };
                ^true;
            } {
                if (value.isKindOf(Number)
                    or: { value.isKindOf(String) }
                    or: { value.isKindOf(Boolean) }
					or: { value.isKindOf(Symbol) }
                    or: { value.isNil }
                ) {
                    ^true;
                } {
                    Error("In LuaExport.%: object % is not a valid lua type".format(scope, value)).throw;
                    ^false;
                };
            };
        };
    }

    at { arg key;
        this.pr_assertLuaType("at", key);
        ^data.at(key);
    }

    put { arg key, value;
        this.pr_assertLuaType("put", key);
        this.pr_assertLuaType("put", value);
        ^data.put(key, value);
    }

    serialize { arg prefixReturn = true;
        var result;
        var seen = IdentitySet.new;

        result = this.pr_serialize(data, seen);

        if (prefixReturn) {
            ^"return " ++ result;
        } {
            ^result;
        };
    }

    pr_serialize { arg x, seen, indent = "";
        var items, childIndent;

        if (x.isNil) { ^"nil" };
        if (x.isKindOf(Boolean)) { ^if(x, "true", "false") };
		if (x.isKindOf(Number)) { ^x.asString };
		if (x.isKindOf(String)) { ^x.asCompileString }; // escape special characters, add ""
		if (x.isKindOf(Symbol)) { ^x.asString };

        if (x.isKindOf(Array)) {
            if (seen.includes(x)) {
                Error("In LuaExport.serialize: cyclic reference in array detected").throw;
            };

            seen.add(x);
            items = x.collect { |item| this.pr_serialize(item, seen, indent) };
            seen.remove(x);

            ^"{ " ++ items.join(", ") ++ " }";
        };

        if (x.isKindOf(Dictionary)) {
			if (seen.includes(x)) {
				Error("In LuaExport.serialize: cyclic reference in dictionary detected").throw;
			};

			if (x.isEmpty) { ^"{}" };

			seen.add(x);

			childIndent = indent ++ LuaExport.indent;

			items = x.asAssociations.collect { |assoc|
				var key, val, keyString, valueString;
				key = assoc.key;
				val = assoc.value;
				if (key.isNil) {
					Error("In LuaExport.serialize: invalid key %".format(key)).throw;
				};

				if (key.isKindOf(Symbol)) {
					keyString = this.pr_serialize(key, seen, childIndent);
				} {
					keyString = "[" ++ this.pr_serialize(key, seen, childIndent) ++ "]";
				};

				valueString = this.pr_serialize(val, seen, childIndent);
				childIndent ++ keyString ++ " = " ++ valueString;
			};

			seen.remove(x);
			^"{\n" ++ items.join(",\n") ++ "\n" ++ indent ++ "}";
		};

        Error("In LuaExport.serialize: object of type % cannot be serialized".format(x.class)).throw;
    }

	write { arg path;
		var file = File(path, "w");

		if (file.isOpen.not) {
			Error("In LuaExport.writeTo: unable to open file for writing at %".format(path)).throw;
		};

		if (path.endsWith(".lua").not) {
			"In LuaExport.writeTo: path does not end in `.lua`".warn;
		};

		file.write(this.serialize(true));
		file.close;

		^this;
	}
}