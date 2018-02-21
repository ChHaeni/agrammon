use v6;

class Agrammon::Model::Input {
    has Str $.name;
    has Str $.description;
    has Str $.type;         # XXX Should be something richer than Str
    has Str $.validator;    # XXX Should be something richer than Str
    has Str %.labels{Str};
    has Str %.units{Str};
    has Str %.help{Str};
}