# NAME

Workers - Blah blah blah

# SYNOPSIS

    use Workers;

    my $master = Your::Master->new;

    my $workers = Workers->new(5, sub {
        my $job = shift;
        # do work
        my $result = {};
        return $result;
    });

    # wrap Master's get_job
    my $get_job; $get_job = sub {
      my $self = shift;
      if (my @job = $self->get_job) {
        return @job;
      }
      return unless my @running = $workers->is_running;
      my @ready = $workers->wait(@running);
      $master->register($_->result) for grep $_->has_result, @ready;
      $self->$get_job;
    };

    while (my @job = $master->$get_job) {
        my @ready = $workers->wait;
        $master->register($_->result) if grep $_->has_result, @ready;
        my $n = @job < @ready ? $#job : $#ready;
        $ready[$_]->work($job[$_]) for 0..$n;
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
