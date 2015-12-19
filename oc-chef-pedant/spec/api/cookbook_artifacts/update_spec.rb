# -*- coding: utf-8 -*-
# Copyright: Copyright (c) 2015 Chef Software, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'pedant/rspec/cookbook_util'

# FIXME For /cookbooks/NAME/VERSION tests we have a limited checking
# on the GET afterwards to do validation of data on the server.  Since
# we can't match the payload against one with dynamically generated
# URLs we're only checking for the return code.
#
# We need to come back (along with adding tests for the GET case
# explicitly in read_spec.rb) and update the tests marked with TODO
# to actually match on the generate response body as well
#

describe "Cookbook Artifacts API endpoint", :cookbook_artifacts, :cookbook_artifacts_update do

  include Pedant::RSpec::CookbookUtil

  context "PUT /cookbooks/<name>/<version> [update]" do

    # for respects_maximum_payload_size
    let(:request_method) { :PUT }
    let(:requestor){admin_user}
    let(:request_url){api_url("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}")}
    let(:cookbook_name) { "cookbook-to-be-modified" }
    let(:cookbook_identifier) { "1111111111111111111111111111111111111111" }
    let(:default_version) { "1.2.3" }

    let(:updated_cookbook_artifact) do
      new_cookbook_artifact(cookbook_name, cookbook_identifier).tap do |payload|
        payload["metadata"]["description"] = "hi there"
      end
    end

    before(:each) {
      make_cookbook_artifact("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}")
    }

    respects_maximum_payload_size


    context "as admin user" do

      let(:fetched_cookbook_artifact) do
        new_cookbook_artifact(cookbook_name, cookbook_identifier).tap do |c|
          c.delete("json_class")
        end
      end

      it "should respond with 409 Conflict", :smoke do
        put(request_url, admin_user, :payload => updated_cookbook_artifact) do |response|
          expect(response).to look_like({
            :status => 409,
            :body_exact => {"error"=>"Cookbook artifact already exists"}
          })
        end

        # verify change didn't happen
        get(request_url, admin_user) do |response|
          expect(response).to look_like({
            :status => 200,
            :body => fetched_cookbook_artifact
          })
        end
      end # it admin user returns 200

      context 'as a user outside of the organization', :authorization do
        let(:expected_response) { unauthorized_access_credential_response }

        it "should respond with 403 (\"Forbidden\") and does not update cookbook" do
          put(request_url, outside_user, :payload => updated_cookbook_artifact) do |response|
            response.should look_like expected_response
          end

          # verify change didn't happen
          get(request_url, admin_user) do |response|
            expect(response).to look_like({
              :status => 200,
              :body => fetched_cookbook_artifact
            })
          end
        end # it outside user returns 403 and does not update cookbook
      end

      context 'with invalid user', :authentication do
        let(:expected_response) { invalid_credential_exact_response }

        it "returns 401 and does not update cookbook" do
          put(request_url, invalid_user, :payload => updated_cookbook_artifact) do |response|
            response.should look_like expected_response
          end

          # verify change didn't happen
          get(request_url, admin_user) do |response|
            expect(response).to look_like({
              :status => 200,
              :body => fetched_cookbook_artifact
            })
          end
        end # it invalid user returns 401 and does not update cookbook
      end # with invalid user
    end # context with permissions for
  end # context PUT /cookbooks/<name>/<version> [update]
end
