require "rails_helper"

RSpec.describe "ApiSecurity::Configuration" do
  let(:environment) { { "FRONTEND_ORIGIN" => "https://www.example.test", "API_INTERNAL_TOKEN" => "a-test-token" } }
  let(:defaults) { ActionDispatch::RemoteIp::TRUSTED_PROXIES }

  def configuration(env)
    ApiSecurity::Configuration.from_env(env)
  end

  it "reads the required variables" do
    config = configuration(environment)

    expect(config.frontend_origin).to eq("https://www.example.test")
    expect(config.internal_token).to eq("a-test-token")
  end

  %w[FRONTEND_ORIGIN API_INTERNAL_TOKEN].each do |name|
    { "missing" => nil, "empty" => "", "blank" => "  " }.each do |state, value|
      it "raises, naming #{name}, when it is #{state}" do
        expect { configuration(environment.merge(name => value).compact) }
          .to raise_error(an_instance_of(ApiSecurity::ConfigurationError).and(having_attributes(message: /#{name}/)))
      end
    end
  end

  describe "TRUSTED_PROXIES" do
    { "unset" => nil, "empty" => "", "blank" => " " }.each do |state, value|
      it "leaves Rails' defaults unchanged when it is #{state}" do
        config = configuration(environment.merge("TRUSTED_PROXIES" => value).compact)

        expect(config.trusted_proxies).to eq(defaults)
      end
    end

    it "adds IPs and CIDRs to the defaults, ignoring spaces around them" do
      config = configuration(environment.merge("TRUSTED_PROXIES" => "192.0.2.1, 198.51.100.0/24,2001:db8::/32"))
      added = %w[192.0.2.1 198.51.100.0/24 2001:db8::/32].map { |entry| IPAddr.new(entry) }

      expect(config.trusted_proxies).to eq(defaults + added)
    end

    %w[not-an-ip 192.0.2.0/33 999.0.0.1 proxy.example.test].each do |entry|
      it "raises, naming the bad value #{entry}" do
        expect { configuration(environment.merge("TRUSTED_PROXIES" => "192.0.2.1,#{entry}")) }
          .to raise_error(an_instance_of(ApiSecurity::ConfigurationError)
            .and(having_attributes(message: /TRUSTED_PROXIES.*#{Regexp.escape(entry)}/)))
      end
    end
  end

  it "keeps the token out of inspect, which ends up in logs and error reports" do
    expect(configuration(environment).inspect).not_to include("a-test-token")
  end

  it "is read once, at boot" do
    booted = ApiSecurity.config

    expect(booted).to be_a(ApiSecurity::Configuration)
    expect(ApiSecurity.config).to equal(booted)
  end
end
