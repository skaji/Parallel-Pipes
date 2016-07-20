# NAME

Workers - Blah blah blah

# SYNOPSIS

```perl
use Workers;

my $master = Your::Master->new;

my $workers = Workers->new(5, sub {
  my $task = shift;
  my $result = do_work($task);
  return $result;
});

# wrap Master's get_task
my $get_task; $get_task = sub {
  my $self = shift;
  if (my @task = $self->get_task) {
    return @task;
  }
  return unless my @running = $workers->is_running;
  my @done = $workers->wait(@running);
  $self->register($_->result) for @done;
  $self->$get_task;
};

while (my @task = $master->$get_task) {
  my @ready = $workers->wait;
  $master->register($_->result) for grep $_->has_result, @ready;
  my $n = @task < @ready ? $#task : $#ready;
  $ready[$_]->work($task[$_]) for 0..$n;
}

$workers->shutdown;
```

# DESCRIPTION

Workers is

# AUTHOR

Shoichi Kaji <skaji@cpan.org>

# COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
