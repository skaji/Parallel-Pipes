[![Actions Status](https://github.com/skaji/Parallel-Pipes/workflows/test/badge.svg)](https://github.com/skaji/Parallel-Pipes/actions)

# NAME

Parallel::Pipes - parallel processing using pipe(2) for communication and synchronization

# SYNOPSIS

    use Parallel::Pipes;

    my $pipes = Parallel::Pipes->new(5, sub {
      # this is a worker code
      my $task = shift;
      my $result = do_work($task);
      return $result;
    });

    my $queue = Your::TaskQueue->new;
    # wrap Your::TaskQueue->get
    my $get; $get = sub {
      my $queue = shift;
      if (my @task = $queue->get) {
        return @task;
      }
      if (my @written = $pipes->is_written) {
        my @ready = $pipes->is_ready(@written);
        $queue->register($_->read) for @ready;
        return $queue->$get;
      } else {
        return;
      }
    };

    while (my @task = $queue->$get) {
      my @ready = $pipes->is_ready;
      $queue->register($_->read) for grep $_->is_written, @ready;
      my $min = List::Util::min($#task, $#ready);
      for my $i (0..$min) {
        # write tasks to pipes which are ready
        $ready[$i]->write($task[$i]);
      }
    }

    $pipes->close;

# DESCRIPTION

**NOTE**: Parallel::Pipes provides low-level interfaces.
If you are interested in using Parallel::Pipes,
you may want to look at [Parallel::Pipes::App](https://metacpan.org/pod/Parallel%3A%3APipes%3A%3AApp) instead,
which provides more friendly interfaces.

Parallel processing is essential, but it is also difficult:

- How can we synchronize our workers?

    More precisely, how to detect our workers are ready or finished.

- How can we communicate with our workers?

    More precisely, how to collect results of tasks.

Parallel::Pipes tries to solve these problems with `pipe(2)` and `select(2)`.

[App::cpm](https://metacpan.org/pod/App%3A%3Acpm), a fast CPAN module installer, uses Parallel::Pipes.
Please look at [App::cpm](https://github.com/skaji/cpm/blob/master/lib/App/cpm/CLI.pm)
or [eg directory](https://github.com/skaji/Parallel-Pipes/tree/main/eg) for real world usages.

<div>
    <a href="https://raw.githubusercontent.com/skaji/Parallel-Pipes/main/author/image.png"><img src="https://raw.githubusercontent.com/skaji/Parallel-Pipes/main/author/image.png" alt="image" class="img-responsive"></a>
</div>

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
