require 'spec_helper'
require 'qless/job'

module Qless
  describe Job do
    class JobClass
      class Nested
      end
    end

    let(:client) { stub.as_null_object }

    describe ".build" do
      it 'creates a job instance' do
        Job.build(client, JobClass).should be_a(Job)
      end

      it 'honors attributes passed as a symbol' do
        job = Job.build(client, JobClass, data: { "a" => 5 })
        job.data.should eq("a" => 5)
      end
    end

    describe "#perform" do
      it 'calls the #perform method on the job class with the job as an argument' do
        job = Job.build(client, JobClass)
        JobClass.should_receive(:perform).with(job).once
        job.perform
      end

      it 'properly finds nested classes' do
        job = Job.build(client, JobClass::Nested)
        JobClass::Nested.should_receive(:perform).with(job).once
        job.perform
      end
    end

    [
     [:fail, 'group', 'message'],
     [:complete],
     [:cancel],
     [:move, 'queue']
    ].each do |meth, *args|
      describe "##{meth}" do
        let(:job) { Job.build(client, JobClass) }

        it 'updates #state_changed? from false to true' do
          expect {
            job.send(meth, *args)
          }.to change(job, :state_changed?).from(false).to(true)
        end

        class MyCustomError < StandardError; end
        it 'does not update #state_changed? if there is a redis connection error' do
          client.stub(:"_#{meth}") { raise MyCustomError, "boom" }
          client.stub(:"_put") { raise MyCustomError, "boom" } # for #move

          expect {
            job.send(meth, *args)
          }.to raise_error(MyCustomError)
          job.state_changed?.should be_false
        end
      end
    end

    describe "#inspect" do
      let(:job) { Job.build(client, JobClass) }

      it "includes the jid" do
        job.inspect.should include(job.jid)
      end

      it "includes the job class" do
        job.inspect.should include(job.klass)
      end

      it "includes the job queue" do
        job.inspect.should include(job.queue_name)
      end
    end
  end
end

