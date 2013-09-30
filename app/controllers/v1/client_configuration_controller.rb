# Provides API for clients to obtain configuration information.
#
# Initial (and currently only) use: Multivariate (ie. A/B) Testing for iOS.

class V1::ClientConfigurationController < ApplicationController

  ##
  # Returns an array of predefined tests in a well known format.
  #
  # The Rolls themsleves are NOT returned, use the /v1/roll/:id route for that.
  #
  # By default, all tests are included.
  #
  # [GET] /v1/client_configuration/multivariate_tests
  #
  #
  def multivariate_tests
    # Using the famous Marshal dump/Marshal load trick to make a deep copy of the settings contents so
    # we don't accidentally overwrite them
    @tests = Marshal.load(Marshal.dump(Settings::ClientConfiguration.multivariate_tests))

    # We're not filtering just yet
    # See V1::RollController#featured for one example of how to filter

    #rabl caching
    @cache_key = "multivariate_tests-all"

    @status = 200
  end
  
end
