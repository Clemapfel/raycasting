Pnew : Pbind {
    *new { |name ...pairs|
        ^super.new(*([\instrument, name] ++ pairs))
    }
}