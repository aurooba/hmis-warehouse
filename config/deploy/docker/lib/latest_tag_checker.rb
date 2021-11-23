# gem install aws_sdk --version=3.1.5
require 'aws-sdk-elasticloadbalancingv2'
require 'aws-sdk-ecr'
require 'aws-sdk-ecs'
require 'aws-sdk-secretsmanager'
require 'byebug'

class LatestTagChecker
  attr_accessor :repo_name
  attr_accessor :image_tag
  attr_accessor :image_tag_latest
  attr_accessor :variant
  attr_accessor :target_group_name

  def initialize(target_group_name:, assume_ci_build: true, secrets_arn:, execution_role:, task_role:, dj_options: nil, web_options:, registry_id:, repo_name:, fqdn:)
    self.target_group_name = target_group_name
    self.repo_name         = repo_name
    self.variant           = 'web'
  end

  def run!
    _set_image_tag!

    results = ecs.describe_task_definition(
      task_definition: "#{target_group_name}-#{variant}"
    )
    image_tag = results.task_definition.container_definitions[0].image.split(':')[1]

    getparams = {
      repository_name: repo_name,
      image_ids: [
        {image_tag: image_tag},
        {image_tag: image_tag_latest}
      ]
    }
    images = ecr.batch_get_image(getparams).images

    if images.count > 2
      puts "❗ More than two images found during latest-* check, something is wrong."
      return
    elsif images.count < 1
      raise "❗ No images matching tag #{image_tag} found during latest-* check, something is wrong."
    elsif images.count == 2 && images[0].image_id.image_digest == images[1].image_id.image_digest
      puts "👍 Latest tag '#{image_tag_latest}' is even with tag '#{image_tag}'."
    elsif images.count == 2 && images[0].image_id.image_digest != images[1].image_id.image_digest
      puts "❗ Latest tag '#{image_tag_latest} is NOT even with tag '#{image_tag}"
    end
  end

  def _set_image_tag!
    if variant == 'pre-cache'
      self.image_tag = "#{_ruby_version}--pre-cache"
    elsif ENV['IMAGE_TAG']
      self.image_tag = ENV['IMAGE_TAG'] + "--#{variant}"
      self.image_tag_latest = "latest-" + ENV['IMAGE_TAG'] + "--#{variant}"
    else
      version = `git rev-parse --short=9 HEAD`.chomp
      self.image_tag = "githash-#{version}--#{variant}"
      self.image_tag_latest = "latest-#{target_group_name}--#{variant}"
    end

    # puts "Setting image tag to #{image_tag}"
  end

  def ecs
    @ecs ||= Aws::ECS::Client.new
  end

  def ecr
    @ecr ||= Aws::ECR::Client.new
  end
end
