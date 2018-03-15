use v6;
use Agrammon::Inputs;
use Text::CSV;

class Agrammon::DataSource::CSV {
    method read($fh) {
        my $csv = Text::CSV.new(sep => ";");
        return gather {
            my $prev;
            my @group;
            while $csv.getline($fh) -> @row {
                $prev //= @row[1];
                if $prev && @row[1] ne $prev {
                    take self!group-input(@group);
                    @group = ();
                }
                push @group, @row;
                $prev = @row[1];
            }
            take self!group-input(@group) if @group;
        }
    }

    method !group-input(@group) {
        my $input = Agrammon::Inputs.new;
        for @group {
            $input.add-single-input(.[2], .[3], +.[4] // .[4]);
        }
        return $input;
    }
}
