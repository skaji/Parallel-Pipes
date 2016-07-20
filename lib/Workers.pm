package Workers;
use strict;
use warnings;
use IO::Select;

use constant WIN32 => $^O eq 'MSWin32';

our $VERSION = '0.001';

{
    package Workers::_IPC;
    use Storable ();
    sub new {
        my ($class, %option) = @_;
        my $read_fh  = delete $option{read_fh}  or die;
        my $write_fh = delete $option{write_fh} or die;
        $write_fh->autoflush(1);
        bless { %option, read_fh => $read_fh, write_fh => $write_fh }, $class;
    }
    sub read {
        my $self = shift;
        my $_size = $self->_read(4) or return;
        my $size = unpack 'I', $_size;
        my $freezed = $self->_read($size);
        my $data = Storable::thaw($freezed);
        $data->{data};
    }
    sub write {
        my ($self, $data) = @_;
        my $freezed = Storable::freeze({data => $data});
        my $size = pack 'I', length($freezed);
        $self->_write("$size$freezed");
    }
    sub _read {
        my ($self, $size) = @_;
        my $fh = $self->{read_fh};
        my $read = '';
        my $offset = 0;
        while ($size) {
            my $len = sysread $fh, $read, $size, $offset;
            if (!defined $len) {
                die $!;
            } elsif ($len == 0) {
                return;
            } else {
                $size   -= $len;
                $offset += $len;
            }
        }
        $read;
    }
    sub _write {
        my ($self, $data) = @_;
        my $fh = $self->{write_fh};
        my $size = length $data;
        my $offset = 0;
        while ($size) {
            my $len = syswrite $fh, $data, $size, $offset;
            if (!defined $len) {
                die $!;
            } elsif ($len == 0) {
                return;
            } else {
                $size   -= $len;
                $offset += $len;
            }
        }
        $size;
    }
}
{
    package Workers::Worker;
    use parent -norequire, 'Workers::_IPC';
    sub new {
        my ($class, %option) = @_;
        $class->SUPER::new(%option, _written => 0);
    }
    sub has_result {
        my $self = shift;
        $self->{_written} == 1;
    }
    sub result {
        my $self = shift;
        die if $self->{_written} == 0;
        $self->{_written}--;
        $self->read;
    }
    sub work {
        my ($self, $task) = @_;
        die if $self->{_written} == 1;
        $self->{_written}++;
        $self->write($task);
    }
}
{
    package Workers::_Worker;
    use parent -norequire, 'Workers::_IPC';
    sub run {
        my $self = shift;
        while (my $read = $self->read) {
            my $result = $self->{code}->($read);
            $self->write($result);
        }
    }
}
{
    package Workers::WorkerNoFork;
    sub new {
        my ($class, %option) = @_;
        bless {%option}, $class;
    }
    sub work {
        my ($self, $task) = @_;
        my $result = $self->{code}->($task);
        $self->{_result} = $result;
    }
    sub result {
        my $self = shift;
        delete $self->{_result};
    }
    sub has_result {
        my $self = shift;
        exists $self->{_result};
    }
}

sub new {
    my ($class, $number, $code) = @_;
    if (WIN32 and $number != 1) {
        die "The number of workers must be 1 under WIN32 environment.";
    }
    my $self = bless {
        code => $code,
        number => $number,
        no_fork => $number == 1,
        workers => {},
    }, $class;

    if ($self->no_fork) {
        $self->{workers}{-1} = Workers::WorkerNoFork->new(code => $self->{code});
    } else {
        $self->_spawn_worker for 1 .. $number;
    }
    $self;
}

sub no_fork { shift->{no_fork} }

sub _spawn_worker {
    my $self = shift;
    my $code = $self->{code};
    pipe my $read_fh1, my $write_fh1;
    pipe my $read_fh2, my $write_fh2;
    my $pid = fork;
    die "fork failed" unless defined $pid;
    if ($pid == 0) {
        close $_ for $read_fh1, $write_fh2, map { ($_->{read_fh}, $_->{write_fh}) } $self->workers;
        my $worker = Workers::_Worker->new(
            read_fh  => $read_fh2,
            write_fh => $write_fh1,
            code     => $code,
        );
        $worker->run;
        exit;
    }
    close $_ for $write_fh1, $read_fh2;
    $self->{workers}{$pid} = Workers::Worker->new(
        pid => $pid, read_fh => $read_fh1, write_fh => $write_fh2,
    );
}

sub workers {
    my $self = shift;
    map { $self->{workers}{$_} } sort { $a <=> $b } keys %{$self->{workers}};
}

sub wait :method {
    my $self = shift;
    return $self->workers if $self->no_fork;

    my @workers = @_ ? @_ : $self->workers;
    if (my @ready = grep { $_->{_written} == 0 } @workers) {
        return @ready;
    }

    my $select = IO::Select->new(map { $_->{read_fh} } @workers);
    my @ready = $select->can_read;

    my @return;
    for my $worker (@workers) {
        if (grep { $worker->{read_fh} == $_ } @ready) {
            push @return, $worker;
        }
    }
    return @return;
}

sub is_running {
    my $self = shift;
    grep { $_->has_result } $self->workers;
}

sub shutdown {
    my $self = shift;
    return $self if $self->no_fork;

    close $_ for map { ($_->{write_fh}, $_->{read_fh}) } $self->workers;
    while (%{$self->{workers}}) {
        my $pid = wait;
        if ($pid == -1) {
            warn "wait() returns -1\n";
        } elsif (my $worker = delete $self->{workers}{$pid}) {
            # OK
        } else {
            warn "wait() unexpectedly returns $pid\n";
        }
    }
    $self->{workers} = {};
    $self;
}

1;
__END__

=encoding utf-8

=head1 NAME

Workers - Blah blah blah

=head1 SYNOPSIS

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

=head1 DESCRIPTION

Workers is

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
