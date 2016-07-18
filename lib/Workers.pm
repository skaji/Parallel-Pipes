package Workers;
use strict;
use warnings;
use IO::Select;

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
        my ($self, $job) = @_;
        die if $self->{_written} == 1;
        $self->{_written}++;
        $self->write($job);
    }
}
{
    package Workers::_Worker;
    use parent -norequire, 'Workers::_IPC';
    sub run {
        my $self = shift;
        while (my $read = $self->read) {
            my $object = $self->{code}->($read);
            $self->write($object);
        }
    }
}

sub new {
    my ($class, $number, $code) = @_;
    my $self = bless {
        code => $code,
        number => $number,
        workers => {},
    }, $class;
    $self->_spawn_worker for 1 .. $number;
    $self;
}

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
            last unless my @running = $workers->is_running;
            $workers->wait(@running);
        }
    }

    while (my @job = $master->get_job) {
        my @ready = $workers->wait;
        $master->register($_->result) if grep $_->has_result, @ready;
        my $n = @job < @ready ? $#job : $#ready;
        map { $ready[$_]->work($job[$_]) } 0 .. $n;
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
