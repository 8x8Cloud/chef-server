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

describe "Cookbook Artifacts API endpoint", :cookbook_artifacts, :cookbook_artifacts_delete do

  include Pedant::RSpec::CookbookUtil

  context "DELETE /cookbooks/<name>/<version>" do
    let(:request_method) { :DELETE }
    let(:request_url){api_url("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}")}
    let(:requestor)      { admin_user }

    let(:cookbook_identifier) { "1111111111111111111111111111111111111111" }
    let(:default_version) { "1.2.3" }

    context "for non-existent cookbooks" do
      let(:expected_response) { cookbook_version_not_found_exact_response }

      let(:cookbook_name)    { "non_existent" }
      let(:cookbook_version) { "1.2.3" }

      it "returns 404" do
        response = delete(request_url, requestor)
        expect(response.code).to eq(404)
        expect(parse(response)).to eq({"error"=>["not_found"]})
      end

      context 'with bad identifier' do

        let(:cookbook_identifier) { "foo@bar" }

        it "returns 404" do
          response = delete(request_url, requestor)
          expect(response.code).to eq(404)
          expect(parse(response)).to eq({"error"=>["not_found"]})
        end

      end # with bad version
    end # context for non-existent cookbooks

    context "for existing cookbooks" do

      let(:cookbook_name) { "cookbook-to-be-deleted" }

      context "when deleting non-existent version of an existing cookbook" do
        let(:non_existing_identifier) { "ffffffffffffffffffffffffffffffffffffffff" }
        let(:non_existing_version_url) { api_url("/cookbook_artifacts/#{cookbook_name}/#{non_existing_identifier}") }

        before(:each) { make_cookbook_artifact("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}") }

        it "should respond with 404 (\"Not Found\") and not delete existing versions" do
          delete(non_existing_version_url, requestor) do |response|
            expect(response.code).to eq(404)
            expect(parse(response)).to eq({"error"=>["not_found"]})
          end

          expect(get(request_url, requestor).code).to eq(200)
        end
      end # it doesn't delete the wrong version of an existing cookbook

      context "when deleting existent version of an existing cookbook", :smoke do

        let(:recipe_name) { "test_recipe" }
        let(:recipe_content) { "hello-#{unique_suffix}" }
        before(:each) do
          recipe_spec = {
            :name => recipe_name,
            :content => recipe_content
          }
          make_cookbook_artifact_with_recipes("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}", [recipe_spec])
        end

        it "should cleanup unused checksum data in s3/bookshelf" do
          artifact_json = get(request_url, requestor)
          expect(artifact_json.code).to eq(200)
          artifact_before_delete = parse(artifact_json)
          existing_recipes = artifact_before_delete["recipes"]

          expect(existing_recipes.size).to eq(1)
          remote_recipe_spec = existing_recipes.first
          expect(remote_recipe_spec).to be_a_kind_of(Hash)

          expect(remote_recipe_spec["name"]).to eq("test_recipe.rb")
          expect(remote_recipe_spec["path"]).to eq("recipes/test_recipe.rb")
          expect(remote_recipe_spec["checksum"]).to be_a_kind_of(String)
          expect(remote_recipe_spec["specificity"]).to eq("default")
          expect(remote_recipe_spec["url"]).to be_a_kind_of(String)

          delete_response = delete(request_url, requestor)
          expect(delete_response.code).to eq(200)

          verify_checksum_url(remote_recipe_spec["url"], 404)
        end

      end # context when deleting existent version...
    end # context for existing cookbooks

    context "with permissions for" do
      let(:cookbook_name) {"delete-cookbook"}
      let(:cookbook_identifier) { "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
      let(:not_found_msg) { ["Cannot find a cookbook named delete-cookbook with version 0.0.1"] }

      let(:original_cookbook) { new_cookbook_artifact(cookbook_name, cookbook_identifier) }
      let(:fetched_cookbook) { original_cookbook.dup.tap { |c| c.delete("json_class") } }

      before(:each) { make_cookbook_artifact("/cookbook_artifacts/#{cookbook_name}/#{cookbook_identifier}") }

      context 'as admin user' do

        it "should respond with 200 (\"OK\") and be deleted" do
          delete_response = delete(request_url, admin_user)
          expect(delete_response.code).to eq(200)
          expect(parse(delete_response)).to eq(fetched_cookbook)

          expect(get(request_url, admin_user).code).to eq(404)
        end # it admin user returns 200
      end # as admin user

      context 'as normal user', :authorization do
        let(:expected_response) { delete_cookbook_success_response }

        let(:requestor) { normal_user }
        it "should respond with 200 (\"OK\") and be deleted" do
          expect(delete(request_url, requestor).code).to eq(200)
        end # it admin user returns 200
      end # with normal user

      context 'as a user outside of the organization', :authorization do
        let(:expected_response) { unauthorized_access_credential_response }
        let(:requestor) { outside_user }

        it "should respond with 403 (\"Forbidden\") and does not delete cookbook" do
          response.should look_like expected_response
          should_not_be_deleted
        end
      end # it outside user returns 403

      context 'with invalid user', :authorization do
        let(:expected_response) { invalid_credential_exact_response }
        let(:requestor) { invalid_user }

        it "should respond with 401 (\"Unauthorized\") and does not delete cookbook" do
          response.should look_like expected_response
          should_not_be_deleted
        end # responds with 401
      end # with invalid user

    end # context with permissions for
  end # context DELETE /cookbooks/<name>/<version>
end
