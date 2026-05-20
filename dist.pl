use v5.42;

package Trial {
    use Moose;
    with 'Dist::Zilla::Role::FileMunger';
    sub munge_file ($self, $file) {
        return if !($ENV{DZIL_RELEASING} && $file->name eq $self->zilla->main_module->name);
        my @line;
        for my $line (split /
/, $file->content, -1) {
            if ($line =~ /^our \$TRIAL/) {
                my $trial_line = sprintf 'our $TRIAL = %d;', $self->zilla->is_trial ? 1 : 0;
                push @line, $trial_line;
            } else {
                push @line, $line;
            }
        }
        $file->content(join "
", @line);
    }
}

package NextRelease {
    use Moose;
    extends 'Dist::Zilla::Plugin::NextRelease';
    sub after_release ($self, @) {} # noop
}

my @prereq = (
    [ Prereqs => 'ConfigureRequires' ] => [
        'Module::Build::Tiny' => '0.053',
    ],
    [ Prereqs => 'RuntimeRequires' ] => [
        'perl' => 'v5.24',
    ],
    [ Prereqs => 'TestRequires' ] => [
        'Test::More' => '0.98',
    ],
);

my @no_index = (
    'Parallel::Pipes::Impl',
    'Parallel::Pipes::Here',
    'Parallel::Pipes::There',
    'Parallel::Pipes::Impl::NoFork',
);

my @plugin = (
    'Git::GatherDir' => [ exclude_filename => 'META.json' ],
    'CopyFilesFromBuild' => [ copy => 'META.json', copy => 'Changes' ],
    'VersionFromMainModule' => [],
    'ReversionOnRelease' => [ prompt => 1 ],
    '=NextRelease' => [ format => '%v  %{yyyy-MM-dd}d%{ (TRIAL RELEASE)}T' ],
    '=Trial' => [],
    'Git::Check' => [ allow_dirty => 'Changes', allow_dirty => 'META.json' ],
    'GithubMeta' => [ issues => 1 ],
    'ReadmeAnyFromPod' => [ type => 'markdown', filename => 'README.md', location => 'root' ],
    'MetaProvides::Package' => [ inherit_version => 0, inherit_missing => 0 ],
    'MetaJSON' => [],
    'Metadata' => [ x_static_install => 1 ],
    'Git::Contributors' => [],

    'CheckChangesHasContent' => [],
    'ConfirmRelease' => [],
    'FakeRelease' => [],
    'CopyFilesFromRelease' => [ match => '\.pm$' ],
    'Git::Commit' => [ commit_msg => '%v%t', allow_dirty => 'Changes', allow_dirty => 'META.json', allow_dirty_match => '\.pm$' ],
    'Git::Tag' => [ tag_format => '%v%t', tag_message => '%v%t' ],
    'Git::Push' => [],
    'MetaNoIndex' => [ map { (package => $_) } @no_index ],

);

my @config = (
    name => 'Parallel-Pipes',
    [ @prereq, @plugin ],
);
