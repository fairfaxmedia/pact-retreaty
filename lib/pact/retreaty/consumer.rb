require 'aws-sdk-s3'
require 'pact'

module Pact
  module Retreaty
    class Consumer
      COMMON_CONFIG = [:name, :version, :s3_bucket, :s3_region, :access_key_id, :access_secret]
      UPLOAD_CONFIG = [:vcs_id]
      DOWNLOAD_CONFIG = [:pactfile, :vcs_fallbacks]
      attr_accessor *(COMMON_CONFIG + UPLOAD_CONFIG + DOWNLOAD_CONFIG)

      def self.create(options = {})
        options[:vcs_id] ||= -> { current_vcs_id }
        new(options).tap { |consumer| yield consumer if block_given? }
      end

      def upload_pacts
        verify_config!(:upload)

        spec_files.each do |path|
          key = upload_key_for_path(path)
          puts "uploading #{key}"
          s3_client.put_object(bucket: s3_bucket, key: key, body: File.read(path))
        end
      end

      def best_pact_uri
        verify_config!(:download)

        catch(:uri_found) do
          realised_vcs_fallbacks.each do |vcs_id|
            uri_for_pactfile_and_vcs_id(vcs_id)
          end
          fail("Retreaty couldn't find a suitable contract for version #{version} of #{name}, under #{realised_vcs_fallbacks.join(' or ')}")
        end
      end

      private

      def initialize(options = {})
        options.each do |k, v|
          send("#{k}=", v)
        end
      end

      def uri_for_pactfile_and_vcs_id(vcs_id)
        summary = s3_summary_for_vcs_id(vcs_id)
        throw(:uri_found, summary.presigned_url(:get)) if summary.exists?
      end

      def s3_summary_for_vcs_id(vcs_id)
        Aws::S3::ObjectSummary.new(bucket_name: s3_bucket, key: s3_path(pactfile, vcs_id), client: s3_client)
      end

      def verify_config!(context)
        required_fields = COMMON_CONFIG + (context == :download ? DOWNLOAD_CONFIG : UPLOAD_CONFIG)
        unless required_fields.select {|field| send(field).nil? }.empty?
          fail("Retreaty requires configuration for #{required_fields.join(', ')} to #{context}")
        end
      end

      def spec_files
        Dir.glob(File.join(pact_dir, '*.json'))
      end

      def upload_key_for_path(path)
        s3_path(File.basename(path), upload_vcs_id)
      end

      def upload_vcs_id
        instance_exec(&vcs_id)
      end

      def s3_path(filename, vcs_id)
        [name, version, vcs_id, filename].compact.join('/')
      end

      def realised_vcs_fallbacks
        vcs_fallbacks.call.map {|id| id == :vcs_id ? current_vcs_id : id }
      end

      # TODO - handle cases where git isn't present - configure with a proc?
      def current_vcs_id #current_branch
        `git symbolic-ref -q --short HEAD`.strip
      end

      def pact_dir
        Pact.configuration.pact_dir
      end

      def s3_client
        @client ||= Aws::S3::Client.new(region: s3_region, credentials: s3_credentials)
      end

      def s3_credentials
        Aws::Credentials.new(access_key_id, access_secret)
      end
    end
  end
end
