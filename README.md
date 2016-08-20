[![Build Status](https://travis-ci.org/skaji/Pipes.svg?branch=master)](https://travis-ci.org/skaji/Pipes)

# NAME

Pipes - The internal of cpm

# SYNOPSIS

```perl
use Pipes;

my $pipes = Pipes->new(5, sub {
  my $task = shift;
  my $result = do_work($task);
  return $result;
});

my $master = Your::Master->new;
# wrap Master's get_task
my $get_task; $get_task = sub {
  my $self = shift;
  if (my @task = $self->get_task) {
    return @task;
  }
  return unless my @written = $pipes->is_written;
  my @ready = $pipes->is_ready(@written);
  $self->register($_->read) for @ready;
  $self->$get_task;
};

while (my @task = $master->$get_task) {
  my @ready = $pipes->is_ready;
  $master->register($_->read) for grep $_->is_written, @ready;
  my $n = @task < @ready ? $#task : $#ready;
  $ready[$_]->write($task[$_]) for 0..$n;
}

$pipes->close;
```

# DESCRIPTION

This is the internal of [App::cpm](https://metacpan.org/pod/App::cpm).

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
