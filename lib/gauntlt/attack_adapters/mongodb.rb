result = "foo"

def get_profile_value(param_name)
  if param_name == nil
    return nil
  end

  gauntlt_profile.each do |name, value|
    if name == param_name
      return value
    end
  end

  nil
end

def attempt_mongo_connection(host_param, user_param = nil, pass_param = nil, use_ssl = false)

  hostname = get_profile_value(host_param)
  username = get_profile_value(user_param)
  password = get_profile_value(pass_param)

  if hostname == nil
    result = "ERROR : No server configured to run test against."

  else
    require 'mongo'
    Mongo::Logger.logger.level = Logger::WARN

    begin
      puts "Connecting to MongoDB server '#{hostname}'. Using SSL? #{use_ssl}"
      client = Mongo::Client.new([ "#{hostname}:27017" ],
                                 database: 'test',
                                 connect_timeout: 2,
                                 socket_timeout: 1,
                                 connect: :direct,
                                 server_selection_timeout: 2,
                                 ssl: use_ssl,
                                 ssl_verify: false)

      if username != nil && password != nil
        puts "Authenticating with username '#{username}' and password '#{password}'"
        client = client.with(user: username,
                             password: password,
                             auth_mech: :scram)
      end

      #puts "Client: " + client.inspect
      #puts "Database: " + client.database.inspect
      puts "Collections: " + client.database.collection_names.join(",")

      result = "SUCCESS"

    rescue Exception=>e
      puts e.message
      result = e.class.name
    end
  end

  puts result
  result
end

def assertExpectedResult(actual, expected)
  unless expected.eql?(actual)
    raise "ERROR : Expected a result of '#{expected}', but got '#{actual}'"
  end
end

Given /^"mongo" is installed$/ do
  Gem::Specification.find_by_name('mongo', '~> 2.1')
end

When /^I try (?:a|an) plaintext anonymous login to server "([^\s]+)"$/ do |host_param|
  result = attempt_mongo_connection(host_param)
end

When /^I try (?:a|an) plaintext login to server "([^\s]+)" with username "([^\s]+)" and password "([^\s]+)"$/ do |host_param, user_param, pass_param|
  result = attempt_mongo_connection(host_param, user_param, pass_param, false)
end

When /^I try (?:a|an) SSL login to server "([^\s]+)" with username "([^\s]+)" and password "([^\s]+)"$/ do |host_param, user_param, pass_param|
  result = attempt_mongo_connection(host_param, user_param, pass_param, true)
end

When /^I try (?:a|an) SSL anonymous login to server "([^\s]+)"$/ do |host_param|
  result = attempt_mongo_connection(host_param, "", "", true)
end

Then /^no valid server should be contactable$/ do
  assertExpectedResult(result, "Mongo::Error::NoServerAvailable")
end

Then /^the operation should fail$/ do
  assertExpectedResult(result, "Mongo::Error::OperationFailure")
end

Then /^the login should be refused as unauthorised$/ do
  assertExpectedResult(result, "Mongo::Auth::Unauthorized")
end

Then /^the login should be refused as an invalid authentication mechanism$/ do
  assertExpectedResult(result, "Mongo::Auth::InvalidMechanism")
end

Then /^the login should be refused due to an invalid client signature$/ do
  assertExpectedResult(result, "Mongo::Auth::InvalidSignature")
end

Then /^the login should be accepted$/ do
  assertExpectedResult(result, "SUCCESS")
end
