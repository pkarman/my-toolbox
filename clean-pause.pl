#!/usr/bin/env perl
# This code works for dagolden, based on a program originally by rjbs.  It
# might not work for you.  You are hereby empowered to do anything you want
# with this code, including fixing its bugs and redistributing it with your
# own license and API and whatever you want.  It'd be nice if you mentioned
# dagolden and rjbs in your fork, but if you don't want to, that's just fine.
#
# The only thing you can't do is act like there's some guarantee that this
# code will actually work or even refrain from blowing stuff up.  You're on
# your own. -- rjbs, 2014-04-23 and dagolden, 2016-07-06

use 5.014;
use strict;
use warnings;

use Carp;
use CPAN::DistnameInfo;
use WWW::Mechanize;
use IO::Prompt::Tiny qw/prompt/;

my %arg;

if (@ARGV) {
    die "usage: $0\n   or: $0 USER PASS\n" unless @ARGV == 2;
    @arg{qw(user password)} = @ARGV;
}

$arg{user}     //= prompt("username: ");
$arg{password} //= prompt("password: ");
$arg{user} = uc $arg{user};

my $username = $arg{user};

die "no username given" unless length $username;
die "no password given" unless length $arg{password};

my $mech = WWW::Mechanize->new;
$mech->credentials( $username, $arg{password} );

my $res =
  $mech->get(q{https://pause.perl.org/pause/authenquery?ACTION=delete_files});

my @files = grep { defined }
  map  { $_->possible_values }
  grep { $_->type eq 'checkbox' } $mech->form_number(1)->inputs;

my %found;

FILE: for my $file (@files) {
    next FILE if $file eq 'CHECKSUMS';

    my $path = sprintf "authors/id/%s/%s/%s/%s",
      substr( $username, 0, 1 ),
      substr( $username, 0, 2 ),
      $username,
      $file;

    my $dni;

    if ( $file =~ m{\.(readme|meta)\z} ) {
        my $ext = $1;
        ( my $fake = $path ) =~ s{\.$1\z}{.tar.gz};

        $dni = CPAN::DistnameInfo->new($fake);
    }
    else {
        $dni = CPAN::DistnameInfo->new($path);

        unless ( defined $dni->extension ) {
            warn "ignoring path with unknown extension: $path\n";
            next FILE;
        }
    }

    next if $dni->dist eq 'perl';

    my $by_name = $found{ $dni->dist } ||= {};
    my $version = $dni->version;
    die "No version found" unless length $version;
    $version =~ s/-TRIAL.*//;
    $version =~ s/_//g;
    die "No version parsed for " . $dni->pathname . " with version " . $dni->version
      unless eval { version->new($version); 1 };
    my $dist = $by_name->{$version} ||= { values => [] };
    push @{ $dist->{values} }, $file;
    $by_name->{$version}{is_trial} = ( $dni->version =~ /_|TRIAL/ ? 1 : 0 );
}

$mech->form_number(1);

my %ticked;

for my $key ( sort keys %found ) {
    my $dist  = $found{$key};
    my $count = 0;

    my @versions = map { $_->[1] }
      sort { $b->[0] <=> $a->[0] }
      map { [ version->new($_), $_ ] }
      keys %$dist;

    for my $version (@versions) {
        my $is_trial = $dist->{$version}{is_trial};

        # skip active TRIAL releases
        if ( $count == 0 && $is_trial ) {
            next;
        }

        # skip up to 3 stable releases
        if ( $count < 3 && !$is_trial ) {
            $count++;
            next;
        }

        # delete everything else
        for my $file ( @{ $dist->{$version}{values} } ) {
            say "scheduling $file for deletion";
            $ticked{$file}++;
            $dist->{$version}{delete} = 1;
        }
    }
}

say "Going to delete ", scalar keys %ticked, " files.";

my $ok = prompt( "Go ahead and delete them (y/n)?", "n" );

if ( $ok !~ /^y(?:es)?$/ ) {
    say "Aborting!";
    exit 1;
}

for my $input ( $mech->find_all_inputs( name => 'pause99_delete_files_FILE' ) ) {
    for my $val ( $input->possible_values ) {
        next if !defined $val || !$ticked{$val};
        $input->value($val);
        last;
    }
}

$mech->click('SUBMIT_pause99_delete_files_delete');

say "Done!";
