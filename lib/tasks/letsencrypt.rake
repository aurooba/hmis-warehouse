namespace :letsencrypt do

  desc "Renew Let's encrypt SSL certificate if necessary"
  task :renew, [:environment, "log:info_to_stdout"] do |task, args|
    config_file = Rails.root.join('config', 'letsencrypt_plugin.yml')
    domain = YAML.load(ERB.new(File.read(config_file), aliases: true).result)[Rails.env]['domain']
    cert_filepath = "certificates/#{domain}-fullchain.pem"
    raw = File.open(Rails.root.join(cert_filepath), 'r')
    cert = OpenSSL::X509::Certificate.new(raw)
    if Date.current > cert.not_after - 29.days
      # puts 'Requesting a new certificate'
      Rake::Task['letsencrypt_plugin'].invoke
    else
      # puts 'NOT Requesting a new certificate, old certificate is fine'
    end
  end

end
