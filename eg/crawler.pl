#!/usr/bin/env perl
use 5.34.0;
use lib "lib", "../lib";
use experimental 'signatures';
use Parallel::Pipes::App;

=head1 DESCRIPTION

This script crawles a web page, and follows links with specified depth.

You can easily change

  * a initial web page
  * the depth
  * how many crawlers

Moreover if you hack Crawler class, then it should be easy to implement

  * whitelist, blacklist for links
  * priority for links

=cut

package URLQueue {
    use constant WAITING => 1;
    use constant RUNNING => 2;
    use constant DONE    => 3;
    sub new ($class, %option) {
        bless {
            max_depth => $option{depth},
            queue => { $option{url} => { state => WAITING, depth => 0 } },
        }, $class;
    }
    sub get ($self) {
        my $queue = $self->{queue};
        map { +{ url => $_, depth => $queue->{$_}{depth} } }
            grep { $queue->{$_}{state} == WAITING } keys %$queue;
    }
    sub set_running ($self, $task) {
        $self->{queue}{$task->{url}}{state} = RUNNING;
    }
    sub register ($self, $result) {
        my $url   = $result->{url};
        my $depth = $result->{depth};
        my $next  = $result->{next};
        $self->{queue}{$url}{state} = DONE;
        return if $depth >= $self->{max_depth};
        for my $n (@$next) {
            next if exists $self->{queue}{$n};
            $self->{queue}{$n} = { state => WAITING, depth => $depth + 1 };
        }
    }
}

package Crawler {
    use Web::Scraper;
    use LWP::UserAgent;
    use Time::HiRes ();
    sub new ($class) {
        bless {
            http => LWP::UserAgent->new(timeout => 5),
            scraper => scraper { process '//a', 'url[]' => '@href' },
        }, $class;
    }
    sub crawl ($self, $url, $depth) {
        my ($res, $time) = $self->_elapsed(sub { $self->{http}->get($url) });
        if ($res->is_success and $res->content_type =~ /html/) {
            my $r = $self->{scraper}->scrape($res->decoded_content, $url);
            warn "[$$] ${time}sec \e[32mOK\e[m crawling depth $depth, $url\n";
            my @next = grep { $_->scheme =~ /^https?$/ } @{$r->{url}};
            return {url => $url, depth => $depth, next => \@next};
        } else {
            my $error = $res->is_success ? "content type @{[$res->content_type]}" : $res->status_line;
            warn "[$$] ${time}sec \e[31mNG\e[m crawling depth $depth, $url ($error)\n";
            return {url => $url, depth => $depth, next => []};
        }

    }
    sub _elapsed ($self, $cb) {
        my $start = Time::HiRes::time();
        my $r = $cb->();
        my $end = Time::HiRes::time();
        $r, sprintf("%5.3f", $end - $start);
    }
}

my $crawler = Crawler->new;
my $queue = URLQueue->new(url => "https://www.cpan.org/", depth => 2);
my @task = $queue->get;

Parallel::Pipes::App->run(
    num => 5,
    tasks => \@task,
    work => sub ($task) {
        $crawler->crawl($task->{url}, $task->{depth});
    },
    before_work => sub ($task) {
        $queue->set_running($task);
    },
    after_work => sub ($result) {
        $queue->register($result);
        @task = $queue->get;
    },
);
