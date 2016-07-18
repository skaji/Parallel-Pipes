# NAME

Workers - Blah blah blah

# SYNOPSIS

    use Workers;

    my $master;
    my $workers = Workers->new(5, sub {
        my $job = shift;
        # do work
        my $result = {};
        return $result;
    });

    while (1) {
        if (my @job = $master->get_job) {
            my @ready = $workers->wait;
            $master->register($_->result) for grep $_->has_result, @ready;
            my $n = @job < @ready ? $#job : $#ready;
            map { $ready[$_]->work($job[$_]) } 0 .. $n;
        } else {
            last unless $workers->is_running;
            $workers->wait;
        }
    }

    while (my @job = $master->get_job) {
        my @ready = $workers->wait;
        $master->register($_->result) if grep $_->has_result, @ready;
        my $n = @job < @ready ? $#job : $#ready;
        map { $ready[$_]->work($job[$_]) } 0 .. $n;
    }

    $workers->shutdown;

# DESCRIPTION

Workers is

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
