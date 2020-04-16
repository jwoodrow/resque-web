require 'test_helper'

module ResqueWeb
  class PluginIntegrationTest < ActionDispatch::IntegrationTest

    module ResqueWeb::Plugins::ResqueWebTestPlugin
      class Engine < ::Rails::Engine
        isolate_namespace ResqueWeb::Plugins::ResqueWebTestPlugin
      end
      class PlugintestController < ApplicationController
        def index
          if Rails.version >= '4.1.0'
            render html: "hello from test plugin", layout: true
          else
            render text: "hello from test plugin", layout: true
          end
        end
      end

      Engine.routes.draw do
        resources :plugintest, :only => [:index]
        root to: 'plugintest#index'
      end
      def self.engine_path
        "/plugin_test"
      end
      def self.tabs
        [{'plugin test' => Engine.app.url_helpers.plugintest_index_path}]
      end
    end

    def visit(action, params = {}, options = {})
      method = options.delete(:method) || :get

      user = ENV["RESQUE_WEB_HTTP_BASIC_AUTH_USER"]
      password = ENV["RESQUE_WEB_HTTP_BASIC_AUTH_PASSWORD"]

      if options[:auth] == :disabled
        ENV["RESQUE_WEB_HTTP_BASIC_AUTH_USER"] = nil
        ENV["RESQUE_WEB_HTTP_BASIC_AUTH_PASSWORD"] = nil
      else
        env = {}
        env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(
          options[:user] || user, options[:password] || password
        ) unless options[:auth] == false
      end

      if Rails.version >= '5.0.0'
        send(method, action, params: params, env: env)
      else
        send(method, action, params, env)
      end

      ENV["RESQUE_WEB_HTTP_BASIC_AUTH_USER"] = user
      ENV["RESQUE_WEB_HTTP_BASIC_AUTH_PASSWORD"] = password
    end

    setup do
      @routes = Engine.routes
      Dummy::Application.reload_routes!
    end

    describe "resque web plugins" do
      it "adds the routes" do
        paths = @routes.routes.map{|m| m.path.spec.to_s}
        _(paths).must_include "/plugin_test"
      end

      it "renders the plugins action" do
        visit "/resque_web/plugin_test/plugintest"
        _(@response.body).must_include "hello from test plugin"
      end

      it "adds a tab for the plugin" do
        visit "/resque_web/"
        _(@response.body).must_include "<a href=\"/resque_web/plugin_test/plugintest\">Plugin test</a>"
      end
    end
  end
end
