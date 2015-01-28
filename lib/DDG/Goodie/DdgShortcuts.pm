package DDG::Goodie::DdgShortcuts;
# ABSTRACT: Returns a cheat sheet for DuckDuckGo keyboard shortcuts

use DDG::Goodie;

zci answer_type => "ddg_shortcuts";
zci is_cached   => 1;

name "DDG_Shortcuts";
description "DuckDuckGo Shortcuts Cheat Sheet";
primary_example_queries "DuckDuckGo shortcuts", "shortcuts";
secondary_example_queries "keyboard shortcuts", "shortcuts cheatsheet";
category "cheat_sheets";
topics "computing", "geek", "trivia";
code_url "https://github.com/duckduckgo/zeroclickinfo-goodies/blob/master/lib/DDG/Goodie/DDGShortcuts.pm";
attribution github  => ['https://github.com/Qeole','Qeole'],
            twitter => ['https://twitter.com/qeole','Qeole'];

my @ddg_aliases = map { (
        $_ . " ",
        $_ . "'s ",
        $_ . "s "
    ) } (
    'duck duck go',
    'duckduck go',
    'duck duckgo',
    'duckduckgo',
    'ddg'
);
my @ddg_shortcuts_triggers = map { (
    $_.'cheatsheet',
    $_.'cheat sheet',
    $_.'keyboard shortcuts',
    $_.'shortcuts',
    $_.'shortcuts cheatsheet',
    $_.'shortcuts cheat sheet'
) } @ddg_aliases;

triggers startend => @ddg_shortcuts_triggers;

my $TEXT = scalar share('ddg_shortcuts.txt')->slurp,
my $HTML = scalar share('ddg_shortcuts.html')->slurp;

handle remainder => sub {

    ## DEGUG -- print all triggers
    #foreach (@ddg_shortcuts_triggers) {
    #    print "$_\n";
    #}
    
    return
        heading => "DuckDuckGo Shortcuts Cheat Sheet",
        answer  => $TEXT,
        html    => $HTML,
};

1;
