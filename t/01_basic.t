use strict;
use warnings;
use Test::More;
use Pipes;
use File::Temp ();
use Time::HiRes ();

my $subtest = sub {
    my $number_of_pipes = shift;
    my $tempdir = File::Temp::tempdir(CLEANUP => 1);

    my $pipes = Pipes->new($number_of_pipes, sub {
        my $num = $_[0]->{i};
        Time::HiRes::sleep(0.01);
        open my $fh, ">>", "$tempdir/file.$$" or die;
        print {$fh} "$num\n";
    });

    for my $i (1..30) {
        my @ready = $pipes->is_ready;
        $_->read for grep $_->is_written, @ready;
        $ready[0]->write({i => $i});
    }
    sleep 1;

    my @file = glob "$tempdir/file*";
    my @num;
    for my $f (@file) {
        open my $fh, "<", $f or die;
        chomp(my @n = <$fh>);
        push @num, @n;
    }
    @num = sort { $a <=> $b } @num;

    is @file, $number_of_pipes;
    is_deeply \@num, [1..30];

    if ($number_of_pipes == 1) {
        is $file[0], "$tempdir/file.$$";
    }

    $pipes->close;
};

subtest number_of_pipes1 => sub { $subtest->(1) };
subtest number_of_pipes5 => sub { $subtest->(5) };

done_testing;
