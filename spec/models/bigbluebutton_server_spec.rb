# -*- coding: utf-8 -*-
require 'spec_helper'

describe BigbluebuttonServer do
  it "loaded correctly" do
    BigbluebuttonServer.new.should be_a_kind_of(ActiveRecord::Base)
  end

  it { should have_many(:rooms).dependent(:nullify) }

  it { should have_many(:recordings).dependent(:nullify) }

  it { should have_one(:config).dependent(:destroy) }
  it { should delegate(:update_config).to(:config) }

  it { should delegate(:available_layouts).to(:config) }
  it { should delegate(:available_layouts_names).to(:config) }
  it { should delegate(:available_layouts_for_select).to(:config) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:url) }
  it { should validate_presence_of(:secret) }
  it { should validate_presence_of(:param) }

  context "uniqueness of" do
    before(:each) { FactoryGirl.create(:bigbluebutton_server) }
    it { should validate_uniqueness_of(:url) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:param) }
  end

  it "has associated rooms" do
    server = FactoryGirl.create(:bigbluebutton_server)
    server.rooms.should be_empty

    r = FactoryGirl.create(:bigbluebutton_room, :server => server)
    server = BigbluebuttonServer.find(server.id)
    server.rooms.should == [r]
  end

  it "has associated recordings" do
    server = FactoryGirl.create(:bigbluebutton_server)
    server.rooms.should be_empty

    r = FactoryGirl.create(:bigbluebutton_recording, :server => server)
    server = BigbluebuttonServer.find(server.id)
    server.recordings.should == [r]
  end

  it { should ensure_length_of(:name).is_at_least(1).is_at_most(500) }
  it { should ensure_length_of(:url).is_at_most(500) }
  it { should ensure_length_of(:secret).is_at_least(1).is_at_most(500) }
  it { should ensure_length_of(:param).is_at_least(3) }

  context ".to_param" do
    it { should respond_to(:to_param) }
    it {
      s = FactoryGirl.create(:bigbluebutton_server)
      s.to_param.should be(s.param)
    }
  end

  context "url format" do
    it { should allow_value('http://demo.bigbluebutton.org/bigbluebutton/api').for(:url) }
    it { should_not allow_value('').for(:url) }
    it { should_not allow_value('http://demo.bigbluebutton.org').for(:url) }
    it { should_not allow_value('demo.bigbluebutton.org/bigbluebutton/api').for(:url) }
  end

  context "supported versions" do
    it { should allow_value('0.8').for(:version) }
    it { should allow_value('0.81').for(:version) }
    it { should allow_value('0.9').for(:version) }
    it { should allow_value('').for(:version) }
    it { should allow_value(nil).for(:version) }
    it { should_not allow_value('0.64').for(:version) }
    it { should_not allow_value('0.6').for(:version) }
    it { should_not allow_value('0.7').for(:version) }
  end

  context "param format" do
    let(:msg) { I18n.t('bigbluebutton_rails.servers.errors.param_format') }
    it { should_not allow_value("123 321").for(:param).with_message(msg) }
    it { should_not allow_value("").for(:param).with_message(msg) }
    it { should_not allow_value("ab@c").for(:param).with_message(msg) }
    it { should_not allow_value("ab#c").for(:param).with_message(msg) }
    it { should_not allow_value("ab$c").for(:param).with_message(msg) }
    it { should_not allow_value("ab%c").for(:param).with_message(msg) }
    it { should_not allow_value("ábcd").for(:param).with_message(msg) }
    it { should_not allow_value("-abc").for(:param).with_message(msg) }
    it { should_not allow_value("abc-").for(:param).with_message(msg) }
    it { should_not allow_value("-").for(:param).with_message(msg) }
    it { should allow_value("_abc").for(:param).with_message(msg) }
    it { should allow_value("abc_").for(:param).with_message(msg) }
    it { should allow_value("abc").for(:param).with_message(msg) }
    it { should allow_value("123").for(:param).with_message(msg) }
    it { should allow_value("abc-123_d5").for(:param).with_message(msg) }
  end

  context "sets param as the downcased parameterized name if param is" do
    after :each do
      @server.save.should be(true)
      @server.param.should == @server.name.downcase.parameterize
    end
    it "nil" do
      @server = FactoryGirl.build(:bigbluebutton_server, :param => nil,
                              :name => "-My Name@ _Is Odd_-")
    end
    it "empty" do
      @server = FactoryGirl.build(:bigbluebutton_server, :param => "",
                              :name => "-My Name@ _Is Odd_-")
    end
  end

  context "#api" do
    let(:server) { FactoryGirl.build(:bigbluebutton_server) }
    it { should respond_to(:api) }
    it { server.api.should_not be_nil }

    context "with the correct attributes" do
      let(:api) { BigBlueButton::BigBlueButtonApi.new(server.url, server.secret, server.version, false) }
      it { server.api.should == api }

      it {
        server.url = 'http://anotherurl.com/bigbluebutton/api'
        server.api.url.should eql('http://anotherurl.com/bigbluebutton/api')
      }
      it {
        server.secret = '12345-abcde-67890-fghijk'
        server.api.secret.should eql('12345-abcde-67890-fghijk')
      }
      it {
        server.version = '0.9'
        server.api.version.should eql('0.9')
      }
    end

    context "returns the cached API object, if any" do
      it {
        BigBlueButton::BigBlueButtonApi.should_receive(:new).once.and_return("fake api")
        server.api
        server.api
      }
    end

    context "automatically fetches the API version if the version if not set" do
      before(:each) {
        server.update_attributes(version: nil)
        BigBlueButton::BigBlueButtonApi.any_instance.stub(:get_api_version).and_return("0.9")
      }
      it { server.api.version.should eql("0.9") }
      it {
        server.api
        server.version.should eql("0.9")
        server.reload.version.should be_nil # doesn't save it
      }
    end
  end

  context "initializes" do
    let(:server) { BigbluebuttonServer.new }

    it "fetched attributes before they are fetched" do
      server.meetings.should == []
    end
  end

  it { should respond_to(:fetch_meetings) }
  it { should respond_to(:meetings) }

  describe "#fetch_meetings" do
    let(:server) { FactoryGirl.create(:bigbluebutton_server) }
    let(:room1) { FactoryGirl.create(:bigbluebutton_room, :server => server, :meetingid => "room1") }
    let(:room2) { FactoryGirl.create(:bigbluebutton_room, :server => server, :meetingid => "room2") }

    # the hashes should be exactly as returned by bigbluebutton-api-ruby to be sure we are testing it right
    let(:meetings) {
      [
       { :meetingID => room1.meetingid, :attendeePW => "ap", :moderatorPW => "mp", :hasBeenForciblyEnded => false, :running => true},
       { :meetingID => room2.meetingid, :attendeePW => "pass", :moderatorPW => "pass", :hasBeenForciblyEnded => true, :running => false},
       { :meetingID => "im not in the db", :attendeePW => "pass", :moderatorPW => "pass", :hasBeenForciblyEnded => true, :running => true}
      ]
    }
    let(:hash) {
      { :returncode => true,
        :meetings => meetings
      }
    }

    before {
      @api_mock = double(BigBlueButton::BigBlueButtonApi)
      server.stub(:api).and_return(@api_mock)
      @api_mock.should_receive(:get_meetings).and_return(hash)
      server.fetch_meetings

      # the keys are updated during fetch_meetings
      room1.moderator_api_password = "mp"
      room1.attendee_api_password = "ap"
      room2.moderator_api_password = "pass"
      room2.attendee_api_password = "pass"
    }

    it { server.meetings.count.should be(3) }
    it { server.meetings[0].should have_same_attributes_as(room1) }
    it { server.meetings[1].should have_same_attributes_as(room2) }
    it { server.meetings[2].meetingid.should == "im not in the db" }
    it { server.meetings[2].name.should == "im not in the db" }
    it { server.meetings[2].server.should == server }
    it { server.meetings[2].attendee_api_password.should == "pass" }
    it { server.meetings[2].moderator_api_password.should == "pass" }
    it { server.meetings[2].running.should == true }
    it { server.meetings[2].new_record?.should be_truthy }
    it { server.meetings[2].external.should be_truthy }
    it { server.meetings[2].private.should be_truthy  }

    it "updates the meeting associated with this room"
  end

  describe "#send_publish_recordings" do
    let(:server) { FactoryGirl.create(:bigbluebutton_server) }

    it { should respond_to(:send_publish_recordings) }

    context "sends publish_recordings" do
      let(:recording1) { FactoryGirl.create(:bigbluebutton_recording, :published => false) }
      let(:recording2) { FactoryGirl.create(:bigbluebutton_recording, :published => false) }
      let(:ids) { "#{recording1.recordid},#{recording2.recordid}" }
      let(:publish) { true }
      before do
        @api_mock = double(BigBlueButton::BigBlueButtonApi)
        server.stub(:api).and_return(@api_mock)
        @api_mock.should_receive(:publish_recordings).with(ids, publish)
      end
      before(:each) { server.send_publish_recordings(ids, publish) }
      it { BigbluebuttonRecording.find(recording1.id).published.should == true }
      it { BigbluebuttonRecording.find(recording2.id).published.should == true }
    end
  end

  describe "#send_delete_recordings" do
    let(:server) { FactoryGirl.create(:bigbluebutton_server) }

    it { should respond_to(:send_delete_recordings) }

    context "sends delete_recordings" do
      let(:ids) { "id1,id2,id3" }
      before do
        @api_mock = double(BigBlueButton::BigBlueButtonApi)
        server.stub(:api).and_return(@api_mock)
        @api_mock.should_receive(:delete_recordings).with(ids)
      end
      it { server.send_delete_recordings(ids) }
    end
  end

  describe "#fetch_recordings" do
    let(:server) { FactoryGirl.create(:bigbluebutton_server) }
    let(:params) { { :meetingID => "id1,id2,id3" } }
    before do
      @api_mock = double(BigBlueButton::BigBlueButtonApi)
      server.stub(:api).and_return(@api_mock)
    end

    it { should respond_to(:fetch_recordings) }

    context "calls get_recordings" do
      let(:response) { { :recordings => [1, 2] } }
      before do
        @api_mock.should_receive(:get_recordings).with(params).and_return(response)
        BigbluebuttonRecording.should_receive(:sync).with(server, response[:recordings], false)
      end
      it { server.fetch_recordings(params) }
    end

    context "calls get_recordings when `full_sync` is set" do
      let(:response) { { :recordings => [1, 2] } }
      before do
        @api_mock.should_receive(:get_recordings).with(params).and_return(response)
        BigbluebuttonRecording.should_receive(:sync).with(server, response[:recordings], true)
      end
      it { server.fetch_recordings(params, true) }
    end

    context "calls get_recordings when `filters` is not set" do
      let(:response) { { :recordings => [1, 2] } }
      before do
        @api_mock.should_receive(:get_recordings).with({}).and_return(response)
        BigbluebuttonRecording.should_receive(:sync).with(server, response[:recordings], false)
      end
      it { server.fetch_recordings }
    end

    context "when the response is empty" do
      let(:response) { { :recordings => [1, 2] } }
      before do
        @api_mock.should_receive(:get_recordings).with(params).and_return(nil)
        BigbluebuttonRecording.should_not_receive(:sync)
      end
      it { server.fetch_recordings(params) }
    end

    context "when the response has no :recordings element" do
      before do
        @api_mock.should_receive(:get_recordings).with(params).and_return({})
        BigbluebuttonRecording.should_not_receive(:sync)
      end
      it { server.fetch_recordings(params) }
    end

    context "works without parameters" do
      before do
        @api_mock.should_receive(:get_recordings).with({}).and_return(nil)
        BigbluebuttonRecording.should_not_receive(:sync)
      end
      it { server.fetch_recordings }
    end
  end

  describe "#config" do
    it "is created when the server is created" do
      server = FactoryGirl.create(:bigbluebutton_server)
      server.config.should_not be_nil
      server.config.should be_an_instance_of(BigbluebuttonServerConfig)
      server.config.server.should eql(server)
    end

    context "if it was not created, is built when accessed" do
      before(:each) {
        @server = FactoryGirl.create(:bigbluebutton_server)
        @server.config.destroy
        @server.reload
        @server.config # access it so the new obj is created
      }
      it { @server.config.should_not be_nil }
      it("is not promptly saved") {
        @server.config.new_record?.should be(true)
      }
      it("is saved when the server is saved") {
        @server.save!
        @server.reload
        @server.config.new_record?.should be(false)
      }
    end
  end

  describe "triggers #update_config" do

    context "on after create" do
      it {
        BigbluebuttonServerConfig.any_instance.should_receive(:update_config).once
        FactoryGirl.create(:bigbluebutton_server)
      }
    end

    context "on after save" do
      let(:server) { FactoryGirl.create(:bigbluebutton_server, version: "0.8") }
      before { server.stub(:set_api_version_from_server) }

      context "if #url changed" do
        before { server.should_receive(:update_config).once }
        it { server.update_attributes(url: server.url + "-2") }
      end

      context "if #secret changed" do
        before { server.should_receive(:update_config).once }
        it { server.update_attributes(secret: server.secret + "-2") }
      end

      context "if #version changed" do
        before { server.should_receive(:update_config).once }
        it { server.update_attributes(version: "0.9") }
      end

      context "not if any other attribute changed" do
        before { server.should_not_receive(:update_config) }
        it { server.update_attributes(name: server.name + "-2") }
      end
    end
  end

  describe "triggers #set_api_version_from_server" do

    context "on after save" do
      let(:server) { FactoryGirl.create(:bigbluebutton_server, version: "0.8") }

      context "when the model is created" do
        it {
          s = FactoryGirl.build(:bigbluebutton_server, version: nil)
          s.should_receive(:set_api_version_from_server).once
          s.save
        }
      end

      context "if #url changed" do
        before { server.should_receive(:set_api_version_from_server).once }
        it { server.update_attributes(url: server.url + "-2") }
      end

      context "if #secret changed" do
        before { server.should_receive(:set_api_version_from_server).once }
        it { server.update_attributes(secret: server.secret + "-2") }
      end

      context "if #version changed" do
        before { server.should_receive(:set_api_version_from_server).once }
        it { server.update_attributes(version: "0.9") }
      end

      context "not if #name changed" do
        before { server.should_not_receive(:set_api_version_from_server) }
        it { server.update_attributes(name: server.name + "-2") }
      end

      # Specific test for when we have a version set in the server, set it to a blank value,
      # and it ends up getting the same old version from the server.
      # Depending on how the hooks to update the version are set up, this won't work.
      context "checking the real value of #version" do
        let(:version_from_api) { "0.9" }
        let(:old_version) { "0.9" }
        let(:server) { FactoryGirl.create(:bigbluebutton_server, version: version_from_api) }

        context "if #version was set to empty" do
          before {
            api_mock = double(BigBlueButton::BigBlueButtonApi)
            api_mock.stub(:version).and_return(version_from_api)
            api_mock.stub(:get_default_config_xml)
            api_mock.stub(:get_available_layouts)
            BigBlueButton::BigBlueButtonApi.stub(:new).and_return(api_mock)
          }
          it {
            server.update_attributes(version: "")
            server.reload.version.should eql(version_from_api)
          }
        end

        context "doesn't raise an exception if the server is offline" do
          before {
            BigBlueButton::BigBlueButtonApi.stub(:new) { raise BigBlueButton::BigBlueButtonException.new('test exception') }
          }
          it {
            server.update_attributes(url: "http://insert-any-invalid-url.mconf.org/bigbluebutton/api")
            server.reload.version.should be_nil
          }
        end

      end
    end
  end

end
