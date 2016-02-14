package DDG::Goodie::CheatSheets;
# ABSTRACT: Load basic cheat sheets from JSON files

use JSON::XS;
use DDG::Goodie;
use DDP;
use File::Find::Rule;
use JSON;

no warnings 'uninitialized';

zci answer_type => 'cheat_sheet';
zci is_cached   => 1;

# Instantiate triggers as defined in 'triggers.json', return a hash that
# allows category and/or cheat sheet look-up based on trigger.
sub generate_triggers {
    my $aliases = shift;
    my $triggers_json = share('triggers.json')->slurp();
    my $json_triggers = decode_json($triggers_json);
    my $trigger_lookup = make_all_triggers($aliases, $json_triggers);
    return $trigger_lookup;
}

sub make_all_triggers {
    my ($aliases, $spec_triggers) = @_;
    # This will contain the actual triggers, with the triggers as values and
    # the trigger positions as keys (e.g., 'startend' => ['foo'])
    my %triggers = ();
    # This will contain a lookup from triggers to categories and/or files.
    my $trigger_lookup = {};

    # Default settings for custom triggers.
    my %defaults = (
        require_name => 1,
        full_match   => 1,
    );

    while (my ($name, $trigger_setsh) = each $spec_triggers) {
        if ($name =~ /cheat_sheet$/) {
            my $file = $name =~ s/_cheat_sheet//r;
            $file =~ s/_/ /g;
            $file = $aliases->{$file};
            die "Bad ID: '$name'" unless defined $file;
            $name = $file;
        }
        while (my ($trigger_type, $triggersh) = each $trigger_setsh) {
            while (my ($trigger, $opts) = each $triggersh) {
                next if $opts == 0;
                # Normalize options to use default options where not provided.
                my %opts = %defaults;
                %opts = (%opts, %{$opts}) if ref $opts eq 'HASH';
                next if $opts{disabled};
                my $require_name = $opts{require_name};
                $triggers{$trigger_type}{$trigger} = 1;
                # In this case, we can only ever have one cheat sheet using
                # this particular trigger else the triggering would be ambiguous.
                unless ($require_name) {
                    warn "Overriding trigger '$trigger' with custom for '$name'"
                        if exists $trigger_lookup->{$trigger};
                    $trigger_lookup->{$trigger} = {
                        is_custom => 1,
                        file      => $name,
                        options   => \%opts,
                    };
                    next;
                }
                my %new_triggers = map { $_ => 1 }
                    (keys %{$trigger_lookup->{$trigger}}, $name);
                $trigger_lookup->{$trigger} = \%new_triggers;
            }
        }
    }
    while (my ($trigger_type, $triggers_a) = each %triggers) {
        triggers $trigger_type => (keys %{$triggers_a});
    }
    return $trigger_lookup;

}

# Parse the category map defined in 'categories.json'.
sub get_category_map {
    my $categories_json = share('categories.json')->slurp();
    my $categories = decode_json($categories_json);
    return $categories;
}

sub get_aliases {
    my @files = File::Find::Rule->file()
                                ->name("*.json")
                                ->in(share('json'));
    my %results;
    my $cheat_dir = File::Basename::dirname($files[0]);

    foreach my $file (@files) {
        open my $fh, $file or warn "Error opening file: $file\n" and next;
        my $json = do { local $/;  <$fh> };
        my $data = eval { decode_json($json) } or do {
            warn "Failed to decode $file: $@";
            next;
        };

        my $name = File::Basename::fileparse($file);
        my $defaultName = $name =~ s/-/ /gr;
        $defaultName =~ s/.json//;

        $results{$defaultName} = $file;

        if ($data->{'aliases'}) {
            foreach my $alias (@{$data->{'aliases'}}) {
                my $lc_alias = lc $alias;
                if (defined $results{$lc_alias}
                    && $results{$lc_alias} ne $file) {
                    my $other_file = $results{$lc_alias} =~ s/$cheat_dir\///r;
                    die "$name and $other_file both using alias '$lc_alias'";
                }
                $results{$lc_alias} = $file;
            }
        }
    }
    return \%results;
}

my $aliases = get_aliases();

my $category_map = get_category_map();

my $trigger_lookup = generate_triggers($aliases);

# Retrieve the categories that can trigger the given cheat sheet.
sub supported_categories {
    my $data = shift;
    my $template_type = $data->{template_type};
    my @additional_categories = @{$data->{categories}}
        if defined $data->{categories};
    my %categories = %{$category_map->{$template_type}};
    my @categories = (@additional_categories,
                      grep { $categories{$_} } (keys %categories));
    return @categories;
}

# Parse the JSON data contained within $file.
sub read_cheat_json {
    my $file = shift;
    open my $fh, $file or return;
    my $json = do { local $/;  <$fh> };
    my $data = decode_json($json);
    return $data;
}

# Attempt to retrieve the JSON data based on the used trigger.
sub get_cheat_json {
    my ($remainder, $req) = @_;
    my $trigger = $req->matched_trigger;
    my $file;
    my $lookup = $trigger_lookup->{$trigger};
    if ($lookup->{is_custom}) {
        return if $lookup->{options}{full_match} && $remainder ne '';
        $file = $lookup->{file};
        return read_cheat_json($file);
    } else {
        $file = $aliases->{join(' ', split /\s+/o, lc($remainder))} or return;
        my $data = read_cheat_json($file) or return;
        return $data if defined $lookup->{$file};
        my @allowed_categories = supported_categories($data);
        foreach my $category (@allowed_categories) {
            return $data if defined $lookup->{$category};
        }
    }
}

handle remainder => sub {
    my $remainder = shift;

    my $data = get_cheat_json($remainder, $req) or return;

    return 'Cheat Sheet', structured_answer => {
        id         => 'cheat_sheets',
        dynamic_id => $data->{id},
        name       => 'Cheat Sheet',
        data       => $data,
        templates  => {
            group   => 'base',
            item    => 0,
            options => {
                content => "DDH.cheat_sheets.detail",
                moreAt  => 0
            }
        }
    };
};

1;
