require 'pathname'
require 'spec_helper'

describe Pact::Retreaty::Consumer do
  let!(:git_command) { "git symbolic-ref -q --short HEAD" }
  let!(:mock_client) { double('S3 Client') }
  let!(:mock_summary){ double('S3 Object Summary') }
  let!(:bucket_name) { 'bucket-name' }
  let(:pacts_path)   { Pathname.new(__dir__).join('..', '..', 'pacts').expand_path }
  let(:json_glob)    { "#{pacts_path}/*.json" }
  let(:json_filename){ "a_pact.json" }
  let(:json_path)    { pacts_path.join(json_filename) }
  let!(:s3_credentials){ {
    s3_bucket: bucket_name,
    s3_region: 'sydney-region',
    access_key_id: 'acess_key_id',
    access_secret: 'access_secret'
  } }
  let!(:create_options) { {
    name: 'consumer-gem',
    version: 'current_version',
    vcs_id: -> { 'change-branch' },
    pactfile: json_filename,
    vcs_fallbacks: -> { [ :vcs_id, 'develop' ] }
  }.merge(s3_credentials) }
  before do
    allow(Aws::S3::Client).to receive(:new).and_return(mock_client)
  end

  subject { described_class.create(create_options) }

  context "uploads pacts" do
    it 'with the correct path' do
      allow(Dir).to receive(:glob).with(json_glob).and_return([json_path])
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(json_path).and_return('xxx')
      expect(mock_client).to receive(:put_object) do |options|
        expect(options[:key]).to eq("consumer-gem/current_version/change-branch/a_pact.json")
      end
      subject.upload_pacts
    end
  end

  context "downloads pacts" do
    let(:branch_summary){ double("S3 Summary", exists?: true, presigned_url: 's3://consumer-gem/current_version/change-branch/a_pact.json' ) }
    let(:develop_summary){ double("S3 Summary", exists?: true, presigned_url: 's3://consumer-gem/current_version/develop/a_pact.json' ) }
    let(:non_existent_summary){ double("S3 Summary", exists?: false) }

    before do
      allow(Aws::S3::ObjectSummary).to receive(:new) do |options|
        if (options[:key] =~ /change-branch/)
          branch_summary
        else
          develop_summary
        end
      end
      allow(IO).to receive(:popen).and_call_original
    end

    it 'with the identical branch in S3' do
      allow(subject).to receive(:`).with(git_command).and_return('change-branch')
      expect(subject.best_pact_uri).to eq("s3://consumer-gem/current_version/change-branch/a_pact.json")
    end

    it 'with the fallback branch in S3' do
      allow(subject).to receive(:`).with(git_command).and_return('random-branch')
      expect(subject.best_pact_uri).to eq("s3://consumer-gem/current_version/develop/a_pact.json")
    end

    it 'with no matching branch in S3' do
      allow(Aws::S3::ObjectSummary).to receive(:new).and_return(non_existent_summary)
      allow(IO).to receive(:popen).with(git_command).and_return('missing-branch')
      expect{ subject.best_pact_uri }.to raise_error(RuntimeError)
    end

  end
end
