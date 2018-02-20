#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dump qw( dump );

my $usage = "$0 release-candidate-url\n";
my $release_candidate = shift(@ARGV) or die $usage;

my $PERL = $^X;

sub border {
    print '=' x 80, $/;
}

sub run {
    my $cmd = shift;
    print '-' x 80, "\n$cmd\n";
    system($cmd) and die "$cmd failed: $!";
}

sub mirror_dir {
    my $url = shift;
    run("wget -q -r --no-parent --reject 'index.html*' $url");
    ( my $dir = $url ) =~ s,^https?://,,;
    my @files = grep {chomp} `ls -1 $dir`;
    return {
        dir => $dir,
        rc  => ( grep {m/\.tar.gz$/} @files )[0],
        md5 => ( grep {m/\.tar.gz.md5$/} @files )[0],
        sha => ( grep {m/\.tar.gz.sha\d*$/} @files )[0],
        key => ( grep {m/\.tar.gz.asc$/} @files )[0],
    };
}

sub compare_md5 {
    my $files = shift;
    chdir( $files->{dir} );
    run("md5sum $files->{md5}");
}

sub compare_sha {
    my $files = shift;
    chdir( $files->{dir} );
    run("shasum -c $files->{sha}");
}

sub check_key {
    my $files = shift;
    run("gpg --verify $files->{key}");
}

sub test_lucy {
    my $files = shift;
    chdir( $files->{dir} );
    run("tar xfz $files->{rc}");
    ( my $pkg = $files->{rc} ) =~ s/\.tar.gz//;
    chdir($pkg) or die "can't chdir $pkg: $!";
    chdir('perl');
    run("perl Build.PL");
    run("./Build dist &>lucy-dist-output");
    my @contents = grep {chomp} `ls -1 .`;
    my $dist = ( grep {m/\.tar.gz$/} @contents )[0];
    ( my $dist_dir = $dist ) =~ s/\.tar.gz//;
    run("tar xfz $dist");
    chdir($dist_dir) or die "can't chdir $dist_dir: $!";
    run("perl Build.PL");
    run("./Build test >> lucy-test-out");
    print "Build test finished for $pkg\n";
}

sub test_clownfish {
    my $files = shift;
    chdir( $files->{dir} );
    run("tar xfz $files->{rc}");
    ( my $pkg = $files->{rc} ) =~ s/\.tar.gz//;
    chdir($pkg) or die "can't chdir $pkg: $!";
    chdir("runtime/perl") or die "can't chdir runtime/perl: $!";
    run("perl Build.PL");
    run("perl Build test >> clownfish-test-out");
    print "Build runtime/perl test finished for $pkg\n";

    if ( $ENV{INSTALL_CLOWNFISH} ) {
        run("sudo $PERL Build install");
        chdir("../../compiler/perl")
            or die "can't chdir ../../compiler/perl: $!";
        run("$PERL Build.PL");
        run("$PERL Build test");
        run("sudo $PERL Build install");
    }
}

my $files = mirror_dir($release_candidate);

#print dump($files);

border();
compare_md5($files);
border();
compare_sha($files);
border();
check_key($files);
border();
if ( $files->{rc} =~ m/clownfish/ ) {
    test_clownfish($files);
}
else {
    test_lucy($files);
}

