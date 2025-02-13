use v6;
use JSON::Fast;

use Agrammon::Formula::Compiler;
use Agrammon::Inputs;
use Agrammon::Formula::LogCollector;
use Agrammon::ModuleBuilder;
use Agrammon::ModuleParser;
use Agrammon::Model::FilterSet;
use Agrammon::Model::Module;
use Agrammon::Outputs;
use Agrammon::Preprocessor;

class X::Agrammon::Model::FileNotFound is Exception {
    has $.file;
    method message() {
        "Model file $!file not found!";
    }
}

class X::Agrammon::Model::FileNotReadable is Exception {
    has $.file;
    method message() {
        "Model file $!file not readable!";
    }
}

class X::Agrammon::Model::CircularModel is Exception {
    has $.module;
    method message() {
        "Module $!module has circular dependency!";
    }
}

role X::Agrammon::Model::BadFormula is Exception {
    has $.module;
    has $.output;
    method !prefix() {
        "Output '$!output' of module '$!module' "
    }
}

class X::Agrammon::Model::InvalidInput does X::Agrammon::Model::BadFormula {
    has $.input;
    method message() {
        self!prefix ~ "uses undeclared input '$!input'"
    }
}

class X::Agrammon::Model::InvalidTechnical does X::Agrammon::Model::BadFormula {
    has $.technical;
    method message() {
        self!prefix ~ "uses undeclared technical '$!technical'"
    }
}

class X::Agrammon::Model::InvalidOutputSymbol does X::Agrammon::Model::BadFormula {
    has $.from;
    has $.symbol;
    method message() {
        self!prefix ~ "uses undeclared output '$!symbol' from $!from"
    }
}

class X::Agrammon::Model::InvalidOutputModule does X::Agrammon::Model::BadFormula {
    has $.from;
    has $.symbol;
    method message() {
        self!prefix ~ "tries to use '$!symbol' from unknown module $!from (missing external?)"
    }
}

class Agrammon::Model {
    #| An annotated input brings together the static (from the model) and
    #| dynamic (from the data source) aspects of an input, for situations
    #| where we want to output a flattened list of inputs.
    class AnnotatedInput {
        has Agrammon::Model::Module $.module is required;
        has Str $.instance-id;
        has Agrammon::Model::Input $.input is required;
        has $.value is required;
        has %.gui-root is required;
    }

    my class ModuleRunner {
        has Agrammon::Model::Module $.module;
        has ModuleRunner @.dependencies;
        has Agrammon::Model::FilterSet $!filter-set;

        submethod TWEAK(--> Nil) {
            if $!module.is-multi {
                $!filter-set .= new(:$!module, :dependencies(@!dependencies.map(*.module)));
            }
        }

        method run(:$input!, :%technical!) {
            my $outputs = Agrammon::Outputs.new();
            my $*AGRAMMON-LOG = $outputs.log-collector;
            my %run-already;
            self!run-internal($input, %technical, $outputs, %run-already);
            return $outputs;
        }

        method !run-internal($input, %technical, $outputs, %run-already --> Nil) {
            my $tax = $!module.taxonomy;
            return if %run-already{$tax};
            if $!module.is-multi {
                # Run each module once by having a fresh copy of the run-already hash
                # instance. Then mark the whole graph as having run.
                $outputs.declare-multi-instance($tax);
                for $input.inputs-list-for($tax) -> $multi-input {
                    my %filters := $!filter-set.filters-for($multi-input);
                    my $*AGRAMMON-INSTANCE = $multi-input.instance-id;
                    my $multi-output = $outputs.new-instance($tax, $multi-input.instance-id, :%filters, :$!filter-set);
                    self!run-as-single($multi-input, %technical, $multi-output, %run-already.clone);
                }
                self!mark-multi-run(%run-already);
            }
            else {
                self!run-as-single($input, %technical, $outputs, %run-already);
                %run-already{$tax} = True;
            }
        }

        method !run-as-single($input, %technical, $outputs, %run-already --> Nil) {
            for @!dependencies -> $dep {
                $dep!run-internal($input, %technical, $outputs, %run-already);
            }
            my @gui = $!module.gui-root-module.gui.split(',') if $!module.gui-root-module;
            my $*AGRAMMON-TAXONOMY = my $tax = $!module.taxonomy;
            my %*AGRAMMON-GUI = %(:de(@gui[1]), :fr(@gui[2]), :en(@gui[3])) if @gui;
            my $env = Agrammon::Environment.new(
                    input => $input.input-hash-for($tax),
                    technical => $!module.technical-hash,
                    technical-override => %technical{$tax},
                    output => $outputs
                    );
            for $!module.output -> $output {
                my $*AGRAMMON-OUTPUT = my $name = $output.name;
                my $result = $output.compiled-formula()($env);
                if $result ~~ Rat && $result.denominator == 0 {
                    warn "ERROR: division by zero";
                    $outputs.add-output($tax, $name, 'ERROR: division by 0');
                }
                else {
                    $outputs.add-output($tax, $name, $result);
                }
                CONTROL {
                    when CX::Warn {
                        note "Warning evaluating output '$name' in $tax: $_.message()";
                        .resume;
                    }
                }
                CATCH {
                    die "Died when evaluating formula '$name' in $tax: $_.message()";
                }
            }
        }

        #| Perform a "run" of the model, but instead of actually running
        #| it, just collect all of the inputs.
        method annotate-inputs($input-data) {
            my %run-already;
            my @result;
            self!annotate-inputs-internal($input-data, %run-already, @result);
            return @result;
        }

        method !annotate-inputs-internal($input-data, %run-already, @result, Str $instance-id?) {
            my $tax = $!module.taxonomy;
            return if %run-already{$tax};
            my $gui-root-module = $!module.gui-root-module;
            my %gui-root;
            if $gui-root-module {
                # what a silly inline signaling
                my @g = $gui-root-module.gui.split(',');
                %gui-root = :de(@g[1]), :fr(@g[2]), :en(@g[3] // @g[0]), :raw(@g[0]);
            }
            if $!module.is-multi {
                for $input-data.inputs-list-for($tax) -> $multi-input {
                    my $instance-id = $multi-input.instance-id;
                    self!annotate-inputs-as-single($multi-input, %run-already.clone,
                            @result, %gui-root, $instance-id);
                }
                self!mark-multi-run(%run-already);
            }
            else {
                self!annotate-inputs-as-single($input-data, %run-already, @result, %gui-root, $instance-id);
                %run-already{$tax} = True;
            }
        }

        method !annotate-inputs-as-single($input-data, %run-already, @result, %gui-root, Str $instance-id?) {
            for @!dependencies -> $dep {
                $dep!annotate-inputs-internal($input-data, %run-already, @result, $instance-id);
            }
            my %input-data := $input-data.input-hash-for($!module.taxonomy);
            for $!module.input -> Agrammon::Model::Input $input {
                my $key = $input.name;
                my $value = %input-data{$key};
                @result.push: AnnotatedInput.new: :$!module, :$input, :$instance-id, :$value, :%gui-root;
            }
        }

        method !mark-multi-run(%run-already --> Nil) {
            %run-already{$!module.taxonomy} = True;
            for @!dependencies -> $dep {
                $dep!mark-multi-run(%run-already);
            }
        }
    }

    has IO::Path $.path;
    has %.preprocessor-options;
    has Agrammon::Model::Module @.evaluation-order;
    has Agrammon::Model::Module @.load-order;
    has Agrammon::ModuleBuilder $!module-builder = Agrammon::ModuleBuilder.new;
    has ModuleRunner $!entry-point;
    has %!output-unit-cache;
    has %!output-print-cache;
    has %!output-print-str-cache;
    has %!output-format-cache;
    has %!output-labels-cache;
    has %!output-order-cache;
    has $!distribution-map-cache;
    has $!index;

    method file2module($file) {
        my $module = $file;
        $module ~~ s:g|'/'|::|;
        $module ~~ s/\.nhd$//;
        return $module;
    }

    method module2file($module) {
        my $file = $module;
        $file ~~ s:g|'::'|/|;
        $file ~= '.nhd';
        return $!path.add($file);
    }

    method load-module($module-name) {
        my $file = self.module2file($module-name);
        die X::Agrammon::Model::FileNotFound.new(:$file)    unless $file.IO.e;
        die X::Agrammon::Model::FileNotReadable.new(:$file) unless $file.IO.r;

        {
            return Agrammon::ModuleParser.parse(
                    preprocess($file.slurp, %!preprocessor-options),
                    actions => $!module-builder
                    ).ast;
            CATCH {
                die "Failed to parse module $file:\n$_";
            }
        }
    }

    method load($module-name, :$compile-formulas = True --> Agrammon::Model) {
        $!entry-point = self!load-internal($module-name);
        self!sanity-check();
        self!compile-formulas() if $compile-formulas;
        return self;
    }

    method !load-internal($module-name, $root?, $root-module?, :%pending, :%loaded --> ModuleRunner) {
        # trying to load module while already loading it
        die X::Agrammon::Model::CircularModel.new(:module($module-name))
        if %pending{$module-name}:exists;

        # module has already been loaded
        return $_ with %loaded{$module-name};

        %pending{$module-name} = True;
        my $module = self.load-module($module-name);
        given $module.taxonomy -> $tax {
            die "Wrong taxonomy '$tax' in $module-name" unless $tax eq $module-name;
        }
        @!load-order.push($module);
        my $instance-root = $root;
        $instance-root //= $module.taxonomy if $module.is-multi;
        my $gui-root-module = $root-module;
        $gui-root-module = $module if $module.gui;
        $module.set-instance-root($instance-root) if $instance-root;
        $module.set-gui-root($gui-root-module) if $gui-root-module;
        my $parent = $module.parent;
        my @externals = $module.external;
        my @dependencies;
        for @externals -> $external {
            my $external-name = $external.name;
            my $include = $external-name.starts-with('::')
                    ?? $external-name.substr(2)
                    !! $parent
                    ?? normalize($parent ~ '::' ~ $external-name)
                    !! $external-name;
            push @dependencies, self!load-internal($include, $instance-root, $gui-root-module, :%pending, :%loaded);
        }
        @!evaluation-order.push($module);
        %pending{$module-name}:delete;

        my $evaluator = ModuleRunner.new(:$module, :@dependencies);
        %loaded{$module-name} = $evaluator;
        return $evaluator;
    }

    # Perform an abstract interpretation of the model, tracking outputs set,
    # in order to check for unknown outputs and outputs used too early.
    method !sanity-check() {
        my %known-outputs;
        for @!evaluation-order -> $module {
            my %known-input := set $module.input.map(*.name);
            my %known-technical := set $module.technical.map(*.name);
            my $tax = $module.taxonomy;
            %known-outputs{$tax} = {};

            for $module.output -> $output (:$name, :$formula, *%) {
                with $formula.input-used.first(* !(elem) %known-input) {
                    die X::Agrammon::Model::InvalidInput.new(
                            module => $module.taxonomy,
                            output => $output.name,
                            input => $_
                            );
                }

                with $formula.technical-used.first(* !(elem) %known-technical) {
                    die X::Agrammon::Model::InvalidTechnical.new(
                            module => $module.taxonomy,
                            output => $output.name,
                            technical => $_
                            );
                }

                for $formula.output-used -> $sym {
                    with %known-outputs{$sym.module} -> %module-outputs {
                        without %module-outputs{$sym.symbol} {
                            die X::Agrammon::Model::InvalidOutputSymbol.new(
                                    module => $module.taxonomy,
                                    output => $output.name,
                                    from => $sym.module,
                                    symbol => $sym.symbol
                                    );
                        }
                    }
                    else {
                        die X::Agrammon::Model::InvalidOutputModule.new(
                                module => $module.taxonomy,
                                output => $output.name,
                                from => $sym.module,
                                symbol => $sym.symbol
                                );
                    }
                }

                %known-outputs{$tax}{$name} = True;
            }
        }
    }

    method !compile-formulas() {
        my @targets;
        my @formula-sources;
        for @!evaluation-order -> $module {
            for $module.input -> $input {
                with $input.default-formula {
                    push @targets, $input;
                    push @formula-sources, compile-formula-to-source($input.default-formula);
                }
            }
            for $module.output -> $output {
                push @targets, $output;
                push @formula-sources, compile-formula-to-source($output.formula);
            }
        }
        use MONKEY-SEE-NO-EVAL;
        for flat @targets Z EVAL(@formula-sources.join(',')) -> $_, $compiled {
            when Agrammon::Model::Output {
                .compiled-formula = $compiled;
            }
            when Agrammon::Model::Input {
                .compiled-default-formula = $compiled;
            }
        }
    }

    sub normalize($module-name) {
        $module-name.subst(/'::' <.ident> '::..'/, '', :g)
    }

    #| Obtains a description of the structure of the model, accounting for multiple
    #| instance modules. The list returned contains single-instance modules as
    #| string names of their taxonomies. A multi-instance module root is a pair,
    #| where the key is the taxonomy name of the root of the multi-instance module
    #| and the value is an array of the modules within that instance.
    method extract-structure() {
        my @singles;
        my %multis;
        for @!evaluation-order -> Agrammon::Model::Module $module {
            if $module.instance-root -> $root {
                %multis{$root}.push($module.taxonomy);
            }
            else {
                @singles.push($module.taxonomy);
            }
        }
        [flat @singles, %multis.pairs]
    }

    method run(Agrammon::Inputs :$input!, :%technical --> Agrammon::Outputs) {
        $!entry-point.run(:$input, :%technical)
    }

    method annotate-inputs($input-data) {
        $!entry-point.annotate-inputs($input-data)
    }

    method dump(Str $sort, $language) {
        my Str $output;
        my \order = $sort eq 'calculation' ?? @!evaluation-order.reverse !! @!load-order;
        for order {
            my $level = .taxonomy.comb('::').elems;
            $output  ~= .taxonomy.indent(4 * $level);
            $output ~= '[]' if (.instance-root // '') eq .taxonomy;
            $output ~= "\n";
            for .input -> $input {
                $output  ~= $input.name.indent(4 * ($level + 1)) ~ "\n";
                $output  ~= $input.labels{$language}.indent(4 * ($level + 2))
                        ~ ' [' ~ ($input.units{$language} // '') ~ "]\n";

            }
        }
        return $output;
    }

    method dump-json(Str $sort, $language) {
        my %input-hash;
        my \order = $sort eq 'calculation' ?? @!evaluation-order.reverse !! @!load-order;
        for order {
            my @keys = .taxonomy.split('::');
            my $last = @keys.pop;
            my $cursor = %input-hash;
            for @keys -> $element {
                $cursor{$element} //= %();
                $cursor = $cursor{$element};
            }
            $cursor{$last}<instances> = True if .instances;
            if .input.elems {
                my @inputs;
                $cursor{$last}<inputs> = @inputs;
                for .input {
                    @inputs.push(.as-template-hash($language));
                }
            }
        }
        return to-json %input-hash;
    }

    method get-module(Str $taxonomy --> Agrammon::Model::Module) {
        self!index{$taxonomy} // fail "No such module '$taxonomy'"
    }

    method get-input(Str $taxonomy, Str $input --> Agrammon::Model::Input) {
        with self.get-module($taxonomy) -> Agrammon::Model::Module $module {
            with $module.input.first(*.name eq $input) {
                $_
            }
            else {
                fail "No such input '$input' on module '$taxonomy'";
            }
        }
        else {
            $_
            # The module lookup failure

        }
    }

    method !index() {
        without $!index {
            $!index = hash @!load-order.map: { .taxonomy => $_ };
        }
        $!index
    }

    method output-unit(Str $module, Str $output, Str $lang --> Str) {
        %!output-unit-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .units }))
        });
        return %!output-unit-cache{$module}{$output}{$lang} // ''
    }

    method output-units(Str $module, Str $output) {
        %!output-unit-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .units }))
        });
        return %!output-unit-cache{$module}{$output} // %()
    }

    method output-print(Str $module, Str $output) {
        %!output-print-str-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .print }))
        });
        return %!output-print-str-cache{$module}{$output} // ''
    }

    method should-print(Str $module, Str $output, @print-set) {
        %!output-print-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => (.split(',').List with .print) }))
        });
        !@print-set or (%!output-print-cache{$module}{$output}) ∩ @print-set
    }

    method output-format(Str $module, Str $output) {
        %!output-format-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .format }))
        });
        return %!output-format-cache{$module}{$output} // ''
    }

    method output-order(Str $module, Str $output) {
        %!output-order-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .order }))
        });
        return %!output-order-cache{$module}{$output} // ''
    }

    method output-labels(Str $module, Str $output) {
        %!output-labels-cache ||= @!evaluation-order.map({
            .taxonomy => %(.output.map({ .name => .labels }))
        });
        return %!output-labels-cache{$module}{$output} // %()
    }

    method distribution-map() {
        $!distribution-map-cache ||= do {
            my \distributables = gather {
                my %seen{ModuleRunner};
                sub walk-to-instance(ModuleRunner $current) {
                    if $current.module.is-multi {
                        walk-instance($current, $current.module.taxonomy);
                    }
                    else {
                        return if %seen{$current}++;
                        for $current.dependencies {
                            walk-to-instance($_);
                        }
                    }
                }
                sub walk-instance(ModuleRunner $current, Str $base) {
                    return if %seen{$current}++;
                    for $current.module.input {
                        if .is-distribute {
                            take $base => $current.module.taxonomy ~ '::' ~ .name;
                        }
                    }
                    for $current.dependencies {
                        if .module.taxonomy.starts-with($base) {
                            walk-instance($_, $base);
                        }
                    }
                }
                walk-to-instance($!entry-point);
            }
            my %result;
            distributables.categorize(*.key, :as(*.value), :into(%result))
        };
        %$!distribution-map-cache
    }
}
