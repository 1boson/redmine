ActionMailer::Base.smtp_settings = {
  :address              => "127.0.0.1",
  :port                 => 25,
  :domain               => "1boson.com",
  :enable_starttls_auto => false
}