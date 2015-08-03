require 'spec_helper'

describe Travis::Build::Script::Php, :sexp do
  let(:data)     { payload_for(:push, :php) }
  let(:script)   { described_class.new(data) }
  subject(:sexp) { script.sexp }
  it             { store_example }

  it_behaves_like 'compiled script' do
    let(:code) { ['TRAVIS_LANGUAGE=php'] }
    let(:cmds) { ['phpunit'] }
  end

  it_behaves_like 'a build script sexp'

  it 'sets TRAVIS_PHP_VERSION' do
    should include_sexp [:export, ['TRAVIS_PHP_VERSION', '5.5']]
  end

  it 'sets up the php version' do
    should include_sexp [:cmd, 'phpenv global 5.5 2>/dev/null', echo: true, timing: true]
    should include_sexp [:cmd, 'phpenv rehash']
  end

  it 'announces php --version' do
    should include_sexp [:cmd, 'php --version', echo: true]
  end

  it 'announces composer --version' do
    should include_sexp [:cmd, 'composer --version', echo: true]
  end

  it 'runs phpunit' do
    should include_sexp [:cmd, 'phpunit', echo: true, timing: true]
  end

  describe 'installs php nightly' do
    before { data[:config][:php] = 'nightly' }
    it { should include_sexp [:cmd, 'curl -s -o archive.tar.bz2 https://s3.amazonaws.com/travis-php-archives/php-nightly-archive.tar.bz2 && tar xjf archive.tar.bz2 --directory ~/.phpenv/versions/', timing: true] }
  end

  describe 'installs php 7' do
    before { data[:config][:php] = '7' }
    it { should include_sexp [:cmd, 'ln -s ~/.phpenv/versions/nightly ~/.phpenv/versions/7', assert: true, timing: true] }
  end

  describe 'fixes php.ini for hhvm' do
    let(:path)     { '/etc/hhvm/php.ini' }
    let(:addition) { %(date.timezone = "UTC"\nhhvm.libxml.ext_entity_whitelist=file,http,https\n) }
    before { data[:config][:php] = 'hhvm' }
    it { should include_sexp [:raw, "sudo mkdir -p $(dirname #{path}); echo '#{addition}' | sudo tee -a #{path} > /dev/null"] }
    it { should include_sexp [:raw, "sudo chown $(whoami) #{path}"] }
    it { should include_sexp [:raw, "grep session.save_path #{path} | cut -d= -f2 | sudo xargs mkdir -m 01733 -p"] }
  end

  describe 'installs hhvm-nightly' do
    before { data[:config][:php] = 'hhvm-nightly' }
    it { should include_sexp [:cmd, 'sudo apt-get update -qq'] }
    it { should include_sexp [:cmd, 'sudo apt-get install hhvm-nightly 2>&1 >/dev/null'] }
  end

  describe 'when desired PHP version is not found' do
    let(:version) { '7.0.0beta2' }
    let(:data) { payload_for(:push, :php, config: { php: version }) }
    let(:sexp) { sexp_find(subject, [:if, "$? -ne 0"], [:then]) }

    it 'installs PHP version on demand' do
      expect(sexp).to include_sexp [:cmd, "curl -s -o archive.tar.bz2 https://s3.amazonaws.com/travis-php-archives/php-#{version}-archive.tar.bz2 && tar xjf archive.tar.bz2 --directory ~/.phpenv/versions/", timing: true]
    end
  end

  # describe 'before_install' do
  #   subject { sexp_filter(sexp, [:if, '-f composer.json'])[0] }

  #   it 'runs composer self-update if composer.json exists' do
  #     should include_sexp [:cmd, 'composer self-update', assert: true, echo: true, timing: true]
  #   end
  # end

  # describe 'install' do
  #   subject { sexp_filter(sexp, [:if, '-f composer.json'])[1] }

  #   describe 'runs composer install if composer.json exists' do
  #     it { should include_sexp [:cmd, 'composer install', assert: true, echo: true, timing: true] }
  #   end

  #   describe 'uses given composer_args' do
  #     before { data[:config].update(composer_args: '--some --args') }
  #     it { should include_sexp [:cmd, 'composer install --some --args', assert: true, echo: true, timing: true] }
  #   end
  # end
end
