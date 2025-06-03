my @prereq = (
    [ Prereqs => 'ConfigureRequires' ] => [
        'Module::Build::Tiny' => '0.052',
        'perl' => '5.008001',
    ],
    [ Prereqs => 'RuntimeRequires' ] => [
        'perl' => '5.008001',
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
    'ExecDir' => [ dir => 'script' ],
    'Git::GatherDir' => [ exclude_filename => 'META.json' ],
    'CopyFilesFromBuild' => [ copy => 'META.json' ],
    'VersionFromMainModule' => [],
    'ReversionOnRelease' => [ prompt => 1 ],
    'NextRelease' => [ format => '%v  %{yyyy-MM-dd HH:mm:ss VVV}d%{ (TRIAL RELEASE)}T' ],
    'Git::Check' => [ allow_dirty => 'Changes', allow_dirty => 'META.json' ],
    'GithubMeta' => [ issues => 1 ],
    'ReadmeAnyFromPod' => [ type => 'markdown', filename => 'README.md', location => 'root' ],
    'MetaProvides::Package' => [ inherit_version => 0, inherit_missing => 0 ],
    'PruneFiles' => [ filename => 'dist.pl', filename => 'README.md', match => '^(xt|author|maint|example|eg)/' ],
    'GitHubREADME::Badge' => [ badges => 'github_actions/test.yml' ],
    'GenerateFile' => [ filename => 'Build.PL', content => "use Module::Build::Tiny;\nBuild_PL();" ],
    'MetaJSON' => [],
    'Metadata' => [ x_static_install => 1 ],
    'Git::Contributors' => [],

    'CheckChangesHasContent' => [],
    'ConfirmRelease' => [],
    'UploadToCPAN' => [],
    'CopyFilesFromRelease' => [ match => '\.pm$' ],
    'Git::Commit' => [ commit_msg => '%v', allow_dirty => 'Changes', allow_dirty => 'META.json', allow_dirty_match => '\.pm$' ],
    'Git::Tag' => [ tag_format => '%v', tag_message => '%v' ],
    'Git::Push' => [],

    'MetaNoIndex' => [ map { (package => $_) } @no_index ],
);

my @config = (
    name => 'Parallel-Pipes',
    [ @prereq, @plugin ],
);
