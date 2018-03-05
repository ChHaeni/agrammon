use Agrammon::Environment;
use Agrammon::OutputReference;

role Agrammon::Formula {
    method evaluate(Agrammon::Environment --> Any) { ... }
    method input-used(--> List) { ... }
    method technical-used(--> List) { ... }
    method output-used(--> List) { ... }

    method !merge-inputs(*@merge) {
        list unique @merge
    }

    method !merge-technicals(*@merge) {
        list unique @merge
    }

    method !merge-outputs(*@merge) {
        list unique :by{ .module ~ '::' ~ .symbol }, @merge
    }
}

class Agrammon::Formula::In does Agrammon::Formula {
    has $.symbol;

    method evaluate(Agrammon::Environment $env) {
        $env.input{$!symbol}
    }

    method input-used() { ($!symbol,) }
    method technical-used() { () }
    method output-used() { () }
}

class Agrammon::Formula::Tech does Agrammon::Formula {
    has $.symbol;

    method evaluate(Agrammon::Environment $env) {
        $env.technical{$!symbol}
    }

    method input-used() { () }
    method technical-used() { ($!symbol,) }
    method output-used() { () }
}

class Agrammon::Formula::Val does Agrammon::Formula {
    has Agrammon::OutputReference $.reference;

    method evaluate(Agrammon::Environment $env) {
        $env.output{$!reference.module}{$!reference.symbol}
    }

    method input-used() { () }
    method technical-used() { () }
    method output-used() { ($!reference,) }
}

role Agrammon::Formula::BinOp does Agrammon::Formula {
    has Agrammon::Formula $.left;
    has Agrammon::Formula $.right;

    method input-used() {
        self!merge-inputs: $!left.input-used, $!right.input-used
    }

    method technical-used() {
        self!merge-technicals: $!left.technical-used, $!right.technical-used
    }

    method output-used() {
        self!merge-outputs: $!left.output-used, $!right.output-used
    }

    method prec() { ... }
    method assoc() { ... }
}

class Agrammon::Formula::BinOp::Multiply does Agrammon::Formula::BinOp {
    method prec() { 'u=' }
    method assoc() { 'left' }
    method evaluate(Agrammon::Environment $env) {
        $!left.evaluate($env) * $!right.evaluate($env)
    }
}

class Agrammon::Formula::BinOp::Add does Agrammon::Formula::BinOp {
    method prec() { 't=' }
    method assoc() { 'left' }
    method evaluate(Agrammon::Environment $env) {
        $!left.evaluate($env) + $!right.evaluate($env)
    }
}
