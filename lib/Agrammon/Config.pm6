use v6;
use Config;

class Agrammon::Config {
    has %.general;
    has %.database;
    has %.gui;
    has %.model;
  
    method load(Str $path) {
        my $config = Config.new;
        $config.read($path);

        %!general  = $config<General>;
        %!database = $config<Database>;
        %!gui      = $config<GUI>;
        %!model    = $config<Model>;
    }

}
