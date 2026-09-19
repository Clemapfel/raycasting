LuaExport {
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

    pr_serialize { arg obj, seen, indent = "";
        var items, childIndent;

        if (obj.isNil) { ^"nil" };
        if (obj.isKindOf(Boolean)) { ^if(obj, "true", "false") };
		if (obj.isKindOf(Number)) { ^obj.asString }; // no escape
        if (obj.isKindOf(String)) { ^obj.asCompileString };
		if (obj.isKindOf(Symbol)) { ^obj.asString }; // no escape

        if (obj.isKindOf(Array)) {
            if (seen.includes(obj)) {
                Error("In LuaExport.serialize: cyclic reference in array detected").throw;
            };

            seen.add(obj);
            items = obj.collect { |item| this.pr_serialize(item, seen, indent) };
            seen.remove(obj);

            ^"{ " ++ items.join(", ") ++ " }";
        };

        if (obj.isKindOf(Dictionary)) {
            if (seen.includes(obj)) {
                Error("In LuaExport.serialize: cyclic reference in dictionary detected").throw;
            };

            if (obj.isEmpty) { ^"{}" };

            seen.add(obj);

            childIndent = indent ++ "    ";
            items = Array.new;

            obj.keysValuesDo { |key, val|
                var keyStr, valStr;
                if (key.isNil) {
                    Error("In LuaExport.serialize: invalid key %".format(key)).throw;
                };

				if (key.isKindOf(Symbol)) {
					keyStr = this.pr_serialize(key, seen, childIndent);
				} {
					keyStr = "[" ++ this.pr_serialize(key, seen, childIndent) ++ "]";
				};

                valStr = this.pr_serialize(val, seen, childIndent);
                items = items.add(childIndent ++ keyStr ++ " = " ++ valStr);
            };

            seen.remove(obj);
            ^"{\n" ++ items.join(",\n") ++ "\n" ++ indent ++ "}";
        };

        Error("In LuaExport.serialize: object of type % cannot be serialized".format(obj.class)).throw;
    }
}