use v6;
use Agrammon::Environment;
use Agrammon::Outputs::FilterGroupCollection;
use Agrammon::Formula;
use Agrammon::Formula::Compiler;
use Agrammon::Formula::Parser;
use Agrammon::Outputs;
use Test;

sub compile-and-evaluate($formula, $env) {
    compile-formula($formula)($env)
}

subtest {
    my $f = parse-formula('In(agricultural_area)', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 42 }
    ));
    is $result, 42, 'Correct result from evaluation';
}, 'In(...)';

subtest {
    my $f = parse-formula('In(agricultural_area);', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 42 }
    ));
    is $result, 42, 'Correct result from evaluation';
}, 'Semicolon at end of expression';

subtest {
    my $f = parse-formula('Tech(er_agricultural_area)', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, ('er_agricultural_area',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        technical => { er_agricultural_area => 101 }
    ));
    is $result, 101, 'Correct result from evaluation';
}, 'Tech(...)';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        Val(mineral_nitrogen_fertiliser_urea, PlantProduction);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 1, 'Have 1 output used';
    is @output-used[0].module, 'PlantProduction',
        'Correct output used module';
    is @output-used[0].symbol, 'mineral_nitrogen_fertiliser_urea',
        'Correct output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.add-output('PlantProduction', 'mineral_nitrogen_fertiliser_urea', 45);
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is $result, 45, 'Correct result from evaluation';
}, 'Val(...)';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'Livestock::DairyCow::Housing::Type');
        Val(dairy_cows, ..::Excretion);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 1, 'Have 1 output used';
    is @output-used[0].module, 'Livestock::DairyCow::Excretion',
        'Correct output used module';
    is @output-used[0].symbol, 'dairy_cows',
        'Correct output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.add-output('Livestock::DairyCow::Excretion', 'dairy_cows', 49);
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is $result, 49, 'Correct result from evaluation';
}, 'Val(...) with name using ..';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'Livestock::DairyCow::Housing::Type');
        Val(dairy_cows, ::Storage::Excretion);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 1, 'Have 1 output used';
    is @output-used[0].module, 'Storage::Excretion',
        'Correct output used module';
    is @output-used[0].symbol, 'dairy_cows',
        'Correct output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.add-output('Storage::Excretion', 'dairy_cows', 10);
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is $result, 10, 'Correct result from evaluation';
}, 'Val(...) with name with leading ::';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(agricultural_area) * Tech(er_agricultural_area);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('er_agricultural_area',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 3 },
        technical => { er_agricultural_area => 101 }
    ));
    is $result, 3 * 101, 'Correct result from evaluation';
}, 'Can parse/interpret * operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(solid_digestate) * Tech(er_solid_digestate) +
        In(compost) * Tech(er_compost);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('solid_digestate', 'compost',),
        'Correct inputs-used';
    is-deeply $f.technical-used, ('er_solid_digestate', 'er_compost'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { solid_digestate => 3, compost => 5 },
        technical => { er_solid_digestate => 10, er_compost => 4 }
    ));
    is $result, 3 * 10 + 5 * 4, 'Correct result from evaluation';
}, 'Correct precedence of * and + operators';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        Val(nh3_nmineralfertiliser, PlantProduction) +
        Val(nh3_nrecyclingfertiliser, PlantProduction::RecyclingFertiliser)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 2, 'Have 2 output used';
    is @output-used[0].module, 'PlantProduction',
        'Correct first output used module';
    is @output-used[0].symbol, 'nh3_nmineralfertiliser',
        'Correct first output used symbol';
    is @output-used[1].module, 'PlantProduction::RecyclingFertiliser',
        'Correct second output used module';
    is @output-used[1].symbol, 'nh3_nrecyclingfertiliser',
        'Correct second output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.add-output('PlantProduction', 'nh3_nmineralfertiliser', 12);
    $output.add-output('PlantProduction::RecyclingFertiliser', 'nh3_nrecyclingfertiliser', 15);
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is $result, 12 + 15, 'Correct result from evaluation';
}, 'Val(...) + Val(...)';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        $a = In(compost);
        my $b = In(compost);
        $b = $b + $b;
        $a * $b
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('compost',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { compost => 55 }
    ));
    is $result, 55 * (55 + 55), 'Correct result from evaluation';
}, 'Variable declaration, assignment, and lookup';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        3 * In(compost) + 20
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('compost',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { compost => 55 }
    ));
    is $result, 3 * 55 + 20, 'Correct result from evaluation';
}, 'Integer literals';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        2.5 * In(compost) + 1.0
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('compost',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { compost => 55 }
    ));
    is $result, 2.5 * 55 + 1.0, 'Correct result from evaluation';
}, 'Rational literals';

subtest {
    my $f = parse-formula('1e-8', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new());
    is $result, 1e-8, 'Correct result from evaluation';
}, 'Float literals';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        "foo\nbar\!"
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new());
    is $result, "foo\nbar!", 'Correct result from evaluation';
}, 'Double-quoted string literals';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        if (In(milk_yield) > Tech(standard_milk_yield)) {
            $a = Tech(a_high);
        }
        else {
            $a = Tech(a_low);
        }
        $a
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_high', 'a_low'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when if condition is true';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when if condition is false';
}, 'if/else construct with > operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        if (In(milk_yield) < Tech(standard_milk_yield)) {
            $a = Tech(a_low);
        }
        else {
            $a = Tech(a_high);
        }
        $a
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_low', 'a_high'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when if condition is false';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when if condition is true';
}, 'if/else construct with < operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        if (In(milk_yield) == Tech(standard_milk_yield)) {
            $a = Tech(a_high);
        }
        else {
            $a = Tech(a_low);
        }
        $a
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_high', 'a_low'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 55, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when if condition is true';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when if condition is false';
}, 'if/else construct with == operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        if (In(milk_yield) != Tech(standard_milk_yield)) {
            $a = Tech(a_low);
        }
        else {
            $a = Tech(a_high);
        }
        $a
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_low', 'a_high'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 55, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when if condition is false';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when if condition is true';
}, 'if/else construct with != operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(milk_yield) != Tech(standard_milk_yield)
            ? Tech(a_low)
            : Tech(a_high)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_low', 'a_high'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 55, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when condition is false';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when condition is true';
}, '... ? ... : ... construct';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(level) eq 'low'
            ? Tech(a_low)
            : Tech(a_high)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('level',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('a_low', 'a_high'), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'low' },
        technical => { a_high => 10, a_low => 5 }
    ));
    is $result-true, 5, 'Correct result when eq matches';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'high' },
        technical => { a_high => 10, a_low => 5 }
    ));
    is $result-false, 10, 'Correct result when eq does not match';
}, 'The string eq operator and string literals';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(level) ne 'low'
            ? Tech(a_high)
            : Tech(a_low)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('level',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('a_high', 'a_low'), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'high' },
        technical => { a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when ne does not match';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'low' },
        technical => { a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when ne matches';
}, 'The string ne operator and string literals';

subtest {
    my $f = parse-formula('return In(agricultural_area)', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 42 }
    ));
    is $result, 42, 'Correct result from evaluation';
}, 'Simple use of return in last statement';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(milk_yield) != Tech(standard_milk_yield)) {
            return Tech(a_low);
        }
        Tech(a_high)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_low', 'a_high'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 55, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'When condition false, get implicit end return value';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'When condition true, get early return value';
}, 'Early return from within a conditional';

subtest {
    my $f = parse-formula('return;', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new());
    nok $result.defined, 'Correct result from evaluation';
}, 'Empty return evalutes to Nil';

subtest {
    my $f = parse-formula('return (In(agricultural_area) + 2) * 3', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
            input => { agricultural_area => 42 }
            ));
    is $result, (42 + 2) * 3, 'Correct result from evaluation';
}, 'The return statement does not parse according to normal function rules';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        (In(solid_digestate) - Tech(er_solid_digestate)) /
        (In(compost) - Tech(er_compost));
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('solid_digestate', 'compost',),
        'Correct inputs-used';
    is-deeply $f.technical-used, ('er_solid_digestate', 'er_compost'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { solid_digestate => 100, compost => 13 },
        technical => { er_solid_digestate => 10, er_compost => 4 }
    ));
    is $result, (100 - 10) / (13 - 4), 'Correct result from evaluation';
}, 'Grouping parentheses and the - and / operators';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        # leading comment
        In(solid_digestate) * Tech(er_solid_digestate) # +
        #In(compost) * Tech(er_compost);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('solid_digestate',),
        'Correct inputs-used';
    is-deeply $f.technical-used, ('er_solid_digestate',),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { solid_digestate => 3 },
        technical => { er_solid_digestate => 10 }
    ));
    is $result, 3 * 10, 'Correct result from evaluation';
}, 'Comments';

subtest {
    my $f = parse-formula('In(solid_digestate) #comment', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('solid_digestate',),
        'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { solid_digestate => 3 }
    ));
    is $result, 3, 'Correct result from evaluation';
}, 'Comment without newline after it at end of formula';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        Sum(n_sol_excretion,Livestock::OtherCattle::Excretion )
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 1, 'Have 1 output used';
    is @output-used[0].module, 'Livestock::OtherCattle::Excretion',
        'Correct output used module';
    is @output-used[0].symbol, 'n_sol_excretion',
        'Correct output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.declare-multi-instance('Livestock::OtherCattle');
    my @values = 9, 3, 27, 4;
    for @values -> $value {
        given $output.new-instance('Livestock::OtherCattle', 'Cow ' ~ $++) {
            .add-output('Livestock::OtherCattle::Excretion', 'n_sol_excretion', $value);
        }
    }
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is +$result, ([+] @values), 'Correct result from evaluation';
}, 'Sum(...)';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        Out(mineral_nitrogen_fertiliser_urea);
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    my @output-used = $f.output-used;
    is @output-used.elems, 1, 'Have 1 output used';
    is @output-used[0].module, 'PlantProduction',
        'Correct output used module';
    is @output-used[0].symbol, 'mineral_nitrogen_fertiliser_urea',
        'Correct output used symbol';
    my $output = Agrammon::Outputs.new;
    $output.add-output('PlantProduction', 'mineral_nitrogen_fertiliser_urea', 89);
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(:$output));
    is $result, 89, 'Correct result from evaluation';
}, 'Out(...)';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        given (In(level)) {
            return Tech(a_low) when 'low';
            return Tech(a_mid) when 'middle';
            return Tech(a_high) when 'high';
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('level',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('a_low', 'a_mid', 'a_high'), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'low' },
        technical => { a_high => 20, a_mid => 10, a_low => 5 }
    ));
    is $result, 5, 'Correct result for first when';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'high' },
        technical => { a_high => 20, a_mid => 10, a_low => 5 }
    ));
    is $result, 20, 'Correct result for final when';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { level => 'middle' },
        technical => { a_high => 20, a_mid => 10, a_low => 5 }
    ));
    is $result, 10, 'Correct result for middle when';
}, 'The given block and statement modifier when';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(milk_yield) != 1 and In(milk_yield) != 2) {
            return 'yes';
        }
        else {
            return 'no'
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 1 }
    ));
    is $result, 'no', 'Correct result when false before and';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 2 }
    ));
    is $result, 'no', 'Correct result when false after and';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 3 }
    ));
    is $result, 'yes', 'Correct result when both true';
}, 'The infix and operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(milk_yield) == 1 or In(milk_yield) == 2) {
            return 'yes';
        }
        else {
            return 'no'
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 1 }
    ));
    is $result, 'yes', 'Correct result when true before or';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 2 }
    ));
    is $result, 'yes', 'Correct result when true after or';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 3 }
    ));
    is $result, 'no', 'Correct result when both false';
}, 'The infix or operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(milk_yield) != 1 && In(milk_yield) != 2) {
            return 'yes';
        }
        else {
            return 'no'
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 1 }
    ));
    is $result, 'no', 'Correct result when false before and';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 2 }
    ));
    is $result, 'no', 'Correct result when false after and';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 3 }
    ));
    is $result, 'yes', 'Correct result when both true';
}, 'The infix && operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(milk_yield) == 1 || In(milk_yield) == 2) {
            return 'yes';
        }
        else {
            return 'no'
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 1 }
    ));
    is $result, 'yes', 'Correct result when true before or';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 2 }
    ));
    is $result, 'yes', 'Correct result when true after or';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 3 }
    ));
    is $result, 'no', 'Correct result when both false';
}, 'The infix || operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        defined In(milk_yield) ? 'yes' : 'nope'
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 }
    ));
    is $result, "yes", 'Correct result from defined when value is defined';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => Nil }
    ));
    is $result, "nope", 'Correct result from defined when value is not defined';
}, 'defined <term>';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        In(milk_yield) // 1
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 }
    ));
    is $result, 55, 'Correct result when LHS is defined';
    $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => Nil }
    ));
    is $result, 1, 'Correct result when LHS is undefined';
}, 'The // operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        foo()
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $calls = 0;
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        builtins => { foo => sub { $calls++; return 42 } }
    ));
    is $calls, 1, 'Built-in function was called';
    is $result, "42", 'Result is return value of built-in function';
}, 'Call a simple built-in function without arguments';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        bar(In(n), Tech(s))
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('n',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('s',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my @args;
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        builtins => { bar => sub ($x, $str) { push @args, ($x, $str); return $str x $x } },
        input => { n => 3 },
        technical => { s => 'foo' }
    ));
    is @args.elems, 1, 'Built-in function was called';
    is @args[0][0], 3, 'Correct first argument';
    is @args[0][1], 'foo', 'Correct second argument';
    is $result, "foofoofoo", 'Result is return value of built-in function';
}, 'Call a simple built-in function with arguments In(...)/Tech(...) arguments';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        writeLog({
            en => 'hello',
            de => In(de),
            fr => Tech(fr)
        });
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my @args;
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        builtins => { writeLog => sub (%h) { push @args, %h; return 'logged' } },
        input => { de => 'hallo' },
        technical => { fr => 'salut' }
    ));
    is @args.elems, 1, 'Built-in function was called once';
    is-deeply @args[0], { en => 'hello', de => 'hallo', fr => 'salut' },
        'Correct hash passed as argument';
    is $result, "logged", 'Result is return value of built-in function';
}, 'Call a simple built-in function with a hash argument';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        writeLog({
            en => 'hello',
            de => In(de),
            fr => Tech(fr),
        });
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my @args;
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        builtins => { writeLog => sub (%h) { push @args, %h; return 'logged' } },
        input => { de => 'hallo' },
        technical => { fr => 'salut' }
    ));
    is @args.elems, 1, 'Built-in function was called once';
    is-deeply @args[0], { en => 'hello', de => 'hallo', fr => 'salut' },
        'Correct hash passed as argument';
    is $result, "logged", 'Result is return value of built-in function';
}, 'Call a simple built-in function with a hash argument with trailing comma';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        return Tech(fr) if In(de) eq 'hallo';
        return 'bonjour';
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'hallo' },
        technical => { fr => 'salut' }
    ));
    is $result-true, "salut", 'Correct result when if is true';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'guten tag' },
        technical => { fr => 'salut' }
    ));
    is $result-false, "bonjour", 'Correct result when if is false';
}, 'Statement modifier if';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        return Tech(fr) unless In(de) eq 'guten tag';
        return 'bonjour';
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'guten tag' },
        technical => { fr => 'salut' }
    ));
    is $result-true, "bonjour", 'Correct result when unless is true';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'hallo' },
        technical => { fr => 'salut' }
    ));
    is $result-false, "salut", 'Correct result when unless is false';
}, 'Statement modifier unless';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        if (In(de) eq 'fahrzeug') {
            return 'vehicle';
        }
        elsif (In(de) eq 'werkzeug') {
            return 'tool';
        }
        elsif (In(de) eq 'spielzeug') {
            return 'toy';
        }
        else {
            return 'thingy';
        }
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my %expect = fahrzeug => 'vehicle', werkzeug => 'tool',
                 spielzeug => 'toy', foo => 'thingy';
    for %expect.kv -> $de, $expect {
        my $result = compile-and-evaluate($f, Agrammon::Environment.new(
            input => { de => $de },
        ));
        is $result, $expect, 'Correct result';
    }
}, 'if/elsif/elsif/else';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        Tech(fr) . " = " . In(de)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'tag' },
        technical => { fr => 'jour' }
    ));
    is $result, "jour = tag", 'Correct result of concatenation';
}, 'The . concatenation operator';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        lc Tech(fr) . " = " . uc In(de)
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('de',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('fr',), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { de => 'Tag' },
        technical => { fr => 'Jour' }
    ));
    is $result, "jour = TAG", 'Correct result of concatenation';
}, 'The uc and lc case-change prefixes';

subtest {
    my $f = parse-formula('$TE->{"foo_" . In(thing)}', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('thing',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used (indirect no included)';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-aaa = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { thing => 'aaa' },
        technical => { foo_aaa => 13, foo_bbb => 12, }
    ));
    is $result-aaa, 13, 'Correct result from evaluation (1)';
    my $result-bbb = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { thing => 'bbb' },
        technical => { foo_aaa => 13, foo_bbb => 12, }
    ));
    is $result-bbb, 12, 'Correct result from evaluation (2)';
}, '$TE->{...} (indirect technical access)';

subtest {
    my $f = parse-formula('die "a painful death"', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used (indirect no included)';
    is-deeply $f.output-used, (), 'Correct output-used';
    throws-like { compile-and-evaluate($f, Agrammon::Environment.new()) },
        X::Agrammon::Formula::Died,
        message => "a painful death";
}, 'The die built-in works';

subtest {
    my $f = parse-formula('warn "a little warning"', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, (), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used (indirect no included)';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $warning;
    {
        compile-and-evaluate($f, Agrammon::Environment.new());
        CONTROL {
            when CX::Warn {
                $warning = .message;
                .resume;
            }
        }
    }
    is $warning, "a little warning", 'Correct warning message';
}, 'The warn built-in works';

subtest {
    my $f = parse-formula('In(agricultural_area);;', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 42 }
    ));
    is $result, 42, 'Correct result from evaluation';
}, 'Doubled-up semicolon at end is ignored';

subtest {
    my $f = parse-formula('In(agricultural_area),', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 42 }
    ));
    is $result, 42, 'Correct result from evaluation';
}, 'Trailing , for no particular reason, but some formulas do it';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $a;
        if (not In(milk_yield) > Tech(standard_milk_yield)) {
            $a = Tech(a_low);
        }
        else {
            $a = Tech(a_high);
        }
        $a
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('milk_yield',), 'Correct inputs-used';
    is-deeply $f.technical-used, ('standard_milk_yield', 'a_low', 'a_high'),
        'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-true = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 55 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-true, 10, 'Correct result when if condition is true';
    my $result-false = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { milk_yield => 35 },
        technical => { standard_milk_yield => 45, a_high => 10, a_low => 5 }
    ));
    is $result-false, 5, 'Correct result when if condition is false';
}, 'The not operator';

subtest {
    my $f = parse-formula('default { return In(agricultural_area); }', 'PlantProduction');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 142 }
    ));
    is $result, 142, 'Correct result from evaluation';
}, 'default { } block just runs the code within it';

subtest {
    my $f = parse-formula(q:to/FORMULA/, 'PlantProduction');
        my $result;
        given (In(agricultural_area)) {
            when 0 {
                $result = "nothing";
            }
            when 1 {
                $result = "something";
            }
            default {
                $result = "lots";
            }
            $result = "bug";
        }
        return $result;
        FORMULA
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('agricultural_area',), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result-first = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 0 }
    ));
    is $result-first, "nothing", 'Correct result from first when';
    my $result-second = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 1 }
    ));
    is $result-second, "something", 'Correct result from second when';
    my $result-default = compile-and-evaluate($f, Agrammon::Environment.new(
        input => { agricultural_area => 2 }
    ));
    is $result-default, "lots", 'Correct result from second when';
}, 'when/default blocks have correct behavior in leaving given';

subtest {
    my $f = parse-formula('In(fgc) P+ In(sv)', 'SomeTestModule');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('fgc', 'sv'), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
            input => {
                fgc => Agrammon::Outputs::FilterGroupCollection.from-scalar(37),
                sv => 5
            }
            ));
    isa-ok $result, Agrammon::Outputs::FilterGroupCollection;
    is $result.Numeric, 42, 'Correct result';
}, 'P+ upgrades scalar value on right side';

subtest {
    my $f = parse-formula('In(sv) P+ In(fgc)', 'SomeTestModule');
    ok $f ~~ Agrammon::Formula, 'Get something doing Agrammon::Formula from parse';
    is-deeply $f.input-used, ('sv', 'fgc'), 'Correct inputs-used';
    is-deeply $f.technical-used, (), 'Correct technical-used';
    is-deeply $f.output-used, (), 'Correct output-used';
    my $result = compile-and-evaluate($f, Agrammon::Environment.new(
        input => {
            fgc => Agrammon::Outputs::FilterGroupCollection.from-scalar(37),
            sv => 5
        }
    ));
    isa-ok $result, Agrammon::Outputs::FilterGroupCollection;
    is $result.Numeric, 42, 'Correct result';
}, 'P+ upgrades scalar value on left side';

done-testing;
