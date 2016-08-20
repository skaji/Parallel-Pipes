package Pipes;
use strict;
use warnings;
use IO::Handle;
use IO::Select;

use constant WIN32 => $^O eq 'MSWin32';

our $VERSION = '0.001';

{
    package Pipe::Impl;
    use Storable ();
    sub new {
        my ($class, %option) = @_;
        my $read_fh  = delete $option{read_fh}  or die;
        my $write_fh = delete $option{write_fh} or die;
        $write_fh->autoflush(1);
        bless { %option, read_fh => $read_fh, write_fh => $write_fh }, $class;
    }
    sub read :method {
        my $self = shift;
        my $_size = $self->_read(4) or return;
        my $size = unpack 'I', $_size;
        my $freezed = $self->_read($size);
        my $data = Storable::thaw($freezed);
        $data->{data};
    }
    sub write :method {
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
    package Pipe::Here;
    use parent -norequire, 'Pipe::Impl';
    sub new {
        my ($class, %option) = @_;
        $class->SUPER::new(%option, _written => 0);
    }
    sub is_written {
        my $self = shift;
        $self->{_written} == 1;
    }
    sub read :method {
        my $self = shift;
        die if $self->{_written} == 0;
        $self->{_written}--;
        $self->SUPER::read;
    }
    sub write :method {
        my ($self, $task) = @_;
        die if $self->{_written} == 1;
        $self->{_written}++;
        $self->SUPER::write($task);
    }
}
{
    package Pipe::There;
    use parent -norequire, 'Pipe::Impl';
    sub run {
        my $self = shift;
        while (my $read = $self->read) {
            $self->write( $self->{code}->($read) );
        }
    }
}
{
    package Pipe::Impl::NoFork;
    sub new {
        my ($class, %option) = @_;
        bless {%option}, $class;
    }
    sub write :method {
        my ($self, $task) = @_;
        my $result = $self->{code}->($task);
        $self->{_result} = $result;
    }
    sub read :method {
        my $self = shift;
        delete $self->{_result};
    }
    sub is_written {
        my $self = shift;
        exists $self->{_result};
    }
}

sub new {
    my ($class, $number, $code) = @_;
    if (WIN32 and $number != 1) {
        die "The number of pipes must be 1 under WIN32 environment.\n";
    }
    my $self = bless {
        code => $code,
        number => $number,
        no_fork => $number == 1,
        pipes => {},
    }, $class;

    if ($self->no_fork) {
        $self->{pipes}{-1} = Pipe::Impl::NoFork->new(code => $self->{code});
    } else {
        $self->_fork for 1 .. $number;
    }
    $self;
}

sub no_fork { shift->{no_fork} }

sub _fork {
    my $self = shift;
    my $code = $self->{code};
    pipe my $read_fh1, my $write_fh1;
    pipe my $read_fh2, my $write_fh2;
    my $pid = fork;
    die "fork failed" unless defined $pid;
    if ($pid == 0) {
        close $_ for $read_fh1, $write_fh2, map { ($_->{read_fh}, $_->{write_fh}) } $self->pipes;
        my $there = Pipe::There->new(
            read_fh  => $read_fh2,
            write_fh => $write_fh1,
            code     => $code,
        );
        $there->run;
        exit;
    }
    close $_ for $write_fh1, $read_fh2;
    $self->{pipes}{$pid} = Pipe::Here->new(
        pid => $pid, read_fh => $read_fh1, write_fh => $write_fh2,
    );
}

sub pipes {
    my $self = shift;
    map { $self->{pipes}{$_} } sort { $a <=> $b } keys %{$self->{pipes}};
}

sub is_ready {
    my $self = shift;
    return $self->pipes if $self->no_fork;

    my @pipes = @_ ? @_ : $self->pipes;
    if (my @ready = grep { $_->{_written} == 0 } @pipes) {
        return @ready;
    }

    my $select = IO::Select->new(map { $_->{read_fh} } @pipes);
    my @ready = $select->can_read;

    my @return;
    for my $pipe (@pipes) {
        if (grep { $pipe->{read_fh} == $_ } @ready) {
            push @return, $pipe;
        }
    }
    return @return;
}

sub is_written {
    my $self = shift;
    grep { $_->is_written } $self->pipes;
}

sub close :method {
    my $self = shift;
    return $self if $self->no_fork;

    close $_ for map { ($_->{write_fh}, $_->{read_fh}) } $self->pipes;
    while (%{$self->{pipes}}) {
        my $pid = wait;
        if (delete $self->{pipes}{$pid}) {
            # OK
        } else {
            warn "wait() unexpectedly returns $pid\n";
        }
    }
    $self->{pipes} = {};
    $self;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pipes - The internal of cpm

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This is the internal of L<App::cpm>.

=head1 AUTHOR

Shoichi Kaji <skaji@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2016 Shoichi Kaji <skaji@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
